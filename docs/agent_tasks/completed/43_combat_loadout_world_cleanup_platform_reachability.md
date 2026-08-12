# 任务 43：新技能自动装配、清场配装与房间可玩性收尾

状态：ACCEPTED
负责人：流程与可玩性执行 3.0（threadId `019ff62b-18e8-7f02-bcb0-9f4e39e2fef2`，hostId `local`）
独立 Review：Review 7.0（threadId `019ff62b-4b52-7ab0-94ce-e1499e6c5099`，hostId `local`）
依赖：Task42 `ACCEPTED`；派发基线 `61738aba363f3bba18f80244841613a74f4ea1de`
回传中枢：Review 6.0，threadId `019fd7fd-4476-7f73-b121-76760fabf284`，hostId `local`

## 1. 目标与用户冻结决定

本任务只收尾当前正式整局中的五个直接可玩性问题，不增加新系统：

1. 正式局获得新技能时，若同类型槽位仍有空位，则自动装入第一个空槽；主动槽顺序固定 `A1 → A2 → A3`，被动槽顺序固定 `P1 → P2 → P3 → P4`。同类型已满时只加入拥有列表，不顶掉、交换或升级任何已装备技能。
2. 正式战斗阶段按 `L` 可打开配装页。房间尚未真正清场时页面只读并明确提示；只有初始波与援军/Boss 全部阵亡、`RunRoomInstance.room_is_cleared == true` 后，点击或拖拽装配才可提交。
3. 正式房间敌人阵亡后下一帧不再留下尸体节点；不得影响死亡事件、梦尘账本、援军立即激活、两波清场与 Boss 停火。
4. 普通宝箱和 Boss 结算宝箱视觉底边贴地，不再悬浮。
5. 风险路线第二房 `combat_02_pressure` 与第三房 `combat_03_layer_elite` 共用的首个平台改为正常跳跃可达；不得增强玩家跳跃、改变重力或加入自动攀爬。

求职作品进度优先：只做直接路径，不引入事件总线、战斗暂停状态机、尸体池、通用地形求解器、动态落地物理、导航/自动寻路或新的 UI 框架。

## 2. 已确认根因与最小几何修正

### 2.1 宝箱

`chest_closed.png` 为 `256×256`，当前 alpha 可见包围盒为 `(31,49)–(227,213)`；`run_reward_chest.tscn` 的 Sprite 以中心为原点、缩放 `0.46`。现有宝箱根位置 `y=478` 时，可见底边为 `478 + (213-128)×0.46 = 517.1`；四个正式普通房模板与 Boss 模板地面顶面均为 `y=540`，所以约悬空 `22.9px`。这与尸体碰撞无关：宝箱是 `Node2D`，没有刚体落地事务。

最小修正是在 `RunRoomInstance` 中把宝箱根 y 调到约 `501`，使可见底边落在 `540±2px`。不得改 Task39 PNG、import、缩放或给宝箱增加物理体。

### 2.2 平台

`combat_02_pressure` 与 `combat_03_layer_elite` 均只读引用 `room_arena_platforms.tscn`。当前地面顶面 `y=540`，首个 `LowerPlatform` 顶面 `y=416`，需上升 `124px`；玩家 `JUMP_VELOCITY=-520`、`GRAVITY=1150`，理论最高上升约 `117.6px`，因此不可达。

只下调共享模板的 `LowerPlatform`，建议中心 `y=442`（顶面 `y=430`）：地面到首平台约 `110px`，首平台到上平台约 `112px`，均保留跳跃空间且无需改玩家参数。稳定路线 `combat_02_swarm` 的平地模板不变；敌人资源与梦尘不变。

## 3. 权威行为合同

### 3.1 自动装配

1. 只覆盖当前正式获得技能的两个入口：普通宝箱技能与商店购买新技能。历史免费奖励继续关闭，不为它扩展新流程。
2. 自动装配属于原获得命令的一部分：技能拥有、钱包（若为购买）、RunSnapshot 与 RuntimeLoadout 同一次成功发布；run revision 只前进一次，若确有自动装配则 loadout revision 只前进一次。
3. 在提交拥有/扣款前，先用现有 RuntimeLoadout 校验候选。若没有 RuntimeLoadout port、没有同类型空槽或同类型已满，正常获得技能但不改配装。
4. 只填第一个同类型空槽；不覆盖、不换位、不重复装配，不根据技能强度或元素做选择。
5. replay/重复宝箱/重复购买继续沿用现有命令记录，不能再次装配或推进 revision。

### 3.2 清场后战斗配装

1. `RunSessionHost` 负责现场事实门禁：正式 `COMBAT`、当前房间有效且其敌人集合已全部阵亡；已释放的正式敌人引用按“已阵亡”处理，不得访问失效节点。
2. `RunSession` 只承担现有事务边界：正式 `COMBAT`、expected run revision、七槽结构、拥有关系、主动/被动槽类型、RuntimeLoadout 校验与一次替换。不得复用或伪造 `ShopDraft`，不得改变钱包、商店会话、升级、重置或路线。
3. `RunFlowCoordinator` 只转发 Host 的清场事务与当前房间清场可用性；UI 不能直接写七槽。
4. 敌人仍存活时允许打开页面，但点击、拖拽、卸下和提交均不得调用权威替换；钱包、run revision、loadout revision 与七槽 0 变化，并显示“清场后可调整”之类的短反馈。
5. 清场后继续复用 Task40 的点击/拖拽、同类型槽、换位、卸下与拒绝恢复语义；每次成功动作最多一次权威调用/一次 revision。按 `L` 或关闭按钮可关闭，不暂停世界也不新增战斗中间态。

## 4. 敌人清理合同

1. 仅正式 `configure_run_spawn` 生成的房间敌人在 `enemy_defeated` 同步发出并完成现有 Host/Room 结算观察后，deferred `queue_free`；下一 `process_frame` 必须失效且不可见、不可碰撞、不可再发弹。
2. `TestRoom` 的历史 `R 重置` 夹具可继续保留，不要求在本任务删除；正式 RunGame 绝不能保留“已击败 · R 重置”尸体。
3. `RunRoomInstance` 与 Host 的敌人完成判断必须容忍已释放引用；初始波清完仍立即激活同一批预实例化援军，两波清完仍只触发一次宝箱/传送门。
4. 不改敌人立绘、受击、伤害、奖励、Boss 1.7 倍轮廓与 ProjectileDelivery 参数。

## 5. 精确 allowlist

```text
growth/run_session.gd
scripts/run_session_host.gd
scripts/run/run_flow_coordinator.gd
scripts/ui/run_overlay_interface.gd
scripts/enemy.gd
scripts/run/run_room_instance.gd
scenes/run/rooms/room_arena_platforms.tscn
combat/tests/run_task31_full_run_e2e_tests.gd
combat/tests/run_task40_drag_compact_hud_tests.gd
growth/tests/run_task32_formal_four_passive_content_tests.gd
growth/tests/run_task41_physical_flow_waves_boss_tests.gd
growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd
growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd.uid
combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd
combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd.uid
docs/design/元素地牢_局内构筑与关卡流程实现契约.md
docs/current_gameplay_design_handoff.md
docs/agent_tasks/pending/43_combat_loadout_world_cleanup_platform_reachability.md
docs/agent_tasks/evidence/task43/**
```

若现有生产调用点证明必须增加文件，先阻塞回传中枢，不得顺手扩权。Task31 只迁移自动装配直接改变的确定性七槽/商店动作，并增加对应强断言；Task40 只迁移 `task40_drag_flow` 入店前 reclaim 已自动位于首个空主动槽后的操作起点；Task32 只把 burning/unending/passive_vitality/passive_energy 的四次“购买后再次点击同一 P 槽”迁移为购买结果已原子装入 P1–P4、购买 run/loadout revision 各只推进一次的字面强断言，不得改变其经济、四被动、跨房重建、HUD 或内容断言；Task41 只迁移正式敌人释放后不再持有/调用 Boss 尸体引用的断言，必须改为“敌人节点已释放且不再产生弹体”，不得削弱六战、波次、宝箱、商店、Boss 与结果断言。

两个新 GDScript 的 `.gd.uid` 必须由本任务此前不存在的冷副本与独立 Godot 4.7.1 profile 首次 editor scan 生成，先逐项复制 UID、再复制源脚本回共享（共享编辑器当前被动开启）；不得手写或认领其他 sidecar。

冷根验证夹具例外：允许在执行/Review 冷根创建空文件
`docs/agent_tasks/evidence/.gdignore`，只用于阻止 Godot 把已归档 evidence CSV 当作翻译表导入。
该文件不是共享生产 allowlist，不得复制回共享、不得进入 Task43 evidence、不得暂存或提交；
候选 source/allowlist 哈希对账必须明确排除它。

## 6. 强只读不变项

- Task42 的 50/50、150 梦尘、两条固定 E2E 经济与全部 evidence 不变。
- Task39 五张 PNG/五个 import、宝箱缩放和其他 VFX 资产不变。
- 六战、两路线、一商店、两波、12 秒/首波全灭立即援军、Boss 零奖励结算不变。
- 玩家跳跃/重力/碰撞体，全部敌人资源、房间梦尘和平台外其他模板不变。
- 七槽仍为 3 主动 + 4 被动；Task40 拖拽/点击共存，商店权威交易不变。
- Task20 继续历史 `BLOCKED`，不追认。

## 7. 专项与回归门禁

执行者在一个最终全新冷根完成：

1. 第一条 Godot 命令为 4.7.1 headless editor scan；scan 前无 `.godot`。独立 Review 的全新冷根必须在第一条 Godot 命令前先放置 §5 冷根专用 `.gdignore`，其 initial/final scan 均须五类标记为 0。执行者当前冷根的首次 scan 早于该例外并已暴露固定 HEAD 历史 CSV 非法文件名错误：原日志必须保留并标为已知 baseline/import blocker，不算成功正式日志；无需因此重跑已经通过的 runner/smoke/capture，但加入夹具后的 final rescan 必须 exit 0 且五类标记为 0。
2. Task43 专项至少覆盖：
   - 宝箱技能与商店购买分别自动进入首个同类型空槽；主动/被动各一例；类型已满不覆盖；重放不重复；run/loadout revision 精确。
   - 活敌时 L 页面可见但只读，点击/拖拽/卸下均零 authority；两波真正清场后同一页可点击与拖拽提交，拒绝恢复与钱包不变。
   - 正式敌人死亡事件只结算一次，下一帧节点释放；首波仍立即唤醒援军，两波后宝箱出现；Boss 释放后无新弹体。
   - 宝箱 alpha 可见底边 `540±2px`，并证明位置不依赖敌人节点。
   - 使用真实 Player 输入/physics frame，从地面正常跳上 `LowerPlatform`；分别以 `combat_02_pressure`、`combat_03_layer_elite` 定义确认共用模板可达，禁止直接赋玩家到平台。
3. Task31、Task32、Task40、Task41 四个直接受影响 runner 单列通过；Task31 仍使用 Task42 固定 safe/risk 身份与精确经济。
4. 执行者从头跑正式 `34/34`（Task42 的 33 个 accepted runners + Task43 新 runner）并精确汇总 tests/assertions；Task20 单列、不得计入接受。
5. `RunGame`、`TestRoom` 各 180 帧 smoke；final editor rescan。
6. 所有成功正式日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。

为节省本轮时间，独立 Review 不必再次重跑其余 29 个未受影响 runner；但必须在独立新冷根重跑 Task43 + Task31/32/40/41、Task20 单列、双 smoke、非 headless capture 与 final rescan，并静态核对执行者的 `34/34` 汇总和精确 allowlist。任一直接 runner 或 smoke 失败即 FAIL。

## 8. 视觉证据（恰好 5 张）

在非 headless 实际 Viewport 生成并原尺寸检查：

1. `1920×1080`：活敌存在时 L 配装页可打开，明确只读/清场门禁。
2. `1920×1080`：两波清场后同一配装页可调整，展示一个真实自动装配槽与可提交状态。
3. `1920×1080`：关闭页面回到世界，敌人尸体为 0、宝箱可见底边贴地、HUD 显示自动装配技能。
4. `2560×1440`：`combat_02_pressure` 玩家以真实跳跃站上首个平台。
5. `2560×1440`：`combat_03_layer_elite` 玩家以真实跳跃站上首个平台。

截图保存前必须先通过对应 authority/节点存活/几何/输入路径断言；不得用文字假图、直接传送玩家或复用旧截图。evidence 只回流 README、正式日志/CSV 与 5 PNG；冷副本生成的 `.import/.translation` 不回流。

## 9. 隔离、保护与回传

- 固定候选只能是 Git HEAD `61738aba363f3bba18f80244841613a74f4ea1de` + 本任务 §5 冻结文件；live `docs/agent_tasks/README.md` 使用 HEAD blob，不把中枢立项行带入执行候选。
- 上述固定候选允许额外存在 §5 冷根专用 `docs/agent_tasks/evidence/.gdignore`，但它只属于验证环境；所有 source/overlay/共享/evidence 对账必须排除，且不得回流。
- 所有 Godot/runner/smoke/capture 只在此前不存在的 `C:\tmp` 冷副本与独立 profile；禁止控制共享 PID `52240` / `9908`。
- 共享 `.godot`、两份中文保护文档、现有 36 个未跟踪 `.import`、50 个未跟踪 `.translation` 与所有来源无关项只读保护；不得删除、覆盖、复制入候选/evidence、认领、暂存或恢复。
- 执行者不做 Git；不得 add/commit/push/reset/restore/checkout/clean/stash。
- 完成或阻塞后必须直接 `send_message_to_thread` 回传中枢 threadId `019fd7fd-4476-7f73-b121-76760fabf284`，附状态、精确 diff/allowlist、冷根/profile、runner 数、smoke/capture、日志标记与保护对账，然后冻结等待 Review。

## 10. 阶段一独立只读审计（2026-08-12）

Review 7.0 已在固定 HEAD `61738aba363f3bba18f80244841613a74f4ea1de` 上完成任务书、现有生产调用点与直接 runner 审计，结论 `PASS`：

- 宝箱 alpha 底边与平台跳跃几何计算成立，且两项均有常数级最小修正；
- 自动装配可在现有 RunSession 获得命令内完成一次原子发布；
- 战斗 L 配装可用现有 UI/Host/Coordinator/RunSession 分层，不得复用 ShopDraft；
- deferred 敌人释放保留同步死亡结算，Host 的失效引用判断属于已授权修改；
- 无需增加 project.godot、combat_hud、RuntimeSkillLoadout、VFX/passive、其他房模板或旧 runner；
- §5 allowlist、两 UID 和窄 Review 门禁足以覆盖实质风险。

据此中枢已正式放行实现；执行者不得扩大范围。

## 11. 执行阻塞（2026-08-12）

最终冷根从头正式 `34/34` 在第 27 项
`growth/tests/run_task32_formal_four_passive_content_tests.gd` 停止：前 26 项均通过，
Task32 仍以四处旧断言要求“购买新被动后，再点击已经由购买自动填入的同一
`P1–P4` 槽位时，run revision 必须再次 `+1`”。Task43 冻结合同要求购买命令
已原子自动装配，且相同映射不得产生第二次 authority/loadout revision；因此不能
通过生产兼容分支解决，也不能弱化 Task43 合同。

该 Task32 runner 不在 §5 allowlist。请求中枢仅扩入
`growth/tests/run_task32_formal_four_passive_content_tests.gd`，允许把四个旧二次装配
断言迁移为字面强断言：购买结果已位于对应 `P1–P4`、购买仅推进一次 run/loadout
revision、随后不再执行第二次同槽装配。扩权前执行冻结；失败 formal 批次不作为
成功证据，获准后必须从头重生正式 `34/34`。

## 12. 中枢精确扩权裁决（2026-08-12）

中枢只读复核 Task32 当前代码后批准 §11 请求，并将任务状态恢复为 `IN_PROGRESS`：

- 精确新增 `growth/tests/run_task32_formal_four_passive_content_tests.gd`；
- burning 与循环中的 unending/passive_vitality/passive_energy 四段，改为购买结果已经分别位于 P1–P4，购买命令只推进一次 run revision、自动装配只推进一次 loadout revision；
- 删除四次购买后再次选择技能/点击同一已占槽及其第二次 revision `+1` 期望；
- Task32 其余经济、价格、拥有、被动无等级、P1–P4 唯一 Runtime、跨房重建、HUD 和正式整局断言禁止修改；
- 不授权任何生产兼容分支、run identity 变更或额外文件。

独立 Review 的直接集合相应扩为 Task43 + Task31/32/40/41；无需重做阶段一审计，current-final 时按修订后任务书验收。失败 formal 批次继续仅作 blocker，不得混入最终成功 evidence。

## 13. 最终 editor rescan 阻塞（2026-08-13）

实现与成功回归已完成：Task43 专项 `4 tests / 125 assertions`；Task31/32/40/41
分别为 `4/534`、`5/181`、`4/118`、`4/112`；从头成功正式集合为
`34/34`、合计 `319 tests / 6889 assertions`；Task20 单列 `7/68`；RunGame 与
TestRoom 双 `180` 帧 smoke 均成功；非 headless capture 已生成并原尺寸检查恰好
5 张任务书指定实际画面。

最终 cold editor rescan 仍被固定 HEAD 中历史 evidence 阻塞。Godot 会递归导入
`docs/agent_tasks/evidence/task42/csv/log_marker_summary.csv` 等历史 CSV，并尝试生成
`log_marker_summary.ERROR:.translation` 与 `log_marker_summary.WARNING:.translation`；
Windows 文件名不允许冒号，因此稳定产生 `Safe save failed`、`Cannot open file` 与后续
filesystem `ERROR:`。在只删除冷扫描相对固定基线新生的 172 个 sidecar 后，从干净
基线重跑仍再次生成 58 个 sidecar并复现同一错误，证明不是 Task43 源码或正式 runner
失败。

可使 rescan 干净的最小做法，是仅在冷根的
`docs/agent_tasks/evidence/.gdignore` 排除历史归档 evidence；但该文件不在 §5 精确
allowlist，执行权限策略已明确拒绝创建，并禁止以其他方式绕过。故当前不能满足
“final editor rescan 五类日志标记为 0”。请求中枢裁决是否精确授权该冷根专用、绝不
回流共享/evidence 的 `.gdignore` 验证夹具；未获授权前保持冻结，现有失败 rescan 仅作
blocker 证据，不进入成功 evidence。

## 14. 中枢冷根验证夹具裁决（2026-08-13）

中枢已只读核对当前冷根日志、Task42 历史 CSV 表头与共享路径，批准 §13 的最小请求，
并把任务状态恢复为 `IN_PROGRESS`：

1. 错误稳定来自固定 HEAD 已归档
   `docs/agent_tasks/evidence/task42/csv/log_marker_summary.csv` 的 `ERROR:` / `WARNING:`
   表头；Godot 尝试生成 Windows 非法文件名
   `log_marker_summary.ERROR:.translation` / `WARNING:.translation`。这不是 Task43 生产、runner、
   smoke 或 capture 失败。
2. 执行者可在当前冷根创建空的
   `docs/agent_tasks/evidence/.gdignore`，随后重跑 final editor rescan；无需重跑已经从头通过的
   `34/34`、Task20、双 smoke 或 5 图 capture。
3. 执行者首次 scan 的原始失败日志必须保留在冷根并在 evidence README/保护 CSV 中如实登记为
   固定 HEAD baseline/import blocker，不得混入“成功正式日志五类标记 0”的统计，也不得删除、
   改写或冒充 PASS。最终 rescan 必须 exit 0 且五类标记为 0。
4. 若为得到可复核的 final rescan 需要清理由该冷根扫描生成、且相对固定 baseline ZIP 明确新增的
   `.import` / `.translation`，只允许按预先生成的精确路径清单删除冷根内这些 sidecar；不得删除
   baseline 已有文件、Task43 源/证据、共享文件或使用宽泛 clean/reset。清单须进入保护对账。
5. 独立 Review 必须另建全新冷根，并在第一条 Godot 命令前创建相同空 `.gdignore`；因此其
   initial scan 与 final rescan 均须 exit 0、五类标记为 0。Review 仍应保留/核验执行者首次 scan
   blocker 的原日志和解释，但不复现无意义的非法文件名错误。
6. `.gdignore` 绝不回流共享、Task43 evidence 或 Git，不构成生产 allowlist 扩权；除该冷根夹具
   外不授权任何新文件或门禁豁免。

## 16. 独立 capture FAIL 与窄返工（2026-08-13）

Review 7.0 在全新 `-02` 冷候选中已独立通过 initial scan、Task43、Task31/32/40/41、
Task20 与双 smoke，但非 headless capture 连续两次失败，结论 `FAIL`，不得接受：

- 第一次只有 `combat_03_layer_elite` 未在 30 个 `process_frame` 内稳定落地，随后真实跳跃事件与
  登台断言连锁失败；
- 未改候选、只移除失败图后完整重跑，`combat_02_pressure` 与 `combat_03_layer_elite` 都未稳定落地，
  两房登台断言失败；
- 专项 runner 的两房真实 physics jump 已通过，生产平台几何没有在该 Review 中失败。确定性缺口只在
  allowlist 内 `combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd`：
  `_capture_platform` 用只等待 `process_frame` 的 `_wait_until` 检查 physics 状态，并读取会被
  `_physics_process` 立即消费的瞬时 `jump_requested`。

中枢批准且仅批准以下窄返工，任务状态恢复 `IN_PROGRESS`：

1. 落地等待必须改为真实 `physics_frame`，最多等待 120 个 physics frames，并要求至少连续 2 个
   physics frames `player.is_on_floor()` 后才记录起跳位置；不得直接赋玩家位置或调用 Player 私有输入方法。
2. 继续用 `Input.parse_input_event` 发送真实 jump 与 `Input.action_press("move_right")`。删除对瞬时
   `jump_requested` 的跨帧读取，改为在后续真实 physics frames 中断言至少一次 `velocity.y < 0`
   且离地，再断言落到 LowerPlatform 的既有几何范围；这同时证明输入确实进入 Player physics 路径。
3. 只允许修改该 capture 脚本、Task43 taskbook、Task43 evidence README/manifest/日志/五张 PNG；
   生产、专项、Task31/32/40/41、设计文档与两 UID 均须逐项保持本次失败候选哈希不变。
4. 执行者无需重跑已通过的专项、直接 runner、`34/34`、Task20 或双 smoke；在当前冷根连续完整运行
   capture 两次，二者均须 `1 test / 0 failures / 5 PNG`、exit 0、五类标记 0，第二次完整覆盖五图；
   两份成功 capture 日志均进入 current-final evidence，失败旧图/日志不得混入成功 evidence。
5. 执行者随后重跑 final editor rescan，更新 evidence/保护对账并冻结 `REVIEW`。
6. Review 必须另建此前不存在的全新冷根/profile，首命令前放置 §14 `.gdignore`；只需重新完成
   initial scan、capture 连续两次、五张最终图原尺寸审阅与 final rescan，并逐项证明除 capture/taskbook/
   evidence 外所有冻结 source 哈希等于本次 `-02` 已通过候选。可复用 `-02` 的专项、Task31/32/40/41、
   Task20 与双 smoke 结论，不必重复运行。

## 15. 执行完成回传（2026-08-13）

Task43 已按 §5/§7/§9/§14 完成并冻结为 `REVIEW`：

- Task43 专项 `4 tests / 125 assertions`；Task31/32/40/41 直接 runner 分别为
  `4/534`、`5/181`、`4/118`、`4/112`，全部 0 failures；
- 从头成功正式集合 `34/34`，合计 `319 tests / 6889 assertions`；Task20 单列
  `7/68`，不计入接受；RunGame/TestRoom 双 180 帧 smoke 均 exit 0；
- 非 headless capture 生成并原尺寸检查恰好 5 张任务书指定画面；
- 冷根空 `.gdignore` 按 §14 创建且未回流。相对 baseline ZIP 新增的 172 个
  `.import/.translation` 已先生成精确清单、验证全部位于冷根后逐项删除；获批夹具后的
  final editor rescan exit 0，五类日志标记全 0；
- 首次 scan 原始 blocker 日志完整保留在冷根，SHA256 和标记计数登记于 evidence，未混入
  44 个成功日志五类标记统计；失败 formal/capture/rescan 均未回流成功 evidence；
- 15 个生产/runner/UID 文件共享与冷根 SHA256 全部一致，冷根 `.gdignore` 明确排除；
- 共享 `.godot` 仍为 `1111 files / 45,801,258 bytes`，外部未跟踪 sidecar 仍为
  `36 import / 50 translation`，fixed HEAD tracked sidecar diff 为 0；两份保护文档哈希不变，
  外部 PID 52240/9908 未控制；无任何 Git 写操作。

正式证据位于 `docs/agent_tasks/evidence/task43/`；执行者只请求独立 Review，不自行
`ACCEPTED`。

## 17. §16 窄返工完成（2026-08-13）

只修改了 `combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd` 与本任务
taskbook/evidence；生产、专项、Task31/32/40/41、两份设计文档和两 UID 全部冻结，
冻结集合 16 个文件逐项 SHA256 mismatch 为 0。

平台 capture 现使用以下真实输入/物理证明：

1. 最多等待 120 个 `physics_frame`，只有连续 2 个 physics frames
   `player.is_on_floor()` 才记录起跳位置；
2. 继续以 `Input.parse_input_event` 发送 jump，以
   `Input.action_press("move_right")` 水平移动；
3. 不再读取跨帧瞬时 `jump_requested`，改在随后最多 120 个 physics frames 中证明至少
   一次 `player.velocity.y < 0.0` 且离地；
4. 最后要求玩家连续 2 个 physics frames 位于 LowerPlatform 的既有 x/y 几何范围且
   `is_on_floor()`；没有直接赋平台位置或调用 Player 私有输入。

当前冷根未改候选连续完整运行 capture 两次，两次均输出
`1 test / 0 failures / 5 PNG`、exit 0、五类日志标记全 0；第二次完整覆盖最终五图，
并已逐张原尺寸复核。两份成功日志均已进入 current-final evidence，旧 capture 日志和
Review 失败产物未混入。随后 Godot 4.7.1 final editor rescan exit 0、五类标记全 0，
冷根非 baseline `.import/.translation` 仍为 0。

capture 源最终 SHA256 为
`71F462543177F7FB0000535D32D8CE9179CA3EB1689A618377018568D42B18EC`；capture UID
仍为 `uid://vg1x71w112xs`，SHA256
`4C7B4486CF8B55F5A106D77421A14DD5C6328DF98DB4CF0F8B27A412EFFDD83A`。
成功日志集合现为 45 个且五类标记非零行 0。任务重新冻结为 `REVIEW`，不自行
`ACCEPTED`。

## 18. 中枢独立验收与接受（2026-08-13）

Review 7.0 以固定 HEAD `61738aba363f3bba18f80244841613a74f4ea1de` 加 Task43
精确冻结 overlay 独立验收。`-02` 全新冷候选已通过 initial scan、Task43 专项、
Task31/32/40/41、Task20 与双 180 帧 smoke；§16 返工后又在此前不存在的
`C:\tmp\element-dungeon-task43-review7-20260813-03\project` 和独立 profile 中完成窄复验：

- 第一条 Godot 命令前候选无 `.godot`，仅按 §14 放置冷根专用 0-byte `.gdignore`；
  initial scan 与 final rescan 均为 Godot 4.7.1、exit 0、五类标记全 0；
- 非 headless capture 在未修改候选的情况下连续两次完整通过，每次均为
  `1 test / 0 failures / 5 images`，第二次确实覆盖全部五图；
- 五图原尺寸复核分别证明活敌时配装只读、清场后可配且新技能自动进入 A2、敌人尸体为 0
  且宝箱贴地、pressure 与 layer_elite 两房均通过真实输入/物理稳定登上 LowerPlatform；
- capture 未传送玩家到平台、未调用 Player 私有输入；最终 capture 源 SHA256 为
  `71F462543177F7FB0000535D32D8CE9179CA3EB1689A618377018568D42B18EC`；
- 除 capture/taskbook/evidence 外的冻结 16 文件与上一轮已通过候选逐项 SHA256 mismatch 为 0；
  执行阶段正式集合保持 `34/34`、`319 tests / 6889 assertions`，Task20 单列 `7/68`；
- current-final evidence 精确为 67 files（README 1、CSV 16、log 45、PNG 5），manifest
  自身外 66 行的 bytes/SHA256 全匹配；45 份成功日志五类标记全 0，且 evidence 内无
  `.gdignore`、`.import`、`.translation` 或旧失败产物。

中枢确认 Task43 的生产实现、直接回归、可玩性画面、冷副本来源与精确 allowlist 均无阻塞，
最终判定 `ACCEPTED`。Task20 仍保持历史 `BLOCKED`，不得因本轮单列 runner 通过而追认。
