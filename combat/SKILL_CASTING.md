# 共享技能栏、CurrentElement 与技能释放系统

本模块实现全元素共享技能栏、唯一 CurrentElement、整数能量、可选冷却、原子释放事务和唯一玩法状态机。

## 文件与职责

| 类型 | 路径 | 职责 |
| --- | --- | --- |
| `SkillDefinition` | `definitions/skill_definition.gd` | 技能公共元数据；主动携带一个类型化 `SkillExecutionDefinition`，被动携带一个类型化 `PassiveEffectDefinition` |
| `SkillLoadout` | `definitions/skill_loadout.gd` | 共享四槽静态模板；旧元素 Loadout 仅作为迁移输入 |
| `CastAttemptResult` | `contracts/cast_attempt_result.gd` | 不可变的成功 `CastSnapshot + SkillExecutionSnapshot` 或结构化拒绝 |
| `DeliverySpawnSnapshot` | `contracts/delivery_spawn_snapshot.gd` | 接受释放时锁定的初始 Transform 与方向 |
| `CurrentElementController` | `components/current_element_controller.gd` | 每角色唯一 CurrentElement 与提交后结构化通知 |
| `EnergyComponent` | `components/energy_component.gd` | 每角色独立的整数能量、确定性自动恢复与提交后通知 |
| `SkillCooldowns` | `components/skill_cooldowns.gd` | 每 Executor 独立的剩余冷却 |
| `SkillExecutor` | `components/skill_executor.gd` | 多态执行定义的原子 prepare/commit、类型化快照和唯一时序状态机 |
| `SkillController` | `components/skill_controller.gd` | 从共享 Runtime Loadout 解析槽位；不创建 Loadout、不读取输入 |

Resource 只保存静态配置。CurrentElement、共享 Runtime Loadout、能量、剩余冷却、当前 Cast、阶段时间和 Delivery 记录都在运行时实例中。Runtime Loadout 由运行局入口创建一次。

主动技能的旧顶层 `energy_cost / active_time / delivery_scene / payload` 已移除。`RuntimeSkillLoadout` 在目录构建时调用执行定义的 `catalog_validation_error()`；被动绑定直接携带 `PassiveEffectDefinition`，不再携带或解释 `passive_effect_id`。

| 执行定义 | 运行语义 |
| --- | --- |
| `InstantDeliveryExecution` | 固定能量、一次预创建并初始化的 Delivery |
| `AllEnergyBurstExecution` | 达到门槛后锁定并消耗接受时的全部能量，产出伤害/附着/半径快照 |
| `ChannelExecution` | 精确间隔扣能和产生 `ChannelTickSnapshot`，支持释放与结构化结束 |
| `ElementReclaimExecution` | 先通过 `ElementReclaimPort.prepare()` 得到已验证提交事务，再原子提交功能效果 |

`CURRENT_ELEMENT` 主动技能在接受时锁定 CurrentElement；`EXCLUSIVE_ELEMENT` 在接受事务内自动切换并锁定专属元素；`NEUTRAL` 锁定 `ElementIds.NONE`。

## 状态图与转换条件

```text
IDLE
  └─ try_cast 成功 ─> STARTUP
                       ├─ startup_time 到达 ─> ACTIVE
                       │                       ├─ 进入时激活已准备的执行 Runtime
                       │                       ├─ Runtime 可生成 Delivery 或零到多个 Tick
                       │                       └─ Runtime 返回类型化结束结果 ─> RECOVERY
                       │                                             └─ recovery_time 到达 ─> IDLE
                       └─ cancel / pause / 离树 ─> CANCELLED ─> IDLE

ACTIVE、RECOVERY 也可由 cancel / pause / 离树进入 CANCELLED。
```

- `advance(delta)` 是可直接测试的确定性时钟；`_process(delta)` 只是调用它。
- 一个大 `delta` 会按 STARTUP → ACTIVE → RECOVERY → IDLE 逐段推进，零时长阶段也不会被跳过。
- ACTIVE 进入时最多把已准备的 Delivery 加入世界一次；引导 Runtime 可在一次 `advance(delta)` 内跨越多个完整 Tick。离开 ACTIVE 时通过 `DeliveryBase.close_hit_window()` 关闭命中窗。
- CANCELLED 是同步通知阶段，通知完成后立刻回到 IDLE，不会留下永久忙碌。
- 动画只可调用带当前 `cast_id` 校验的 `notify_presentation_marker()`；该方法不能扣费、生成 Delivery 或推进状态。
- `cancel_current_cast(reason, expected_cast_id)` 可用 token 拒绝迟到的旧回调。

## 原子 try_cast

正式入口由 `SkillController` 从 `RuntimeSkillLoadout` 取出技能，再进入 Executor 的已验证路径。Runtime Loadout 构造时会一次性验证每个类型化执行定义；`InstantDeliveryExecution` 额外确认其 `delivery_scene` 根节点继承 `DeliveryBase`。正常释放不再重复实例化探针或做动态方法检查。Executor 不提供绕过目录的公开施法旁路。

一次同步释放事务按以下顺序执行：

1. 检查忙碌/重入、槽位、主动类型、依赖、身份和外部门禁。
2. 调用属性与出生点 Provider，得到不可变候选数据。
3. 在所有回调结束后复查 Delivery 父节点、CurrentElement、能量与冷却。
4. 构造 `SkillExecutionContext`，由具体定义完成纯 `prepare()`，生成不可变 `SkillExecutionSnapshot`、Runtime，以及可选的 Delivery/功能提交事务。
5. 对需要 Delivery 的策略，在树外实例化并完成 `initialize_delivery()`；对功能策略，完成所有可失败查询和事务验证。
6. 静默提交功能事务、能量、冷却、元素、当前 Cast、Runtime 和 STARTUP。
7. 全部状态完成后再发布 element/phase/cast/execution/cooldown/energy/功能事务通知。

任一准备步骤失败都不会扣能量、开始冷却、切换元素或留下半创建节点。接受后的取消遵循 `energy_refund_policy`：`BEFORE_DELIVERY` 可在 Delivery 尚未加入世界时退还能量，但已提交冷却和自动元素切换不回滚；`NEVER` 不退款。

能量默认每秒恢复 5 点，消费后延迟 1 秒开始；小数恢复量跨帧累计，到整数时才提交并发出通知。恢复暂停时延迟也暂停。正式 Player 在 STARTUP/ACTIVE、受击和死亡期间暂停恢复，在 RECOVERY/IDLE 且未受击时恢复推进。
### 结构化拒绝原因

| 枚举 | `reason_name()` | 含义 |
| --- | --- | --- |
| `NONE` | `none` | 成功 |
| `BUSY` | `busy` | 当前非 IDLE，或事务/推进正在发布 |
| `INSUFFICIENT_ENERGY` | `insufficient_energy` | 能量不足 |
| `COOLDOWN_ACTIVE` | `cooldown_active` | 特殊技能仍在冷却；结果携带 `cooldown_remaining` |
| `ELEMENT_UNAVAILABLE` | `element_unavailable` | 技能需要的元素不在可用列表中 |
| `EXTERNAL_GATE_REJECTED` | `external_gate_rejected` | Player 动作门禁拒绝 |
| `INVALID_CONFIGURATION` | `invalid_configuration` | Skill、Payload、身份、Provider 返回值等配置非法；`detail` 给出细因 |
| `SLOT_UNASSIGNED` | `slot_unassigned` | 共享槽位未配置 |
| `MISSING_COMPONENT` | `missing_component` | 缺少 Energy/CurrentElement/Executor |
| `DELIVERY_UNAVAILABLE` | `delivery_unavailable` | Delivery 根类型、实例化、初始化或父节点不可用 |
| `NO_LEGAL_TARGET` | `no_legal_target` | 功能执行在准备期未找到合法目标；不提交能量、冷却或成功表现 |
| `NO_BENEFIT` | `no_benefit` | 功能执行在准备期确定没有收益；不提交能量、冷却或成功表现 |

## Agent D 最小接线

```gdscript
# 建议在 Player 的组件均入树后执行。
skill_executor.configure_dependencies(
    $EnergyComponent,
    $ElementFormController,
    get_tree().current_scene, # Delivery 的世界父节点，必须在 SceneTree 中
)
skill_executor.configure_cast_identity(
    get_instance_id(), # root_owner_id
    get_instance_id(), # caster_id
    &"player",
)

skill_executor.set_external_action_gate(
    func(_skill: SkillDefinition) -> bool:
        return player_can_start_skill()
)
skill_executor.set_stat_snapshot_provider(
    func(_skill: SkillDefinition) -> CombatStatSnapshot:
        return CombatStatSnapshot.new(attack_multiplier, flat_damage_bonus)
)
skill_executor.set_spawn_snapshot_provider(
    func(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
        var direction := Vector2.RIGHT if facing_right else Vector2.LEFT
        return DeliverySpawnSnapshot.new(global_transform, direction)
)

skill_controller.configure_runtime(
    $ElementFormController, # node name may stay stable
    $SkillExecutor,
    runtime_loadout,
)
```

按槽位释放，不在组件里硬编码 Q/J/鼠标：

```gdscript
var attempt := skill_controller.try_cast_slot(&"primary")
if not attempt.accepted:
    match attempt.reject_reason:
        CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY:
            show_energy_warning()
        CastAttemptResult.RejectReason.COOLDOWN_ACTIVE:
            show_cooldown(attempt.cooldown_remaining)
```

切形态和取消：

```gdscript
skill_controller.request_element(ElementIds.FIRE)
skill_controller.cycle_next()

# 受击、死亡或集成层明确中止；可传当前 token 防止旧回调误取消新 Cast。
skill_controller.cancel_current_cast(&"hit", skill_executor.current_cast_id)
```

可订阅的提交后通知：

```text
CurrentElementController.element_changed(result)
EnergyComponent.energy_changed(current, maximum, delta)
SkillController.cast_attempted(slot_id, result)
SkillExecutor.cast_started(cast_snapshot, payload)
SkillExecutor.phase_changed(cast_id, previous, current)
SkillExecutor.delivery_spawned(cast_id, delivery_id, node)
SkillExecutor.execution_started(snapshot)
SkillExecutor.execution_activated(snapshot)
SkillExecutor.execution_tick_generated(channel_tick_snapshot)
SkillExecutor.execution_ended(snapshot, end_result)
SkillExecutor.cast_cancelled(cast_snapshot, reason)
SkillExecutor.cast_finished(cast_snapshot)
SkillExecutor.cooldown_started / cooldown_finished
```

Player 继续权威管理输入、移动、受击和动画。它只根据 phase 通知决定移动锁和表现，不直接修改 Executor 内部时间。

移动锁不能按技能 ID 猜测。Player 应读取 `skill_executor.current_movement_policy`；`ChannelExecution` 明确返回 `ALLOW_MOVEMENT`。按住结束时调用 `request_channel_release(current_cast_id)`，受击、死亡、暂停或离树仍调用通用取消入口。

普通攻击仍位于共享四槽之外；Player 只持有稳定的 BASIC_ATTACK_SKILL_ID，并从本局唯一 RuntimeSkillLoadout 目录解析定义，不再保存第二份导出 Resource。

## Agent C Delivery 初始化协议

每个 `delivery_scene` 根节点必须继承 `DeliveryBase`。`initialize_delivery()` 与 `close_hit_window()` 是强类型基类协议，不再接受只靠同名方法的鸭子类型节点：

```gdscript
class_name CustomDelivery
extends DeliveryBase

func _on_delivery_ready() -> void:
    # 此时已经 add_child，可启动运行时行为。
    pass

func close_hit_window() -> void:
    # 只有需要主动命中窗的类型才需覆盖；基类默认无操作。
    pass
```

Executor 的顺序是：

```text
RuntimeSkillLoadout 构造：实例化探针 → 验证根节点类型 → 释放探针（每个目录一次）
释放准备：实例化真实 DeliveryBase → initialize_delivery(snapshot, payload, 1, transform, direction)
事务提交：能量 / 冷却 / 元素 / Cast / STARTUP
进入 ACTIVE：delivery_parent.add_child(delivery) → delivery_spawned
```

初始化返回 `false` 时，释放会以结构化 `DELIVERY_UNAVAILABLE` 拒绝，资源保持不变。投递加入世界后不由 Executor 销毁；施法者后续切形态不会重算或重染已锁定 Payload。若 STARTUP 期间取消或父节点失效，尚未入树的准备实例会被释放，并按技能退款策略处理。
## 自动测试

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_skill_tests.gd
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_combat_tests.gd
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_skill_execution_contract_tests.gd
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_passive_runtime_contract_tests.gd
```

当前结果：

- Agent B：28 tests，144 assertions，通过。
- Agent A 回归：27 tests，124 assertions，通过。
- Task 14 主动执行契约：12 tests，72 assertions，通过。
- Task 14 被动 Runtime 契约：5 tests，55 assertions，通过。
- 测试覆盖水/火通用技能、中立 Cast、专属形态拒绝、原子扣费/冷却、5 点/秒恢复与暂停、零冷却重放、STARTUP/ACTIVE 打断、接受通知期延迟取消、预检回调重入、飞行中切形态、大 delta、旧 token、暂停/离树、共享 Skill 与 Loadout Resource 的双角色隔离。
