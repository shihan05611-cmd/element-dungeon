# 任务 31：基础内容、数值与整轮端到端回归

状态：BLOCKED
负责人：Content/Balance & E2E Validation Agent（复用 Run Flow/Scene Integration Agent 2.0 职责对话，threadId `019fd63e-f9d7-7760-b68c-45b552c90881`，hostId `local`）
依赖：任务 30 `ACCEPTED`；Task30 阶段检查点 `fa94956bbaa9be32cafa2a585d8bd2116da5882e`；恢复执行前新增依赖任务 32 `ACCEPTED`
回传中枢：Review 5.0，threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`，hostId `local`

## 1. 目标与完成定义

本任务是任务 26～31 串行实现的最后一项。只在任务 27～30 已冻结的权威、七槽 Runtime、真实六战流程和正式 UI 之上调整首批静态内容、房间数值、必要几何/出生点，并新增内容与整局 E2E 夹具。

完成时必须同时证明：

1. 正式 `RunGame` 从主入口实际完成安全路线与风险路线各一局；每局恰好六战、三商店、两次路线、Boss 后同一权威事务直达冻结结算。
2. 两条路线实际改变房间模板、敌群/压力和梦尘结果，不是只换门牌文字。
3. 房 1 保底梦尘足够在首店购买至少一个主动；购买、升级、70% 向下取整重置不存在套利或重复结算。
4. 至少存在一条主力专精、一条多主动和一条主动+被动的可行局内构筑预算；被动仍无等级。
5. Boss 明显强于普通房敌人但不增加新美术/多阶段机制；Boss 击杀和房间完成梦尘均为 0，结算后没有第四商店、免费奖励或无效资源。
6. 任务 26 的 14 场景矩阵、任务 27～30 接受基线、两个 smoke、两档实际 Viewport 和共享区保护全部通过。

本轮目标是“可内部测试的基础节奏”，不是最终商业化数值。房间时长、整局时长、梦尘赚/花/余额、技能使用占比和路线结果必须记录为首版基线，但不为了追求窄秒数目标而修改权威或伪造测试。

## 2. 用户决定与冻结规则

- 单一货币是梦尘；金币、正式经验成长、属性点、遗物、免费技能奖励继续停用。
- 配装固定 `A1–A3` 主动、`P1–P4` 被动；主动/被动严格分区，同技能唯一，空槽有效。
- 主动购买时为 Lv1，独立升级；重置只返还累计升级实付的 70% 并向下取整，购买价不返。
- 技能购买、升级、重置、装配/换槽/卸下都是独立即时权威事务；离店不二次提交技能或属性。
- SP、CurrentElement、元素附着/反应、接受时快照和各技能自身冷却不因通用等级或本轮平衡而改写；不加入强制轮换或通用冷却。
- 正式流程为六战、房 1/3/5 后三商店、战 2/5 两次真实路线选择、最终 Boss 后直接结算。
- 当前项目没有独立标题入口；结果页“返回入口”保持明确禁用且不得改变权威状态，Task31 只验证该接受边界。“开始新一局”必须创建新的 authority 并重置整局状态。

## 3. 职责与权威边界

本任务可以：

- 调整 allowlist 内 `.tres` 的购买价、主动等级曲线、技能效果数值、房间梦尘、敌群配置、路线披露和显式受控恢复配置；
- 仅在必要时调整四张 allowlist 房间模板的几何和出生点；
- 新增三份 Task31 runner/capture 和 Task31 evidence；
- 用正式权威入口和真实场景实例完成两条整局 E2E。

本任务不拥有任何权威规则。不得修改 `RunSession`、`RunDirector`、快照/命令、七槽/被动 Runtime、Player/Enemy、RunFlowCoordinator、HUD/Overlay、VFX、`project.godot` 或正式入口接线。若 E2E 暴露结构问题：

- 经济/等级/模式缺陷回传任务 27 职责；
- 七槽/被动缺陷回传任务 28 职责；
- 流程、房间生命周期或结算缺陷回传任务 29 职责；
- HUD、商店、路线或结算 UI 缺陷回传任务 30 职责。

此时更新本任务为 `BLOCKED` 并自动回传中枢，不得扩大 allowlist、用数值掩盖、在测试中跳关或在静态资源里发明第二权威。

## 4. 精确 allowlist

除本节外一律禁止修改。

### 4.1 静态内容与数值

- `resources/content/run_content_catalog.tres`
- `resources/content/skills/element_bolt_content.tres`
- `resources/content/skills/elemental_fury_content.tres`
- `resources/content/skills/elemental_laser_content.tres`
- `resources/content/skills/element_reclaim_content.tres`
- `resources/content/skills/burning_content.tres`
- `resources/content/skills/unending_content.tres`
- `resources/run/flows/prototype_two_layer_six_combat.tres`
- `resources/run/rooms/combat_01_entry.tres`
- `resources/run/rooms/combat_02_swarm.tres`
- `resources/run/rooms/combat_02_pressure.tres`
- `resources/run/rooms/combat_03_layer_elite.tres`
- `resources/run/rooms/combat_04_validation.tres`
- `resources/run/rooms/combat_05_stable.tres`
- `resources/run/rooms/combat_05_risk.tres`
- `resources/run/rooms/combat_06_final_boss.tres`

### 4.2 房间模板（只限几何/出生点）

- `scenes/run/rooms/room_arena_flat.tscn`
- `scenes/run/rooms/room_arena_platforms.tscn`
- `scenes/run/rooms/room_arena_corridor.tscn`
- `scenes/run/rooms/room_arena_boss.tscn`

不得在这四个场景中加入调试 UI、权威脚本、钱包/配装状态、新敌人逻辑或 capture 逻辑。

### 4.3 新增验证与证据

- `growth/tests/run_task31_content_balance_tests.gd`
- `combat/tests/run_task31_full_run_e2e_tests.gd`
- `combat/tests/capture_task31_full_run_visuals.gd`
- `docs/agent_tasks/pending/31_run_content_balance_e2e_regression.md`
- `docs/agent_tasks/evidence/task31/**`

`docs/agent_tasks/README.md` 由中枢维护，不属于执行者 allowlist。

## 5. 明确禁止与保护项

- 禁止修改任何 Task31 allowlist 外 `.gd/.tscn/.tres`、`project.godot`、正式图片/VFX/资产或历史 evidence。
- 禁止修改任务 27～30 已接受的权威、Runtime、UI、runner/capture/evidence；Task20 继续历史 `BLOCKED`，不得追认或混入正式门禁。
- 禁止修改 `scenes/test_room.tscn`、`scripts/test_room.gd` 来冒充完整局。
- 禁止 runner 直接调用房间完成、终局或结果构造函数跳过敌人/路线/商店；必须经正式 `RunGame`、真实 `RunRoomInstance`、正式命令/事务和房间敌人接收路径推进。
- 禁止通过极端提高敌人生命、关闭 AI/物理/VFX、隐藏伤害、直接写钱包/配装/revision、伪造快照或在 capture 内 mock 正式系统来“通过”门禁。
- 禁止新增金币、被动等级、遗物、属性点、免费奖励、Boss 后商店、随机平台系统、新 Boss 美术/招式/多阶段。
- 共享 Godot 编辑器可以按用户决定被动保持开启，但不得对共享项目调用 Godot/MCP save、reload、reimport、run、test 或 capture，也不得控制/关闭该进程。
- 不删除、覆盖、恢复或认领共享 `.godot`、`.gd.uid`、`.import`、`.workbuddy/**`、`docs/架构评估与扩展性改进建议.md` 或其他既有未跟踪项。
- 不使用子 Agent；不执行 `git add/commit/push/reset/restore/checkout/clean/stash`。

## 6. 内容与数值门禁

### 6.1 价格与技能等级

- 六份首批技能内容必须通过正式 catalog 校验，ID/类型/槽位建议保持唯一且与任务 27～30 冻结合同一致。
- 每个主动购买价为正；房 1 保底余额至少能购买一个首店主动，且一次购买只扣一次。
- 主动等级从 Lv1 连续递增，升级价严格逐级上升；效果只使用已接受的等级效果白名单，不改变技能行为、范围、SP 规则、冷却或反应公式。
- 被动没有主动等级表、升级价格或重置收益。
- 任意有效购买/升级/重置序列均满足梦尘守恒；重复命令、余额不足、满级、陈旧 revision 全状态不变；70% 向下取整返还不能产生循环套利。

### 6.2 房间、路线与 Boss

- 八份战斗房资源均有有效 PackedScene、出生点和敌群；不存在空房、不可抵达敌人、敌人出生在几何体内或阻塞出口。
- 安全路线与风险路线至少在敌人数量/耐久压力、房间模板和梦尘产出中各有可审计差异；风险路线梦尘期望严格高于对应安全路线。
- 房 1、3、5 的产销预算分别支撑早期购买、中期升级/补购和 Boss 前构筑；不要求玩家强制轮换技能，也不把单技能专精预设为失败。
- 至少用权威事务完成并记录三条预算：主力主动专精、多主动购买/升级、主动加四被动。三条路径均不得靠越权写状态。
- Boss 敌群/耐久配置明显强于任一普通房的单体压力，使用现有场景/敌人能力即可；Boss 敌人和房间完成梦尘均精确为 0。
- 若配置受控恢复，必须是流程资源中的显式、可审计数值，不能由离店或 UI 隐式全恢复；未采用也需在报告中说明。

### 6.3 14 场景矩阵

Task31 evidence README 必须逐项列出任务 26 契约第 9 节的 14 场景，并映射到本轮实际 runner/log/截图或已接受回归入口。至少覆盖：单梦尘和成长/遗物停用、主动/被动购买、严格 3+4、四被动跨房、SP/冷却不变、升级/换装/重置、商店权威一致和 Boss 直结算。

## 7. 自动化门禁

### 7.1 冷副本与命令顺序

1. 开始前只读固化 `HEAD`、完整 `git status`、Task31 allowlist 的路径/字节/SHA/时间、允许范围外基线、共享 `.godot` 和全部未跟踪 sidecar；记录共享 Godot 进程但不控制它。
2. 创建此前不存在的全新 `C:\tmp` 执行冷副本和独立 profile；排除 `.git/.godot/.workbuddy/cache`。逐文件核对复制，Task31 证据输出目录在首次 capture 前必须为空。
3. 冷副本第一条 Godot 命令必须是 Godot 4.7.1 headless editor scan，exit `0`，日志中 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全为 `0`。
4. 此后所有 runner、smoke、完整局、图形 capture 和最终 rescan 只在该冷副本/profile 运行。

### 7.2 专项与完整回归

- `run_task31_content_balance_tests.gd`：覆盖 catalog、价格/等级连续性、效果白名单、预算/守恒/返还、八房引用、路线差异、Boss 零梦尘和 14 场景矩阵静态/领域部分。
- `run_task31_full_run_e2e_tests.gd`：从正式新 main scene 完成安全路线与风险路线各一局，覆盖购买、升级、重置、即时七槽、四被动跨房、失败结算、开始新一局和“返回入口禁用且不改变权威”。
- 两局都必须经六个真实战斗房实例推进，记录六个不同实例、至少四种真实模板、三商店、两路线和 Boss 直结算；不得直接调用完成/终局跳关。
- 复跑 Task30 接受基线 `26/26 runners / 282 tests / 3127 assertions`；加上两个 Task31 runner 后正式 runner 数应为 `28/28`，tests/assertions 以新 runner 实际输出精确汇总。
- Task12/16/18/24 迁移数字保持 `13/113、11/209、9/124、10/237`，除非 Task31 未获授权的旧 runner 被改动（这将直接构成越界失败）。
- Task20 runner 单列运行并记录，继续历史 `BLOCKED`，不得计入 28 个门禁 runner。
- 正式 `RunGame` 与 `TestRoom` 各 180 帧 smoke，全部正式日志五类标记为 0；capture 后再做一次 editor rescan。

## 8. 实际 Viewport 与人工检查

- 使用非共享、非编辑器、非 headless 的 Godot 4.7.1 图形进程，从正式 `RunGame` 重新生成实际 Viewport；禁止保存到共享项目外的历史图后冒充本轮。
- 至少生成 14 张正式 PNG：1920×1080 安全路线完整局、2560×1440 风险路线完整局；每档至少包含两种不同房模板、路线 1 门牌、路线 2 门牌、商店/构筑、Boss 与结果，另覆盖失败结算和新一局状态。
- 保存前必须断言实际窗口/Viewport 尺寸、正式 authority phase/snapshot、房间实例/模板、路线选项、梦尘账、技能等级/七槽/四被动、Boss 零梦尘与结果；截图只能在对应断言通过后写入。
- HUD/商店/路线/结算沿用 Task30 接受实现；画面不得出现等级/经验/属性/遗物/免费奖励或目标附着文字。不得有不可恢复裁切、互相覆盖、敌人/玩家/出生点落入几何或风险房与安全房视觉完全相同。
- 执行者必须逐张以原始分辨率打开人工检查，并在 evidence README 记录每图路径、尺寸、字节、SHA、权威状态和检查结论。

## 9. 测量与证据交付

`docs/agent_tasks/evidence/task31/README.md` 至少包含：

- 全部修改文件的字节/SHA 与 allowlist 对账；
- 最终价格、等级曲线、八房敌群/梦尘、两条路线差异与 Boss 数值表；
- 安全/风险两局的总时长、逐房时长、梦尘 earned/spent/refunded/balance、购买/升级/重置、最终技能等级、七槽、四被动和技能使用占比；
- 三条构筑预算与 14 场景矩阵逐项证据；
- scan、28 个正式 runner、Task20 单列、双 smoke、capture、rescan 的精确 exit/tests/assertions/日志标记；
- 至少 14 张实际 Viewport 的逐图信息和人工检查；
- 冷副本/profile、复制核对、共享 `.godot`/sidecar 前后对账、保护项和 Git 写操作为 0。

正式 evidence 只保留 README、UTF-8/LF 日志和 PNG；不得复制 `.gd.uid`、`.import`、冷副本 `.godot`、项目外诊断图或失败开发产物回共享区。失败开发日志可在 README 如实摘要，但不得冒充最终门禁。

## 10. 状态、冻结与自动回传

- 开工后将状态改为 `IN_PROGRESS`。
- 全部门禁通过后只改为 `REVIEW`，写完证据、最终只读对账后冻结；不得自行 `ACCEPTED`。
- 任一结构缺陷、allowlist 冲突、正式门禁或视觉失败无法在本任务静态内容边界内解决时，改为 `BLOCKED`，停止写入并说明应退回的任务职责。
- 完成或阻塞后，直接调用 `send_message_to_thread` 回传中枢 Review 5.0：threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`，hostId `local`；不要等待用户转述。
- 回传必须包含状态、修改文件/SHA、最终数值表、两局测量、精确 runner/tests/assertions、scan/smoke/capture/rescan、视觉证据、allowlist/共享保护、风险和 Git 写操作为 0。
- 回传后保持冻结。中枢收到 `REVIEW` 将自动建立另一全新冷副本独立验收；执行者交付不等于接受。

## 11. 执行者阻塞记录（2026-08-06）

必读材料、Task30 正式 runner/capture 与 Task31 allowlist/全仓调用点完成只读审计后，发现正式内容无法在本任务边界内满足本任务自身的“四被动”硬门禁：

- 正式 catalog 被已接受的 Task16/Task27 契约冻结为一个固定基础攻击与六个可购买内容；六个可购买内容只有四个主动和 `burning`、`unending` 两个被动。
- Task31 同时要求正式 `RunGame` E2E 覆盖“四被动跨房”、实际 Viewport 保存前断言“四被动”，并完成“主动加四被动”权威预算。
- 七槽 Runtime 正确拒绝同一技能重复装备，因此两个正式被动最多只能合法占用两个被动槽。
- 增加两个正式被动内容会违反本任务仅列六份技能内容的 allowlist，并使冻结的 Task16/Task27 精确 catalog 数量断言失败；修改旧 runner、在 Task31 runner 内注入夹具或重复技能均为任务书明确禁止的绕过。

该缺口应退回任务 27 的正式内容/catalog 职责，补齐至少两个可购买被动并同步重新冻结 catalog 及其接受基线；任务 28 的四被动 Runtime 和任务 30 的四槽 UI 当前审计未发现结构缺陷。执行者未运行任何 Godot 命令，未创建冷副本，未新增 Task31 runner/capture，未调整静态数值，也未进行 Git 写操作。阻塞证据见 `docs/agent_tasks/evidence/task31/README.md`。

## 12. 中枢 Review 5.0 阻塞审计与恢复条件（2026-08-06）

中枢独立只读核对正式 catalog、六份内容资源、`RuntimeSkillLoadout` 唯一性、Task16/27 精确数量断言以及最高优先级需求文档第 4.1、12 节后，确认阻塞成立。最高优先级需求要求“四个不同被动同时装备”，不能把门禁降低为两个被动或用空槽/重复技能替代。

- 新增前置任务 32，把已由 Task28 Runtime 验证的 `passive_vitality` 与 `passive_energy` 正式接入 catalog，补齐与现有风格一致的独立图标，并迁移 Task16/27 两条受影响的 catalog 数量/legacy 断言。
- 任务 32 不新增被动机制：分别沿用现有 `+20` 最大生命和 `+10` 最大 SP 的静态被动定义；`passive_focus`、`passive_balance` 继续保持旧资源、不得注册。
- 任务 32 必须独立验收并由中枢标记 `ACCEPTED` 后，本任务才可恢复；届时中枢将补发新的检查点、接受 runner 数字和 allowlist 基线。
- 本次 Task31 阻塞记录与 evidence 保留，不作为失败实现；任务31继续冻结，当前不运行任何部分门禁。
