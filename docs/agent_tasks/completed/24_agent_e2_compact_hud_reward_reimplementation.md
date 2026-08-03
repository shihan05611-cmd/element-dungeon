# 任务 24：紧凑战斗 HUD 与奖励选择重新接入

状态：ACCEPTED
负责人：UI Implementation Agent 2.0
依赖：任务 19、21、22、23 已验收；任务 20 保持历史 `BLOCKED`

## 1. 目标与设计决定

从任务 12 已恢复并验收的 UI 基线重新实现任务 19 的 A「双锚紧凑带」，一次完成主战斗 HUD 与奖励选择界面。设计依据为 `docs/ui/hud_reward_layout_research.md`；用户提供的外部同名文档与项目内副本均为 40,276 字节、SHA-256 `A629CD23D1F8F83C2736B88458F7029515EAF0B33368BA454B150D18990C5BE5`，内容完全一致。

本任务不复用任务 20 的失败实现。任务 20 的测试、证据和事故记录只作为反例与保护对象。

用户本轮明确决定：

- 主要 HUD 采用方案 A 的左上生存胶囊 + 底部居中技能带；
- 奖励阶段采用方案 A 的 1/2/3 项等宽比较卡与独立确认路径；
- **目标身上的水/火元素附着暂不使用任何正式 HUD 文字展示**。不实现目标跟随文字标签、固定 Target 文字面板或离屏文字回退；后续另立 VFX 任务表达该信息；
- CurrentElement 仍是玩家下一步操作所需信息，继续以形状、短文字和颜色冗余编码常驻。

## 2. 正式表现规格

### 2.1 战斗 HUD

- 左上生存胶囊只常驻 HP、能量与低生命警示；移除角色名、长状态句和常驻调试信息。
- 底部居中技能带固定为 `CurrentElement / ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1`。
- ACTIVE 常驻图标、键帽、冷却遮罩/秒数和必要短状态；PASSIVE 使用不同轮廓，不显示虚假键帽或冷却。
- 可用、冷却、能量不足、忙碌、锁定和失败必须不读长句也能区分；短时反馈置于顶部安全区。
- 操作帮助不再常驻；只允许首次进入或设置变化后的短时回显。
- 正式 HUD 不显示目标元素附着文字。为保持任务 12 公开接口/旧测试兼容，可以保留不可见兼容节点和只读数据绑定，但不得在实际 Viewport 中渲染。
- 目标常驻包围盒以任务 19 方案 A 的约 `8.10%` 为目标，不得通过不可读字号换面积。

### 2.2 奖励选择

- 页面采用固定纵向结构：标题/上下文区、卡片比较区、底部操作安全区；禁止再次使用会让卡片整体下沉的 `SIZE_EXPAND_FILL + SIZE_SHRINK_CENTER` 组合。
- 3 项等宽并排；2 项等宽居中；1 项单卡居中。UI 按权威 offer 实际数量布局，不补候选。
- 卡片以一致顺序展示权威已有字段：图标与名称、奖励/技能类型、元素策略、核心效果、能耗/冷却或触发条件、已有/已装备/槽位合法性等构筑状态。
- 缺少权威字段时收起对应行，不从 ID、颜色或文案猜测稀有度、协同、推荐度或替换收益。
- 移动焦点不领取；显式确认才调用既有事务。一项候选也不能自动领取；提交中阻止重复输入，失败后保留可恢复焦点。
- 长中文、长英文不得挤压或覆盖底部确认区；优先摘要、换行和聚焦详情，不把正式正文缩到不可读。

### 2.3 分辨率与无障碍

- 逻辑画布仍为 `1152×648`；P0 验证 `1920×1080`、`2560×1440`，P1 验证 `1366×768`、`2560×1600`、`3840×2160`，P2 验证 `3440×1440`，`900×540` 仅作极限压力测试。
- 使用 Control 锚点、容器与逻辑/物理缩放换算；16:10 与超宽扩展战场，核心 HUD 保持在安全框，不横向拉伸。
- 可交互/焦点热区不小于 44 px；焦点始终可见；普通文本对比至少 4.5:1。
- 水/火、可用/冷却、成功/失败不能只靠颜色；减少动态模式禁止位移、缩放、闪烁和持续脉冲。

## 3. 权威边界与兼容要求

- 固定共享槽位、CurrentElement、冷却/能量/忙碌/锁定、单一最终伤害数字及奖励事务都只消费现有权威状态。
- 不修改 SkillExecutor、Delivery、Targeting、CombatResult、RuntimeLoadout、RunSession、ShopDraft、Growth、Catalog 或 VFX 规则。
- 不新增目标选择逻辑，不删除目标附着数据或信号；本轮只决定“不在正式 HUD 用文字显示”。
- 奖励页继续覆盖真实奖励 → 路线 → 商店/ShopDraft 链路，不伪造重随、取消、撤销或新规则。
- 任务 12 的公开节点路径和方法尽量保持兼容；若视觉重排必须调整内部结构，先通过适配层保留已有调用，不修改任务 12 历史测试来掩盖回归。

## 4. 独占写入范围

只允许修改或新增：

- `scripts/combat_hud.gd`
- `scripts/ui/combat_ui_tokens.gd`
- `scripts/ui/run_overlay_interface.gd`
- `combat/tests/run_task24_compact_hud_reward_tests.gd`
- `combat/tests/capture_task24_visuals.gd`
- `docs/agent_tasks/pending/24_agent_e2_compact_hud_reward_reimplementation.md`
- `docs/agent_tasks/evidence/task24/**`

基线三脚本必须在首次写入前确认：

- CombatHUD：Git blob `661d017c4bb2025541deb09d72ec55bf5a12594f`
- RunOverlayInterface：Git blob `b98a9c223f87caa983bb97d14639d73c62957337`
- CombatUiTokens：Git blob `78751a2d90c88f6457861717b7781c1d8179d278`

任一基线不匹配或出现其他执行者对上述文件的新写入，立即停止并报告协调者。

## 5. 禁止范围与执行方式

- 禁止修改任何 `.tscn`、`.tres`、正式图片/动画/VFX、`project.godot`、`combat/` 与 `growth/` gameplay 实现、任务 20 测试/证据及任务 21～23 恢复成果。
- 禁止使用共享 Godot 编辑器或 Godot MCP 执行保存、reimport、plugin reload、ResourceSaver 或 ProjectSettings.save。
- 共享项目只用文本补丁修改 allowlist 文件；所有 scan、测试、smoke、实际 Viewport 截图和运行日志必须在全新的 `C:\tmp` 冷副本/独立 profile 中完成。冷副本首条 Godot 命令必须是 headless editor scan。
- 执行者禁止所有 Git 写操作，不提交、不暂存、不恢复、不清理。
- 任务 20 的旧 runner 继续作为非门禁历史诊断，不得修改成“通过”；任务 24 使用新 runner 建立新基线。

## 6. 验证与证据

自动化至少覆盖：

- HUD 固定 3+1 槽序、CurrentElement、状态语法、无可见目标附着文字；
- 全部分辨率的边界、安全区、字号与 44 px 热区；
- 1/2/3 项奖励布局、焦点顺序、显式确认、重复提交保护和长文本；
- 色觉辅助、减少动态和单一最终伤害数字；
- 任务 12、16、18 专项继续通过；已接受的 18 个 runner 加任务 24 新 runner 全部通过；任务 20 runner 单独报告但不计入门禁；
- editor scan、180 帧主场景 smoke 退出码 0，完整日志无新增 error/warning。

在 `docs/agent_tasks/evidence/task24/` 提供实际 Godot Viewport 证据与 README，至少能独立核验：

1. 1080p、1440p 主 HUD；
2. 16:10、4K、超宽和 900×540 压力边界；
3. 冷却、0 能量、忙碌/失败与 PASSIVE 状态；
4. 三项、两项、单项奖励及显式确认；
5. 80 中文字符/长英文名压力态；
6. 色觉辅助、减少动态；
7. Fury/Laser/Reclaim 实际战斗无遮挡；
8. 正式 Viewport 中不存在目标水/火附着文字面板、跟随标签或离屏文字回退。

## 7. 交付

- 执行完成后在本任务书追加修改文件、测试数字、冷副本路径、视觉证据索引、保护对账和遗留风险。
- 状态只更新到 `REVIEW` 并冻结继续写入；执行者不得自行标记 `ACCEPTED` 或自验收。
- 独立 Review 必须使用与执行者隔离的 Review 职责对话和新的冷副本，重新运行门禁并人工查看实际 Viewport。

## 8. 执行侧交付（2026-08-03）

本任务已按 allowlist 完成实现并冻结继续写入，状态只更新到 `REVIEW`，未自行验收或标记 `ACCEPTED`。

### 8.1 修改文件

- `scripts/combat_hud.gd`
- `scripts/ui/combat_ui_tokens.gd`
- `scripts/ui/run_overlay_interface.gd`
- `combat/tests/run_task24_compact_hud_reward_tests.gd`
- `combat/tests/capture_task24_visuals.gd`
- `docs/agent_tasks/pending/24_agent_e2_compact_hud_reward_reimplementation.md`
- `docs/agent_tasks/evidence/task24/**`

### 8.2 实现结果

- 主 HUD 为固定 `280×76` 左上 HP/EN 胶囊与 `544×72` 底部居中技能带，顺序为 `CurrentElement / ACTIVE_1 / ACTIVE_2 / ACTIVE_3 / PASSIVE_1`，逻辑画布常驻面积为 8.10%。
- ACTIVE 使用键帽、权威图标、冷却遮罩/秒数和短状态；PASSIVE 无虚假键帽/冷却，使用独立轮廓与触发态；CurrentElement 同时使用形状、短文字和颜色。
- 正式 Viewport 永不渲染目标水/火附着文字；ElementCarrier 数据、信号和不可见任务 12 兼容绑定保持不变。
- 奖励页一次支持权威 1/2/3 项等宽居中卡片，固定标题/上下文、卡片比较区和底部确认区；聚焦不领取，独立确认才调用 RunSession；重复提交受阻，失败恢复候选与焦点。
- 任务 12 公开路径通过不可见适配层保留；未复用任务 20 的失败实现或修改其历史 runner。

### 8.3 冷副本验证

- 最终冷副本：`C:\tmp\element-dungeon-task24-cold-20260803-06`
- 独立 profile：`C:\tmp\element-dungeon-task24-profile-20260803-06`
- 冷复制：1127/1127 文件、36,245,015/36,245,015 字节。
- 首条 Godot 命令：4.7.1 headless editor scan；exit 0，`SCRIPT ERROR / Parse Error / ERROR / WARNING` 全零。
- 已接受 18 runners：18/18，224 tests / 1683 assertions。
- Task 24 新 runner：10 tests / 190 assertions。
- 合计：19/19 runners，234 tests / 1873 assertions；任务 12/16/18 专项分别为 13/110、11/209、9/124。
- 主场景 180 帧 smoke：exit 0。
- 非编辑器图形 Godot 实际 Viewport capture：14/14，exit 0；除单列的 Task 20 历史诊断外，22 份门禁日志 error/warning 全零。
- 任务 20 旧 runner 单独非门禁报告：7 failures / 83 assertions、exit 1；未混入门禁。

### 8.4 证据与保护

- 完整日志、14 张实际 Viewport PNG、尺寸索引、人工复核和 Review 指引见 `docs/agent_tasks/evidence/task24/README.md`。
- Task 20 与任务 21～23 共 41 个保护文件相对最终冷副本逐项 SHA-256 相等，0 mismatch。
- 共享项目未启动 Godot，未修改共享 `.godot`；未执行任何 Git 写操作。

### 8.5 遗留风险

- 当前正式内容仍缺少可按键的专属主动，自动调谐表现继续由既有冻结契约测试覆盖；本任务未越界扩写内容或规则。
- 900×540 是压力下限；未来继续增长本地化字段时需复测卡片摘要，但不应增加第二排技能栏。
- 独立 Review 必须使用新的冷副本/profile 从 editor scan 开始重新复跑并人工查看实际 Viewport；本执行者不作 ACCEPTED 结论。

## 9. 独立 Review 结论（2026-08-03）

中枢 Review 5.0 未采信执行侧结论，在全新冷副本 `C:\tmp\element-dungeon-task24-review-20260803-165846355\project` 与独立 profile 中从 4.7.1 headless editor scan 重新验收。冷复制源/目标为 1178/1178 文件、38,173,942/38,173,942 字节，逐文件路径、字节与 SHA-256 一致；可计数 editor scan 使用独立调试端口，exit 0，完整日志中 `SCRIPT ERROR / Parse Error / ERROR / WARNING` 全零。

- 已接受 18 runners 加任务 24 新 runner：19/19，234 tests / 1873 assertions；任务 12/16/18/24 专项分别为 13/110、11/209、9/124、10/190，全部日志干净。
- 任务 20 旧 runner 单列为非门禁历史诊断，保持 7 failures / 83 assertions、exit 1，未修改、未混入恢复基线，也未改变其 `BLOCKED` 状态。
- 主场景 180 帧 smoke exit 0，日志全清。
- 使用新的非 headless、非编辑器 Godot 进程重新生成 14/14 张实际 Viewport；人工检查覆盖 1080p、1440p、16:10、4K、超宽、900×540、状态组合、奖励 3/2/1、长中英文、色觉辅助、减少动态及 Fury/Laser/Reclaim，未见越界、互盖或任何目标附着文字。
- 冷副本 Review-only 夹具另以真实 `try_cast_slot` Reclaim 事务验证：提交被接受，播放计数只增 1，目标水层从 2 归零，截图中 HUD 与 VFX 无遮挡；该夹具和补充图只存在于 Review 冷副本，不进入正式项目。
- 奖励聚焦不领取，只有独立确认调用权威 RunSession；失败可恢复焦点，重复提交受保护，UI 不拥有奖励或技能规则。
- 共享区审计前后 1880/1880 文件逐项字节、SHA-256、时间和属性一致，0 missing / 0 added / 0 changed；共享 `.godot` 700 项零漂移，两枚任务 24 `.gd.uid` 始终不存在，Git 状态与 refs 未被冷副本验收改变。

结论：任务 24 独立验收通过，状态更新为 `ACCEPTED` 并归档。任务 20 继续保持历史 `BLOCKED`。
