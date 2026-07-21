# Combat MVP（Agent A 公共契约）

本目录是水/火 MVP 的公共战斗协议与目标侧权威实现。它不包含输入、技能状态机、Delivery、具体投射物、土/电、Buff、玩家正面附着或 Boss 部位规则。

## 公共类型

| 类型 | 关键只读数据 / 职责 |
| --- | --- |
| `ElementIds` | 唯一元素目录：`NONE / WATER / FIRE`；业务脚本不得自由拼写元素 ID。 |
| `ElementDefinition` | 静态元素显示定义；Resource 不保存运行时层数。 |
| `AttackPayloadDefinition` | 静态伤害、`NONE / FOLLOW_CAST_FORM / FIXED_ELEMENT`、元素量和表现标签。 |
| `CombatStatSnapshot` | 只接受 `attack_multiplier`、`flat_damage_bonus` 两个标量字段；工厂深复制并拒绝未知字段。 |
| `CastSnapshot` | `cast_id / skill_id / root_owner_id / caster_id / team_id / cast_element_id / stat_snapshot`；创建后不可写且没有 Delivery 字段。 |
| `RuntimeAttackPayload` | 锁定的 `base_damage / offensive_damage / element_id / element_amount / presentation_tags`。 |
| `ElementSnapshot` | 不可变的水/火整数层和容量，始终满足每种元素 `0..capacity<=10`。 |
| `HitRequest` | `CastSnapshot / RuntimeAttackPayload / delivery_id / hit_index / hit_position / hit_direction`；不包含目标引用。 |
| `ElementResolution` | 纯规则输出：前后快照、delta、反应消耗、剩余来袭量和倍率。 |
| `CombatPlan` | Receiver 内部、提交前完整验证的计划。 |
| `CombatResult` | UI/表现单向读取的外部结果；分别包含伤害/元素状态、反应、最终伤害、世界命中坐标、身份和表现标签。 |

`CombatStatus.SubResult` 明确区分 `NOT_AVAILABLE / NOT_PROCESSED / PROCESSED_NO_CHANGE / APPLIED`。`CombatStatus.RejectReason` 提供非法请求、目标失效、无组件、友伤、无敌、格挡、闪避、重复命中、通知期重入、目标配置和提交验证失败等结构化原因。

## 数值顺序

当前最小防御模型是目标命中时读取的非负 `defense_flat`：

```text
offensive_damage = max(0, base_damage * attack_multiplier + flat_damage_bonus)
reacted_damage = offensive_damage * reaction_multiplier
mitigated_damage = max(0, reacted_damage - defense_flat)
final_damage = roundi(mitigated_damage)
```

中间值不取整。水火反应使用 `1.0 + 0.3 * consumed` 独立乘区。

## receive_hit 精确顺序

`CombatReceiver.receive_hit(request)` 同步执行且没有 `await`：

1. 检查 Request、目标生命周期、team、无敌/格挡/闪避和近期重复身份。
2. 获取有效 Carrier/Health，并在命中时读取目标元素、生命和防御。
3. 纯计算 `ElementResolution` 与 `DamageResolution`，组装完整 `CombatPlan`。
4. 验证全部快照、delta、最终生命及组件是否能接受完整替换。
5. 先静默替换 ElementCarrier，再静默替换 DamageReceiver。
6. 从已提交计划创建不可变 `CombatResult`，登记有界近期命中键。
7. 在重入保护仍生效时按固定顺序通知：`hit_resolved → reaction_triggered → element_state_changed → health_state_changed → death_candidate → presentation_requested`。Carrier/Health 自身通知也发生在完整提交后。

通知回调里的新命中会同步得到 `REENTRANT` 拒绝，不会观察或制造半提交。死亡处理或 `queue_free()` 应订阅 `death_candidate`，此时所有状态已经完成。

## Agent B：锁定 Cast 与 Payload

```gdscript
var stats := CombatStatSnapshot.from_dictionary({
    CombatStatSnapshot.ATTACK_MULTIPLIER: 1.25,
    CombatStatSnapshot.FLAT_DAMAGE_BONUS: 2.0,
})
var cast := CastSnapshot.new(
    cast_id,
    skill_id,
    root_owner_id,
    caster_id,
    team_id,
    current_form_element_id,
    stats,
)
var runtime_payload := payload_definition.build_runtime(cast)
if not cast.is_valid() or not runtime_payload.is_valid():
    # 释放事务整体拒绝，不扣费、不开始冷却。
    return
```

`CastSnapshot` 和 `RuntimeAttackPayload` 应在释放被接受时一次创建；Delivery 生成后不得替换它们。

## Agent C：Delivery 命中提交

```gdscript
var request := HitRequest.new(
    cast_snapshot,
    runtime_payload,
    delivery_id, # 同一 Cast 内唯一且 > 0
    hit_index,   # 多段使用不同的 >= 0 值
    hit_world_position,
    hit_direction,
)
var result := combat_receiver.receive_hit(request)
if result.accepted:
    # Delivery 只消费结果/决定自身生命周期，不计算伤害或元素。
    pass
```

调用对象本身就是目标；不要在 Request 中补目标。主要的每目标去重仍由 Delivery 持有。Receiver 仅保留默认 64、可配置上限 256 的近期防御缓存，并在离树时清空。

## 目标组件接线

在场景中给 `CombatReceiver.element_carrier_path`、`damage_receiver_path` 指向受控子组件；测试或运行时组装也可在入树前调用：

```gdscript
receiver.configure_components(element_carrier, damage_receiver)
```

只存在 DamageReceiver 时正常伤害；只存在 ElementCarrier 时正常附着/反应；两者都不存在时返回 `NO_RECEIVERS`。合法命中最终伤害为 0 时，元素仍结算。

## 自动测试

无需第三方插件：

```powershell
Godot_v4.7.1-stable_win64.exe --headless --log-file .godot/combat-tests.log --path <project> --script res://combat/tests/run_combat_tests.gd
```

测试覆盖纯规则矩阵、非法输入、无组件降级、最终零伤害、整体拒绝、一次取整、共享 Resource 隔离、有界去重、通知后状态、通知期重入、致命伤和待删除目标。

## MVP 限制

- 仅水/火；没有自动衰减、土/电、吸收、引爆、Buff 或正面附着。
- 防御只实现命中时读取的 `defense_flat`；没有暴击、易伤、抗性等乘区。
- Receiver 的近期缓存只是有界防线；Delivery 仍负责命中窗内的主要去重。
- DamageReceiver 只发死亡候选，不自行删除宿主。
- 现有 Player、Enemy、主测试房间和 `prototype_skill` 未由本模块修改。
