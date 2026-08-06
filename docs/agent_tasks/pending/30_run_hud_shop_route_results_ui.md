# 任务 30：正式 RunGame HUD、梦尘商店、路线与结算 UI

状态：PENDING
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
