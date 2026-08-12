# 任务 42：普通宝箱概率、梦尘节奏与两条完整局最终调优

状态：ACCEPTED
负责人：Growth / Economy Tuning Agent 2.0（threadId `019ff62b-18e8-7f02-bcb0-9f4e39e2fef2`，hostId `local`）
独立 Review：Review 7.0（threadId `019ff62b-4b52-7ab0-94ce-e1499e6c5099`，hostId `local`）
依赖：Task41 `ACCEPTED`；派发基线 `041928642bda41bdc1adc4b6ed16fa05db2ac17c`
回传中枢：Review 6.0，threadId `019fd7fd-4476-7f73-b121-76760fabf284`，hostId `local`

## 1. 目标与用户冻结决定

这是本批流程工作的最后一项窄调优，不再增加玩法系统。用户已决定：普通宝箱只有“技能 / 大额梦尘”两类；六战只有一间实体商店；当前以求职作品进度为先，避免臃肿防御编程与过度设计。

本任务冻结：

1. 普通宝箱保持稳定 `50%` 未拥有 `reward_pool` 技能 / `50%` `150` 梦尘；技能池为空时必为 `150` 梦尘。
2. Task41 已接受的六战、两路线、一商店、五个普通宝箱、Boss 零奖励结算宝箱、敌群数量/援军时机均不改变。
3. 当前房间梦尘表保持不变：safe 路线五个普通战基础总收入 `595`，risk 路线 `700`；到唯一商店前的基础收入分别为 `345` / `365`。最终余额不要求清零，商店后的奖励可进入结算账本。
4. 商店价格、主动等级价格、`70%` 重置返还、技能效果与七槽均不调；本任务只消除宝箱技能选择偏差并冻结现有经济节奏。

## 2. 唯一生产修正

当前 `RunSession.claim_formal_room_chest()` 用同一个非负稳定哈希同时执行：

```text
stable_hash % 2                    # 奖励类型
stable_hash % candidates.size()    # 技能索引
```

当 `candidates.size()` 为偶数时，进入技能分支的哈希已经固定为偶数，第二个取模只能覆盖部分索引。这不是随机波动，而是确定性选择偏差。

只允许做最小修正：

- 保留当前 `run_id + room_id` 稳定身份、排序后的未拥有候选、50/50 类型分支和事务边界；
- 类型使用最低位，技能索引使用移除该位后的稳定值（例如整数 `stable_hash / 2` 后再 `% candidates.size()`，或严格等价的单文件实现）；
- 相同 run/room/owned 输入仍得到相同结果；不得引入全局 RNG、随机种子服务、权重表、保底、重复保护器、掉落历史、存档迁移或概率框架；
- 不增加无玩家路径使用的容错或防御层。

若冷基线显示仓库已不存在该偏差，冻结并回传中枢，不为制造 diff 改写等价代码。

## 3. 两条固定完整局

继续使用 Task31 已接受的固定 `task31_safe` / `task31_risk` run identity，不挑选新 ID 来迎合结果。技能索引解耦后：

- 两局的梦尘宝箱数量保持由类型位决定，因此 safe 仍为 `300` 宝箱梦尘、risk 仍为 `450`；
- 先在全新冷候选实际取得新的技能顺序、购买/升级/返还/余额，再把结果写成显式强断言；不得动态使用实际结果反推 expected，也不得排序掩盖顺序；
- safe 继续完成 bolt Lv3、一次重置和四被动；risk 继续完成 reclaim/laser Lv2、多主动与四被动；两局都真实经过五次普通宝箱、五次普通门、一次实体商店世界出口、Boss 与结算宝箱；
- 保留 Task41 的 `scene_changed` 新局同步、真实 `move_right + physics_frame + F` 离开商店、权威 revision/七槽/交易/失败新局断言；不得弱化既有强门禁。

## 4. Cohort 调优门禁

新增一个窄领域 runner，直接通过正式 `RunSession`/目录/流程命令验证，不复制生产公式作为假测试：

1. 至少 `512` 个稳定 run identity；同一 cohort 重建两次，逐 run/room 结果完全一致。
2. 对候选池仍非空的首次普通宝箱，技能/梦尘比例各在 `45%～55%`；空池 `100%` 为 150 梦尘。
3. 专门构造恰好四个未拥有 reward 候选；只统计技能分支，四个候选各占 `20%～30%`，不得有候选为 0。该断言必须能在未修正的 Task41 基线上失败，从而真正覆盖偶数候选偏差。
4. 奖励只来自正式 `reward_pool` 且已拥有技能不会再掉；同 run/room 重放、重复领取、陈旧 revision 仍零变化。
5. 精确锁定 `DREAM_DUST_AMOUNT == 150`、safe/risk 房间基础总收入 `595/700`、商店前 `345/365`、Boss 三项奖励 0。

不做统计框架、CSV 驱动配置、蒙特卡洛服务或基准数据库；runner 内固定小 cohort 即可。

## 5. 精确 allowlist

```text
growth/run_session.gd
combat/tests/run_task31_full_run_e2e_tests.gd
combat/tests/run_task40_drag_compact_hud_tests.gd
growth/tests/run_task42_reward_economy_tuning_tests.gd
growth/tests/run_task42_reward_economy_tuning_tests.gd.uid
combat/tests/capture_task42_reward_economy_visuals.gd
combat/tests/capture_task42_reward_economy_visuals.gd.uid
docs/design/元素地牢_局内构筑与关卡流程实现契约.md
docs/design/元素地牢_局内构筑与成长机制变更需求.md
docs/current_gameplay_design_handoff.md
docs/agent_tasks/pending/42_reward_economy_two_run_tuning.md
docs/agent_tasks/evidence/task42/**
```

两个新 GDScript 的 `.gd.uid` 只能由本任务此前不存在的冷副本与独立 Godot 4.7.1 profile 的首次 editor scan 生成，再逐项复制回共享；不得手写、使用共享 Godot 生成或认领其他 sidecar。若现有 runner 可完整承担视觉证据而无需新 capture，先由 Review 明确收窄，不得留下无用途新脚本。

以下是强只读依赖，不在 allowlist：`RunChestRewardSnapshot` 的 150 常量、七个普通房和 Boss `.tres`、全部技能 content/价格、Task41 runner/capture/evidence、Task39 资产/import。若其中任何值与本任务冻结口径不一致，先阻塞回传中枢，不得自行扩权。

## 6. 旧 runner 与文档边界

- `run_task31_full_run_e2e_tests.gd` 只迁移因技能索引解耦直接变化的 safe/risk 技能顺序、对应购买账本与强断言；不得改路线、房间、敌群、真实商店出口、失败/新局、七槽、等级或 authority 断言。
- `run_task40_drag_compact_hud_tests.gd` 只迁移固定 `task40_drag_flow` 因新索引确定性获得 `element_reclaim` 而直接失效的购买前置：必须字面断言进入商店时已拥有 reclaim、`purchase:element_reclaim` 不存在、钱包/购买账本/revision 未发生购买变化，然后继续原卡片装配、槽位交换、点击替代、HUD、失败恢复与单次 authority commit 全部门禁。不得使用“已拥有/未拥有”动态分支，也不得修改 run identity 或降低 Task40 其他断言。
- 其余既有正式 runner 源码零修改；尤其 Task41、Task38 与历史 Task20 runner 保持 HEAD blob。
- 三份现行设计文档只把 Task42 “尚未完成”更新为最终 50/50、150、房间基础总额、选择位解耦和两局固定事实；不宣称做过敌人伤害/生命、房间美术、长期 meta 或完整商业平衡。

## 7. 验证与 evidence

1. 固定 HEAD `041928642bda41bdc1adc4b6ed16fa05db2ac17c` + 本任务精确 overlay，在此前不存在的 `C:\tmp` 冷副本/独立 profile 验证；第一条 Godot 命令严格为 4.7.1 headless editor scan。
2. 新 Task42 cohort runner 直接运行至少两次；Task31 E2E 以三个独立进程运行，三次 safe/risk 奖励顺序和全部经济字段一致。
3. 复跑当前正式 `32` 个接受 runner + Task42 新 runner，预期 `33/33`，精确报告 tests/assertions；Task20 继续单列 `7/68`，永不追认。
4. RunGame/TestRoom 各 180 帧；非 headless capture 后 final rescan。所有成功正式日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。
5. 只需 `4～6` 张新截图：safe 商店交易前/后、safe Results 精确账本、risk Results 精确账本，并至少覆盖 1920×1080 与 2560×1440。Task41 的房间/门/Boss 11 图与 Task40 分辨率矩阵不重拍。
6. 保存截图前必须断言当前 run identity、phase、shop session/revision、余额/收支、技能顺序、等级和七槽；逐张原尺寸 QA。Evidence 只复制 README、正式日志、CSV 与最终 PNG，冷副本 `.import/.translation` 不回流。
7. 固定对账共享 `.godot`、全部既有 sidecar、Task41/Task39 依赖与两份未跟踪中文保护文档；执行者不读取保护文档内容、不修改/删除/认领/暂存。

## 8. 禁止与非目标

- 不改 50/50、150、房间梦尘、技能价格/等级、70% 返还、商店位置、敌人数量/伤害/生命、Boss、UI 或场景。
- 不增加 RNG 服务、概率资源、保底/权重/掉落历史、对象池、事件总线、遥测、存档/联机/热重载兼容层。
- 不把完整两局改成只算公式；不以测试专用终局方法、直接离店事务或坐标瞬移绕过正式路径。
- 不控制共享 Godot/editor/godot-ai，不在共享项目运行 scan/runner/smoke/capture；不使用子 Agent，不做 Git 写操作。

## 9. 状态、交付与自动回传

开工置 `IN_PROGRESS`。全部门禁完成后只置 `REVIEW` 并冻结；若需扩权或冻结值不自洽则置 `BLOCKED` 或保持 `IN_PROGRESS` 并立即回传。交付必须列出修改文件、最终 safe/risk 精确奖励与账本、cohort 实际分布、runner totals、冷根/profile、截图、日志标记、UID/sidecar/缓存/保护对账以及 Git 写操作为 0。

完成或阻塞后必须直接调用 `send_message_to_thread` 回传中枢 `019fd7fd-4476-7f73-b121-76760fabf284`（hostId `local`），不得等待用户转述，不得自行 `ACCEPTED`。

## 10. 协调记录（2026-08-12）

- 旧玩法执行对话连续承载 Task38、Task41 与三轮返工并发生上下文压缩；旧独立 Review 跨 Task38～41 且发生压缩。Task42 触碰经济口径和两局强断言，二者均按 `RED / 禁止复用` 处置。
- 新建 Growth / Economy Tuning Agent 2.0 与 Review 7.0，直接使用共享保存项目；模型和推理档位采用用户默认，不机械设置极高。新任务书自包含用户决定、固定 HEAD、权威边界、allowlist、门禁和回传目标。
- Review 7.0 阶段一只读审计 `PASS`：固定 HEAD 的偶数候选偏差成立，`stable_hash / 2` 后取模是最小正确修复；512 cohort、50/50 与四候选区间、33/33 正式入口、两枚 UID、4～6 图和 allowlist 均可执行，无需扩到 `project.godot` 或其他旧 runner。实现 Review 必须确认 cohort 两遍均新建正式 `RunSession` 并走正式命令，Task31 的新技能顺序与 purchases/upgrades/refund/balance 使用固定字面强断言；旧 `_expected_purchase_spend(...)` 不得继续承担 expected 验收。

## 11. 执行阻塞记录（2026-08-12）

- 固定 HEAD + Task42 最小生产修正使固定 `task40_drag_flow` 在唯一商店前已通过普通宝箱拥有 `element_reclaim`；正确商店 UI 因此不再创建 `purchase:element_reclaim` 控件。Task40 已接受 runner 的 `_test_formal_slot_swap_single_commit()` 却固定要求该购买按钮存在并直接触发 `pressed`，导致 Nil `SCRIPT ERROR`。
- 该失败在最终冷根的 formal33 第 31 项以及此前不存在的独立确认 profile 中稳定复现；前 30 个正式入口均通过。它不是 profile 污染、共享 editor 漂移或 Task31 时序问题。
- Task42 §6/§8 同时要求 Task40 runner 保持 HEAD blob 且 formal `33/33`。生产不能为单个历史 runner 特判 run ID、候选顺序或已拥有技能；因此两项门禁不可同时满足。执行者未修改 Task40，也未继续 capture、smoke、final rescan 或文档完成态更新，冻结等待中枢决定是否授权把 Task40 runner 加入返工 allowlist，令其兼容“宝箱已拥有则直接进入装配/交换”而不弱化其 HUD/authority 合同。
- 已完成且冻结的部分事实：新生产 cohort 两遍均为 `256/256`，四候选技能分布 `65/65/64/62`；旧 HEAD 同 runner 预期失败为 `129/0/127/0`；Task31 三独立进程均 `4 tests / 559 assertions`，safe 为 `300 + elemental_laser|elemental_fury|element_reclaim + 895/300/300/105/400`，risk 为 `450 + elemental_laser|elemental_fury + 1150/390/115/0/645`。两枚 UID 均来自首次全新冷 scan，未使用共享 Godot 生成。
- 中枢裁决：该 runner 是最小生产修正直接影响的固定身份回归，授权将 `combat/tests/run_task40_drag_compact_hud_tests.gd` 加入窄 allowlist。迁移必须锁定当前确定性拥有结果并证明购买控件缺席及零购买副作用，不得采用动态兼容分支。任务恢复 `IN_PROGRESS`，可在原最终冷根叠加该既有 runner 迁移后继续 formal33、Task20、双 smoke、capture、final rescan 与完整 evidence；无需重建 UID 或改动其他文件。

## 12. 执行完成记录（2026-08-12）

- 生产修正仅在 `growth/run_session.gd` 将技能索引改为 `(stable_hash / 2) % candidates.size()`；50/50 类型位、150 梦尘、排序候选、正式事务与全部 Task41 流程不变。Task42 cohort 两遍均为技能/梦尘 `256/256`，四候选按字面顺序为 `element_reclaim=65 / elemental_fury=65 / elemental_laser=64 / unending=62`；固定旧 HEAD 同 runner 按预期失败为 `129/0/127/0`。
- Task31 三个独立进程均为 `4 tests / 559 assertions`。`task31_safe` 固定为宝箱梦尘 `300`、技能顺序 `elemental_laser|elemental_fury|element_reclaim`、`earned/purchases/upgrades/refund/balance = 895/300/300/105/400`；`task31_risk` 固定为 `450`、`elemental_laser|elemental_fury`、`1150/390/115/0/645`。原 `scene_changed`、真实 `move_right + physics_frame + F`、等级、七槽、失败新局与 authority 门禁保留。
- 经中枢授权的 Task40 窄迁移字面锁定 `task40_drag_flow` 入店前已拥有 `element_reclaim`、不存在 `purchase:element_reclaim`，且钱包、购买账本、revision 无购买变化；其后原装配、交换、点击、HUD、拒绝恢复和单次 authority commit 门禁继续执行，单列结果 `4 tests / 113 assertions`。
- 从头重生的成功正式批次为 `33/33`，合计 `315 tests / 6790 assertions`；旧中断 formal 批次没有混入成功集合。Task20 单列 `7/68`，不追认；RunGame/TestRoom 各 180 帧通过；final 4.7.1 editor rescan 通过。成功集合 45 份日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全部为 0。
- 非 headless capture 生成并原尺寸 QA 四张新图：safe 商店前/后两张 `1920x1080`，safe/risk Results 两张 `2560x1440`；保存前均通过 run identity、phase、shop session/revision、经济、技能顺序、等级、七槽和 authority 断言。
- 最终冷根为 `C:\tmp\element-dungeon-task42-final-20260812-01`，独立 profile 为 `C:\tmp\element-dungeon-task42-profile-20260812-01`。两枚 UID 均由首次全新冷 scan 生成并 UID-first 回流：runner `uid://d2hft1c3d3qe3`、capture `uid://d0bale15eq5sj`；共享 editor 未改写。
- 共享保护对账：既有 `.uid/.import` 仍为 `658 files / 328030 bytes`，另有两枚 Task42 UID；622 个 tracked sidecar diff 为 0，Task41 runner/capture/tracked evidence diff 为 0，Task39 五 PNG/五 import `10/10` 哈希一致，两份中文保护文档仅做哈希核对且不变，中枢 README 保持外部所有权。被动共享 editor 令 `.godot` 从 `1110/45800979` 漂到 `1111/45801258`，并维持外部未跟踪 `36 .import + 50 .translation`；仅记录，未控制、删除、复制、认领或暂存。Git 写操作为 0。
- 正式 evidence 只含 README、成功日志、结构化 CSV、四张 PNG，以及单独隔离的旧 HEAD 分布门禁预期失败日志；不含冷根 `.import/.translation`、旧中断 formal 批次或 Task40 blocker 日志。任务状态置 `REVIEW`，等待独立 Review 7.0；不得自行 `ACCEPTED`。

## 13. 中枢独立验收与接受（2026-08-12）

- Review 7.0 从固定 HEAD `041928642bda41bdc1adc4b6ed16fa05db2ac17c` 的 Git 对象与 Task42 当前精确 overlay 构建此前不存在的 `C:\tmp\element-dungeon-task42-review7-20260812-01\project` 和独立 profile；另建 `...review7-headbias...` 固定旧实现辨识候选。未复用执行根、执行日志或执行截图，候选 live README 为固定 HEAD blob，两份中文保护文档与共享外部 sidecar 均未进入。
- 源差异与 allowlist 精确一致：唯一生产变化是 `growth/run_session.gd` 的一行索引位解耦；Task31 删除动态 expected helper 并保留完整局强门禁；Task40 仅做中枢授权的固定身份窄迁移。两个 Task42 UID 全局各唯一一次，622 个 tracked sidecar、Task41 runner/capture/tracked evidence 与 Task39 五 PNG/五 import 全部零漂移。
- 独立 cohort 两遍均为 `3/2210`：512 个正式身份精确 `256 skill / 256 dust`，四候选为 `65/65/64/62`。固定 HEAD + 完全相同 runner 独立候选稳定为 `129/0/127/0`、6 项断言失败，证明 runner 能杀死旧偏差而不是复制生产公式自证。
- Task31 三个独立进程均为 `4/559`，safe/risk 奖励顺序和 `895/300/300/105/400`、`1150/390/115/0/645` 账本逐字段一致；Task40 单列为 `4/113`。正式全量 `33/33 = 315 tests / 6790 assertions`；Task20 历史 runner 单列 `7/68` 且不追认；双 180 帧 smoke、capture 与 final rescan 均通过。
- 本轮 45 份成功正式日志五类标记全部为 0。Review 首次 Task20 包装命令错误未形成候选测试结论，之后以正确参数重跑通过；该 harness 记录只留 Review 根，不属于共享 evidence，也未改候选源。
- Review 从自身候选重新生成四图并逐张原尺寸复核：safe 商店前后清楚显示余额 `495→0` 与购买/升级/返还 `300/300/105`；safe/risk Results 精确显示 `895/300/300/105/400` 与 `1150/390/115/0/645`，七槽、等级、路线和按钮无裁切。
- 共享 Task42 evidence 精确为 64 files = 1 MD + 13 CSV + 46 logs + 4 PNG，`.import/.translation` 为 0，未混入中断 formal 或 blocker 日志。共享 `.godot`、外部 36 import + 50 translation、两份保护文档和共享 Godot/editor 进程均只读保持，未认领。
- 中枢结论：Task42 `ACCEPTED`。概率与梦尘调优阶段闭合；后续自动装配、清场配置、尸体/宝箱与平台可达性使用 Task43，不重开本任务。
