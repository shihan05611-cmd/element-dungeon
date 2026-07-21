# Agent B 任务书：元素形态、技能释放、能量与冷却

## 1. 任务定位

你负责玩家侧独立的技能领域组件：形态、技能槽、释放状态机、能量、可选冷却，以及创建不可变释放快照。

开始编码前必须先读取 Agent A 已冻结的公共类型；若公共契约检查点尚未完成，只能做只读分析和测试设计，不得自行创建一套重复 DTO。

项目根目录：`C:\Users\heliashi\Documents\元素地牢-4.7`

原始策划与技术方案：

- `C:\Users\heliashi\Downloads\横板动作地牢_元素系统策划案_更新版.md`
- `C:\Users\heliashi\Downloads\元素地牢_技能与元素系统技术方案.md`

本任务书中的冻结规则优先。

## 2. 文件边界

你可以负责：

- `SkillDefinition`。
- `SkillLoadout`。
- `ElementFormController`。
- `SkillController`。
- `SkillExecutor`。
- `EnergyComponent`。
- `EnergyComponent` 提供当前值、最大值和提交后的 `energy_changed(current, maximum, delta)` 通知，供 HUD 单向读取。
- `ElementFormController` 提供当前形态只读查询和提交后的 `form_changed` 通知；HUD 用它更新图标、文字和语义颜色。
- 技能冷却的运行时状态。
- 相关独立测试和专用测试场景。

Agent A 拥有公共快照、Payload、HitRequest、CombatResult 和核心结算类型；Agent C 拥有具体 Delivery；Agent D 独占现有玩家、敌人和主场景迁移。

不得修改：

- `scripts/player.gd`
- `scripts/enemy.gd`
- `scenes/player.tscn`
- `scenes/enemy.tscn`
- `scenes/test_room.tscn`
- Agent A 已冻结的公共类型
- Agent C 的 Delivery 内部

## 3. 已冻结的游戏规则

- 只支持水、火两种玩家形态。
- 两种形态拥有相互独立的技能槽映射。
- 通用技能在释放被接受时使用当前形态决定元素。
- 元素专属技能必须校验当前形态。
- 元素量为整数层，每种元素上限 10。
- AOE 对每个目标携带完整配置元素量。
- 多段攻击的每个 `hit_index` 独立携带完整配置元素量。
- 能量和特殊技能冷却在释放请求被接受时立即消费/开始。
- 能量默认每秒恢复 5 点；消费后延迟 1 秒再恢复，使用整数提交和小数累计，不能因帧率产生额外取整误差。
- STARTUP/ACTIVE、受击与死亡期间恢复和恢复延迟都暂停；RECOVERY/IDLE 恢复推进。EnergyComponent 提供暂停窄接口，由 Agent D 根据 Player 状态接线。
- 释放被打断时不退还能量，也不取消已经开始的冷却。
- 常规技能默认 `cooldown = 0`；只有明确配置的特殊技能才有冷却。
- 施法期间允许切换形态，但当前 Cast 的技能、元素和攻击快照不改变；下一次释放才读取新形态。
- 本次释放的攻击属性、元素、阵营、技能和 Payload 在接受释放时锁定。
- 反应和击杀归本次触发攻击的 `root_owner_id`。
- MVP 只允许攻击敌对目标；正面元素附着不在范围内。

## 4. 状态机必须是唯一真源

`SkillExecutor` 使用明确状态机：

```text
IDLE → STARTUP → ACTIVE → RECOVERY → IDLE
                  ↘ CANCELLED → IDLE
```

要求：

- `startup_time / active_time / recovery_time` 和状态机推进是玩法时序真源。
- 动画只能跟随状态或提供受当前 cast token 校验的表现标记。
- 动画方法轨不得独立扣费、改元素、造成伤害或推进另一套玩法状态。
- 每个状态进入事件、Delivery 生成事件和结束事件必须恰好发生一次。
- 一个较大的 `delta` 跨越多个阶段时仍必须按顺序触发所有必要事件，不能跳过 ACTIVE 或重复生成 Delivery。
- 暂停、施法者离树、受击、死亡和显式取消必须得到确定结果。
- 旧动画回调或旧 cast token 不能影响新释放。

建议公开可直接测试的推进入口，不应强制依赖真实输入或动画播放才能测试状态机。

## 5. 释放事务

不要把 `can_cast()` 与资源消费拆成可能被误用的两阶段操作。提供一个同步的权威入口，例如：

```text
try_cast(slot_or_skill) -> CastAttemptResult
```

该入口必须在一次调用中完成：

1. 校验当前 Executor 状态。
2. 校验形态及元素专属资格。
3. 校验能量。
4. 校验冷却。
5. 校验外部动作门禁。
6. 消耗能量。
7. 开始冷却。
8. 分配唯一 `cast_id`。
9. 创建不可变 `CastSnapshot` 和 Runtime Payload。
10. 进入 STARTUP。

失败时不得部分扣费或留下半创建的 Cast。返回结构化失败原因，至少区分：忙碌、能量不足、冷却中、形态不符、外部门禁拒绝、配置无效。

## 6. 与现有 Player 的集成契约

当前 `player.gd` 同时管理移动、普通攻击和受伤。你不得直接重写它，也不得让 SkillExecutor 直接修改玩家速度或播放现有动画。

提供窄接口供 Agent D 接线：

- 外部动作门禁：Player 可决定当前是否允许开始技能。
- `cancel_current_cast(reason)`：受击、死亡、离场时由 Player/集成层调用。
- `cast_started`、`phase_changed`、`cast_cancelled`、`cast_finished` 等通知。
- 当前 phase 和 cast token 的只读查询。
- 能量恢复暂停接口；集成层只传入是否暂停，不直接改内部计时或累计值。
- 形态切换请求接口和形态变化通知。
- 按槽位发起释放的接口；组件内部不要硬编码 Q/J/鼠标等输入。

职责划分：

- SkillExecutor 只权威管理技能释放阶段。
- Player/Agent D 权威管理移动、受击和输入映射。
- Agent D 通过窄接口决定不同技能阶段是否锁移动、怎样播放动画、何时因受击取消。

## 7. Delivery 生成协议

Agent C 会提供具体 Delivery。你只依赖其公共初始化协议：

1. 从 `PackedScene` 实例化 Delivery，但先不要加入 SceneTree。
2. 分配同一 Cast 内唯一的 `delivery_id`。
3. 在 `add_child()` 前传入 `CastSnapshot`、Runtime Payload、`delivery_id` 和初始方向/变换。
4. 初始化函数只能缓存纯数据，不应依赖 `@onready` 子节点。
5. 完成初始化后再加入场景树。

不得沿用当前原型“先 `add_child()`，后 `configure()`”的顺序。

默认行为：

- 投射物在进入 ACTIVE 时生成一次。
- 近战命中窗在 ACTIVE 进入时打开、离开时关闭。
- 同一技能如需多段，使用显式的 `hit_index` 配置；不得通过动画回调碰巧重复触发。
- 投射物生成后，即使施法者死亡或切换形态，也保持已锁定的攻击数据继续存在，除非关卡卸载销毁它。

## 8. Resource 与运行时隔离

- Skill、Payload 和 Loadout Resource 仅保存静态配置。
- 能量、冷却剩余、当前形态、当前 Cast、命中记录绝不能写回 Resource。
- 两名角色可共享同一套 `.tres`，运行时状态必须完全隔离。
- `SkillLoadout` 表达静态槽位映射；未来装备变化如需运行时编辑，应创建实例状态，不直接修改共享 Resource。
- 所有元素 ID 必须经 Agent A 的 Element Catalog/ID 常量校验。

## 9. 必测用例

至少覆盖：

- 水形态释放通用技能，快照元素为水。
- 火形态释放同一通用技能，快照元素为火。
- 水专属技能在火形态被明确拒绝且不扣能量。
- 能量足够时一次请求完成扣费、冷却和 Cast 创建。
- 能量不足或冷却中不产生任何部分状态。
- 常规技能 `cooldown = 0` 可以在前后摇和能量允许时再次释放。
- 特殊技能冷却按接受请求时开始。
- STARTUP 被打断时不退款。
- ACTIVE 生成 Delivery 后被打断，已生成 Delivery 不被重新着色或重算属性。
- 投射物飞行中切水/火，旧投射物保持释放元素。
- 施法期间切形态不取消当前 Cast；下一 Cast 使用新形态。
- 大 delta 跨阶段时，每个阶段事件和生成事件恰好一次。
- 迟到的旧动画/cast token 回调不影响新 Cast。
- 施法者离树、死亡、暂停均不会留下永久忙碌状态。
- 两个角色共享 Skill/Loadout Resource，能量、冷却、形态完全独立。

## 10. 禁止项

- 不实现具体伤害、元素反应或目标状态修改。
- 不在技能脚本中搜索敌人或直接调用目标扣血。
- 不硬编码输入。
- 不用 Signal 拼装核心释放顺序。
- 不把动画当第二套状态机。
- 不修改现有正式 Player/Enemy 场景。
- 不提前实现输入缓存、Hit Stop、土电技能、吸收、引爆或通用 Buff。
- 不删除或替换 `prototype_skill`；迁移由 Agent D 完成。

## 11. 交付与验收

交付时提供：

- 状态图和每个转换条件。
- `try_cast()`、取消、切形态和 Delivery 初始化的调用示例。
- 所有结构化失败原因。
- 自动测试及结果。
- Agent D 接线所需的最小 API 说明。

验收条件：释放事务无部分扣费；状态机是唯一玩法时序；快照不可被后续形态或 Resource 修改污染；组件脱离玩家输入和动画也能独立测试；现有主场景未被修改。
