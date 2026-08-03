# 任务 25：商店技能即时装配

状态：ACCEPTED

负责人：UI Implementation Agent 2.0 职责对话 `019fc67f-02a6-7540-9549-02513a23af09`

依赖：任务 24 已 `ACCEPTED` 并归档；任务 20 继续保持历史 `BLOCKED`

## 1. 用户决定

技能在商店中的装配、换槽和卸下不再等待“确认配装与属性”。玩家完成一次合法槽位操作后，权威 RuntimeLoadout 必须立即生效。

本决定只取消“技能装配需要商店确认”：

- 奖励页仍是“聚焦不领取、独立确认后领取”，不得取消任务 24 的显式奖励确认。
- 属性点分配仍可保留草稿，并在离开商店时确认提交。
- 商店离开/属性提交仍需明确操作；按钮文案不得再声称技能装配等待确认。

## 2. 权威与事务边界

- UI 不得直接修改 RuntimeLoadout。必须由 RunSession 提供商店阶段的权威即时装配入口。
- 即时装配必须验证商店阶段、活动草稿、槽位、技能拥有权、重复装备和 RuntimeLoadout 合法性；验证全部通过后才原子提交。
- 装配失败时，已提交 RuntimeLoadout、ShopDraft 预览、属性点草稿、run revision 和 UI 显示都不得出现部分变化。
- 成功装配后必须更新 RunSession snapshot 并发出既有权威变更通知；ShopDraft 要重新对齐新的 revision/loadout 基线，同时保留尚未确认的属性点分配。
- 同一映射的重复请求不得造成重复提交、重复 revision 或重复通知。
- 最终商店确认只负责提交仍待处理的属性点并推进/离开商店；不得要求再次确认已经即时生效的技能装配。

## 3. UI 行为

- 点击技能后点槽位、拖放、换槽和清空槽位都走同一个即时权威入口。
- 成功后立即显示权威槽位映射，并给出“已装配至 ACTIVE 1”或“已卸下”等短反馈。
- 失败后显示权威失败原因，保留可恢复的选择/焦点，并回到权威快照，不保留虚假预览。
- 商店提示改为“技能装配即时生效；属性分配在离店时确认”等准确文案。
- 商店按钮改为“确认属性并离开”或等价准确文案，不能继续显示“确认配装与属性”。
- 战斗阶段共享配装仍只读；任务 24 奖励页布局与显式领取确认保持不变。

## 4. 允许修改范围

- `growth/run_session.gd`
- `growth/shop/shop_draft.gd`
- `scripts/ui/run_overlay_interface.gd`
- 新增 `growth/tests/run_task25_immediate_shop_equip_tests.gd`
- 新增 `combat/tests/capture_task25_shop_equip_visual.gd`
- `docs/agent_tasks/pending/25_agent_e3_immediate_shop_skill_equip.md`
- `docs/agent_tasks/evidence/task25/**`

若确需新增一个纯事务结果 contract，必须在交付记录说明必要性；不得借此改写 RuntimeLoadout、奖励规则或商店路线规则。

## 5. 禁止事项

- 不得修改任务 24 已接受的 runner、capture、证据、CombatHUD 或 CombatUiTokens。
- 不得修改任务 20 测试/证据，不得让任务 20 runner 成为门禁。
- 不得取消奖励页“确认领取”，不得把领取、拥有、槽位合法性等权威规则下放到 UI。
- 不得修改 `.tscn`、`.tres`、正式图片/VFX、`project.godot`、combat gameplay、技能执行或伤害逻辑。
- 不得使用共享 Godot 编辑器/MCP 保存、reload、reimport 或运行验收；不得执行任何 Git 写操作。

## 6. 自动化验收

Task 25 新 runner 至少覆盖：

1. 商店合法装配在不调用 `confirm_shop` 时立即更新 RuntimeLoadout 与 RunSession snapshot；
2. 换槽、卸下同样即时生效；
3. 非商店、陈旧草稿、未拥有技能、非法槽位和重复装备被拒绝且全状态不变；
4. 相同映射重复请求幂等，不增加 revision/通知；
5. 已分配但未确认的属性点在即时装配后仍保留；
6. 最终商店确认提交属性并推进阶段，已即时装配的技能不需要第二次确认；
7. UI 点击、拖放与清空都使用权威入口，失败后回到权威快照；
8. 任务 24 奖励聚焦不领取，仍需独立确认且重复提交保护不回归。

恢复任务 24 已接受的 19 个 runner 全部通过（基线 234 tests / 1873 assertions），再加入 Task 25 新 runner单列总数；任务 20 旧 runner继续只作非门禁历史诊断。另需通过 Godot 4.7.1 editor scan 和主场景 180 帧 smoke，正式门禁日志 `SCRIPT ERROR / Parse Error / ERROR / WARNING` 全零。

## 7. 视觉证据

在新的冷副本图形 Godot 中至少生成一张 1920×1080 实际 Viewport：商店配装界面完成一次技能换槽后，槽位立即显示权威结果，提示明确写出即时生效，离店按钮只表达属性/离店职责；不得只提供静态 mockup。

## 8. 执行与交付

- 开始前固化 Git status、允许范围与三份无关未跟踪文档；保护任务 24 与任务 20/21～23成果。
- 所有 scan、runner、smoke、截图只在新的 `C:\tmp` 冷副本与独立 profile 执行。
- 完成后在本任务书追加修改文件、事务接线、精确测试数字、冷副本路径、证据索引和保护对账。
- 执行者只把状态更新到 `REVIEW` 并冻结继续写入；不得自行 `ACCEPTED`，不得暂存、提交或 push。

## 9. Git 基线与排除项

- 派发基线：`HEAD a0c736b031be7bd13f42a6f025585aa35b22e5cd`；`origin/main d1c019f72ae7ba1301786e05caf491b4de079453`；main ahead 2。
- 明确排除并保护：`.workbuddy/memory/2026-07-31.md`、`docs/架构评估与扩展性改进建议.md`、`docs/design/元素地牢_关卡流程竞品探测与适配设计报告.md`。

## 10. 执行阻塞记录（2026-08-03）

- 已在 allowlist 内修改 `growth/run_session.gd`、`growth/shop/shop_draft.gd`、`scripts/ui/run_overlay_interface.gd`：新增 RunSession 商店即时配装事务，成功后单次推进 run/loadout revision、在聚合通知前重基线 ShopDraft 并保留未确认属性点；Overlay 的点击、拖放、移动与卸下均接入该事务，战斗正式交互保持只读，商店文案与离店按钮职责已修正。
- 新增 `growth/tests/run_task25_immediate_shop_equip_tests.gd` 时，写入权限层以“需要用户再次明确批准该新路径”为由连续拒绝；已确认 runner/capture 均未产生半文件，未使用替代写入方式绕过。
- 因 Task25 runner、Viewport capture 和证据目录无法新增，尚未建立冷副本，也未运行 editor scan、19+1 runners、180 帧 smoke 或图形截图；三个脚本当前仅完成文本补丁，不能声明通过或进入 `REVIEW`。
- 阻塞前 Git 写操作为零；任务20/21～24保护集合基线为 88 文件、聚合 SHA-256 `BFF2EAFCD639463A3F652A612430275C7D066B3D8503D0D1C1D1FC20BE1B71CA`；三份明确排除文件未修改。等待中枢审计并取得对新增 Task25 allowlist 路径的明确授权后，由本职责对话继续执行。

中枢随后确认用户已在看到精确路径与风险后明确授权上述 Task25 runner、capture 与 evidence 路径；本职责对话据此恢复 `IN_PROGRESS`，保留本节作为历史阻塞事实并从既有三个未验证补丁继续。
## 11. 执行侧交付（2026-08-03）

本任务已按 allowlist 完成实现和执行侧隔离验证，现冻结继续写入。状态只更新到 REVIEW，未自行验收或标记 ACCEPTED。

### 11.1 修改文件

- growth/run_session.gd
- growth/shop/shop_draft.gd
- scripts/ui/run_overlay_interface.gd
- growth/tests/run_task25_immediate_shop_equip_tests.gd
- combat/tests/capture_task25_shop_equip_visual.gd
- docs/agent_tasks/pending/25_agent_e3_immediate_shop_skill_equip.md
- docs/agent_tasks/evidence/task25/**

### 11.2 权威事务接线

- RunSession.apply_shop_loadout_immediately(draft, candidate) 统一验证 SHOP 阶段、活动/未陈旧草稿、候选映射、技能拥有权与 RuntimeLoadout 合法性；验证全部通过后才调用 RuntimeLoadout 端口。
- 非商店、陈旧草稿、未拥有、非法槽位、重复装备、校验失败和最终提交拒绝均全状态不变；同一映射请求幂等，不增加 loadout/run revision，不重复通知。
- 成功操作只提交一次并只推进一次 revision；RunSession 在发出 snapshot_changed(..., &"shop_loadout_applied") 前调用 ShopDraft.rebase_after_immediate_loadout(...)，使草稿对齐新 revision/loadout，同时保留未确认属性点。
- Overlay 的正式商店点击、拖放、换槽与清空都走该 RunSession 入口；成功显示权威映射和“即时生效”短反馈，失败恢复权威 snapshot、选择和焦点。战斗阶段正式槽位交互保持只读。
- 商店说明改为“技能装配即时生效；属性分配在离店时确认”，按钮改为“确认属性并离开”。成功即时装配后的 draft 已重基线，因此最终 confirm_shop 只提交属性并推进离店，没有第二次技能提交。
- 任务 24 奖励卡的聚焦不领取、独立确认、重复提交保护未取消。

### 11.3 冷副本与精确门禁

- 最终冷副本：C:\tmp\element-dungeon-task25-cold-20260803-02\project
- 独立 profile：C:\tmp\element-dungeon-task25-profile-20260803-02
- 冷复制：1184/1184 文件、38,273,217/38,273,217 字节，逐文件 SHA-256 0 mismatch；首条 Godot 命令前无 .godot。
- 首条 Godot 命令：Godot 4.7.1 headless editor scan，exit 0。
- Task 25 新 runner：8 tests / 242 assertions，exit 0。
- 任务 24 已接受基线：19/19 runners，234 tests / 1873 assertions；任务 12/16/18/24 专项分别为 13/110、11/209、9/124、10/190。
- 总计：20/20 runners，242 tests / 2115 assertions。
- 主场景 180 帧 smoke：exit 0。
- 正式 scan/runner/smoke/capture 共 23 份日志：SCRIPT ERROR=0、Parse Error=0、ERROR:=0、WARNING:=0。
- 任务 20 未混入门禁、未修改；继续保持历史 BLOCKED 与已记录的非门禁 7 failures / 83 assertions。

### 11.4 实际 Viewport 与证据

- 图形 Godot 4.7.1 使用 OpenGL/NVIDIA 实际渲染，capture 通过真实 RunSession 进入 SHOP，并用正式点击把 element_bolt 从 ACTIVE 1 换至 ACTIVE 2；权威 run revision 为 15 → 16，capture exit 0。
- docs/agent_tasks/evidence/task25/01_shop_immediate_equip_1920x1080.png 为 1920×1080，SHA-256 1C5AC767E47F113148564BF38F699EA121B5945BED73BC9D9ED034FBA26C3B2E。保存前夹具已断言权威映射、单次 revision、即时反馈、商店说明和“确认属性并离开”按钮。
- 执行侧本地图片查看器与 computer-use 均被 Windows CreateProcessWithLogonW 1385 阻断，未冒充完成人工主观验图；完整 PNG、像素完整性结果、日志索引和独立人工复核要求见 docs/agent_tasks/evidence/task25/README.md。中枢 Review 必须在新冷副本重新生成并人工打开画面。

### 11.5 allowlist 与保护对账

- 写入仅限本任务书列出的三个实现脚本、两枚 harness、任务书及 evidence/task25/**。
- 任务 20 evidence、任务 21～23 恢复任务书、任务 24 归档任务书/evidence 的 88 文件保护集合保持 88/88，聚合 SHA-256 BFF2EAFCD639463A3F652A612430275C7D066B3D8503D0D1C1D1FC20BE1B71CA；相对最终冷副本 0 mismatch。
- 任务 20/24 runner/capture、CombatHUD、CombatUiTokens 六个关键禁止文件相对最终冷副本 0 mismatch；任务 25 五个实现/harness 也与最终冷副本 0 mismatch。
- 三份明确排除文件哈希保持派发值；共享 .godot 仍为 700 文件、聚合 SHA-256 E4E4B369A9EFA25854C66DC9BA389C6C290311199DD9C84C91551FDEC6799EB1；两枚 Task 25 .gd.uid 均不存在。
- 未修改场景、资源、正式资产、CombatHUD/Token、任务 20/24 runner/capture/evidence或其他 gameplay 文件。
- Git 写操作为零：未 add、commit、push、reset、restore、checkout、clean 或 stash。

### 11.6 遗留风险与 Review 要求

- 为兼容冻结任务 12 的直接 ShopDraft 测试，Overlay 仍保留仅供历史夹具调用的预览兼容分支；正式商店输入均已使用 RunSession 权威事务，正式战斗输入只读。独立 Review 应继续用真实场景 revision/snapshot 检查该边界。
- 执行侧不作 ACCEPTED 结论。中枢必须在全新 Review 冷副本/profile 从 headless editor scan 开始重跑 20 个 runner、180 帧 smoke，并人工查看重新生成的实际 Viewport；失败时只报告并退回，不由本执行者越界修复。

## 12. 中枢独立验收（2026-08-03）

- 结论：`PASS`，由中枢标记 `ACCEPTED` 并归档；任务 20 继续保持历史 `BLOCKED`。
- Review 冷副本：`C:\tmp\element-dungeon-task25-review-20260803-01\project`；独立 profile：`C:\tmp\element-dungeon-task25-review-20260803-01\profile`。
- 冷复制排除 `.git`、`.godot` 与根 `cache`：1212/1212 文件、38,702,864/38,702,864 字节，逐文件 SHA-256 为 0 mismatch；第一条 Godot 命令前不存在 `.godot`。
- Godot 4.7.1 headless editor scan exit 0；完整日志 `SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 0。
- Task25 专项为 8 tests / 242 assertions；任务24已接受19-runner基线为 19/19、234 tests / 1873 assertions；合计 20/20 runners、242 tests / 2115 assertions。任务20未进入门禁。
- Review 首次 runner 调度误把 editor-only 设置路径传给普通 runner，20 个进程均在项目脚本加载前统一拒绝；该诊断不作为产品结论。移除错误参数后，20 个 runner 全部从头重跑并通过，正式日志四类错误/警告均为 0。
- 主场景 180 帧 smoke exit 0，四类错误/警告均为 0。
- 中枢先移走冷副本中复制来的执行者 PNG，再由新的非编辑器图形 Godot 重新生成 1920×1080 实际 Viewport；Review PNG SHA-256 为 `50C3526CEEEC3AC834610EE2A3604133CC44DF029BEA85B297BD32327532DEAD`，与执行者旧图不同。人工检查确认 ACTIVE 1 清空、元素弹位于 ACTIVE 2、绿色“已换至 ACTIVE 2 · 即时生效”反馈、商店说明与“确认属性并离开”按钮完整可见，无覆盖或裁切。
- 自动测试与真实场景 revision/snapshot 共同确认：即时装配只推进一次权威 revision；失败全状态不变并恢复选择/焦点；最终确认只提交属性并离店；战斗交互只读；任务24奖励仍聚焦不领取、独立确认且有重复提交保护。
- 用户明确允许共享 Godot 编辑器保持开启后继续验收；中枢未对共享项目运行 Godot。Review 前后 1212 个非缓存项目文件、32 个 Task25 allowlist 文件、三份排除文件、702 个共享 `.godot` 文件及 Git 状态均为 0 mismatch。
- 中枢未修改游戏代码、场景、资源或正式资产；未 push。
- 归档文档写入后，持续开启的共享编辑器于 2026-08-03 13:34:53 UTC 新生成两枚 Task25 `.gd.uid` 与证据 PNG 的 `.import` sidecar；它们晚于独立零漂移复核，不属于执行交付或已验收冷副本。中枢未删除、覆盖或修改这些文件，并将其从 Task25 暂存与提交中精确排除。
