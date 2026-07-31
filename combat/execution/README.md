# 类型化技能执行契约

主动释放统一经过 `REQUEST → VALIDATE/PREPARE → ACCEPT/COMMIT → RUNTIME → END`。`SkillExecutor` 只依赖 `SkillExecutionDefinition`、`SkillExecutionRuntime` 和边界结果，不读取具体技能 ID，也不按策略类型做中央分派。

## 定义、快照与 Runtime

- `SkillExecutionDefinition.prepare(context, services)` 必须在提交前完成所有可能失败的 Provider、空间查询、Delivery 初始化及外部事务验证。
- `SkillExecutionPrepareResult` 携带接受快照、Runtime、可选的树外 Delivery 和可选的 `SkillExecutionCommitTransaction`。
- `SkillExecutionSnapshot` 锁定 Cast、元素、攻击属性、接受时能量/上限、初始消耗与移动策略。策略子类再锁定 Payload、半径或 Tick 参数。
- `SkillExecutionRuntime` 用 `time_to_boundary / advance_time / reach_boundary` 暴露确定性边界。Executor 可处理大 `delta`，但不需要知道 Runtime 的具体类型。
- `SkillExecutionEndResult` 区分 `COMPLETED / RELEASED / INSUFFICIENT_ENERGY / CANCELLED / INTERRUPTED / DEATH / TREE_EXITED / PAUSED / INTERNAL_FAILURE`。

提交顺序固定为：外部事务静默提交、初始能量、冷却、元素、执行状态；随后才发布结构化通知。准备拒绝不产生任何上述副作用。

## 四种执行策略

| 策略 | 锁定与边界 |
| --- | --- |
| `InstantDeliveryExecution` | 固定消耗；接受前创建并初始化 Delivery；ACTIVE 时只加入树一次。 |
| `AllEnergyBurstExecution` | 门槛 20；消耗全部接受时能量；倍率 `E×0.08`，层数 `floor(E/20)`，半径 `1+floor(E/max×10)×0.1`。 |
| `ChannelExecution` | 每满 0.5 秒扣 5 能量并产生一个 50% 攻击、1 层的 Tick；首 Tick 不提前，尾段不扣费，允许移动。 |
| `ElementReclaimExecution` | 当前元素、零能耗、5 秒冷却；满能量返回 `NO_BENEFIT`，端口无目标返回 `NO_LEGAL_TARGET`，均不进入提交。 |

Channel 的每个 `ChannelTickSnapshot` 从接受时锁定的 `CombatStatSnapshot` 和元素生成 Payload。释放、取消或能量不足只结束 Runtime，不会补发尾 Tick。

## 被动运行时

`SkillDefinition.passive_effect_definition` 直接携带 `PassiveEffectDefinition`。`PassiveSkillController` 在装备、重建或复活时为每个绑定创建一个新的 `PassiveEffectRuntime`，卸下、死亡、换层或清空时注销；`PassiveEffectAdapter` 只聚合 Runtime 的属性快照并转发类型化时间/普攻事件，不含字符串效果分派。

- `BurningPassiveEffectRuntime` 每满 1 秒通过 `PassiveTargetPort` 查询固定火层，提交 `层数×0.05` 的中立元素伤害 Payload，不消耗附着层。
- `UnendingPassiveEffectRuntime` 只消费生产方认证的 `BasicAttackCommittedEvent`，读取该目标快照中的固定水层并通过 `PassiveOwnerPort` 恢复同等生命。
- 四个现有属性被动使用 `StatModifierPassiveEffectDefinition → StatModifierPassiveEffectRuntime`，保持原有生命、能量和攻击倍率叠加。

空间目标查询、燃烧伤害实际提交、不息生命恢复，以及回收的多目标层数消费由集成层实现对应 Port；这些 Port 不得把可失败工作延迟到提交之后。
