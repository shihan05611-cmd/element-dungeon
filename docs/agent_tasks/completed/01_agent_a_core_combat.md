# Agent A 任务书：公共协议、元素结算与目标组件

## 1. 任务定位

你负责首版水火战斗链路的公共协议和目标侧核心。你的代码会被其他 Agent 依赖，因此必须先完成“公共契约检查点”，再继续实现结算与目标组件。

本任务只实现水、火、普通伤害和元素反应。不得实现土、电、建造物赋能、吸收、引爆、Buff、玩家正面附着或 Boss 部位系统。

项目根目录：`C:\Users\heliashi\Documents\元素地牢-4.7`

原始策划与技术方案：

- `C:\Users\heliashi\Downloads\横板动作地牢_元素系统策划案_更新版.md`
- `C:\Users\heliashi\Downloads\元素地牢_技能与元素系统技术方案.md`

本任务书中的冻结规则优先于原技术方案中的“建议、可选、暂定”表述。

## 2. 当前工程事实

- Godot 4.7 / GDScript 项目。
- 当前正式场景仍通过 `receive_interaction()` 直接交互。
- 没有正式的生命、伤害、能量、元素或统一接收器。
- `prototype_skill` 是可拆卸原型，不是已完成的战斗底座。
- 不得直接改动 `scripts/player.gd`、`scripts/enemy.gd`、`scenes/player.tscn`、`scenes/enemy.tscn`、`scenes/test_room.tscn`；这些文件由 Agent D 独占迁移。

## 3. 已冻结的 MVP 规则

### 3.1 元素与附着

- 只支持 `water`、`fire`。
- 元素量使用整数层，不使用浮点层数。
- 每个载体的每种元素范围为 `0..10`，超过部分截断到 10。
- 同元素命中时累加至上限 10。
- 附着不随时间自动衰减。
- 附着在被反应消耗、载体死亡或离开房间时清除。
- 反应后，本次攻击未消耗的来袭元素继续附着。
- MVP 只允许敌对目标；友方赋能和正面附着不在范围内。

### 3.2 水火反应

```text
consumed = min(target_opposite_amount, incoming_amount)
reaction_multiplier = 1.0 + 0.3 * consumed
```

- 水触发火与火触发水完全对称。
- 消耗双方等量元素。
- 最大单次消耗为 10，因此当前理论最大反应倍率为 4.0。
- 目标原有同元素保持不变；未消耗的来袭元素累加到同元素池并受上限 10 限制。

### 3.3 命中与部分处理

- 闪避、格挡、无敌、阵营不合法和重复命中属于整体拒绝：伤害和元素均不提交。
- 合法命中即使最终伤害为 0，元素仍可附着。
- 没有 `DamageReceiver` 时可以只处理元素。
- 没有 `ElementCarrier` 时可以只处理伤害。
- 两者都没有时明确拒绝，不报错。
- `CombatResult` 必须分别表达伤害、元素和反应的处理状态，不能只靠一个 `accepted` 布尔值表达全部语义。

### 3.4 伤害顺序

```text
offensive_damage = 技能基础伤害经过施法者攻击属性修正
reacted_damage = offensive_damage * reaction_multiplier
mitigated_damage = 目标防御结算(reacted_damage)
final_damage = roundi(max(0, mitigated_damage))
```

- 中间阶段不得取整，只在最终应用生命变化前取整一次。
- 反应倍率是独立乘区。
- 暴击、易伤、抗性等尚未确认，不得擅自加入通用公式。
- 反应伤害和击杀归本次触发攻击的 `root_owner_id`；旧附着来源只允许作为调试信息。

### 3.5 快照与生命周期

- 施法者的元素、阵营、技能、Payload 和所需攻击属性在释放被接受时锁定。
- 目标防御和目标当前元素在命中时读取。
- 公共快照只保存标量、稳定 ID 和不可变值；不得依赖可变 Resource 或强 Node 引用提供关键结算数据。
- 可选 Node 引用必须按弱引用对待，使用前检查有效性和待删除状态。

## 4. 公共契约检查点

先实现并冻结下列公共类型。完成后通知协调者，Agent B/C 才开始依赖这些文件：

- `ElementIds` 或等价的唯一元素目录，禁止业务脚本自由拼写 `StringName`。
- `ElementDefinition`。
- `AttackPayloadDefinition`，至少支持 `NONE / FOLLOW_CAST_FORM / FIXED_ELEMENT`。
- `CastSnapshot`：创建后不可补写 Delivery。
- `RuntimeAttackPayload`。
- `ElementSnapshot`。
- `HitRequest`。
- `ElementResolution`。
- 内部 `CombatPlan`。
- 外部 `CombatResult`。
- `CombatResult` 至少提供 `final_damage`、命中世界坐标、反应信息和表现标签，供 UI 单向读取。
- `DamageReceiver` 在完整提交后提供当前生命、最大生命和变化量通知；UI 不得依赖提交前事件。
- 结构化拒绝原因和子结果状态。

公共协议必须满足：

- `HitRequest` 不包含 `target_receiver`；调用对象本身就是目标。
- `CastSnapshot` 不包含可后补的 `delivery` 字段。
- 命中身份至少包含 `cast_id + delivery_id + hit_index`。
- `HitRequest` 不允许负元素量、未知元素 ID、非有限伤害或缺失攻击身份。
- `stat_snapshot` 不得是无约束的任意 Dictionary；至少通过构造函数/工厂校验允许字段并进行深复制。
- Resource 中不得保存冷却、释放者、剩余时间、已命中目标等运行时状态。

如果必须修改已冻结的公共签名，先停止并向协调者说明影响，不得自行让其他 Agent 返工。

## 5. 实现范围

建议所有新增代码位于 `res://combat/`，职责优先于具体文件名。

你负责：

- 公共数据类型和输入校验。
- `ElementCarrier`：封装快照、整体替换、清空和静默提交。
- 水火纯 Resolver。
- 当前最小伤害 Resolver。
- `DamageReceiver` 或不死亡的 Health 测试实现。
- `CombatReceiver`：合法性检查、读取快照、预计算、静默提交、最终通知。
- 纯规则和目标提交测试。

首版不要创建万能 `ReactionRule` DSL。允许使用一个明确的水火规则类或稳定的小型策略接口。

`carrier_profile` 不得混用 `hostile/friendly/summon/earth_construct/boss_part` 等不同维度标签。MVP 只实现结算真正需要的能力，例如：

- 是否允许元素附着。
- 是否允许异元素反应。
- 每元素容量，目前固定或配置为 10。
- 是否接受普通伤害。

阵营关系来自攻击与目标的 team/relationship 校验，不属于载体类型。

## 6. 提交语义

`CombatReceiver.receive_hit(request) -> CombatResult` 必须同步完成以下流程，中间不得 `await`：

1. 校验目标状态、阵营、无敌/格挡状态和 Request。
2. 读取目标元素与防御快照。
3. 纯计算出完整 `CombatPlan`。
4. 验证全部 delta 和最终数值。
5. 对 ElementCarrier、DamageReceiver 等组件进行无 Signal 的静默写入。
6. 所有状态均完成后生成 `CombatResult`。
7. 最后统一发送命中、反应、生命变化、死亡候选和表现通知。

这不是数据库回滚事务。实现目标是“外部监听者只能观察到完整提交后的状态”。提交阶段禁止重入；死亡或 `queue_free()` 必须等提交完成后处理。

Receiver 不得永久保存无界 `hit_token` 集合。首要去重责任属于 Agent C 的 Delivery/命中窗；Receiver 只做有界的防御性验证或近期缓存时，必须有明确容量和清理点。

## 7. 必测用例

至少覆盖：

```text
水 3 命中空载体       → 水 3，倍率 1.0
水 5 命中已有水 8     → 水 10，倍率 1.0
水 5 命中已有火 2     → 火 0、水 3，倍率 1.6
水 2 命中已有火 5     → 火 3、水 0，倍率 1.6
水 10 命中已有火 10   → 水 0、火 0，倍率 4.0
火命中水               → 与水命中火严格对称
元素量 0               → 不反应、不产生幽灵残量
负数/未知 ID/非法快照 → 结构化拒绝，不修改状态
无 Carrier             → 正常伤害
无 DamageReceiver      → 正常附着和反应
两组件都无             → 明确拒绝且不报错
合法命中但最终伤害为 0 → 元素仍按规则处理
无敌/格挡              → 伤害和元素都不处理
```

补充验证：

- 两个目标共享同一 Resource 时运行时状态互不污染。
- Signal 回调中读取到的元素和生命均为最终状态。
- 致命伤、回调触发新命中、目标待删除均不产生半提交状态或失效引用错误。
- 不出现负元素、超过 10、NaN 或无限值。

## 8. 禁止项

- 不修改 Player、Enemy 和主测试房间。
- 不实现输入、动画、技能状态机或具体投射物。
- 不在 Delivery 或具体技能脚本内写反应规则。
- 不引入外部测试插件或网络依赖。
- 不提前实现对象池、万能 Buff 系统或未来元素组合。
- 不删除 `prototype_skill`。

## 9. 交付与验收

交付时提供：

- 公共类型及字段说明。
- `receive_hit()` 的精确提交顺序。
- 可重复运行的自动测试及结果。
- Agent B/C 所需的最小调用示例。
- 仍存在但不影响 MVP 的限制清单。

验收条件：纯 Resolver 无场景副作用；所有冻结规则得到唯一结果；目标组件缺失能安全降级；所有通知发生在完整提交之后；其他 Agent 无需修改你的公共类型即可接入。
