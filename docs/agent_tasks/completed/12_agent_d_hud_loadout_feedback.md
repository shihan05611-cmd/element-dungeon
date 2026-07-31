# Agent D 4.0 任务书：战斗 HUD、配装界面、反馈与体验验收

状态：ACCEPTED
负责人：Agent D 4.0
协调线程：`019fb35f-3267-7810-a0e7-17f1cb319639`（Agent D 4.0：正式 HUD 与配装体验）
依赖：11_agent_f_architecture_slimming、16_agent_d2_skill_content_catalog、17_vfx_agent_first_skill_assets、18_agent_d3_skill_vfx_runtime 全部 Review 验收通过

## 1. 任务定位

完成共享技能栏和元素机制的正式 HUD、配装界面、战斗反馈、可访问性与体验验证。UI 只能读取快照和提交后事件，不能拥有战斗或成长规则。

## 2. 独占范围

可以修改：

- scripts/combat_hud.gd
- scripts/combat_feedback.gd
- 新建配装、奖励、商店和提示 UI 脚本
- scenes/combat_hud.tscn
- 新建 UI 场景与主题资源
- test_room 的 UI 接线
- D 集成/布局/视觉测试和体验记录文档

不得修改 E/B/C 核心契约、Agent A 公式/Resolver、SkillExecutor 或 Delivery 内部。

## 3. 战斗 HUD

- 固定显示 CurrentElement，使用颜色 + 图形 + 文本，不能只靠颜色。
- 固定显示 ACTIVE_1～3 与 PASSIVE_1，任何状态变化不得引起位置或尺寸跳动。
- EXCLUSIVE_ELEMENT 使用固定元素实心角标。
- CURRENT_ELEMENT 使用动态角标，预览当前将锁定的元素。
- NEUTRAL 使用中性空心角标。
- 通用技能被接受后短暂显示元素锁定反馈。
- 专属技能自动切换成功时显示槽位到 CurrentElement 指示器的反馈。
- 手动切换只显示手动反馈，并立即更新通用技能角标。
- 失败释放只显示失败原因，不播放自动切换或锁定成功反馈。
- 能量不足、冷却中、忙碌/不可操作使用不同表现。
- ACTIVE 位置中的 PASSIVE 显示“被动”，移除释放键帽、能量和冷却信息。
- PASSIVE_1 永远不显示可释放键帽。

元素切换动画控制在约 150～200ms，只影响表现，不阻塞输入。

## 4. 配装界面

- 明确区分 ACTIVE/PASSIVE 行为类型和三种元素策略。
- ACTIVE 技能拖入 PASSIVE_1 时明确拒绝并显示原因。
- PASSIVE 拖入 ACTIVE 位置时允许，并预览“该按键将不可释放”。
- 0 主动配置显示：
  - 当前没有可按键技能；
  - 战斗将依赖普通攻击与被动。
- 不强制至少装备一个主动技能。
- 不增加额外技能栏、快捷栏或隐藏槽位。
- 技能说明分别标注固定元素、读取当前元素或无属性。
- 共享四槽只显示一次，不按水火分页或保存两套配置。

## 5. 战斗反馈与可读性

- 敌人身上的元素类型和层数清晰可读，同样使用颜色 + 图形。
- 反应反馈显示实际消耗层数和倍率。
- 使用 CombatResult.offensive_damage、reacted_damage、final_damage 展示语义；画面只产生一个最终伤害数字，另以“反应 ×倍率 / 消耗 N 层”说明增伤，禁止伪造第二次伤害。
- 水火图形在色觉障碍模式下保持可区分。
- 投射物和命中特效使用锁定元素，不读取实时 CurrentElement。
- 减少动态模式保留全部语义信息，仅减少位移、缩放和闪烁。

## 6. 被动与遗物可见性

- 配装变化后被动列表与真实注册一致。
- 显示元素变化类被动/遗物响应范围：全部、仅手动或仅自动。
- 同元素专属技能不显示变化触发反馈。
- 三个 ACTIVE 位置同时装被动时，每个被动各显示一次，不重复堆叠条目。
- 死亡、换层和读档后 UI 不重复列出效果。

## 7. 自动与视觉测试

- 四槽在 1152×648 与窗口缩放下固定、无重叠、无跳动。
- CurrentElement 和三类技能不依赖颜色也可识别。
- ACTIVE 位置 PASSIVE 没有键帽、能量和冷却。
- 0 主动 + 4 被动警告可见且不阻塞确认。
- 能量不足、冷却、忙碌反馈互不混淆。
- 专属失败无切换动画；成功接受才有自动切换动画。
- 手动切换、自动切换和通用锁定反馈可区分。
- 2 层水被 2 层火消耗显示 1.6 倍和消耗 2 层。
- 1 层水被多层火命中只显示实际消耗 1 层。
- 减少动态和色觉障碍模式完成截图检查。
- 全部回归测试和主场景 smoke test 通过。

## 8. P2 体验验证

形成简短记录，不把主观结论写进战斗规则：

- 新玩家能否不看说明识别固定、通用和无属性技能。
- 是否理解专属技能会改变后续通用技能元素。
- 记录通用技能前的手动切换频率。
- 检查是否误以为已生成攻击会跟随实时元素。
- 比较 1、2、3 个主动技能的操作负担和有效选择。
- 验证 0 主动配置可进入并完成流程，且没有明显成为最优解。
- 用第三、第四元素模拟数据验证 HUD 与配装不增加技能栏。
- 若需要连续切换两次以上的情况过多，只记录为后续输入评审，不修改共享槽结构。

## 9. 最终验收条件

- 任意时刻最多显示 3 个主动位置 + 1 个被动位置。
- 元素切换永远不更换装备技能。
- 同一技能键在所有元素状态保持同一技能 ID。
- 专属技能失败不切换，接受成功才切换。
- 打断和取消不回滚元素。
- 通用技能和已生成攻击使用锁定元素。
- HUD 不只依赖颜色表达元素或技能类型。
- 0 主动配置合法、明确且不阻塞流程。

## 10. 交付

- 报告测试结果、截图路径、体验记录、修改文件清单和剩余限制。
- 不执行任何 Git 命令；由用户统一提交。

## 11. 协调者正式下发（2026-07-30）

- 任务 11、16、17、18 已全部 `ACCEPTED`；当前基线为 17/17 个无头入口、`211 tests / 1573 assertions`，任务 18 专项为 `9 / 124`。
- UI 必须直接消费唯一 `RunContentCatalog`、Runtime 快照和任务 17/18 已验收的六技能图标/表现字段；不得重绘、替换或复制 VFX，不得改变唯一 `SkillVfxCoordinator`。
- 任务 14/15 的费用、冷却、Channel、命中、范围、Tick、元素层数与事务语义全部冻结。UI 只读取快照和提交后事件，不得复制或推导权威规则。
- 视觉验收除 1152×648 外，还须覆盖窗口缩放、色觉障碍、减少动态、0 主动 + 4 被动、ACTIVE 放被动及 PASSIVE_1 拒绝主动等关键状态；不得以节约成本为由缩减测试或截图。
- 已新建干净的 Agent D 4.0 任务并直接下发。完成后只更新为 `REVIEW`，向协调线程回传，由协调者独立验收；不得执行 Git 或自行标记 `ACCEPTED`。

## 12. Agent D 4.0 交付记录（2026-07-30）

状态只更新为 `REVIEW`，未自行标记 `ACCEPTED`，全程未执行 Git 命令。

### 文件边界

- `scripts/combat_hud.gd`、`scenes/combat_hud.tscn`：正式固定四槽 HUD、CurrentElement、目标层数、结构化释放反馈、色觉辅助和减少动态。
- `scripts/combat_feedback.gd`：只消费提交后的 `CombatResult`，画面只生成一个最终伤害数字，并附实际倍率/消耗层数。
- `scripts/ui/combat_ui_tokens.gd`、`scripts/ui/run_overlay_interface.gd`：共享配装、奖励、路线和商店 UI；事务仍由 `RunSession` / `ShopDraft` / RuntimeLoadout 执行。
- `scripts/test_room.gd`：仅增加 HUD 到既有 `RunSessionHost` 的 UI 接线。
- `combat/tests/run_hud_loadout_feedback_tests.gd`、`combat/tests/capture_task12_visuals.gd`：任务 12 自动验收和实际 TestRoom 截图入口。
- `docs/agent_tasks/evidence/task12/`：九张截图、P2 启发式体验记录和遗留风险。

未修改 SkillExecutor、Delivery、Targeting、Carrier/Receiver/Resolver、growth、RunSessionHost 规则或正式技能数值；未重绘、替换或复制任务 17/18 VFX，TestRoom 保留唯一 `SkillVfxCoordinator`。

### 验证结果

- 任务 12：`13 tests / 110 assertions`。
- 任务 18：`9 / 124`。
- 任务 16：`11 / 209`。
- 任务 15：`26 / 163`。
- 全部无头入口：`18/18`，合计 `224 tests / 1683 assertions`。
- Godot editor scan：退出码 0。
- 主场景 smoke：`--quit-after 180`，退出码 0。
- 实际 TestRoom：1152×648、900×540、色觉辅助、减少动态、ACTIVE 放被动、PASSIVE_1 拒绝主动、0 主动 + 4 被动结构态、单一最终伤害数字和奖励 UI 均已截图。

### 证据与风险

完整索引与 P2 记录见 `docs/agent_tasks/evidence/task12/README.md`。

- 正式六技能目录目前只有两个被动，四个不同被动的合法事务由任务 10/06 测试定义覆盖；0 主动 + 4 被动截图是 UI 结构压力夹具，RuntimeLoadout 仍会拒绝重复技能。
- 正式目录目前没有可按键专属主动，自动调谐 HUD 反馈以只读 CastSnapshot/策略夹具覆盖；原子切换与失败不切换继续由任务 14/15 冻结回归覆盖。
- 900×540 是本轮复核的实用下限；未来更长本地化文案需重新验证文本密度，但不得通过增加技能栏解决。

## 13. 协调者独立验收（2026-07-30）

结论：`ACCEPTED`。任务 12 已满足正式 HUD、共享配装、战斗反馈、可访问性与体验验收条件，允许归档。

### 独立复核

- 文件边界通过：HUD 只读取现有组件、快照与提交后事件；配装预览调用 `RuntimeLoadout.validate_snapshot`，商店、奖励与路线分别调用既有 `ShopDraft` / `RunSession` 事务，没有在 UI 中复制战斗、奖励、成长或配装规则。
- 任务 12 专项独立复跑：`13 tests / 110 assertions`；任务 18、16、15 专项分别为 `9/124`、`11/209`、`26/163`。
- 全部无头入口独立复跑：`18/18`，合计 `224 tests / 1683 assertions`，全部通过。
- Godot 4.7.1 editor scan 与主场景 `--quit-after 180` 均退出码 0。
- 连接编辑器实际运行 TestRoom：固定四槽、配装层开关、F4 减少动态、F5 色觉辅助均正常；game log 仅有 helper 注册信息。editor log 的 12 条 warning 全部位于任务外既有 combat/growth 文件，任务 12 新增文件无 warning/error。
- 九张实际截图全部复核：1152×648 与 900×540 无越界/重叠；元素不只依赖颜色；ACTIVE 放被动、PASSIVE_1 拒绝主动、0 主动警告、唯一最终伤害数字和奖励目录文案均符合任务书。

### 边界说明与保留风险

- `project.godot` 的较新时间戳来自 Godot AI 插件重载时临时移除再恢复 `editor_plugins/enabled` 与 `autoload/_mcp_game_helper`；当前值恢复为既有配置，净功能变化为零，不属于任务 12 实现。
- 正式目录仅有两个被动、暂无可按键专属主动，因此四被动与自动调谐部分保留为结构/表现夹具；真实合法性和原子切换继续由任务 10/06 与 14/15 回归覆盖。未来正式内容补齐后须再做内容态复验。
- 900×540 接近当前文本密度下限；更长本地化文案需要重新视觉验收，但不得通过增加技能栏解决。