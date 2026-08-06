# 任务 30：正式 RunGame HUD、梦尘商店、路线与结算 UI

状态：ACCEPTED
负责人：UI/HUD Implementation Agent 2.0（threadId `019fc67f-02a6-7540-9549-02513a23af09`，hostId `local`）
依赖：任务 29 `ACCEPTED`，实现检查点 `dc834ff27a500b5259b7be244ee3febf61704429`；任务 20 继续历史 `BLOCKED`

## 1. 目标与完成定义

依据以下文档，在任务29已验收的真实六战 RunGame 上完成正式展示与交互层：

- `docs/design/元素地牢_局内构筑与成长机制变更需求.md`
- `docs/design/元素地牢_局内构筑与关卡流程实现契约.md` 第 10.4 节
- `docs/agent_tasks/completed/24_agent_e2_compact_hud_reward_reimplementation.md`
- `docs/agent_tasks/completed/25_agent_e3_immediate_shop_skill_equip.md`
- `docs/agent_tasks/completed/27_run_economy_skill_progression_authority.md`
- `docs/agent_tasks/completed/28_seven_slot_passive_runtime.md`
- `docs/agent_tasks/completed/29_playable_six_room_run_flow.md`
- `docs/agent_tasks/CENTRAL_REVIEW_RULES.md`

正式 `res://scenes/run/run_game.tscn` 不再依赖 Task29 的 smoke panel 提供玩家交互。玩家必须能仅通过正式 UI 完成战斗信息读取、三个商店、两次路线选择、最终 Boss 结算和新一局/返回入口。UI 只消费任务29暴露的权威 snapshot、result 和 command result，并发送正式命令；不得复制钱包、路线、价格、等级、七槽合法性、房间推进或结算规则。

完成时必须同时满足：

1. 战斗 HUD 正式显示 HP、SP、CurrentElement、3 个主动槽与独立低权重的 4 个被动槽；
2. 商店完整显示梦尘与主动购买/升级/重置信息，并通过任务27/25权威事务操作；
3. 路线门牌完整显示资源、遭遇、环境、风险，聚焦不等于选择，必须显式确认；
4. 结算显示 outcome、六战进度、梦尘收支、最终主动等级和七槽，可开始新一局或返回入口；
5. 正式 UI 完全隐藏经验、等级、属性点、遗物和旧免费奖励流程；
6. 从 `RunGame` 真实场景只使用正式 UI 完成一整局，任务29权威与场景流程保持不变。

## 2. UI 信息与交互合同

### 2.1 战斗 HUD

- 主状态区显示当前/最大 HP、当前/最大 SP 与 CurrentElement。
- CurrentElement 继续使用“形状 + 短文字 + 颜色”三重冗余；不能退化为只靠颜色。
- 主动槽严格为 A1～A3：显示键帽、技能名/图标、等级、SP 消耗和可释放/冷却/能量不足/忙碌/失败状态。
- 被动槽严格为 P1～P4，放在独立低权重区域；不得显示键帽、SP 消耗、虚假冷却或可点击施放状态。
- 空槽必须可辨，但不能制造“缺少技能即错误”的假警报；主动与被动不能混区。
- 正式画面继续不显示目标水/火附着文字面板、跟随标签或离屏文字回退；底层元素数据/信号不在本任务改变。
- Fury、Laser、Reclaim、伤害数字、玩家、敌人与房间关键几何不能被 HUD 大面积遮挡。

### 2.2 梦尘商店

- 显示当前梦尘余额、固定候选、购买价、已拥有状态、主动当前等级、下一级效果与价格、累计实付、重置预计返还（累计实付的 70%，向下取整）和七槽分区。
- 技能购买、升级、重置、装配、换槽、卸下均调用 RunSession 权威事务；UI 不自行扣款、升级、退款、改 revision 或判定拥有权。
- 延续用户已决定的 Task25 规则：技能装配/换槽/卸下即时生效，不需要在商店再次确认；不能恢复“离店时才确认技能装配”。
- 重置属于经济事务，必须有明确独立确认与取消；聚焦或查看预计返还不能触发重置。
- 权威拒绝（余额不足、满级、陈旧 revision/session、非法槽位、重复装备等）必须恢复权威 snapshot、保留可理解的选择/焦点，并给出短反馈。
- 离店按钮文案与行为不得暗示提交技能草稿；使用“离开商店”或同义正式文案，只推进任务29权威流程。

### 2.3 路线门牌

- 同时显示两张权威路线卡；每张至少包含资源/梦尘预期、遭遇、环境、风险与标题。
- Hover、键盘焦点、手柄焦点和查看详情都不能选择路线；必须通过独立“确认路线”动作才发送一次命令。
- 陈旧 option/revision、重复确认和权威拒绝不得本地推进或加载目标房；UI 应刷新 snapshot 并保留可恢复焦点。
- 路线卡只能显示 snapshot 中冻结的实际 target 信息，不能硬编码另一个房间或在 UI 中重新计算风险。

### 2.4 结算

- 显示通关/失败 outcome、`6/6` 或失败时实际房间进度、梦尘收入/支出/余额、最终主动等级、A1～A3/P1～P4 七槽和两次路线摘要。
- Boss 后不得出现免费奖励、第四商店或额外梦尘；结算只读任务29冻结的 `RunResultSnapshot`。
- “开始新一局”必须建立新的 RunGame/RunSession；“返回入口”若项目当前没有独立标题入口，可安全返回项目定义的入口或提供明确不可用状态，但不得伪造完成事务。
- 失败结算与通关结算必须可区分，并保持键盘/焦点导航可用。

## 3. 精确 allowlist

只允许创建或修改以下路径：

```text
scripts/combat_hud.gd
scripts/ui/combat_ui_tokens.gd
scripts/ui/run_overlay_interface.gd
scenes/combat_hud.tscn
scenes/run/run_game.tscn
scripts/run/run_flow_coordinator.gd
combat/tests/run_agent_d_integration_tests.gd
combat/tests/run_hud_loadout_feedback_tests.gd
combat/tests/run_compact_hud_reward_tests.gd
combat/tests/run_task24_compact_hud_reward_tests.gd
combat/tests/run_task30_run_ui_tests.gd
combat/tests/capture_task30_run_ui_visuals.gd
docs/agent_tasks/pending/30_run_hud_shop_route_results_ui.md
docs/agent_tasks/evidence/task30/**
```

其中：

- `scenes/run/run_game.tscn` 只允许把 smoke panel 依赖串行替换为正式 HUD/Overlay 接线；不得改变 Host、Player、RoomStaging、RoomContainer、flow 或 content catalog。
- `scripts/run/run_flow_coordinator.gd` 只允许增加 UI-facing 信号、只读 snapshot/状态访问和现有权威命令的薄转发；不得新增流程、钱包、路线、房间或结算状态。
- 四个旧 UI runner 只迁移已废止的 3+1、免费奖励、经验/属性/遗物 UI 夹具，并保留仍有效的 Task12/24 可访问性、权威和布局合同。
- `run_compact_hud_reward_tests.gd` 虽在本任务 allowlist 内用于移除旧免费奖励断言，但它继续作为 Task20 历史非门禁，不得把 Task20 追认 `ACCEPTED`；Task20 evidence/capture 不修改。

其他路径不得创建、修改、删除、移动或重序列化。若正式 UI 确实缺少权威只读字段或命令，先更新任务书为 `BLOCKED` 并自动回传中枢，不得越权改 Growth/RunFlow/房间资源。

## 4. 禁止事项与保护边界

- 不修改 `growth/**`、`resources/run/**`、房间模板、`scripts/run_session_host.gd`、`scripts/run/run_room_instance.gd`、`scripts/enemy.gd`、`project.godot` 或任务29权威测试来迁就 UI。
- 不改变梦尘产出、余额、价格、主动等级曲线、累计实付、70%返还、七槽合法性、路线 target、房间完成、Boss 零梦尘或结果冻结。
- 不恢复免费技能/遗物奖励页、3+1 混装、经验等级、属性点分配、遗物区或终局商店。
- 不让本地预览先扣款、先装备、先选路线、先结算再等待权威；失败不能被 UI 成功动画掩盖。
- 不修改任务12/20/24历史 PNG/evidence，不修改正式 VFX/图片、碰撞、技能时序或房间几何。
- 不删除或覆盖共享编辑器生成的 `.gd.uid/.import`，不认领现有 28 个未跟踪 sidecar。
- 不使用子 Agent；不执行 `git add/commit/push/reset/restore/checkout/clean/stash` 等 Git 写操作。

共享 Godot 编辑器按用户决定可以被动保持开启以维持 MCP。执行者不得在共享项目调用 Godot/MCP save、reload、reimport、运行、测试或截图，也不得关闭或控制共享编辑器进程。所有引擎操作只在任务30冷副本和独立 profile 中进行。

## 5. 自动化与回归门禁

### 5.1 新 Task30 主 runner

`combat/tests/run_task30_run_ui_tests.gd` 至少覆盖：

- 3 主动 + 4 被动严格分区、空槽、主动/被动信息差异；
- HP/SP/CurrentElement 三重冗余和主动状态语法；
- 商店购买、升级、满级拒绝、余额不足、重置聚焦不提交/独立确认、70%预计返还；
- 技能装配、换槽、卸下即时生效且离店不二次提交；
- 权威拒绝与陈旧 revision/session 后 UI 恢复；
- 路线聚焦不选择、显式确认只提交一次、陈旧 route 拒绝；
- Boss 后只显示结果，无奖励/商店；通关与失败结算、新一局/返回入口；
- 键盘、焦点导航、色觉冗余、减少动态和 1366×768 边界。

测试不得通过直接写 UI 内部字段、直接调用终局方法或替换假 snapshot 来冒充真实 RunGame 主路径；窄组件断言可以使用夹具，但至少一项必须从 `run_game.tscn` 通过正式 UI 完整走一局。

### 5.2 已接受基线

- Task29 接受基线为 `25/25 runners / 273 tests / 2905 assertions`。
- Task12/16/18/24 接受数字为 `13/110、11/209、9/124、10/190`。Task30允许迁移 Task12/24相关 runner，修改后必须报告新旧差异并且不得静默删除仍有效的断言。
- 所有 25 个已接受 runner 都必须恢复，再加 Task30 新 runner；预期 runner 数至少为 `26/26`，精确 tests/assertions 由交付报告给出。
- Task20 `run_compact_hud_reward_tests.gd` 单列非门禁，不计入接受总数；即使迁移后可运行，也不得据此改变任务20历史状态。
- `run_game.tscn` 180 帧 smoke、`test_room.tscn` 180 帧 smoke均须 exit `0` 且日志干净。
- 另跑真实完整一局 UI 自动化：所有商店与路线操作必须走可见正式控件，最终断言六战、三商店、两路线、Boss 零梦尘结算与常驻 Player/Host/Runtime。
- 正式 scan、runner、smoke、完整局和 capture 日志中的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 `0`。

## 6. 实际 Viewport 与人工检查

使用非编辑器、非 headless、禁止保存共享项目的 Godot 4.7.1 图形进程，从真实 `RunGame` 生成实际 Viewport；不能只拍静态 mockup、组件预览或 TestRoom。

最低证据矩阵：

- 1920×1080：战斗 HUD、早期商店、路线、四被动七槽、通关结算；
- 2560×1440：战斗 HUD、商店、路线、通关结算；
- 1366×768：战斗/商店/路线边界压力检查，文字、按钮和焦点不得裁切或互相覆盖；
- 至少一张失败结算；至少一组权威拒绝/陈旧恢复；至少一组色觉冗余与减少动态；
- Fury/Laser/Reclaim、伤害数字、玩家/敌人和房间关键几何无遮挡；正式画面无目标附着文字。

capture 在保存每张 PNG 前必须自动断言对应权威 phase/snapshot、分辨率、控件可见性、焦点/确认状态和界面边界。执行侧必须逐张以原始分辨率实际打开，人工检查信息层级、中文/英文长文案、遮挡、裁切、焦点、按钮语义和状态一致性，并在证据 README 记录结论。

## 7. 冷副本、共享保护与 Git

- 建立此前不存在的 `C:\tmp` 冷副本和独立 profile，排除 `.git/.godot/.workbuddy/cache`，逐文件比较数量、字节与 SHA-256；冷副本第一条 Godot 命令必须是 4.7.1 headless editor scan。
- 开始前与完成后核对 HEAD、完整 `git status`、Task30 allowlist 内容/SHA、Task29权威/场景保护文件、Task20/24历史证据、共享 `.godot` 和未跟踪 sidecar。共享编辑器被动漂移单列，不删除、不认领。
- Task29 实现检查点为 `dc834ff27a500b5259b7be244ee3febf61704429`。Task30 开工时 HEAD 必须包含本任务书且没有其他未声明的 tracked 差异；实际分发 HEAD 由中枢聊天消息给出并由执行者在开工审计中记录。当前已知工作树保留项为 `.workbuddy/memory/2026-07-31.md`、`docs/架构评估与扩展性改进建议.md` 和 28 个未跟踪 `.gd.uid/.png.import` sidecar；均不属于 Task30。
- 执行者 Git 写操作必须为零。中枢只有在独立 Review PASS、回归和精确 allowlist 暂存审计后才可提交；不 push。

## 8. 完成、冻结与自动回传

只有正式 UI 可从 RunGame 完整走一局、自动化/视觉/共享保护全部通过后，才把本任务更新为 `REVIEW` 并冻结；不得自行标记 `ACCEPTED`。

交付必须包含：

- 修改/新增文件与最终 SHA-256；
- 战斗 HUD、商店、路线、结算四类 UI 的权威接线摘要；
- Task30 runner、25-runner基线、两个smoke和完整一局 UI 自动化精确数字；
- 全部正式日志错误计数、冷副本/profile与复制核对；
- 每张 Viewport 路径、尺寸、SHA、保存前断言与人工原图检查；
- Task29权威/场景、Task20/24历史证据、共享 `.godot`/sidecar 和 allowlist 外零漂移对账；
- 已知风险与 Git 写操作为零声明。

回传中枢：

- threadId：`019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`
- hostId：`local`
- 完成或阻塞后，直接调用 `send_message_to_thread` 回传；不要等待用户转述。

完成回传 `REVIEW`，阻塞回传 `BLOCKED`。回传后保持冻结，中枢收到 `REVIEW` 后将自动开始独立冷副本验收；这不等于执行者自行通过。

## 9. 执行侧交付记录（2026-08-06）

状态更新为 `REVIEW`；执行者从此处冻结继续写入，等待中枢独立验收，未自行标记 `ACCEPTED`。

### 9.1 正式实现

- `run_game.tscn` 已从 smoke panel 串行替换为正式 `CombatHUD`；`RunFlowCoordinator` 只增加 snapshot 读取、UI result 信号与既有权威命令的薄转发。
- HUD 实现 HP/SP/CurrentElement、A1–A3 主动带与独立 P1–P4 被动带；目标权威数据/信号保留，但正式附着/跟随/离屏文字均不可见。
- 正式 overlay 完成梦尘商店、Task25 即时七槽装配、路线聚焦后独立确认、陈旧恢复、成功/失败冻结结算与新一局；经验/属性/遗物/免费奖励不进入正式 RunGame。
- UI 不直接修改 RuntimeLoadout、钱包、技能等级、返还、路线、房间推进或结果；全部状态来自 Task29 snapshot/result，全部操作经 coordinator 转发 Task29/27/25 authority。

### 9.2 精确验证

- 冷副本 `C:\tmp\element-dungeon-task30-exec-20260806-01\project`；独立 profile `C:\tmp\element-dungeon-task30-exec-20260806-01\profile`。第一条实际 Godot 命令为 4.7.1 headless editor scan，exit `0`；最终 rescan exit `0`。
- Task30：`9 tests / 172 assertions`；既有门禁：`25/25 runners / 273 tests / 2955 assertions`；合计：`26/26 / 282 tests / 3127 assertions`。
- 基线 assertion 差异为 +50：Task12 `13/110 -> 13/113`（七槽/HUD 迁移 +3），Task24 `10/190 -> 10/237`（3+1 到严格 3+4、正式隐藏目标文字迁移 +47）；Task16 `11/209`、Task18 `9/124` 不变。
- Task20 非门禁迁移为 `7 tests / 68 assertions` 并通过，但继续历史 `BLOCKED`，不计入 26-runner 总数。
- RunGame/TestRoom 两条 180 帧 smoke 均 exit `0`；非 headless 实际 RunGame capture 为 `1 test / 215 assertions / 15 screenshots`，OpenGL 3.3 / RTX 2060，exit `0`。
- 32 个正式日志中 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 `0`。

### 9.3 视觉与保护

- 15 张实际 Viewport 覆盖 1920×1080、2560×1440、1366×768 的战斗/商店/路线/结算，以及七槽、陈旧恢复、色觉+减少动态和失败结算；保存前 215 条 authority/phase/focus/bounds 断言全部通过。
- 执行者逐张原始分辨率人工检查并修正 SP 标签、空槽重叠、重复辅助提示、房间标题遮挡和商店水平溢出；最终无不可恢复裁切、互相覆盖、关键几何遮挡或正式目标附着文字。
- HEAD 保持 `a33e17e9eea7bba7a76b72e351bd32d40a3e5e56`；allowlist 外 tracked diff 为 0。Task29 authority/保护场景、Task20/24 历史 evidence 均无 diff。
- 既有 28 sidecars 保持 28 files / 2,613 bytes / aggregate `49D58226E3D509EC87B2D521BF37F9606035DDC29F5B5584875812E681197E41`；共享 `.godot` 保持 705 files / 34,863,310 bytes / aggregate `57FB4C9A83EA037D0EACABBB80D72E3C262FDBD2AA7157862CA1ACB6AAECD429`，均与开工一致。
- 当前无独立标题入口，故“返回入口”明确禁用；“开始新一局”可用。正式场景不实例化 smoke panel，但保留只读兼容别名供 Task29 接受 runner 使用。
- 完整文件 SHA、日志、逐图尺寸/SHA/人工结论和保护明细见 `docs/agent_tasks/evidence/task30/README.md`。Git 写操作为零。

## 10. 独立 Review 失败与整改恢复（2026-08-06）

中枢在全新 `C:\tmp\element-dungeon-task30-review5-20260806-01\project` 独立验收中确认全部自动化、smoke、图形 capture 执行和共享保护通过，但视觉门禁判定 `FAIL`。任务因此从 `REVIEW` 恢复为 `IN_PROGRESS`；本节保留失败记录，不覆盖首次交付记录。

明确失败项：

1. `04_colorblind_reduced_motion_1920x1080.png` 的顶部反馈面板与 P1 被动卡相交；旧 capture 只断言各 HUD 区域分别在边界内，没有断言反馈层与被动带不相交。
2. 旧 15 图只覆盖静态 HUD/商店/路线/结算，没有从真实 RunGame 权威配装与释放路径生成 Fury/Laser/Reclaim 和伤害数字的实际画面与保存前断言，未满足 §6。

整改严格限于 Task30 原 allowlist 中必要的 `scripts/combat_hud.gd`、`combat/tests/capture_task30_run_ui_visuals.gd`、Task30 evidence 与本任务书。商店/路线/结算事务接线、Task29 authority/房间/VFX 资产与其他 gameplay 不修改；完成后必须使用新的、此前不存在的冷副本/profile，从 headless editor scan 开始完整复跑并再次更新为 `REVIEW`。

## 11. Review5 整改交付（2026-08-06）

状态恢复为 `REVIEW`；执行者从此处冻结继续写入并等待中枢独立验收，未自行标记 `ACCEPTED`。

- 正式反馈面板已移入标题下方中央安全带；1920×1080、2560×1440、1366×768 三档均在真实反馈可见时断言其与 status/active/passive HUD 不相交，三张原图人工检查通过。
- capture 从真实 RunGame 商店权威事务购买并即时装配 Laser(A2)、Reclaim(A3)、Fury(A1)，再经玩家正式槽位释放、executor、实际 VFX presentation、伤害 label 与敌人状态取得三张证据；没有 mock/TestRoom、关闭 gameplay 或改 VFX/房间资产。
- 最终冷副本为 `C:\tmp\element-dungeon-task30-remediation-final-20260806-01\project`，独立 profile 为同根 `profile`。第一条 Godot 命令为 4.7.1 headless editor scan，exit `0`；最终 rescan 同为 `0`。
- Task30 `9/172`；既有 `25/25 runners / 273 tests / 2955 assertions`；合计 `26/26 / 282 tests / 3127 assertions`。Task20 单列 `7/68` 并继续历史 `BLOCKED`。
- RunGame/TestRoom 180 帧 smoke 均 exit `0`；实际 RunGame 图形 capture 为 `1 test / 427 assertions / 20 screenshots`，exit `0`。
- 32 个正式日志共 70,470 bytes，五类错误/警告标记全 `0`；20 张 PNG 共 4,243,186 bytes。执行者已逐张以原始分辨率检查，反馈、三技能/伤害、角色、房间、商店、路线和结果均通过视觉门禁。
- HEAD、allowlist、Task29/20/24 保护、共享 `.godot` 与既有 28 sidecars 全部零漂移；Task30 sidecar 为 `0`。完整 SHA、日志与逐图结论见 `docs/agent_tasks/evidence/task30/README.md`。
- 开发冷副本中的权限层失败与已修复的 capture 开发失败未纳入正式证据。Git 写操作为零。

## 12. 第二次独立 Review 失败与再次整改（2026-08-06）

中枢在另一个全新 `C:\tmp\element-dungeon-task30-review5-remediation-20260806-01\project` 中确认 26/26 runners、Task20 非门禁、双 smoke、`1/427/20` 图形 capture、三档 feedback、Laser/Fury、全部日志和共享保护均通过，但判定新生成的 `17_reclaim_authority_1920x1080.png` 存在一次 HUD 子内容异常：HP 行、CurrentElement 形状/短文字以及部分 A1–A3 文案在 Reclaim 瞬态帧出现裁切/缺失。外层 panel 几何断言不足以证明子内容实际可读，因此第二次 Review 仍为 `FAIL`，任务从 `REVIEW` 恢复为 `IN_PROGRESS`；前两次失败及交付记录均保留。

再次整改只允许触及 Task30 既有 allowlist 中必要的正式 HUD、capture、evidence 与本任务书。必须定位 HUD transform/clip/layer 或 capture 绘制时序根因，在仍显示真实 Reclaim presentation 与伤害数字的帧增加 HP label/bar/value、CurrentElement 形状/短文字/颜色、A1–A3 名称/状态的 visible、非空、所属 panel 内几何及必要像素可见性门禁。不得裁图、删除 17 图、挪走 VFX、改 Task29 权威/房间/VFX 资产，或选择不再体现真实 Reclaim 的时刻规避。完成后建立新的最终冷副本/profile，从首条 headless editor scan 开始完整复跑并再次更新为 `REVIEW`。

## 13. 第二次 Review 整改交付（2026-08-06）

状态再次更新为 `REVIEW`；执行者从本节起冻结继续写入并等待中枢独立验收，未自行标记 `ACCEPTED`。

- 定位结果：Reclaim 真实技能帧中的 HUD `CanvasLayer`、Control transform、clip、z-order 与子控件实际 global rect 均保持稳定；Godot 实际 Viewport 图像以及保存后的 PNG 像素中，HP label/bar/value、CurrentElement 形状/短文字/颜色和 A1–A3 名称/状态始终完整。第二次 Review 所见缺失来自大尺寸稀疏全图的预览/读图呈现层，而不是正式游戏 HUD 或 PNG 像素缺失；正式 17 图仍保留完整 Reclaim、伤害 5、玩家、敌人和房间画面，没有裁图、换时机或挪动 VFX。
- 正式 HUD 反馈动画改为只改变透明度，不再改变 Control 位置；CurrentElement 不再用低透明度表达状态，保证形状、短文字和颜色三重语义在瞬态中保持全不透明。
- capture 对 HP label/bar/value、CurrentElement swatch/shape/text 与 A1–A3 name/state 连续两个 completed draw 和最终保存帧分别断言：节点可解析、visible、文本非空、全局矩形位于所属 panel/Viewport 内、最终 modulate alpha 为 1；同时断言 HUD CanvasLayer 不低于 10 且 transform 为 identity。
- 保存门禁使用逻辑 1152×648 到实际 1920×1080 的坐标映射，在最终 Viewport 图像中对上述子内容矩形执行亮像素检查；真实 Reclaim presentation、伤害数字、敌人/玩家与世界几何在保存前保持活动。PNG 统一写为无 alpha RGB8 标准 PNG，写回后重新加载并逐字节比较解码像素与通过门禁的 Viewport 图像完全一致。
- 新的正式冷副本为 `C:\tmp\element-dungeon-task30-reclaim-final2-20260806-01\project`，独立 profile 为同根 `profile\Roaming` / `profile\Local`。该根此前不存在；复制后先把 20 张旧 PNG 移到 project 外备份，第一条 Godot 命令是 4.7.1 headless editor scan，exit `0`。
- Task30 `9 tests / 172 assertions`；既有门禁 `25/25 runners / 273 tests / 2955 assertions`；合计 `26/26 / 282 tests / 3127 assertions`。Task20 单列 `7/68` exit `0`，继续历史 `BLOCKED`。
- RunGame/TestRoom 两条 180 帧 smoke 均 exit `0`；非 headless 真实 RunGame capture 为 `1 test / 1264 assertions / 20 screenshots`，OpenGL 3.3 / RTX 2060，exit `0`。32 个正式日志共 91,521 bytes，五类错误/警告标记全 `0`；20 张 PNG 共 3,515,179 bytes。
- 执行者逐张以原始分辨率打开正式全图，并对 Reclaim、Fury 及基础 HUD 的原 PNG 像素另做 project 外只读区域核对；区域核对只用于诊断预览层，不是裁剪证据或替代正式 20 张全图。正式 17 图的 HP、CurrentElement、A1–A3、Reclaim、伤害数字与角色均完整。
- 共享编辑器按用户决定保持打开。执行者未调用、控制或关闭共享 Godot/MCP；其启动后被动产生的 `.godot` 与 38 个 sidecar 增量已按前后数量、字节、aggregate、时间和路径在 evidence README 单列，观察稳定且全部可归因于新/更新脚本与证据 auto-import，不删除、不认领、不暂存。
- HEAD、allowlist 外 tracked diff、Task29 权威/保护场景、Task20/24 历史 evidence 及最终共享/冷副本 manifest 对账见 evidence README。Git 写操作为零。

## 14. 中枢 Review 5.0 独立验收（2026-08-06）

中枢在第三个全新 Review 冷副本中完成独立复验，结论为 `PASS`，本任务由中枢更新为 `ACCEPTED` 并归档。

- Review 冷副本：`C:\tmp\element-dungeon-task30-review5-final-20260806-02\project`；独立 profile 为同根 `profile\Roaming` / `profile\Local`。复制前根不存在；排除 `.git/.godot/.workbuddy/cache` 后为 `1476/1476 files / 44,116,600 bytes / 0 mismatch`，首条 Godot 命令前 `.godot` 不存在。复制来的旧 20 PNG 及其 20 个 `.png.import` 已先移到同根项目外可恢复备份，正式 Viewport 输出目录为空。
- 第一条 Godot 4.7.1 headless editor scan exit `0`；25 个已接受 runner 加 Task30 共 `26/26 runners / 282 tests / 3127 assertions`，全部 exit `0`。Task20 单列 `7 tests / 68 assertions`、exit `0`，继续历史 `BLOCKED` 且不计入门禁。
- `RunGame` 与 `TestRoom` 两条 180 帧 smoke 均 exit `0`；非 headless 真实 RunGame capture 为 `1 test / 1264 assertions / 20 screenshots`、exit `0`；capture 后最终 editor rescan 亦 exit `0`。32 份 Review 日志共 67,994 bytes，`SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全部为 `0`。
- 中枢逐张以此前未使用的冷副本绝对路径打开 20 张新图；HUD、三档反馈、商店、路线、成功/失败结算、Laser、Reclaim、Fury、伤害数字、玩家/敌人与房间均通过。当前大图预览器对 Reclaim 原图曾漏显稀疏 HUD 行，但同一正式 PNG 经 Windows `System.Drawing` 独立解码后的完整整图与直接原像素裁片均显示 HP/SP、CurrentElement、A1-A3 完整；结合 capture 保存前物理像素门禁和保存后逐字节回读，确认是预览器呈现问题，不是正式 PNG 或游戏画面缺失。
- 验收结束时 Task30 11 个实现/runner/capture/任务书/README 对象与共享区 SHA 一致；allowlist 外 tracked diff 为 `0`，Task29 权威/场景、Task20/24 历史 evidence 与禁止路径均无 diff。共享编辑器保持被动开启且未被 Review 控制；共享 `.godot` 稳定为 `754 files / 37,416,266 bytes`，未跟踪 sidecar 稳定为 `66 files / 28,555 bytes`，不删除、不认领、不暂存。
- `git diff --check` 通过；本次独立验收不使用共享 Godot/MCP、不修改游戏实现，也不追认任务20。中枢仅在本节记录、任务归档和精确 allowlist 暂存完成后建立 Task30 阶段检查点，不 push。
