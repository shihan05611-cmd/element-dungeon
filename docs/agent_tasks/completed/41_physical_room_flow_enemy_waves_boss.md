# 任务 41：实体宝箱/传送门流程、单商店房、敌群援军与简化 Boss

状态：ACCEPTED
负责人：Run Flow / Scene Integration Agent（threadId `019ff4cd-81c3-75a2-8cf0-2b68ea066497`，hostId `local`）
依赖：Task38/39/40 `ACCEPTED`；派发基线 `87dceba3167365665cc726777a6fca78d7ae7d8e`
回传中枢：Review 6.0，threadId `019fd7fd-4476-7f73-b121-76760fabf284`，hostId `local`

## 1. 目标与冻结流程

把正式 `RunGame` 从“杀完立即翻页/离店按钮推进”改成玩家可在世界中实际完成的一局：

```text
Combat1 -> 普通宝箱 -> 传送门 -> Route1
        -> Combat2 -> 普通宝箱 -> 传送门
        -> Combat3 -> 普通宝箱 -> 传送门
        -> 实体 Shop -> 商店出口传送门
        -> Combat4 -> 普通宝箱 -> 传送门 -> Route2
        -> Combat5 -> 普通宝箱 -> 传送门
        -> Boss -> 结算宝箱 -> Results
```

- 一局仍恰好六战、两次路线选择；六战中只保留一个正式商店，固定在战 3 后。
- 战 1～5 清场后只弹出普通宝箱；宝箱交互完成后才解锁传送门；只有传送门交互才完成本房并推进路线、商店或下一战。
- Boss 清场后弹出结算宝箱；交互不发技能/梦尘，直接提交 Boss 房完成并进入既有结算。Boss 后没有传送门、路线或商店。
- `Chest`/`Portal` 不新增为 `RunPhase` 或节点种类；它们是现有 COMBAT 房间完成命令之前的实体门禁。禁止为本任务扩张整套状态机。

## 2. 普通宝箱权威合同

1. 普通宝箱每房恰好领取一次，结果只有两种：
   - 未拥有的正式 `reward_pool` 技能一项；
   - 大额梦尘 `150`。
2. 首版概率固定 `50% / 50%`。按稳定 `run_id + room_id`（或等价稳定房间身份）确定，不使用每帧随机；未拥有技能池为空时必须回退为 `150` 梦尘。
3. 技能加入既有 `SkillInventoryState`，使用现有合法 acquisition kind（可用 `SCRIPTED`）；梦尘只通过既有 `RunEconomyState.commit_earned`。UI/场景不得直接改拥有库、钱包或 revision。
4. 在 `RunSession` 增加一个窄的正式宝箱命令：校验 formal flow、COMBAT、当前 room、expected revision、command id 重放与每房只领一次；接受时原子提交一个结果并只增加一次 run revision。返回值必须包含类型化奖励快照，禁止任意 `Dictionary` payload。
5. 活动房 `room_cleared` 与交互距离由 `RunFlowCoordinator`/`RunRoomInstance` 门禁；未清场、宝箱未领取、错误房间实例、陈旧 revision、重复交互均不得推进房间或重复发奖。
6. Task31 已冻结的各房“击杀梦尘 + 完成梦尘”总额在 Task41 不调优：新增敌人之间重新分配或将新增实例奖励设为 0，使每个既有普通房的原有基础总额保持不变；宝箱 `150` 是本轮新增的临时大奖。精确概率、梦尘与敌人数值留给 Task42。

## 3. 世界交互与实体门禁

- `project.godot` 新增单一 `interact` action，正式键位为 `F`；Player 只发出窄的 `interact_requested` 信号，不建立全局交互管理器。
- 允许一个小型类型化 `RunWorldInteractable` 同时服务宝箱与传送门：持有种类、启用/锁定、提示与交互距离，不拥有 RunSession、奖励或流程权威。
- 使用 Task39 已接受资产，严格只读消费：
  - `assets/generated/vfx/run_reward_chest/chest_closed.png`
  - `assets/generated/vfx/run_reward_chest/chest_open.png`
  - `assets/generated/vfx/run_route_portal/portal.png`
- 清场时显示关闭宝箱与锁定/隐藏的门；宝箱成功后切开箱图并明确显示技能名或 `+150 梦尘`，同时解锁门。重复按 F 不再发奖。
- 门只在玩家进入清晰交互范围并按 F 时推进；不得靠接触自动切房。提示至少明确 `F`、对象和当前锁定原因。
- 正式房完成只允许通过 Host 的窄公共方法提交；`RunSessionHost._on_enemy_defeated` 在 formal flow 中不得再自动 `_complete_room()`，legacy 流程保持原行为。

## 4. 单个实体商店房

- 正式节点图改为：`C1 -> Route1 -> C2 -> C3 -> Shop -> C4 -> Route2 -> C5 -> Boss -> Result`。两条路线分支继续指向真实 C2/C5 房资源。
- 商店固定在战 3 后，使用新的 `room_shop_formal.tscn`；用场景/程序几何做明显安全房、标题、玩家出生点和出口区域即可，不细化美术。
- 进入 SHOP phase 时必须真实替换上一战的活动房并把同一 Player 移到商店出生点；既有购买、升级、70% 重置、拖拽/点击配装、键盘焦点与权威快照全部复用。
- 正式 RunGame 中不得通过商店 UI 的“离开商店”按钮绕过世界门。将该按钮隐藏/禁用并用短文案提示“前往出口传送门，按 F 继续”；领域层 `leave_formal_shop` 和测试夹具接口继续保留。
- 商店出口传送门交互只调用一次既有 `RunFlowCoordinator.leave_shop -> RunSession.leave_formal_shop`；成功后进入 C4 的 `ROOM_LOADING`。拒绝时保持商店、钱包、配装与 revision 的权威快照。
- 任一时刻最多一个活动 combat/shop room。商店不生成敌人、宝箱或战斗奖励。

## 5. 普通房敌群与单次援军

1. 战 1～5 的每个可能房配置都必须满足：首波 `3～5` 个；援军 `2～3` 个；只生成一轮援军。Boss 房例外，保持一名 Boss、无援军。
2. `CombatRoomDefinition` 增加最小字段即可：既有 `enemy_spawns` 作为首波，新增 `reinforcement_spawns` 与暂定 `reinforcement_delay_seconds = 12.0`。不得引入刷怪导演、波次 DSL、对象池、NavMesh 或难度缩放框架。
3. 推荐在 `RunRoomInstance.configure` 时把援军预实例化为休眠对象，避免新增 Host/VFX 动态注册协议。休眠援军在激活前必须不可见、无 AI/physics processing、无实体碰撞、不可被 targeting/hurtbox 命中且 `CombatReceiver` 不接受 hit；Host/VFX 可预先绑定完整敌人集合。
4. 以下任一条件先到即激活援军，且只能激活一次：
   - 首波全部死亡：下一处理时机立即激活，不等待剩余计时；
   - 房间激活后满 `12.0` 秒。
5. 只有首波和援军都已激活/击败后才发一次 `room_cleared`。首波杀完不得直接弹宝箱；计时与首波死亡同帧不得生成/激活两次。
6. 房间 deactivate/queue_free 后计时不再触发；新房使用自己的局部计时。不要为不支持的存档中途恢复、网络同步或热重载增加防御层。

## 6. 简化 Boss

- 复用现有 `scenes/enemy.tscn` 和动画；Boss 运行时视觉放大约 `1.6～1.8x`，有清楚的紫色外描边/紫色轮廓层。不得接新人物立绘或制作新 Boss 角色资产。
- 只增加一种低空、慢速、可用普通跳跃躲过的横向远程弹体；近战行为可保留。建议间隔 `1.6～2.2s`、伤害约 `7～9`，不追踪玩家垂直位置，不做多阶段、弹幕树或复杂预判。
- 新 `boss_arc_projectile.tscn` 直接复用既有 `ProjectileDelivery`/CombatReceiver 权威命中链，并显示 Task39 已接受的 `assets/generated/vfx/boss_arc_projectile/projectile.png`。不得在 Boss 脚本直接扣 Player HP。
- 弹体面对左右方向正确、被墙阻挡/命中一次即结束；站立路径会受击，正常跳跃轨迹可以越过。Boss 死亡后不再发射，残留投射物在房间完成/切换时清理。
- Boss 继续击杀梦尘 0、完成梦尘 0；只有结算宝箱交互能进入结果。

## 7. 设计文档同步

本任务是用户明确的新正式合同，需同步三份现行设计文档：

- `元素地牢_局内构筑与关卡流程实现契约.md` 的当前权威摘要、节点表、状态图、房间运行时、商店数量、奖励与终局口径；历史 Task29/31 验收记录可保留，但必须标成历史，不能继续与当前合同并列冻结。
- `元素地牢_局内构筑与成长机制变更需求.md` 中“普通房不发免费技能/最终 Boss 直结算”的旧口径：改为战 1～5 的实体普通宝箱可出未拥有技能或大额梦尘，Boss 仍是零局内奖励的结算宝箱。
- `current_gameplay_design_handoff.md` 增加 Task41 当前六战、一商店、宝箱/传送门和敌群/Boss事实；不得声称 Task42 调优已经完成。

## 8. 精确 allowlist

```text
project.godot
growth/contracts/run_chest_reward_snapshot.gd
growth/contracts/run_chest_reward_snapshot.gd.uid
growth/contracts/run_command_result.gd
growth/flow/combat_room_definition.gd
growth/flow/run_flow_definition.gd
growth/run_session.gd
scripts/player.gd
scripts/enemy.gd
scripts/run_session_host.gd
scripts/run/run_room_instance.gd
scripts/run/run_flow_coordinator.gd
scripts/run/run_world_interactable.gd
scripts/run/run_world_interactable.gd.uid
scripts/run/run_shop_room_instance.gd
scripts/run/run_shop_room_instance.gd.uid
scripts/ui/run_overlay_interface.gd
scenes/run/run_game.tscn
scenes/run/interactables/run_reward_chest.tscn
scenes/run/interactables/run_route_portal.tscn
scenes/run/rooms/room_shop_formal.tscn
scenes/run/boss_arc_projectile.tscn
resources/run/flows/prototype_two_layer_six_combat.tres
resources/run/rooms/combat_01_entry.tres
resources/run/rooms/combat_02_swarm.tres
resources/run/rooms/combat_02_pressure.tres
resources/run/rooms/combat_03_layer_elite.tres
resources/run/rooms/combat_04_validation.tres
resources/run/rooms/combat_05_stable.tres
resources/run/rooms/combat_05_risk.tres
resources/run/rooms/combat_06_final_boss.tres
growth/tests/run_task29_run_flow_contract_tests.gd
growth/tests/run_task31_content_balance_tests.gd
growth/tests/run_task32_formal_four_passive_content_tests.gd
combat/tests/run_task29_real_room_flow_tests.gd
combat/tests/run_task30_run_ui_tests.gd
combat/tests/run_task31_full_run_e2e_tests.gd
combat/tests/run_task40_drag_compact_hud_tests.gd
growth/tests/run_task41_physical_flow_waves_boss_tests.gd
growth/tests/run_task41_physical_flow_waves_boss_tests.gd.uid
combat/tests/capture_task41_physical_flow_visuals.gd
combat/tests/capture_task41_physical_flow_visuals.gd.uid
docs/design/元素地牢_局内构筑与关卡流程实现契约.md
docs/design/元素地牢_局内构筑与成长机制变更需求.md
docs/current_gameplay_design_handoff.md
docs/agent_tasks/pending/41_physical_room_flow_enemy_waves_boss.md
docs/agent_tasks/evidence/task41/**
```

五个新 GDScript 的 `.gd.uid` 只能由本任务此前不存在的冷副本和独立 Godot 4.7.1 profile 的首次 editor scan 生成，再按上述精确路径逐个复制回共享交付；不得手写、使用共享 Godot 生成或认领其他 sidecar。新场景只消费 Task39 已接受 PNG/import，五个既有 asset import 必须逐项哈希不变；本任务不得新增或修改任何 `.png.import`。

若实现确实需要上述列表外的生产文件，先冻结并回传中枢扩权；不得先写后报。历史 capture 源与历史 evidence 不要求迁移，不得为追求旧截图脚本继续可运行而扩大范围。

## 9. 旧 runner 迁移边界

- 只迁移被新流程直接击中的断言：三商店→一商店、杀敌自动完成→宝箱/门、战 3 实体商店、首/援军计数、Boss 结算宝箱、UI 离店按钮改为世界门。
- 现有经济、购买/升级/重置、七槽、Task38/40、失败结算、新局、场景唯一性和历史保护断言不得放宽或删除；需要通过新路径满足。
- Task20 继续单列历史 `BLOCKED`；即使新流程下 `7/68` 通过也绝不追认。
- 不改旧 capture/evidence，不以修改断言规避真实 F 交互、两波敌人或实际房间替换。

## 10. 验证门禁

1. 在此前不存在的 `C:\tmp` 冷副本与独立 profile 验证；候选由固定 HEAD `87dceba3167365665cc726777a6fca78d7ae7d8e` + Task41 精确冻结叠加构建，第一条 Godot 命令严格为 4.7.1 headless editor scan。
2. Task41 专项至少覆盖：
   - 唯一节点图为六战/两路线/一商店，两个分支均真实到达；
   - 首波 3～5、援军 2～3、首波早死立即激活、12 秒激活、竞态只一次、两波全灭才 clear；休眠敌人不可见/不可碰撞/不可命中；
   - 战 1～5 杀敌后不完成、宝箱一次发 skill 或 150 dust、技能池空回退 dust、重复/陈旧命令零变化、宝箱后门才解锁、门按 F 才完成；
   - 实体商店替换战 3，UI 不能直接离店，出口门只调用一次既有离店事务，购买/升级/重置/拖拽/点击仍可；
   - Boss 1.6～1.8x + 紫轮廓、低空弹体走既有 Delivery、站立命中/跳跃躲避/墙阻挡/死亡停发；Boss 零奖励，结算宝箱一次进入结果；
   - safe/risk 两条完整局均不调用测试专用终局跳转，实际经过五次普通宝箱、五次普通门、一次实体商店门、一只 Boss 和一个结算宝箱。
3. 复跑全部当前正式 `31` 个接受 runner + Task41 新 runner，预期入口数 `32/32`，精确报告 tests/assertions；Task38、Task40 专项继续通过。Task20 单列 `7/68`。
4. `RunGame`、`TestRoom` 各 `--quit-after 180`；非 headless capture 后 final rescan。所有成功正式日志对 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 五类标记均为 0。
5. 非 headless 真实 RunGame 生成 `10～12` 张正式证据即可，保存前先断言对应 authority/phase/room instance/revision/敌人数/奖励：
   - 首波与援军；关闭/打开宝箱；门解锁与按门后路线；实体商店与出口门；
   - Boss 放大紫轮廓、低空弹体可跳路径、结算宝箱、最终 Results。
   - 至少覆盖 `1920×1080`、`2560×1440`，并对 `1366×768` 的 F 提示/商店出口做边界检查；Task40 已接受的 16:10/4K/超宽矩阵无需本任务重做多图，只做程序化不越界复核即可。
6. 截图逐张原尺寸 QA；宝箱/门不得显示完整绿色背景或错误纹理，Boss 描边和弹体在暗场可辨。Evidence 目录只复制正式 README、日志、CSV 与最终 PNG；冷副本生成的 evidence `.import`/`.translation` 不回流共享。

## 11. 非目标与禁止

- 不做房间美术细化、程序化地图生成器、新敌人种类/动画、复杂 Boss、多阶段、掉落物物理、随机词条或长期平衡系统。
- 不做通用事件总线、服务定位器、Interaction Manager、Wave Director、Loot DSL、对象池、存档迁移、联机同步或未被当前玩家路径使用的容错层。
- 不改变元素反应、SP、技能伤害/冷却、Task38 回收/元素回响、Task40 拖拽/HUD 合同；不修改 Task39 PNG/prompt/manifest/import。
- 不控制共享 Godot/editor/godot-ai，不在共享项目运行 scan/runner/smoke/capture；不使用子 Agent，不做 Git 写操作。

## 12. 保护、状态与自动回传

开工前固化 HEAD/status、allowlist SHA、共享 `.godot`/sidecar/进程与两个未跟踪中文保护文档。二者不修改、删除、认领或暂存；所有来源外变化原样保留。

开工置 `IN_PROGRESS`；完成全部门禁只置 `REVIEW` 并冻结，阻塞置 `BLOCKED`。完成或阻塞后必须直接 `send_message_to_thread` 回传中枢 `019fd7fd-4476-7f73-b121-76760fabf284`（hostId `local`），不得等待用户转述，不得自行 `ACCEPTED`。

## 13. 执行记录（2026-08-12）

- 固定基线保持 `87dceba3167365665cc726777a6fca78d7ae7d8e`。开工只读记录：共享 `.godot` 990 files / 42,684,249 bytes；sidecar 617 files / 291,063 bytes；共享 Godot/godot-ai 进程 0；两份中文保护文档 SHA-256 分别为 `CB104DDA391DE0F3933AE97A55560AE182F7AEA45306E00E1CD6F4F768D69037`、`3745D2725AC0F484CFE447196D387F5D5E888A59BFC0F75A052DEBF6A8A55870`。中枢 `docs/agent_tasks/README.md` 外部变更未触碰/认领。
- 最终候选使用此前不存在的 `C:\tmp\element-dungeon-task41-final-20260812-03` 与独立 profile `C:\tmp\element-dungeon-task41-final-profile-20260812-03`；由固定 HEAD 只读 archive + Task41 精确 allowlist 构建，冷候选 README 为 HEAD blob（SHA-256 `38DCBB2C23981E67E95846811B0FB657A2558B6AEA8C265BE2C25E33D93A204B`）。第一条 Godot 命令为 4.7.1 headless editor scan。
- 完成六战/两路线/单实体商店物理流程；战 1～5 的两波清场、typed skill/150 梦尘宝箱与门门禁；Boss 1.7 倍紫轮廓、既有 `ProjectileDelivery` 低空慢弹及零奖励结算宝箱。实现/迁移/设计文档共 43 个文件，另有本 taskbook 与 63 个 evidence 文件，均在 §8 allowlist 内。
- 五个新 `.gd.uid` 均来自本任务最初全新冷副本/profile 的首次 scan，SHA-256：`25B093885EF93BDAB13DFE74C432870EDA5449B29941EA36699D8B85C415A59B`、`FE249A3ECE53273709D30862F7ABAD4AECF55A3242A9767F9163533567D2B309`、`8A751FBE8B0438BED1EA2B3A1D3F786613A98FA6EF360F70ECD43D183B3E99B4`、`72DAA3AC71490180DA962DF7826B855036853738602D412F25FC066DDCFD5D5C`、`E3331BE5D69E4E5D91B3D73321CC9D29548D0159062306D57ECD09E925B27FF3`。共享 sidecar 最终为 622 files / 291,163 bytes，精确增加上述五个 20-byte UID；Task39 五 PNG/五 import 10/10 哈希零漂移。
- 最终门禁：正式 32/32 runner，312 tests / 4531 assertions；8 个直接受影响 runner 为 42/1736；Task20 单列 7/68；RunGame/TestRoom 双 180 帧 exit 0；11 张非 headless authority-checked PNG 覆盖 1920×1080、1366×768、2560×1440；final rescan exit 0；46 个正式日志五类标记均为 0。
- 最终只读对账：共享 `.godot` 仍为 990 files / 42,684,249 bytes；Task41 evidence 为 README + 46 logs + 5 CSV + 11 PNG = 63 files，`.import/.translation` 均为 0；保护文档哈希不变；共享 README SHA-256 为 `21930CF16C409B1F9779D9C6257243CDB6266D70F8C00745B81F99FA151C9DA5` 且保持外部所有权；Godot/godot-ai 进程 0。曾发现的两个早期 Task41 冷副本 runner 残留进程已按精确冷根命令行确认并只清理自身 PID，未控制共享 editor/Godot。
- 完整 provenance、逐项日志、精确 CSV 与原尺寸 QA 位于 `docs/agent_tasks/evidence/task41/`。任务按要求停在 `REVIEW`，等待中枢独立验收，不自行 `ACCEPTED`。

## 14. 独立验收 FAIL 后唯一时序返工（2026-08-12）

- 独立验收发现旧 evidence 的 Task31 E2E 在 direct/formal 间可因 `reload_current_scene` 时序取得不同 time-based run ID；旧 current-final evidence 因此整体作废，不再作为验收依据。本轮严守返工 allowlist，仅修改 `combat/tests/run_task31_full_run_e2e_tests.gd`、本 taskbook 与 `evidence/task41/**`；生产代码、资源、场景、设计文档与其他 runner 均未修改。
- complete→failure 与 failure→risk 两处边界均改为等待 `SceneTree.scene_changed`；确认 `current_scene` 是不同 instance 的新 `RunFlowCoordinator` 后，在其 deferred `_bootstrap_run` 之前写入稳定 `run_id_override`。新增两处新 Coordinator identity、failure/risk 实际 snapshot run ID 精确相等断言；不引入 arbitrary frame/time wait、生产测试钩子或全局静态状态。
- risk 路径固定 run ID 为 `task31_risk`，五个普通宝箱结果稳定为 `450` 梦尘 + `element_reclaim` / `elemental_fury`；仍通过正式商店购买 `elemental_laser` 并升级到 Lv2。精确风险账本为 earned `1150`、purchases `420`、upgrades `115`、balance `615`。safe 固定 run ID 为 `task31_safe`，宝箱结果稳定为 `300` 梦尘 + `element_reclaim` / `burning` / `elemental_fury`，账本 `895/225/300/475`。
- 最终 runner SHA-256 为 `0A369DF1C5D08C9067B070FEC6A1718A78883641747E6C7A15ECD545EC94816C`。此前不存在的返工冷根为 `C:\tmp\element-dungeon-task41-rework-20260812-04`，独立 profile 为 `C:\tmp\element-dungeon-task41-rework-profile-20260812-04`；固定 HEAD 与 README HEAD blob 不变，第一条 Godot 命令仍为 4.7.1 headless editor scan。
- 同一 Task31 E2E 以三个独立 Godot 进程连续运行三次，均为 4 tests / 537 assertions、exit 0；三次 safe/risk chest metrics 与精确经济完全一致，见 `logs/repeatability/summary.csv`。之后 direct8 为 42 tests / 1746 assertions，formal32 为 312 tests / 4541 assertions，全部 exit 0；formal 第 29 项同样为 4/537。
- Task20 单列 7/68、双 180 帧 smoke、11 张非 headless capture、11/11 原尺寸 QA、final rescan 均重新生成并通过；49 个新正式日志五类标记为 0。共享 evidence 将完整替换为 README + 49 logs + 6 CSV + 11 PNG = 67 files，冷副本 `.import/.translation` 不回流。
- 最终外部对账继续要求：43 项实现/测试/设计清单仅该 runner 哈希变化且共享↔冷候选 43/43；Task39 10 项、五个 UID、共享 `.godot`/sidecar、两份中文保护文档与中枢 README 全部零漂移；Godot/godot-ai 进程 0。状态保持 `REVIEW`，等待中枢重新独立验收。

## 15. 第二次独立 Review 后 safe 强断言窄返工（2026-08-12）

- 第二次独立 Review 在运行验收前静态发现：§14 runner 已固定 safe typed chest 结果，但 `_test_safe_run` 仍以实际 `chest_dust` 动态重算期望，未直接锁死 safe 奖励顺序与最终经济。因此 §14 的 67-file evidence 及 formal `312/4541` 整体作废，不再作为验收依据。
- 本轮唯一代码变更仍为 `combat/tests/run_task31_full_run_e2e_tests.gd`：紧邻 safe `_finalize_metrics` 新增六项强断言，精确要求 chest dust `300`、chest skills 按实际稳定顺序为 `element_reclaim|burning|elemental_fury`，以及 earned/purchases/upgrades/balance 为 `895/225/300/475`。bolt Lv3、购买/升级/七槽、risk 六项强断言及 §14 的两处 `scene_changed` 同步全部保留；生产代码、资源、场景、设计文档和其他 runner 未修改。最终 runner SHA-256 为 `9001DC63006A18C90DFD900B3E2B4F7A3EC40A8B180CB862444FECF81F393022`。
- fresh 候选使用此前不存在的 `C:\tmp\element-dungeon-task41-rework2-20260812-05` 与独立 profile `C:\tmp\element-dungeon-task41-rework2-profile-20260812-05`；由固定 HEAD ZIP archive + Task41 §8 当前 allowlist 构建，第一条 Godot 命令为 4.7.1 headless editor scan，候选中枢 README 为固定 HEAD blob。
- 同一 Task31 E2E 三个连续独立进程均 exit 0、`4/543`；三次 safe 均为 `300 + element_reclaim|burning|elemental_fury + 895/225/300/475`，risk 均为 `450 + element_reclaim|elemental_fury + 1150/420/115/615`。direct8 全部通过，精确合计 `42/1752`；formal32 全部通过，精确合计 `312/4547`，其中第 29 项同样为 `4/543`。
- Task20 单列 `7/68`、RunGame/TestRoom 双 180 帧 smoke、11 张非 headless authority-checked capture、final rescan 与 49 日志五类标记扫描均从本轮 fresh 候选完整重生；旧日志和 PNG 未混入。本轮共享 evidence 精确为 README + 49 logs + 6 CSV + 11 PNG = 67 files。
- 最终仍要求：除该 runner 外上一轮 42/42 冻结清单不变，新共享↔冷候选 43/43；Task39 10/10、五个 UID、共享 `.godot`/sidecar、两份中文保护文档和中枢 README 全部零漂移；共享 evidence 无 `.import/.translation`。状态保持 `REVIEW`，等待中枢第二次返工后的独立验收。

## 16. 第三次独立验收后实体商店 UX 返工（2026-08-12）

- 第三项独立验收确认 formal SHOP 自动打开全屏交易面板后没有可见关闭入口，`toggle_loadout()` 也只重绘面板；玩家因此看不到或无法走向右侧世界出口。上一轮 67-file evidence、formal `312/4547` 及像素相同的旧 06/07 商店图整体作废。
- 本轮生产变更仅限 `scripts/ui/run_overlay_interface.gd`：formal SHOP header 显示可点击、可聚焦的“关闭商店界面 / 返回世界  L”按钮，并注册为 `formal_control(&"close_shop_panel")`；点击仅 `hide_overlay`。formal SHOP 的 `toggle_loadout()` 在可见时关闭、隐藏时用同一权威 snapshot/shop draft 重开。footer `leave_shop` 继续 disabled；路线、结算、legacy 行为和正式离店事务均未改变。
- Task41 专项、Task31 完整 E2E 与 Task41 capture 三条路径均改为关闭面板后通过真实 `move_right` 物理帧从出生点走入 `exit_portal.can_interact` 范围，再发送 interact/F 输入；三者均不再直接赋值商店内 player position。测试锁定关闭 authority 零变化、L 重开同一 shop session/draft、footer 仍 disabled，以及世界房、玩家、门和 `F · 离开商店` 提示可见。
- fresh 候选使用此前不存在的 `C:\tmp\element-dungeon-task41-shopux-20260812-07` 与独立 profile `C:\tmp\element-dungeon-task41-shopux-profile-20260812-07`；由固定 HEAD ZIP archive + §8 当前 allowlist 构建，第一条 Godot 命令为 4.7.1 headless editor scan，候选中枢 README 为固定 HEAD blob。首次窄跑候选 `...-06` 因测试等待未显式使用 physics frame 而废弃，不属于最终证据来源。
- 最终 SHA-256：`run_overlay_interface.gd` = `BB3A86E1507F6885D825641DC5234FA90F596BB2C8D91619F9DC522FC8D970F5`；Task41 runner = `74F771FA9BAA8E1E300D6759B1199ADF2CFB6917763AD3D957366FA57A5ECA42`；Task31 E2E = `19D84D16D05A66BBE0B4343A57AFF69E94F47C960D6B7DEDD195E944E5A21EC1`；capture = `071ED494F326577A965C09A1F4272C9AF42128104F15AA5FC77D0E128CB625F6`。
- Task31 三个连续独立进程均 exit 0、`4/557`，safe/risk 固定 metrics 三次一致。direct8 为 `42/1779`，formal32 为 `312/4574`；Task41 专项 `4/110`。Task20 `7/68`、双 180 帧 smoke、11 图 capture 与 final rescan 均通过，49 日志五类标记合计 0。
- 06 交易面板 SHA-256 为 `32B378B2BC5964701F75F3182C4FECB3A80679E131B4EB43CBE0CE07B1965DAC`，07 世界门提示为 `186527C08E5148836F2C1077D740DE72E823A196DD412356D482DAE33324F746`，两者不同且 1366×768 原尺寸 QA 通过。共享 evidence 仍精确为 README + 49 logs + 6 CSV + 11 PNG = 67 files。
- 最终要求：相对 §15 冻结候选仅 overlay、Task41 runner、Task31 runner、capture 四项变化，其余实现/测试/设计 39/39 不变；生产变更仅 overlay。Task39 10/10、五个 UID、共享 `.godot`/sidecar、中枢 README 与两份保护文档零漂移；状态保持 `REVIEW`，等待中枢重新独立验收。

## 17. 中枢独立验收与接受（2026-08-12）

- Review 6.0 使用此前不存在的 `C:\tmp\element-dungeon-task41-review-shopux-20260812-01\project` 与独立 profile，从固定 HEAD `87dceba3167365665cc726777a6fca78d7ae7d8e` + §8 精确冻结 overlay 构建候选；未复用执行根、旧 Review 候选或旧截图。候选 live README 为固定 HEAD blob，两份中文保护文档未进入候选。
- 冻结 source/taskbook 与共享逐项一致，Review 期间共享与候选 source 均零漂移；Task39 五 PNG/五 import 10/10 不变，五个 Task41 UID 精确且候选全局 373/373 唯一。旧 622 个 sidecar scan 前后 changed/missing 均为 0；共享 sidecar 保持 622 files / 291,163 bytes，共享 `.godot` 保持 990 files / 42,684,249 bytes。
- 静态与权威路径通过：formal SHOP 自动打开；header `close_shop_panel` 可见、可用、可聚焦且文案正确；关闭按钮与 L 只隐藏/重开同一 snapshot/session/draft，wallet/loadout/revision/draft 零变化；footer `leave_shop` 保持 disabled，唯一离店权威仍为世界 ExitPortal。Task41 专项、Task31 safe/risk E2E 与 capture 的商店段均以真实 `move_right` + `physics_frame` 到达 `can_interact` 后发送 F，无坐标直写、导航或自动寻路框架。
- 独立运行通过：Task31 三个独立进程均为 `4/557` 且 safe/risk 业务字段一致；direct8 为 `42/1779`；formal32 为 `312/4574`，其中 Task41 专项 `4/110`；Task20 历史 runner 单列 `7/68` 且不追认；RunGame/TestRoom 双 180 帧、非 headless 11 图 capture 与 final rescan 均通过。49 份正式日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。
- 11 张截图均由本轮 Review 重新生成并逐张原尺寸复核；06 显示完整商店面板与关闭入口，07 显示无遮挡实体商店、玩家、右侧 ExitPortal 和 `F · 离开商店`。两图均为 1366×768，SHA 分别为 `32B378B2...B1965DAC` 与 `186527C0...324F746`，像素不同。Boss 紫轮廓、低位横向弹体、结算宝箱和结果页均清楚可读。
- 首扫 Godot 已完整运行至 editor DONE、五类标记为 0；其外层 PowerShell 因 Review harness 写成 `exit$LASTEXITCODE` 而误报包装器 exit 1。该命令完成后的拼写问题由 scan 日志、旧 sidecar 零漂移、全部后续门禁和 final rescan exit 0 交叉确认，不构成候选失败。
- 共享 evidence 精确为 README + 49 logs + 6 CSV + 11 PNG = 67 files，`.import/.translation` 为 0；allowlist、冻结哈希、保护项与共享缓存均无阻塞。非阻塞视觉抛光仅为部分测试战斗图的 99999 伤害数字较密，不影响正式玩法可用性。
- 中枢结论：Task41 `ACCEPTED`。后续回归或数值调优必须使用新任务号，不重开本任务。
