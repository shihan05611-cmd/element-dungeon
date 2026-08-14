# 任务 49：五阶段演示流程与首关主动技能保底

状态：ACCEPTED
负责人：独立执行任务（中枢派发）
依赖：任务 46（ACCEPTED）；与 Task 48 文件不重叠，可并行
Git 基线：`main` HEAD `fc7b531`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L3
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级/停线触发：必须修改精确 allowlist 外生产文件、改变奖励公共返回结构、引入随机不稳定、或与 Task 48 发生文件重叠时立即停线回传。用户已明确授权删除旧六战 flow，不为旧流程保留兼容层。

## 1. 用户冻结需求

作为演示作品缩短正式局内流程：

1. 正式流程严格为五个可玩阶段：`战斗 → 战斗 → 商店 → 战斗 → Boss`，Boss 后进入结算。
2. 首个战斗房间恰好生成 `2` 个初始敌人，且整个房间不生成援军。
3. 首关清场后的宝箱必定掉落 `1` 个玩家尚未拥有的主动技能；不得掉落被动或只给梦尘。

若主动奖励池已无未拥有主动技能，必须使用显式、可测试的降级结果，不得死锁流程；默认降级为现有梦尘奖励，并在结果/提示中保持可解释。不得为“必掉主动”重复授予已拥有技能。

## 2. 流程实现口径

1. 删除 `resources/run/flows/prototype_two_layer_six_combat.tres`，不保留旧六战流程兼容层；旧分支房间资源可作为未使用素材继续保留，不要求删除。
2. 新增 `resources/run/flows/prototype_five_stage_demo.tres`，正式顺序固定为：
   - `combat_01_entry`
   - 复用 `combat_02_swarm`
   - `shop_demo_mid`
   - 复用 `combat_04_validation`
   - 复用 `combat_06_final_boss`
   - `run_result`
3. 新流没有路线选择节点；`RunGame` 默认 flow 切换为新资源。
4. `RunFlowDefinition` 的正式严格计数改为 `4 combat（含 Boss）/1 shop/0 route`；不引入为已删除旧流服务的兼容参数。
5. 直接改造 `combat_01_entry.tres` 为 `2` 初始敌人、`0` 援军。房间定义增加窄的单波/奖励策略字段，使该首关合法表达单波与主动技能保底；其他普通房间继续遵守既有 `3~5 + 2~3` 双波门禁。

## 3. 首关主动技能保底

1. 权威条件来自当前正式房间定义，而非 UI、显示名称或硬编码“第一次数”。
2. `RunSession.claim_formal_room_chest` 在该房间只从 `reward_pool` 中、玩家未拥有且 `gameplay_definition.is_active_skill()` 的内容选择。
3. 保持现有确定性排序/选择和幂等 command replay；同一 command 不得重复授予。
4. 非保底房间的奖励逻辑、商店购买、技能升级和 Boss 结算语义不变。

## 4. 精确生产 allowlist

1. `growth/flow/run_flow_definition.gd`
2. `growth/flow/combat_room_definition.gd`
3. `growth/run_session.gd`
4. `resources/run/flows/prototype_two_layer_six_combat.tres`（删除）
5. `resources/run/flows/prototype_five_stage_demo.tres`（新增）
6. `resources/run/rooms/combat_01_entry.tres`
7. `scenes/run/run_game.tscn`
8. `scripts/ui/run_overlay_interface.gd`
9. `scripts/run/run_flow_smoke_panel.gd`
10. `scenes/run/run_flow_smoke_panel.tscn`
11. `resources/run/rooms/combat_06_final_boss.tres`

不得修改 `RunChestRewardSnapshot` 公共结构、`scripts/player.gd`、`project.godot` 或 Task 48 文件。

`run_overlay_interface.gd` 仅迁移冻结的正式总数显示，不重构通用路线 UI；正式结算必须为 `4 combat / 1 shop / 0 route`，通用路线面板若保留则战斗总数必须读取当前正式合同或显示 `4`，不得继续硬编码 `/6`。`run_flow_smoke_panel.gd` 仅迁移五阶段标题、计数、结算文案及新正式流不经过路线节点所需的 smoke 推进；`run_flow_smoke_panel.tscn` 仅同步默认标题/静态文案，不得重做场景 UI。不得删除仍可复用的通用路线能力。

`combat_06_final_boss.tres` 仅将玩家可见 `display_name` 的旧“战 6”迁移为正式流程中的“战 4”；内部 `room_id` 保持不变，不改 Boss spawn、生命、防御、位置、模板、标签或奖励。

## 5. 测试与证据 allowlist

1. `growth/tests/run_task49_five_stage_demo_flow_tests.gd`（新增专项）
2. 对应 `.gd.uid`（仅隔离 scan 确实生成时）
3. `growth/tests/run_task32_formal_four_passive_content_tests.gd`
4. `growth/tests/run_task41_physical_flow_waves_boss_tests.gd`
5. `growth/tests/run_task42_reward_economy_tuning_tests.gd`
6. `growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd`
7. `combat/tests/run_task29_real_room_flow_tests.gd`
8. `combat/tests/run_task30_run_ui_tests.gd`
9. `combat/tests/run_task31_full_run_e2e_tests.gd`
10. `growth/tests/run_task29_run_flow_contract_tests.gd`
11. `growth/tests/run_task31_content_balance_tests.gd`
12. `combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd`
13. `combat/tests/capture_task49_five_stage_demo_visuals.gd`（必要时新增）
14. 对应 `.gd.uid`（仅隔离 scan 确实生成时）
15. `docs/agent_tasks/pending/49_five_stage_demo_flow_and_first_room_reward.md`
16. `docs/agent_tasks/evidence/task49/**`
17. `combat/tests/run_task40_drag_compact_hud_tests.gd`
18. `combat/tests/capture_task29_full_run_visual.gd`
19. `combat/tests/capture_task30_run_ui_visuals.gd`
20. `combat/tests/capture_task31_full_run_visuals.gd`
21. `combat/tests/capture_task32_formal_four_passive_visual.gd`
22. `combat/tests/capture_task40_drag_compact_hud_visuals.gd`
23. `combat/tests/capture_task41_physical_flow_visuals.gd`
24. `combat/tests/capture_task42_reward_economy_visuals.gd`

现有测试/capture 仅可更新“旧六战正式流已被五阶段演示流替换”导致的 flow preload、直接流程断言和路径推进，不得顺改其他 Task 29/31/43 行为门禁。Task43 capture 只迁移其 flow 引用与五阶段推进，不改平台跳跃、配装、清场或视觉断言。发现其他直接冻结旧正式流程的 runner/capture 时停线回传补充 allowlist。

Task49 专属 capture 允许在 Boss 截图前仅等待测试清场产生的 `99999` 伤害字消退，确保 Boss 与“战 4”标题可读；不得隐藏生产伤害 UI、改伤害数值、绕过 `CombatReceiver` 或修改正式战斗行为。

新增纳入的 Task29/30/31/32/40/41/42 runner/capture 只允许迁移正式五阶段推进与 `4/1/0` 计数。旧路线阶段、已移出正式流的房间及其专属截图/断言因正式路径不可达可删除或替换为新五阶段对应节点；但各原任务的拖拽、紧凑 HUD、权威恢复、奖励经济、被动配装、物理波次、Boss、结算及分辨率门禁必须保留。不得为了让旧 capture 通过而恢复路线节点、旧六战 flow 或兼容分支。

## 6. 禁止项

除已明确授权删除旧六战 flow 文件外，不删除旧房间/路线素材；不顺带调敌人属性、梦尘经济、商店价格或 Boss 数值；不处理 Task 20/48；不删除、暂存、认领共享未跟踪产物；不连接、关闭或控制共享 Godot/editor/godot-ai；不执行 Git 写操作，不 push，不自行 `ACCEPTED`。

## 7. 专项验收

专项 runner 至少证明：

1. 新流每条路径均为且仅为 `战、战、商、战、Boss、Result`，不存在路线选择，完成战斗数为 `4`。
2. 旧六战 flow 路径已不存在，生产和测试引用均迁移到五阶段 flow；不得留下加载失败引用。
3. 首关实例只有 `2` 个初始敌人、`0` 援军，首批全部击败后立即清场，不等待 12 秒或生成援军。
4. 首关正常奖励池场景必得未拥有主动技能；被动永不入选；command replay 幂等。
5. 主动池耗尽时按冻结降级策略完成宝箱与传送流程，不死锁、不重复授予。
6. 第二战后进入商店，离店进入第三战，第三战后直达 Boss，Boss 后结算。

## 8. L3 Review 门禁

执行者只在全新隔离副本/独立 profile 实现验证并交付 `REVIEW`。中枢在另一全新冷副本按 `REVIEW_L3_PLAYBOOK.md` 运行 editor scan、专项、直接影响域回归、主场景完整五阶段 smoke、单组 `1920x1080` 流程/首关证据和 final scan；正式日志五类标记为零，allowlist、sidecar、manifest 与共享零漂移通过后才能 `ACCEPTED`。

## 9. 中枢范围对齐（2026-08-13）

- 首轮执行前审计发现 `run_task29_run_flow_contract_tests.gd`、`run_task31_content_balance_tests.gd` 与 Task43 capture 直接 preload 将删除的旧 flow，执行者按 §5 正确停线，生产与测试零修改。
- 中枢确认三者均为删除旧 flow 的确定性加载依赖，已精确加入 allowlist；只授权迁移 flow 引用及对应五阶段流程断言。Task 49 恢复 `IN_PROGRESS`，模型保持 `gpt-5.6-sol`、thinking=`high`。

## 10. 中枢第二次范围对齐（2026-08-13）

- 候选专项与 Task49 专属六图 capture 已通过，但视觉 QA 发现正式结算 UI 仍显示路线 `0/2`，正式 smoke 仍显示“六战”及 `6/3/2`；同时八份直接实例化 `run_game.tscn` 的既有 runner/capture 冻结旧路线和旧房间推进。执行者按升级触发正确停线，未擅改 allowlist 外文件。
- 用户此前已明确旧关卡流程可直接删除。中枢决定不保留旧六战/路线兼容路径：精确加入两份活跃 UI 脚本及八份直接消费者，按上述窄迁移口径恢复执行。Review Level 仍为 L3，模型保持 `gpt-5.6-sol`、thinking=`high`。

## 11. 中枢第三次范围对齐（2026-08-13）

- 执行交付后中枢静态扫描发现 `scenes/run/run_flow_smoke_panel.tscn` 仍含默认标题“六战原型”，且已在生产 allowlist 的 `run_overlay_interface.gd` 通用路线面板仍硬编码战斗 `/6`；因此“活跃范围无旧语义残留”的交付声明不成立，首次独立 L3 在动态运行前暂停。
- 中枢精确加入 `scenes/run/run_flow_smoke_panel.tscn`，只授权同步五阶段默认标题/静态文案；同时要求已有 UI 文件清除 `/6` 硬编码但保留通用路线能力。其余范围、L3 等级与 `gpt-5.6-sol` / `high` 不变，Task49 恢复 `IN_PROGRESS`。

## 12. 独立 L3 Review 回填（2026-08-13）

- Review Model：`gpt-5.6-sol`；thinking：`high`；Result：`FAIL`。不得据此标记 `ACCEPTED`。
- Review 从当前接受 HEAD `616867f` 建立此前不存在的 `C:\tmp\element-dungeon-task49-review-20260813-01` 和独立 profile，只覆盖 Task49 最新精确 overlay并删除旧 flow；与基线的 33 项差异全部在 allowlist 内。Task48 `project.godot` / `scripts/player.gd` 与 Task51 `scripts/enemy.gd` 保持 `616867f` blob，冷根未带入共享受保护 `global_instakill`。
- Godot `4.7.1.stable.official.a13da4feb` cold-first scan exit 0；Task49 专项与 10 个直接影响域 runner 合计 `54 tests / 3796 assertions / 0 failures`；当前 `RunGame` 五阶段六图 capture 为 `1 test / 6 images / 0 failures`。已运行 13 份日志的五类标记均为 0。
- 原尺寸目检第 5 张图触发确定性失败：Boss 是正式第 4 场战斗，但玩家可见标题仍为“战 6 · 占位最终 Boss”，来源为当前 allowlist 外 `resources/run/rooms/combat_06_final_boss.tres:20`；同图还有大量 `99999` 伤害文字遮挡 Boss。其余五图分别证明首关 2 敌、立即清场、主动奖励、两战后商店和结算 `4/1/0`。
- 按 L3 确定性失败停线规则，发现后不再运行 Task40/41 代表性 capture 抽样或 final scan；Review 未自行修复或扩大 allowlist。共享 `.godot` 与外部 Godot 进程零漂移；验收窗口出现的 Task52 并发新增均未进入候选。
- 独立证据：`docs/agent_tasks/evidence/task49/review_l3/`。Git 写、暂存、提交、push 均为 0。

## 13. 中枢第四次范围对齐（2026-08-13）

- 独立 L3 在集成候选的第 5 张正式图发现 Boss 房仍显示“战 6 · 占位最终 Boss”，来源为 allowlist 外 `combat_06_final_boss.tres`；同时此前房间由 capture 使用 `99999` 经 `CombatReceiver` 清场产生的伤害字尚未消退，遮挡 Boss。自动 runner、其余五图、Task48/51 集成和日志均已通过。
- 中枢精确加入 Boss 房资源，仅授权玩家可见编号 `6 -> 4`；Task49 capture 已在 allowlist，仅授权截图前等待测试伤害字自然消退。Task49 恢复 `IN_PROGRESS`，其余生产和测试范围不变。修正后先由原执行者最小重验，再由原 L3 Review 对话从 `616867f + Task49 overlay` 重新构建候选复验失败点和未完成门禁。

## 14. 独立 L3 第四次复验回填（2026-08-13）

- Review Model：`gpt-5.6-sol`；thinking：`high`；Result：`PASS`。任务状态保持 `REVIEW`，不得据此自行标记 `ACCEPTED`。
- Review 从当前接受 HEAD `616867f` 新建 `C:\tmp\element-dungeon-task49-review-20260813-02` 与独立 profile，只覆盖最新 Task49 精确 overlay 并删除旧 flow；相对基线 34 个状态差异全部在 allowlist。未复用执行者 formal-02，未消费共享混合工作树或用户保护的 `global_instakill`。
- 相对上次失败候选，运行时仅两处窄修：Boss `display_name` 为“战 4”；Task49 capture 在 Boss 图前仅等待 1 秒。其余 30 个运行时 overlay 文件哈希不变；活跃生产旧语义复扫为 0。
- Godot `4.7.1.stable.official.a13da4feb` cold-first scan exit 0。前轮同等集成候选 11 runners `54 tests / 3796 assertions / 0 failures` 按 L3 规则复用；本轮 Task49、Task30、Task41 新鲜抽查合计 `18/353/0`。
- Task49 当前主流程 capture 为 `1 test / 6 images / 0 failures`；六图逐张原尺寸通过，第 5 图明确为“战 4”且 Boss 无 `99999` 遮挡，第 6 图为 `4/1/0`。Task40 代表性 capture 为 `1/140/7`，Task41 为 10 张 authority-checked 图；主场景 180 帧 smoke 与 final scan 均 exit 0。
- 9 份正式日志五类标记均为 0。冷根 sidecar 771→771；共享 `.godot` 1169→1169、sidecar 3991→3991、status 11939→11939、外部 Godot PID 前后均精确一致。
- Task48 `project.godot` / `scripts/player.gd` 与 Task51 `scripts/enemy.gd` 保持 `616867f` blob。Git 暂存、提交、push 均为 0；独立证据为 `docs/agent_tasks/evidence/task49/review_l3/rerun_02/`。
- 独立 L3 第四次复验最终结论：`PASS`。正式候选从接受 HEAD `616867f` 全新构建并叠加最新 Task49 精确 overlay；复用矩阵 `54 tests / 3796 assertions / 0 failures`，本轮抽查 `18 tests / 353 assertions / 0 failures`。Task49 六图、Task40/41 共 17 张代表性截图、主场景 smoke、cold-first/final scan、日志、manifest、Task48/51 保护和共享零漂移均通过。完整证据见 `docs/agent_tasks/evidence/task49/review_l3/rerun_02/`。

## 15. 中枢接受与归档（2026-08-14）

- 中枢采纳独立 L3 最终 `PASS`，Task49 更新为 `ACCEPTED` 并归档。
- 接受合同为正式五阶段 `战、战、商、战、Boss`，严格 `4 combat / 1 shop / 0 route`；首关 `2` 初始敌人、`0` 援军、清场立即、未拥有主动技能保底及主动池耗尽 `DREAM_DUST=150` 降级均通过。
- 旧六战 flow 已删除，活跃生产范围旧六战语义为 0；Boss 玩家可见标题为“战 4”，六图结算为 `4/4、1/1、0/0`。
- Task48/51 接受内容保持不变；用户独立 `global_instakill`、Task52、中央规则修改和其他共享漂移均不属于 Task49，不暂存、不认领。
