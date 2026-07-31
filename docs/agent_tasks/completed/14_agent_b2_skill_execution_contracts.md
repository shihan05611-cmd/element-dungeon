# Agent B 2.0 任务书：首批技能执行契约与类型化被动

状态：ACCEPTED
负责人：Agent B 2.0
依赖：11_agent_f_architecture_slimming 已验收
后续：本任务 Review 通过后才能开始 `15_agent_c_first_batch_deliveries.md`

## 1. 任务定位

首批正式技能已经超出“固定能量 + 单次 Delivery”的现有模型。本任务只建立可扩展、类型化且可验证的运行契约：

- 攻击力 × 技能倍率的伤害输入。
- 固定消耗、全能量爆发、持续引导和功能型主动技能的执行策略。
- 接受时锁定的类型化执行快照。
- 可实例化、可注销的被动 `Definition → Runtime` 生命周期。
- 普攻命中、时间推进等类型化被动事件。

Agent B 不实现具体范围查询、激光几何、回收多目标事务、内容目录或美术表现。

## 2. 首轮只读审计与停点

第一次接到本任务时不得修改文件：

1. 阅读任务 08、09、11，本任务书和 `docs/design/共享技能槽与元素释放规则.md`。
2. 审计 `CombatStatSnapshot`、`AttackPayloadDefinition`、`RuntimeAttackPayload`、`SkillDefinition`、`SkillExecutor`、`EnergyComponent`、`RuntimeSkillLoadout` 和 `combat/passives/**`。
3. 列出准备新增、替换、迁移和删除的类型与公共 API。
4. 说明现有正式技能数值如何无损迁移到“攻击力 × 技能倍率”。
5. 说明每种执行策略如何保持“所有可失败操作在提交前完成”。
6. 列出预计修改文件、测试入口和仍需 Agent C/D 提供的端口。
7. 停止，等待用户明确回复“执行任务 14”。

不得在审计回合顺手编码。

## 3. 冻结的数值语义

- 玩家基础攻击力为 10。
- 有效攻击力由基础攻击力叠加角色成长、被动和临时攻击修正得到。
- 主动和伤害型被动统一使用：

```text
技能伤害 = 有效攻击力 × 技能伤害倍率 + 固定伤害加值
反应后伤害 = 技能伤害 × (1 + 实际消耗层数 × 30%)
最终伤害 = max(0, 反应后伤害 - 固定防御)，最后统一四舍五入
```

- 当前正式内容的固定防御为 0，但必须保留既有防御字段和 `DamageResolver` 边界。
- 不加入技能等级、品质、随机词条或随进度自动提高倍率。
- 迁移不能改变已有原型的可观察伤害：例如 10 攻击力下，元素弹 100% 仍为 10，现有 5 点普攻应等价迁移为 50%。

## 4. 类型化执行定义与快照

### 4.1 内容定义

主动技能不再假定只有一个固定 `energy_cost + payload + delivery_scene` 路径。建立可替换的执行定义或等价多态结构，至少能表达：

- `InstantDeliveryExecution`：固定消耗、一次性 Delivery。
- `AllEnergyBurstExecution`：满足最低门槛后消耗当前全部能量。
- `ChannelExecution`：按固定间隔扣能并生成 Tick，支持按住、释放和中断。
- `ElementReclaimExecution`：先经外部端口查询可执行性，再提交非伤害型效果。

这些名称可以根据现有命名规范调整，但不得用中央 `match skill_id`、字符串脚本名或无结构 `Dictionary` 代替多态契约。

### 4.2 接受快照

建立不可变、类型化的执行快照或执行计划。按策略锁定必要字段：

- skill_id、cast_id、锁定元素和攻击属性。
- 接受时有效攻击力、技能倍率和固定加值。
- 接受时当前能量、最大能量和实际消耗量。
- 本次元素附着量、范围倍率、Tick 间隔及每 Tick 消耗。
- 移动锁定策略和取消/结束原因。

不得让 Delivery、Channel Tick 或 VFX 在接受后重新读取实时 CurrentElement、实时攻击力或“本次消耗了多少能量”。

### 4.3 RuntimeSkillLoadout 迁移边界

`RuntimeSkillLoadout` 是静态技能定义进入正式配装与被动生命周期的边界，必须随本任务的新契约同步迁移：

- 不再直接读取旧 `delivery_scene`、`payload` 或 `passive_effect_id` 字段。
- 目录构建时改为验证主动技能的类型化执行定义，以及被动技能的类型化 `PassiveEffectDefinition`。
- 被动绑定直接携带类型化定义并据此实例化 Runtime，不再把字符串效果 ID 交给中央适配器解释。
- 继续只负责共享槽合法性、技能目录查询、配装替换和被动 Runtime 生命周期；不得在其中新增按 skill_id 分派的执行器、Delivery 工厂或全局内容注册表。
- 旧字段迁移完成后不得保留双读、回退或兼容分支。旧资源的一次性数据迁移应在正式 Resource 中完成，而不是在运行时猜测旧结构。

任务 16 只消费迁移后的 `RuntimeSkillLoadout` 接口并接入唯一内容目录，不负责再次改造上述执行或被动契约。

## 5. 主动执行事务

流程仍为 `REQUEST → VALIDATE/PREPARE → ACCEPT/COMMIT → RUNTIME → END`。

- 外部策略先做纯验证和准备；失败返回结构化 RejectReason。
- 能量、冷却、元素自动切换和执行状态必须整体提交。
- 提交后不能因内部“不可能失败”留下部分资源变化。
- 固定消耗路径的现有行为、退款规则和重入保护必须保留。
- 功能型主动必须能在接受前返回“没有合法目标/没有收益”等结构化失败；失败时不扣能、不进冷却、不切元素、不播放成功表现。
- `SkillExecutor` 不得知道“元素之怒”“激光”“回收”等具体技能 ID。

## 6. 三种特殊主动的契约要求

### 6.1 元素之怒

- CURRENT_ELEMENT 主动。
- 当前能量低于 20 时拒绝。
- 接受时消耗全部当前能量，并锁定实际消耗量。
- `damage_multiplier = energy_spent × 0.08`。
- `element_amount = min(10, floor(energy_spent / 20))`；元素容量与 `RuntimeAttackPayload` 上限仍为 10，超过 200 能量时只继续提高伤害，不得把合法释放误报为配置错误。
- `radius_scale = 1 + floor(energy_spent / maximum_energy × 10) × 0.10`。
- 示例：20 能量为 160% 伤害倍率、1 层；100/100 能量为 800%、5 层、2.0 倍半径。
- Agent B 只生成执行快照；具体范围爆发由 Agent C 实现。

### 6.2 元素激光

- CURRENT_ELEMENT 持续引导主动。
- 每完整 0.5 秒消耗 5 能量，造成一次 50% 攻击力伤害并附着 1 层。
- Tick 使用引导接受时锁定的元素和攻击力。
- 第一 Tick 在首个完整 0.5 秒到达时发生；不足一个 Tick 的尾段不扣能、不造成命中。
- 松开输入、能量不足、受击/死亡、取消或离树时安全结束；不得多扣一个 Tick。
- 引导期间允许角色移动。执行定义必须暴露类型化移动策略，不能由 Player 猜技能 ID。
- Agent B 实现 Channel 时钟、资源事务和结束契约；穿透全部目标的 Beam Delivery 由 Agent C 实现。

### 6.3 回收

- CURRENT_ELEMENT 功能型主动，固定冷却 5 秒，不消耗能量。
- 范围内没有当前元素附着时拒绝。
- 玩家能量已满时拒绝，即使范围内存在可吸收元素。
- 两种拒绝都不进入冷却、不产生成功事件或表现。
- Agent B 提供接受前查询/准备和提交端口；Agent C 实现范围查询与原子层数消耗。

## 7. 被动 Definition → Runtime

删除 `passive_effect_id` 字符串和 `PassiveEffectAdapter` 中按字符串分派的中央 `match`，改为类型化定义和每次装备产生的 Runtime：

- `PassiveEffectDefinition` 是不可变 Resource，只保存静态规则。
- `PassiveEffectRuntime` 保存计时、订阅和本次装备实例状态。
- 每个已装备被动只创建并注册一个 Runtime。
- 卸下、整体换装、死亡、换层、读档和结束一局时必须按既有生命周期注销或重建，不重复订阅。
- Runtime 至少支持确定性 `advance(delta)` 和类型化事件入口。
- 被动触发不受角色当前元素影响；固定元素只描述它读取的目标元素或 UI 语义。
- 现有四个属性型被动必须迁移到新契约并保持行为，不允许为了等待任务 16 长期保留两套正式 API。

## 8. 首批被动契约

### 8.1 燃烧

- 固定读取目标火元素附着。
- 敌方单位有火附着时，每满 1 秒触发一次。
- 每 Tick 伤害倍率为 `目标当前火层数 × 5%`。
- 不消耗火层，不读取玩家 CurrentElement。
- 需要类型化目标查询和伤害提交端口；Agent B 用测试替身验证 Runtime，正式空间接线留给后续任务。

### 8.2 不息

- 固定读取目标水元素附着。
- 只有固定普通攻击命中对应目标并正式提交成功后触发。
- 恢复生命为该目标命中结算时的水附着层数 × 1。
- 不消耗水层，不读取玩家 CurrentElement；原文中的火元素为已确认笔误。
- 必须使用类型化“普通攻击已提交”事件，不能依赖动画名、输入键、presentation tag 或日志字符串猜测。

## 9. 文件范围

可修改：

- `combat/components/skill_executor.gd`
- `combat/components/energy_component.gd`
- `combat/components/skill_cooldowns.gd`
- `combat/loadouts/runtime_skill_loadout.gd`
- `combat/contracts/**` 中与攻击、执行和类型化事件直接相关的文件
- `combat/definitions/skill_definition.gd`
- `combat/definitions/attack_payload_definition.gd`
- 新建 `combat/execution/**`
- `combat/passives/**`
- `scripts/passive_effect_adapter.gd`，仅用于移除旧字符串分派和接上新端口
- 现有正式 Skill Resource，仅限字段/倍率契约的等价迁移
- 对应单元测试和执行契约文档

不得修改：

- `combat/delivery/**` 的具体空间行为。
- `ElementCarrier`、`CombatReceiver`、反应公式和 `DamageResolver` 顺序。
- `growth/run_session.gd`、奖励、商店和路线逻辑。
- `scripts/run_session_host.gd`、`scripts/test_room.gd`、正式场景和 HUD。
- 首批六技能的内容目录、获取配置、图标或 VFX。

## 10. 验收

- 10 攻击力下，50%、100%、800% 等倍率得到正确 offensive_damage。
- 成长、属性被动和临时攻击修正仍在接受时锁定，已生成攻击不随实时数值变化。
- 19 能量的元素之怒拒绝；20 和 100 能量生成正确类型化快照并原子扣能。
- Channel 在大 delta、连续帧、松键、能量不足、取消和重入下不漏 Tick、不重复 Tick、不多扣能。
- 激光执行策略明确为允许移动。
- 回收的“无附着”和“满能量”预检使用结构化拒绝，且不提交冷却。
- 现有四个属性被动完成新 Runtime 迁移；全项目正式代码不再使用 `passive_effect_id` 或中央字符串 `match`。
- `RuntimeSkillLoadout` 不再直接读取旧 `delivery_scene`、`payload` 或 `passive_effect_id`，并能在目录构建时拒绝缺失或非法的类型化执行/被动定义。
- 共享槽校验、原子换装和被动生命周期回归通过；迁移不得把具体技能 ID、Delivery 创建或执行策略分派塞进 `RuntimeSkillLoadout`。
- 燃烧和不息用测试端口验证触发公式、元素读取、不消耗层数和生命周期去重。
- 原有共享槽、元素事务、Delivery 快照和成长回归全部通过。
- 全量测试及主场景 smoke 通过，无新增脚本错误或警告。

## 11. 交付

- 报告新增、替换和删除的契约及公共 API。
- 报告 `RuntimeSkillLoadout` 从旧顶层字段到类型化执行/被动定义的迁移方式，以及确认已删除的旧字段读取路径。
- 报告旧数值到攻击力倍率的迁移表。
- 报告专项、全量和 smoke 结果及剩余需由 Agent C/D 接线的端口。
- 不执行任何 Git 命令，不自行把任务标为 `ACCEPTED`。

## 12. Agent B 2.0 实施证据（2026-07-23）

### 12.1 契约与公共 API

- 攻击输入迁移为 `CombatStatSnapshot.BASE_ATTACK = 10`，并锁定 `effective_attack / damage_multiplier / fixed_damage_bonus / offensive_damage`；既有反应与 `DamageResolver` 顺序未修改。
- 新增 `SkillExecutionDefinition → SkillExecutionPrepareResult → SkillExecutionSnapshot → SkillExecutionRuntime → SkillExecutionEndResult` 多态链，以及可预验证的 `SkillExecutionCommitTransaction`。
- 已实现 `InstantDeliveryExecution`、`AllEnergyBurstExecution`、`ChannelExecution`、`ElementReclaimExecution`；`SkillExecutor` 只消费执行基类和边界结果，不按 `skill_id` 或字符串分派。
- `CastAttemptResult` 成功结果新增类型化 `execution_snapshot`，拒绝新增 `NO_LEGAL_TARGET / NO_BENEFIT`；Executor 新增 execution started/activated/tick/ended 通知、`current_movement_policy` 和类型化 Channel release。
- 新增 `PassiveEffectDefinition → PassiveEffectRuntime`、`PassiveRuntimeContext`、Owner/Target Port、`PassiveDamageRequest` 与认证的 `BasicAttackCommittedEvent`；`PassiveEffectAdapter` 已删除字符串效果分派，只聚合 Runtime 并转发类型化事件。
- `RuntimeSkillLoadout` 现在验证 `execution_definition.catalog_validation_error()` 或 `passive_effect_definition`，被动绑定直接携带类型化定义。正式 `.gd/.tres` 扫描确认 `passive_effect_id`、旧顶层 `skill.delivery_scene/payload/active_time`、`base_damage` 和中央 `match skill_id/effect` 均为零命中。

### 12.2 正式资源等价迁移

| Resource | 旧可观察伤害 | 新倍率（10 基础攻击） | 执行/被动定义 |
| --- | ---: | ---: | --- |
| `element_slash` | 5 | 50% | `InstantDeliveryExecution` |
| `element_bolt` | 10 | 100% | `InstantDeliveryExecution` |
| `water_lance` | 14 | 140% | `InstantDeliveryExecution` |
| `fire_lance` | 14 | 140% | `InstantDeliveryExecution` |
| `passive_vitality` | 最大生命 +20 | 不变 | `StatModifierPassiveEffectDefinition` |
| `passive_energy` | 最大能量 +10 | 不变 | `StatModifierPassiveEffectDefinition` |
| `passive_focus` | 攻击倍率 ×1.10 | 不变 | `StatModifierPassiveEffectDefinition` |
| `passive_balance` | 生命 +10、能量 +5、攻击 ×1.05 | 不变 | `StatModifierPassiveEffectDefinition` |

### 12.3 验证结果

- 任务 14 主动执行专项：12 tests / 72 assertions，通过。
- 任务 14 被动 Runtime 专项：5 tests / 55 assertions，通过。
- 战斗、技能、Delivery、Agent D 集成及成长共 14 个入口：161 tests / 1045 assertions，全部通过。
- Godot `--headless --editor --quit` 全局脚本扫描通过，日志无 `SCRIPT ERROR / ERROR / WARNING`。
- 正式主场景 `res://scenes/test_room.tscn` 无头运行 180 帧，日志无 `SCRIPT ERROR / ERROR / WARNING`。
- 未执行任何 Git 命令；任务只提交到 `REVIEW`，未自行标记 `ACCEPTED`。

### 12.4 后续 Agent C/D 接线

- Agent C：为元素之怒提供范围 Delivery，为激光提供 Beam Delivery；实现 `ElementReclaimPort` 的范围查询、预验证事务与多目标层数原子消费；实现 `PassiveTargetPort` 的空间目标快照和燃烧伤害提交。
- Agent D：把 Player 移动门禁接到 `current_movement_policy`，把按住/松开接到 `request_channel_release()`；由正式普攻命中成功路径发布 `BasicAttackCommittedEvent`；提供 `PassiveOwnerPort` 的属性捕获/治疗，并按既有生命周期推进 Adapter 的 `advance(delta)`。

## 13. Review 首轮结论与返修（2026-07-24）

结论：`CHANGES_REQUESTED`。主体契约和既有回归通过，但以下三项完成前不得重新提交 `REVIEW`，任务 15 继续保持 `PENDING`。

### 13.1 已独立复验通过

- 14/14 战斗与成长测试入口全部通过：161 tests / 1045 assertions。
- Godot 4.7.1 `--headless --editor --quit` 扫描退出码为 0。
- `res://scenes/test_room.tscn` 实际运行进入 `live`，复验窗口内 game log 无脚本错误。
- 20、100 能量爆发、Channel 大 delta/释放/耗尽、回收预检、类型化被动和旧资源倍率迁移均通过现有专项。

### 13.2 必须返修

1. **元素之怒在可达的高能量上限下错误拒绝**
   - 独立复现：`energy_before = maximum_energy = 220` 时，`AllEnergyBurstExecution.prepare()` 返回 `INVALID_CONFIGURATION / invalid_element_amount`。
   - 原因：当前直接生成 `floor(220 / 20) = 11` 层，而 `RuntimeAttackPayload` 和元素容量只允许 `0..10`。
   - 冻结修正：按第 6.1 节使用 `min(10, floor(energy_spent / 20))`；伤害倍率与半径公式不变，220 能量仍应合法接受并原子消耗全部能量。
   - 新增至少 200、220 能量边界测试，验证 220 能量不是配置错误、层数封顶 10、伤害倍率仍为 `17.6`。

2. **Channel 在不足一次 Tick 费用时仍被接受**
   - 独立复现：当前能量 4、每 Tick 费用 5 时，`ChannelExecution.prepare()` 返回成功，`minimum_energy_required()` 为 0，接受时消费 0。
   - 冻结修正：Channel 的接受门槛为一次 Tick 费用；`minimum_energy_required()` 应返回 `energy_per_tick`。0～4 能量必须在提交前返回 `INSUFFICIENT_ENERGY`，不发布成功事件、不进入执行态、不改变冷却或元素；5 能量可接受并在首个完整 Tick 精确消费。
   - 新增 4/5 能量边界测试，并保留现有运行中“剩余不足下一 Tick 时安全结束”的契约。

3. **本次改动新增编辑器警告**
   - Godot 编辑器记录 `combat/components/skill_executor.gd:704`：`STANDALONE_TERNARY`。
   - 该行属于任务 14 新增代码。改为无警告的显式控制流，并复跑编辑器脚本扫描；不得以过滤日志方式掩盖。

### 13.3 重新提交 Review 的证据

- 报告上述三个返修点的代码位置和新增测试名。
- 任务 14 主动专项、被动专项、14 个全量入口全部通过。
- 编辑器与主场景复验无任务 14 新增的 `SCRIPT ERROR / ERROR / WARNING`。
- 仍不得自行将状态改为 `ACCEPTED` 或移动到 `completed/`。

### 13.4 Agent B 2.0 返修提交证据（2026-07-24）

- 元素之怒：`combat/execution/all_energy_burst_execution.gd:61` 将附着量改为 `min(10, floor(E/20))`；伤害倍率和半径公式未加封顶。新增 `all_energy_burst_200_snapshot` 与 `all_energy_burst_220_caps_element_amount`，验证 200/220 与 220/220 均接受并原子消耗全部当前能量、层数为 10、220 能量倍率仍为 17.6。
- Channel：`combat/execution/channel_execution.gd:30` 的 `minimum_energy_required()` 返回 `energy_per_tick`，并在 `:54` 的直接 prepare 边界再次拒绝不足一次 Tick 费用。新增 `channel_rejects_four_atomically` 与 `channel_accepts_five_and_spends_first_tick`，验证 4 能量不发成功事件、不进执行态、不改能量/冷却/元素，5 能量在首个完整 0.5 秒精确消费。
- 编辑器警告：`combat/components/skill_executor.gd:697` 的 pending cancel 改为显式 `if` 控制流，删除独立三元表达式。
- 主动执行专项：16 tests / 102 assertions，通过；被动 Runtime 专项：5 tests / 55 assertions，通过。
- 要求的 14 个全量入口全部通过，更新后合计 165 tests / 1075 assertions，0 failed。
- Godot 4.7.1 `--headless --editor --quit` 返修扫描退出码 0；日志对 `SCRIPT ERROR / ERROR / WARNING / STANDALONE_TERNARY` 均为零命中。
- 正式主场景无头运行 180 帧退出码 0；game log 对上述错误与警告模式均为零命中。
- 未执行 Git 命令；任务重新提交到 `REVIEW`，未标记 `ACCEPTED`，未归档或移动任务文件。

## 14. Review 最终验收（2026-07-24）

结论：`ACCEPTED`。

- 独立核对三项返修：220 能量爆发合法接受且附着封顶 10；Channel 4 能量原子拒绝、5 能量首 Tick 精确消费；`STANDALONE_TERNARY` 已移除。
- 独立复跑 14/14 测试入口：165 tests / 1075 assertions，0 failed。
- Godot 4.7.1 `--headless --editor --quit` 扫描退出码 0，目标错误与返修警告零命中。
- `res://scenes/test_room.tscn` 实际运行进入 `live`，复验窗口内 game log 无脚本错误。
- 任务 14 正式解锁任务 15；归档后不得重新打开，后续回归另立任务。