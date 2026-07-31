# Agent C 新任务书：锁定元素 Delivery、延迟攻击与池复用安全

状态：ACCEPTED
负责人：Agent C
依赖：08_agent_b_current_element_cast_transaction Review 验收通过

## 1. 任务定位

复核并强化所有攻击载体只使用接受释放时锁定的 skill_id、CastSnapshot 和 RuntimeAttackPayload，覆盖投射物、多段、延迟范围以及未来对象池复用生命周期。

## 2. 独占范围

可以修改：

- combat/delivery/**
- combat/contracts 中仅与 Delivery 生命周期直接相关的新窄契约
- combat/tests/run_delivery_tests.gd
- combat/tests/run_delivery_skill_integration_test.gd
- 专用 Delivery 测试脚本与场景
- scripts/element_projectile.gd 和 scripts/transient_melee_delivery.gd 中仅与锁定表现/生命周期有关的部分

不得修改 SkillExecutor、CurrentElement、成长系统、伤害/元素 Resolver、Player、HUD 或正式房间流程。

## 3. 锁定规则

- initialize_delivery 只接受已经验证并锁定的 CastSnapshot 与 RuntimeAttackPayload。
- Delivery 不读取施法者实时 CurrentElement、当前槽位或当前 SkillDefinition。
- 投射物颜色、特效标签和命中元素来自锁定 Payload。
- 多段攻击的每个 hit_index 使用同一锁定元素，除非未来技能定义显式生成多个独立 Cast；本任务不得自行引入变化。
- 延迟攻击在排队时持有不可变快照，触发时不重新查询施法者。
- 同一技能键换装或元素变化不影响已经生成的 Delivery。

## 4. 池复用契约

当前不要求建立全局对象池管理器，但必须提供并测试安全的复用边界：

- 只有 finished、已离树并完成清理的 Delivery 才能 reset/prepare_for_reuse。
- reset 清除旧 Cast、Payload、delivery_id、方向、距离、命中缓存、信号连接和完成状态。
- 新一轮 initialize 只能在 reset 后执行一次。
- 未 reset 的二次 initialize 明确拒绝。
- 复用后绝不能携带上一轮元素、skill_id、hit_index 或目标去重记录。
- 非池路径继续安全 queue_free，不要求所有正式攻击立即使用对象池。

## 5. 必测用例

- 通用水投射物生成后 CurrentElement 切火，投射物仍为水。
- 专属技能自动切换后生成的投射物使用专属锁定元素。
- 延迟范围攻击排队后切换元素，全部命中保持原元素。
- 多段攻击全部段使用同一 Cast 快照，同时 hit_index 去重仍正确。
- 连续施法使用不同 Cast/Delivery ID 且互不污染。
- 池对象水攻击结束、reset、复用为火攻击后没有旧水元素或命中缓存。
- 未 reset 二次初始化拒绝。
- cancel、finish、撞墙、超距、离树和 reset 均清理引用。
- 现有高速薄目标、墙优先、多 Hurtbox 和快照测试全部回归。

## 6. 交付

- 报告测试结果、修改文件清单和剩余限制。
- 不执行任何 Git 命令；由用户统一提交。
