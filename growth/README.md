# Growth Core（Agent E 交付）

`res://growth/**` 是独立的局内成长领域。它跨房间保存一局状态，但不依赖 Player、HUD、场景树、CombatReceiver 或其他 Node。静态 `SkillRewardDefinition` / `RelicDefinition` Resource 可以跨局共享；所有拥有状态、冷却、次数、经验、奖励和路线状态都属于单个 `RunSession`。

本实现只有角色等级，没有技能等级。技能和遗物均以稳定 ID 唯一拥有，奖励不会重复发放已拥有内容。

## 聚合与依赖

```text
RunSession
├── ProgressionState ── ExperienceService
├── SkillInventoryState
├── RelicInventoryState ── RelicController ── GrowthEffectPort (Agent D)
├── PendingRewardState ── RewardGenerator
├── RunDirector ── RouteState
└── RuntimeLoadoutPort (Agent B)
```

`RunSession.snapshot()` 每次创建新的 `RunSnapshot`。子快照无写接口；数组 getter 返回副本。运行时对象只保存标量、稳定 ID、内部集合和不可变快照，不保存 Node、场景实例或可变战斗 Resource。

## 冻结公共契约

| 契约 | 生命周期与用途 |
| --- | --- |
| `RunPhase` | `COMBAT / REWARD / ROUTE_CHOICE / SHOP / RUN_COMPLETE`。`RUN_COMPLETE` 为终态。 |
| `RewardType` | 首版只有 `SKILL / RELIC`。 |
| `RunCommandResult` | 同步命令的接受状态、结构化拒绝原因和显式类型结果；不使用任意 Dictionary payload。 |
| `ProgressionSnapshot` | 等级、当前级经验、下一级需求、未分配点、显式三属性和 revision。 |
| `SkillInventorySnapshot` | 已拥有技能 ID 的排序副本。 |
| `RelicInventorySnapshot` | 已拥有遗物 ID，以及名称、描述、内部冷却和本房触发次数。 |
| `RuntimeLoadoutSnapshot` | `RuntimeLoadoutSlotSnapshot` 显式条目组成的共享 `slot_id → skill_id` 只读映射；带 revision 和结构校验错误。槽位不随当前元素切换。 |
| `RouteSnapshot` | 当前阶段、已完成战斗房数、当前房间、已选奖励类型和路线选项。 |
| `RunSnapshot` | 组合全部子快照、PendingReward、开放形态和整局 revision。 |
| `RewardOption / RewardOffer` | 不可变选项；offer ID 由房间、类型、seed 和选项稳定 ID 构成。无效 Offer 明确携带配置错误。 |
| `RunEvent` 子类 | `FormChangedEvent / CombatCommittedEvent / EnemyKilledEvent / RoomCompletedEvent / RelicAcquiredEvent`；关键字段显式声明。 |
| `GrowthEffectPort` | 恢复能量、治疗、临时攻击倍率、增加最大生命/能量；无 Node 查询。 |
| `RuntimeLoadoutPort` | Agent B 提供只读快照、纯校验和原子整体替换。 |

### 状态机

允许的边只有：

```text
COMBAT ──房间完成──> REWARD ──领取成功──> ROUTE_CHOICE
                                               ├──奖励路线──> COMBAT
                                               └──每 3 房──> SHOP
SHOP ──确认──> COMBAT
SHOP ──第 6 房后确认结束──> RUN_COMPLETE
```

任何其他跳转返回 `INVALID_TRANSITION` 或 `INVALID_STATE`，原阶段不变。房间身份在 COMBAT 开始时冻结，完成前不能替换。击杀同时以事件 ID 和 `room_id + enemy_id` 去重；房间完成以稳定房间 ID 去重。

## 角色成长与 ShopDraft

首版经验曲线冻结为：

```text
当前等级升级需求 = 100 + (当前等级 - 1) × 50
```

一次经验可连续升级；每升一级仅增加 1 个未分配点，不直接改变战斗属性。

| 属性 | 快照派生值 |
| --- | --- |
| `GrowthStatIds.ATTACK` | `attack_multiplier = 1.0 + points × 0.05` |
| `GrowthStatIds.VITALITY` | `maximum_health_bonus = points × 10` |
| `GrowthStatIds.ENERGY` | `maximum_energy_bonus = points × 5` |

`open_shop_draft()` 只在 SHOP 阶段成功。草稿保存整局 revision、成长 revision、Loadout revision 和进入商店时映射。所有加点/换装先改草稿；`reset()` 恢复基线。`confirm_shop()` 先完成基线、拥有状态、属性预算、Loadout 和阶段校验，再整体提交；失败不会修改成长状态、Loadout 或阶段。已确认草稿不能重复确认。

`ShopCommitSummary` 同时提供提交前后的成长与 Loadout 快照。Agent D 应根据 `progression_before/after` 的最大值增量更新玩家当前生命/能量，而不是完全恢复。

## 奖励规则

`RewardGenerator.generate(run_snapshot, room_context, seed, skill_catalog, relic_catalog)` 是无状态纯服务：

1. 校验静态目录和唯一 ID。
2. 排除已拥有、未开放形态无法装备或不属于第一关初始池的技能。
3. 按稳定内容 ID 排序后使用显式 seed 洗牌，最多取 3 项。
4. 第一关不足 3 个合法初始技能时返回 `insufficient_initial_skill_candidates`，不重复填充。
5. 排除本局已拥有遗物，同一 Offer 内不重复 ID。

生成成功后 Offer 进入 `PendingRewardState`。同一奖励界面重开直接返回原 Offer，传入新 seed 也不会重抽。领取先校验 Offer/Option/拥有状态/后续路线，再提交库存与阶段；每个 Offer 只能成功领取一次。技能池耗尽后 `RunDirector` 不生成技能路线。

## 遗物

`RelicDefinition` 只保存静态显示与效果参数；`RelicRuntimeState` 保存本局内部冷却、当前房间和本房触发次数。`RunSession` 统一负责 RunEvent ID、元素 sequence 和逻辑击杀身份；`RelicController` 只分发已经保证唯一的事件，并从小型 `RelicEffectRegistry` 选择策略。

已实现的首版策略：

- 形态切换恢复能量；
- 反应消耗达到阈值恢复能量；
- 房间完成治疗；
- 反应后临时攻击倍率；
- 获得时增加最大生命；
- 获得时增加最大能量。

所有效果必须由 `GrowthEffectPort` 返回成功后才登记触发次数和内部冷却。重复事件不会再次触发。两个 `RunSession` 可共享同一个 `RelicDefinition`，但运行时冷却和次数完全隔离。

## Agent B：Runtime Loadout 接口

Agent B 的可变实现继承 `RuntimeLoadoutPort`：

```gdscript
class_name RuntimeLoadoutState
extends RuntimeLoadoutPort

func snapshot() -> RuntimeLoadoutSnapshot:
    # 从内部状态创建显式 entry 副本，revision 随成功替换递增。
    return RuntimeLoadoutSnapshot.new(copied_entries, revision)

func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
    # 必须纯校验：candidate.is_valid()、revision、固定 3 主动 + 1 被动槽、
    # 技能主动/被动兼容性、重复技能、未知技能等。不得改变现有映射。
    return RuntimeLoadoutChangeResult.success(candidate)

func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
    # 必须整体替换成功，或保持旧状态完全不变。
    return RuntimeLoadoutChangeResult.success(snapshot())
```

接入 `RunSession`：

```gdscript
var session := RunSession.new(
    skill_reward_catalog,
    relic_catalog,
    initial_owned_skill_ids,
    unlocked_form_ids,
    runtime_loadout_state,
    growth_effect_adapter,
)

var readonly_loadout := session.snapshot().loadout
var primary_skill_id := readonly_loadout.get_skill_id(&"active_1")
```

技能是否已拥有由 `RunSession` 在商店确认前校验；Agent B 负责固定四槽形状和技能主动/被动等静态配置合法性。成长域不根据当前元素验证技能可释放性，因此 `0 主动 + 4 被动` 只要端口规则允许就是合法映射。`try_replace_snapshot` 不得部分修改或在事务中发布可观察到半状态的通知。

## Agent D：事件、属性和 UI 接口

集成层只把已经提交的战斗结果投影为显式 DTO。形态切换必须同时携带前后元素、来源、单调序列、时间戳、事件 ID 和房间 ID：

```gdscript
session.handle_event(FormChangedEvent.new(
    stable_form_change_event_id,
    current_room_id,
    previous_element_id,
    current_element_id,
    FormChangedEvent.Source.MANUAL, # 或 SKILL_AUTO
    monotonic_form_change_sequence,
    Time.get_ticks_msec(),
))
```

响应形态切换的遗物可配置 `ALL / MANUAL_ONLY / SKILL_AUTO_ONLY`。同元素事件无效；相同 event ID 或非递增 sequence 不会再次触发，去重状态属于单个 `RunSession`。

其他战斗事件同样使用稳定身份：

```gdscript
if combat_result.accepted:
    session.handle_event(CombatCommittedEvent.new(
        stable_hit_event_id,
        current_room_id,
        combat_result.cast_id,
        combat_result.delivery_id,
        combat_result.hit_index,
        stable_target_id,
        combat_result.skill_id,
        combat_result.source_element_id,
        combat_result.final_damage,
        combat_result.reaction_consumed,
        combat_result.current_health,
    ))

session.handle_event(EnemyKilledEvent.new(
    stable_kill_event_id,
    current_room_id,
    stable_enemy_id,
    enemy_experience_reward,
))

session.handle_event(RoomCompletedEvent.new(
    stable_room_complete_event_id,
    current_room_id,
    room_completion_experience,
    player_damage_taken_this_room,
))
```

HUD 和界面只读取快照，并监听提交后通知：

```gdscript
session.snapshot_changed.connect(func(current: RunSnapshot, cause: StringName) -> void:
    level_label.text = str(current.progression.level)
    experience_label.text = "%d / %d" % [
        current.progression.experience,
        current.progression.experience_required_for_next_level,
    ]
    unspent_label.text = str(current.progression.unspent_stat_points)
)
```

攻击快照取 `current.progression.allocated_stats.attack_multiplier`。体质和能量分别取 `maximum_health_bonus` / `maximum_energy_bonus`。成长域不直接修改 Player；Agent D 的 `GrowthEffectPort` 实现负责把同步命令适配到真实组件。

## 测试

Godot 4.7.1 可重复执行；完整命令见 `growth/TESTING.md`。06 契约套件命令为：

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> --log-file .godot/growth-06-contract-tests.log --script res://growth/tests/run_growth_06_contract_tests.gd
```

当前五套 Growth 回归合计 43 tests / 269 assertions。除既有成长、奖励、状态机、遗物和事务行为外，06 套件覆盖共享四槽、快照复制/排序/revision、非法条目、ShopDraft、未拥有技能、端口接受 0 主动 + 4 被动、同元素事件拒绝、来源过滤、event ID/sequence 双重去重与双局隔离。

## 明确限制

- 尚未接入 Player、HUD、场景或 Agent B 的正式可变 Runtime Loadout；这些属于 Agent B/D 的独占范围。
- 静态技能/遗物目录和具体内容 Resource 由集成层提供；本任务没有越界创建战斗技能或正式场景。
- 经验曲线目前固定为线性公式，没有策划配置 Resource、等级上限或跨局永久成长。
- 尚无存档/读档、货币、购买出售、技能等级、遗物品质/升级/词条。
- 遗物策略只覆盖上列 6 种窄效果；没有低生命检测、无伤额外经验等未实现方向。
- 如果非商店检查点同时耗尽技能和遗物目录，领取会以 `no_legal_next_routes` 配置错误拒绝；不会伪造重复奖励。
- `GrowthEffectPort` 是同步端口；适配器负责真实组件的容量、死亡状态和临时效果叠加规则。
