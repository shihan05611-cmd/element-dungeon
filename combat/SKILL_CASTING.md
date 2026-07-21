# Agent B：元素形态与技能释放系统

本模块实现玩家侧的水/火形态、独立技能槽、整数能量、可选冷却、原子释放事务和唯一玩法状态机。它只依赖 Agent A 已冻结的 `CastSnapshot`、`RuntimeAttackPayload`、`CombatStatSnapshot` 与 `ElementIds`，不修改 Player、Enemy、主场景或具体 Delivery 内部。

## 文件与职责

| 类型 | 路径 | 职责 |
| --- | --- | --- |
| `SkillDefinition` | `definitions/skill_definition.gd` | 静态技能 ID、形态限制、三段时序、能量、冷却、Delivery Scene、Payload |
| `SkillLoadout` | `definitions/skill_loadout.gd` | 单一形态的静态槽位映射 |
| `CastAttemptResult` | `contracts/cast_attempt_result.gd` | 不可变的成功快照或结构化拒绝 |
| `DeliverySpawnSnapshot` | `contracts/delivery_spawn_snapshot.gd` | 接受释放时锁定的初始 Transform 与方向 |
| `ElementFormController` | `components/element_form_controller.gd` | 每角色独立的水/火形态与提交后通知 |
| `EnergyComponent` | `components/energy_component.gd` | 每角色独立的整数能量、确定性自动恢复与提交后通知 |
| `SkillCooldowns` | `components/skill_cooldowns.gd` | 每 Executor 独立的剩余冷却 |
| `SkillExecutor` | `components/skill_executor.gd` | 原子 `try_cast()`、快照和唯一时序状态机 |
| `SkillController` | `components/skill_controller.gd` | 根据当前形态解析槽位；不读取输入 |

Resource 只保存静态配置。当前形态、能量、剩余冷却、当前 Cast、阶段时间和 Delivery 记录都在 Node/RefCounted 运行时实例中。

`ANY_FORM` 通用技能既可使用 `FOLLOW_CAST_FORM` 跟随施法形态，也可使用 `NONE` 作为中立技能。中立技能仍会锁定 `CastSnapshot` 的施法形态，但生成的 `RuntimeAttackPayload` 为无元素、0 附着量。

## 状态图与转换条件

```text
IDLE
  └─ try_cast 成功 ─> STARTUP
                       ├─ startup_time 到达 ─> ACTIVE
                       │                       ├─ 进入时生成一次 Delivery
                       │                       └─ active_time 到达 ─> RECOVERY
                       │                                             └─ recovery_time 到达 ─> IDLE
                       └─ cancel / pause / 离树 ─> CANCELLED ─> IDLE

ACTIVE、RECOVERY 也可由 cancel / pause / 离树进入 CANCELLED。
```

- `advance(delta)` 是可直接测试的确定性时钟；`_process(delta)` 只是调用它。
- 一个大 `delta` 会按 STARTUP → ACTIVE → RECOVERY → IDLE 逐段推进，零时长阶段也不会被跳过。
- ACTIVE 进入最多生成一次 Delivery；离开 ACTIVE 时只关闭一次可选的 `close_hit_window()`。
- CANCELLED 是同步通知阶段，通知完成后立刻回到 IDLE，不会留下永久忙碌。
- 动画只可调用带当前 `cast_id` 校验的 `notify_presentation_marker()`；该方法不能扣费、生成 Delivery 或推进状态。
- `cancel_current_cast(reason, expected_cast_id)` 可用 token 拒绝迟到的旧回调。

## 原子 try_cast

`SkillExecutor.try_cast(skill) -> CastAttemptResult` 在一次同步调用内完成：

1. 检查忙碌/重入、静态配置和依赖。
2. 检查当前形态、能量、冷却和 Player 提供的外部门禁。
3. 读取攻击属性、初始 Transform 和方向，构造不可变候选快照。
4. 构造并验证 Agent A 的 `CastSnapshot` 与 `RuntimeAttackPayload`。
5. 静默提交能量、冷却、当前 Cast 和 STARTUP。
6. 全部状态完成后再发出 phase/cast/cooldown/energy 通知。

任一校验失败都不会扣能量、开始冷却或返回半创建快照。成功后即使 STARTUP 被打断也不退款、不清除冷却。

能量默认每秒恢复 5 点，消费后延迟 1 秒开始；小数恢复量跨帧累计，到整数时才提交并发出通知。恢复暂停时延迟也暂停。正式 Player 在 STARTUP/ACTIVE、受击和死亡期间暂停恢复，在 RECOVERY/IDLE 且未受击时恢复推进。

### 结构化拒绝原因

| 枚举 | `reason_name()` | 含义 |
| --- | --- | --- |
| `NONE` | `none` | 成功 |
| `BUSY` | `busy` | 当前非 IDLE，或事务/推进正在发布 |
| `INSUFFICIENT_ENERGY` | `insufficient_energy` | 能量不足 |
| `COOLDOWN_ACTIVE` | `cooldown_active` | 特殊技能仍在冷却；结果携带 `cooldown_remaining` |
| `FORM_MISMATCH` | `form_mismatch` | 元素专属技能与当前形态不符 |
| `EXTERNAL_GATE_REJECTED` | `external_gate_rejected` | Player 动作门禁拒绝 |
| `INVALID_CONFIGURATION` | `invalid_configuration` | Skill、Payload、身份、Provider 返回值等配置非法；`detail` 给出细因 |
| `SLOT_UNASSIGNED` | `slot_unassigned` | 当前形态的槽位未配置 |
| `MISSING_COMPONENT` | `missing_component` | 缺少 Energy/Form/Executor |
| `DELIVERY_UNAVAILABLE` | `delivery_unavailable` | Delivery 父节点无效、待删除或不在树中 |

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
    $ElementFormController,
    $SkillExecutor,
    water_loadout,
    fire_loadout,
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
skill_controller.request_form(ElementIds.FIRE)
skill_controller.toggle_form()

# 受击、死亡或集成层明确中止；可传当前 token 防止旧回调误取消新 Cast。
skill_controller.cancel_current_cast(&"hit", skill_executor.current_cast_id)
```

可订阅的提交后通知：

```text
ElementFormController.form_changed(current, previous)
EnergyComponent.energy_changed(current, maximum, delta)
SkillController.cast_attempted(slot_id, result)
SkillExecutor.cast_started(cast_snapshot, payload)
SkillExecutor.phase_changed(cast_id, previous, current)
SkillExecutor.delivery_spawned(cast_id, delivery_id, node)
SkillExecutor.cast_cancelled(cast_snapshot, reason)
SkillExecutor.cast_finished(cast_snapshot)
SkillExecutor.cooldown_started / cooldown_finished
```

Player 继续权威管理输入、移动、受击和动画。它只根据 phase 通知决定移动锁和表现，不直接修改 Executor 内部时间。

## Agent C Delivery 初始化协议

每个 `delivery_scene` 根节点必须实现：

```gdscript
func initialize_delivery(
    cast_snapshot: CastSnapshot,
    payload: RuntimeAttackPayload,
    delivery_id: int,
    initial_transform: Transform2D,
    direction: Vector2
) -> bool:
    # 此时尚未 add_child；这里只缓存纯数据，不访问 @onready。
    return true
```

Executor 的固定顺序是：

```text
PackedScene.instantiate()
→ initialize_delivery(snapshot, payload, unique_delivery_id, transform, direction)
→ delivery_parent.add_child(delivery)
→ delivery_spawned
```

初始化返回 `false`、缺少方法或父节点失效时，本 Cast 确定性取消且不退款。投射物加入世界后不由 Executor 销毁；施法者死亡、取消或切形态都不会重算/重染已锁定 Payload。实现近战命中窗的 Delivery 可提供无参数 `close_hit_window()`，Executor 只在离开 ACTIVE 时调用一次。

## 自动测试

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_skill_tests.gd
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_combat_tests.gd
```

当前结果：

- Agent B：25 tests，143 assertions，通过。
- Agent A 回归：27 tests，123 assertions，通过。
- 测试覆盖水/火通用技能、中立 Cast、专属形态拒绝、原子扣费/冷却、5 点/秒恢复与暂停、零冷却重放、STARTUP/ACTIVE 打断、接受通知期延迟取消、预检回调重入、飞行中切形态、大 delta、旧 token、暂停/离树、共享 Skill 与 Loadout Resource 的双角色隔离。
