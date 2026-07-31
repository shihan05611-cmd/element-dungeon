# Agent C 任务书：首批特殊技能 Delivery 与目标事务

状态：ACCEPTED
负责人：Agent C
依赖：14_agent_b2_skill_execution_contracts 已通过 Review
后续：本任务验收后，任务 16 才能进行正式内容集成；任务 17 才能冻结最终 VFX 范围与时序

## 1. 任务定位

消费任务 14 已冻结的执行快照和端口，实现首批技能中三个具体空间行为：

- 元素之怒：按锁定范围倍率进行一次范围爆发。
- 元素激光：持续 Beam，每个 Tick 穿透并命中范围内全部合法目标。
- 回收：查询范围内当前元素附着，原子消耗并汇总恢复量。

Agent C 不修改费用策略、技能内容目录、奖励、Host、HUD 或美术碰撞表现。

## 2. 共同边界

- 只消费任务 14 的类型化执行快照，不重新读取施法者实时能量、攻击力或 CurrentElement。
- 伤害仍经 `HitRequest → CombatReceiver` 提交；不得在 Delivery 内复制反应、减伤或生命规则。
- 非伤害的回收不得伪装成 0 伤害 HitRequest。
- 查询只接受正式 `CombatHurtbox` / 明确端口，不遍历任意父节点猜组件。
- 多目标顺序必须确定，测试不得依赖物理查询的偶然返回顺序。
- VFX、Shader 和贴图大小不能决定命中范围；逻辑形状是唯一权威。

## 3. 元素之怒范围爆发

- CURRENT_ELEMENT 使用接受时锁定元素。
- 使用快照中的 damage_multiplier、element_amount 和 radius_scale。
- 爆发只提交一个逻辑命中窗；同一目标最多命中一次。
- 范围内所有合法敌方 Hurtbox 均可命中；墙体阻挡规则必须显式配置并测试。
- 20 能量快照应为 160%、1 层；100/100 能量为 800%、5 层、2.0 倍基础半径。
- 快照生成后改变能量、最大能量、攻击力或元素，不得改变本次结果。
- 若复用 `DelayedAreaDelivery`，必须证明其协议足够；不得为了复用而污染通用基类。

## 4. 元素激光

- Beam 使用任务 14 Channel 提供的 0.5 秒 Tick。
- 穿透光束范围内全部合法目标，不在首个目标处停止。
- 每个目标在每个 Tick 最多命中一次；下一个 Tick 可以再次命中。
- 每 Tick 使用新的 hit_index 或等价明确身份，使 DeliveryBase 去重只覆盖当前 Tick。
- 每 Tick 造成 50% 攻击力伤害并附着 1 层锁定元素。
- 目标中途进入光束后从下一合法 Tick 起可被命中；离开后不命中。
- 大 delta 跨越多个 Tick 时按顺序精确提交，不合并伤害、不漏掉合法 Tick。
- 松键、能量不足、中断、死亡、离树和换层时关闭查询并清理记录。
- 激光允许玩家移动；Delivery 不得把角色位移锁写回战斗规则。

## 5. 回收范围事务

### 5.1 预检

- 使用接受时锁定的当前元素。
- 查询范围内全部合法敌方 `ElementCarrier`。
- 若总可吸收层数为 0，返回任务 14 定义的结构化失败。
- 若玩家能量已满，返回结构化失败。
- 预检失败不消耗层数、不恢复能量、不进冷却、不发布成功事件。

### 5.2 原子提交

- 首版消耗范围内全部目标的全部匹配元素层数。
- 恢复能量 = 实际消耗总层数 × 5，由 EnergyComponent 按最大值截断。
- 接近满能量时允许发生上限截断；报告中必须分别记录“消耗层数、理论恢复、实际恢复”。
- 提交前为每个 Carrier 生成完整前后快照并验证全部替换可行。
- 全部验证通过后先静默提交所有 Carrier 和能量，再统一发布变化通知。
- 任一目标在提交前失效或快照不再匹配时，整个事务拒绝，不能只消耗部分目标。
- 目标顺序使用稳定身份排序，保证重复运行结果一致。

## 6. 复用与生命周期

- 元素之怒和激光若使用对象池，必须满足任务 09/11 的脱树、重入树和状态清理要求。
- 每次复用清空命中索引、目标缓存、Tick 计数、Beam 查询状态和旧快照。
- `queue_free`、取消和目标释放不能产生悬空回调。
- 不创建无界全局目标账本，不把目标 Node 写入静态 Resource。

## 7. 文件范围

可修改：

- `combat/delivery/**`
- 新建 `combat/targeting/**` 或同等窄范围查询实现
- `combat/components/element_carrier.gd`，仅限类型化、原子的层数消费边界
- 任务 14 明确交给 Agent C 的执行端口实现
- `combat/contracts/**` 中仅为上述空间结果必需的增量类型
- Delivery/目标事务测试、专用测试场景和说明

不得修改：

- `SkillExecutor`、费用/冷却/Channel 时钟和被动契约。
- `DamageResolver`、水火反应公式、CombatReceiver 结算顺序。
- `growth/**`、奖励、商店、RunSession。
- `scripts/run_session_host.gd`、`scripts/test_room.gd`、HUD 和正式内容目录。
- 技能图标、VFX 贴图或正式技能 Resource。

## 8. 自动测试

- 元素之怒覆盖最小、最大和中间能量半径；单目标、多目标、墙体、重复 overlap 和快照锁定。
- 激光覆盖 0.49/0.50/1.00 秒、大 delta、多目标穿透、目标进出、每 Tick 去重和跨 Tick 重命中。
- 激光取消、能量不足、死亡、离树和复用后无残留命中。
- 回收覆盖无目标、无匹配元素、满能量、单目标、多目标、混合水火、接近满能量、目标失效和原子失败。
- 回收只移除锁定元素，另一元素保持不变；通知中的 delta 与实际前后快照一致。
- 所有伤害型行为仍通过 CombatReceiver，并保留反应层数和倍率规则。
- 全量回归和主场景 smoke 通过，无新增脚本错误或警告。

## 9. 交付

- 报告新增 Delivery、查询端口、事务类型和场景。
- 报告三种技能的专项测试及全量回归。
- 向任务 16 提供可直接配置的正式场景路径、逻辑范围参数和执行示例。
- 向任务 17 提供只读 VFX 基准：逻辑半径、Beam 长宽、Tick 时序、生成点和结束时序。
- 不执行任何 Git 命令，不自行把任务标为 `ACCEPTED`。

## 10. 协调者下发记录（2026-07-24）

- 前置任务 14 已由 Review 独立复验并归档为 `ACCEPTED`，最终基线为 165 tests / 1075 assertions。
- 本任务已正式下发给 Agent C；只允许按第 7 节文件范围实现，不得修改 B 的执行时钟、费用策略或正式 Host/内容目录。
- Agent C 完成后提交 `REVIEW`，由协调者独立复验；通过前任务 16 不得开工。

## 11. Agent C 实施记录（2026-07-24）

### 11.1 交付内容

- 新增 `ElementRageDelivery` 与 `res://combat/delivery/element_rage_delivery.tscn`：只消费 `AllEnergyBurstExecutionSnapshot`，按 `base_radius × radius_scale` 执行单命中窗圆形查询；墙体阻挡由 `walls_block_targets` / `blocking_collision_mask` 显式配置。
- 新增 `ElementBeamDelivery` 与 `res://combat/delivery/element_beam_delivery.tscn`：不持有时钟，只按顺序消费任务 14 生成的 `ChannelTickSnapshot`；每 Tick 清理上一 Tick 账本，将当前 Tick 的锁定 payload 直接经 `HitRequest → CombatReceiver` 提交。
- 新增 `CombatTargetQuery2D` / `CombatTargetCandidate2D`：查询结果只来自 `CombatHurtbox`，按 Receiver 实例稳定身份及 Hurtbox 身份排序。
- 新增 `RangeElementReclaimPort`、`RangeElementReclaimTransaction` 与 `ElementReclaimTargetPlan`；新增 `ElementLayerConsumePlan` 和 `ElementCarrier` 的类型化预览、静默提交、提交后发布边界。
- 回收事务锁定所有 Carrier 完整前后快照及能量快照；验证全部目标后，先静默提交全部 Carrier 和截断后的能量，再按稳定身份发布 Carrier 通知，最后发布实际能量 delta。任一目标、Carrier 或能量快照变化均使整体预提交校验失败。
- 任务 16/17 的场景、参数、执行接线和只读 VFX 基准见 `combat/delivery/FIRST_BATCH_DELIVERIES.md`。

### 11.2 专项测试

命令：

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . `
  --script res://combat/tests/run_first_batch_delivery_tests.gd
```

结果：`TASK 15 FIRST BATCH TESTS PASSED: 26 tests, 163 assertions`。

覆盖：

- 元素之怒：20/50/100 能量半径与 160%/400%/800% payload、单/多目标、水火反应、墙体开关、重复 Hurtbox 去重、能量/攻击/元素快照锁定。
- Beam：0.49/0.50/1.00 秒、1.5 秒大 delta 三个顺序 Tick、多目标穿透、目标进出、单 Tick 去重、跨 Tick 重命中、乱序拒绝、松键、能量不足、死亡、离树与复用清理。
- 回收：无显式目标、无匹配、满能量、单/多目标、混合水火、接近满能量截断、稳定通知顺序、目标失效、Carrier 快照变化、能量快照变化及整体原子拒绝。

### 11.3 全量、扫描与 smoke

- 全量：15 个无头入口全部通过，合计 `191 tests / 1238 assertions`（原基线 `165 / 1075` 加任务 15 `26 / 163`）。
- 编辑器扫描：`Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit` 返回 0；无新增脚本错误或警告。
- 主场景 smoke：`Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 180` 返回 0；180 帧无运行期错误或警告。
- 未修改 `SkillExecutor`、费用/冷却/Channel 时钟、被动契约、`DamageResolver`、反应公式、`CombatReceiver` 顺序、growth、Host、HUD、正式内容目录或 VFX；未执行任何 Git 命令。

结论：Agent C 已完成任务 15 并提交 `REVIEW`，等待协调者独立复验；未自行标记 `ACCEPTED`，未归档。

## 12. Review 最终验收（2026-07-24）

- 静态复核通过：元素之怒仅消费锁定的 `AllEnergyBurstExecutionSnapshot`；Beam 不自建时钟，只按顺序消费 `ChannelTickSnapshot`；伤害统一经 `HitRequest → CombatReceiver`。
- 目标查询边界通过：空间查询只接受类型化 `CombatHurtbox`，结果稳定排序；同一 Receiver 的重复 Hurtbox 可确定性去重，墙体规则为显式配置。
- 回收事务通过：完整锁定 Carrier 与能量快照，全部预检后静默提交，再按稳定顺序发布通知；快照或目标失效时整体拒绝，无部分提交。
- 协调者独立复跑 15/15 个无头入口全部通过，合计 `191 tests / 1238 assertions`；其中任务 15 专项为 `26 tests / 163 assertions`。
- Godot 4.7.1 编辑器会话可正常解析并启动主场景；主场景实际运行至 1618 帧，当前运行日志无错误或警告。编辑器中仅保留既有、与任务 15 文件无关的基线 warning，未发现本任务新增脚本问题。
- 任务 16 的正式内容集成与任务 17 的最终范围/时序收口解除任务 15 前置阻塞。

结论：任务 15 验收通过，状态改为 `ACCEPTED`，由协调者归档。
