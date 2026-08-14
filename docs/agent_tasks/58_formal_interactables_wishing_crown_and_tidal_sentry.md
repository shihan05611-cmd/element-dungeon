# 任务 58：正式交互物、许愿皇冠与潮汐哨兵接线

状态：PENDING
负责人：独立世界交互/敌人工程执行任务（中枢派发）
依赖：任务 53、57（ACCEPTED）
Git 基线：`main` HEAD `51b8ffde0894fd430517225e693b7c44008038aa`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L3
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级/停线触发：必须修改 `project.godot`、Player/HUD/存档/经济权威、Task57 房间背景或碰撞、正式五阶段顺序、通用 delivery 契约，或 allowlist 外生产文件；无法在不读取用户 `global_instakill` runner 的前提下验证；旧资产引用无法精确归零；静态远程怪需要随机/导航/移动才能成立。触发即 `BLOCKED`，不得自行扩域。

## 1. 用户冻结目标

1. 宝箱正式使用 `chest_closed_v2.png / chest_open_v2.png`；传送门正式使用 `portal_locked_v2.png / portal_active_v2.png`，必须是真实双状态图片，不能用 modulate 冒充状态。
2. 全库运行引用迁移并验收后，精确删除旧宝箱/传送门资产，不保留兼容副本；历史 completed/evidence 文档可保留路径事实，不得为“引用归零”篡改历史。
3. 商店完整背景不改。`wishing_crown_v1.png` 作为独立世界交互对象；玩家靠近按 F 后打开现有商店 UI，不把皇冠烘入背景，也不让皇冠直接提交购买、离店或经济事务。
4. 新增 Tidal Sentry：第一版静态立绘 + 既有 projectile delivery，不移动、不巡逻、不导航、不随机。正式 Battle02 至少一只放在图中平台上，鼓励玩家使用平台；不改变战斗总阶段数和奖励总量。
5. Task57 的 Battle01 → Battle02 → Shop → Battle01 → Boss、1536×832 authored world、Camera 与碰撞全部保持不变。

## 2. 冻结资产与最低风险实现

### 2.1 正式资产（字节只读）

- `assets/world/interactables/run_reward_chest/chest_closed_v2.png`：80×72，SHA `2714DAC5A5EC44B7C092A7D2F3574FB0E71A6529090138051DE1FA154C400D97`。
- `assets/world/interactables/run_reward_chest/chest_open_v2.png`：80×72，SHA `CBC4344454B8D0D969545046A53A1B037CDB354091A4D526B5009285E0F74D68`。
- `assets/world/interactables/run_route_portal/portal_locked_v2.png`：64×96，SHA `B9CFFEAC3D5037FEB793072E6A8317A01A8D2422A230ED9671FC5A59ACC30FFD`。
- `assets/world/interactables/run_route_portal/portal_active_v2.png`：64×96，SHA `0EDDAA9C484FEDB119C31DA6E081141549FCD4297E7823151C4A2BD330A7C2EA`。
- `assets/art_preview/world_objects/wishing_crown_v1.png`：160×128，SHA `3CC3557EAA97349116A7EF5251ABD0586AEBD9F3E3BB283B89585C5E76FD7095`。
- `assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png`：100×100，SHA `10C931DD8823F5DA24AA6A6EFC13D00944A0EB57F07BF7AAEE6EC531786F65F1`。

全部 Nearest、Lossless、无 mipmap/repeat；交互物按 manifest 1×，Sentry 按 manifest 3×。不得重采样或改像素。

### 2.2 推荐实现路径

1. 保持现有 `RunWorldInteractable`；为传送门增加显式 locked/active texture 状态刷新，宝箱继续由正式事务调用 `open_chest()` 切换真实 open 图。
2. 新增 `SHOP_CROWN` kind 与独立皇冠 scene；`RunShopRoomInstance` 返回皇冠或出口，`RunFlowCoordinator` 只把皇冠交互转成“商店 UI 已打开”的展示信号，权威购买/离店仍走既有命令。
3. `RunFlowSmokePanel` 在 SHOP 初始隐藏现有 ShopButtons，收到皇冠打开信号后显示；阶段离开时复位。世界出口传送门仍可正常离店。
4. 新建 Tidal Sentry 专用 scene/script，继承现有 `CombatEnemy` 组件与死亡/奖励协议，重用 `boss_arc_projectile.tscn`/`ProjectileDelivery`；只处理重力落台、正式 Player 获取、确定性冷却和水平发射，不修改通用 `scripts/enemy.gd`。
5. Battle02 保持现有房间几何；把 `InitialEnemySpawns/Spawn1`（平台 marker）对应 spawn 改为 Sentry，保持敌人总数、该 spawn 的 55 HP 与 15 梦尘不变。

## 3. 旧资产精确删除合同

删除前先冻结 bytes/SHA 与运行/当前权威文档引用图。只有生产 scene/script/resource 对旧 PNG 的引用为 0、正式新状态运行验收通过后，才逐项删除：

1. `assets/generated/vfx/run_reward_chest/chest_closed.png`
2. `assets/generated/vfx/run_reward_chest/chest_closed.png.import`
3. `assets/generated/vfx/run_reward_chest/chest_open.png`
4. `assets/generated/vfx/run_reward_chest/chest_open.png.import`
5. `assets/generated/vfx/run_reward_chest/manifest.md`
6. `assets/generated/vfx/run_reward_chest/prompt.md`
7. `assets/generated/vfx/run_route_portal/portal.png`
8. `assets/generated/vfx/run_route_portal/portal.png.import`
9. `assets/generated/vfx/run_route_portal/manifest.md`
10. `assets/generated/vfx/run_route_portal/prompt.md`

不得删除父目录之外的文件，不得宽泛清理 `assets/generated/vfx/**`。历史任务书/evidence 的旧路径文字不是运行引用；`docs/vfx/final_asset_manifest.md`、`docs/art/宝箱与传送门正式采纳交接清单.md`、`docs/art/像素美术规范_v1.md` 属当前权威说明，必须同步为新资产与旧目录已退役。

## 4. 生产 allowlist

### 4.1 可修改/新增

- `scenes/run/interactables/run_reward_chest.tscn`
- `scenes/run/interactables/run_route_portal.tscn`
- `scenes/run/interactables/run_wishing_crown.tscn`（新增）
- `scripts/run/run_world_interactable.gd`
- `scripts/run/run_room_instance.gd`
- `scripts/run/run_shop_room_instance.gd`
- `scripts/run/run_flow_coordinator.gd`
- `scripts/run/run_flow_smoke_panel.gd`
- `scenes/run/rooms/room_shop_formal.tscn`
- `scenes/run/enemies/tidal_sentry.tscn`（新增）
- `scripts/run/enemies/tidal_sentry.gd`（新增）
- `resources/run/rooms/combat_02_swarm.tres`
- 三份正式资产 manifest：`assets/world/interactables/run_reward_chest/manifest_v2.md`、`assets/world/interactables/run_route_portal/manifest_v2.md`、`assets/world/enemies/tidal_sentry/manifest_v1.md`
- 三份当前权威美术/VFX 文档：`docs/vfx/final_asset_manifest.md`、`docs/art/宝箱与传送门正式采纳交接清单.md`、`docs/art/像素美术规范_v1.md`
- §3 十项旧资产删除。

正式六张 PNG 只读，不得修改。若专用 Sentry script 无法在不改 `scripts/enemy.gd` 的前提下正确复用协议，停线回传具体证据，不得自行把共享敌人基类加入 allowlist。

### 4.2 测试/evidence allowlist

- `combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd`（新增）
- `combat/tests/capture_task58_formal_interactables_crown_sentry.gd`（新增）
- 仅在旧路径/ShopButtons 初始可见/Combat02 敌人类型的直接断言确实冻结旧行为时，可修改：`growth/tests/run_task41_physical_flow_waves_boss_tests.gd`、`growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd`、`combat/tests/run_task29_real_room_flow_tests.gd`、`combat/tests/run_task31_full_run_e2e_tests.gd`、`combat/tests/run_task57_full_room_background_collision_tests.gd` 及其 Task57 capture；不得削弱流程、经济、奖励、配装、碰撞或五阶段门禁。
- `docs/agent_tasks/58_formal_interactables_wishing_crown_and_tidal_sentry.md`
- `docs/agent_tasks/evidence/task58/**`

## 5. L3 门禁

1. 固定基线 + 精确 overlay 建全新执行冷根和独立 profile；第一条 Godot 命令为 4.7.1 headless cold-first scan。
2. 专项断言：六张正式 PNG SHA/尺寸/alpha 与 manifest；宝箱关闭→开启、传送门 locked→active 的真实 texture 状态；底部锚点与地面误差≤2 world px；旧运行路径引用为 0。
3. Shop：入店 UI 初始关闭；皇冠独立可见且落地，近距 F 只打开既有 UI；重复交互不重复提交；购买/升级/配装/离店仍走既有事务；出口 portal 使用 active 图并可离店。
4. Sentry：Battle02 平台 marker 实例化专用 scene；全程水平位移≤1px，无导航/巡逻/随机；稳定落在 one-way 平台；确定性获得 Player，至少连续发射 3 发正式 projectile，每发同实例进入 lifecycle、不会出生即撞墙，能命中 Player 或墙并清理；死亡、元素承载、奖励和清房正常。
5. 正式五阶段从 `RunGame` 完成一次，房间映射、`4/1/0` 结果、总奖励与 Task57 几何保持；Task41/43/29/31/57 与相关 boss projectile 回归全部通过。
6. fresh capture 至少 7 张：closed chest、open chest、locked portal、active portal、shop crown/UI closed、crown交互后 UI open、Battle02 平台 Sentry + live projectile；原尺寸检查遮挡、尺度、脚底和 HUD。
7. 180 帧 smoke、final editor scan；所有正式日志五类标记 0；sidecar、allowlist、正式 PNG、删除清单、evidence manifest 与共享工作区零漂移对账。

## 6. 共享保护与禁止

- 用户 `global_instakill`：共享 `project.godot`、`scripts/player.gd`、专属 runner/UID/tmp 不得读取 runner、修改、运行、复制、删除、暂存或认领。
- Task12..34 历史 `.import` 删除、Task47、Task54/55 取消产物、translation/import/`.godot`/中文保护文档和其他外部脏文件全部保护。
- Godot PID17624、godot-ai PID3964 为共享实例；禁止连接、关闭、重启、reload、reimport、保存或控制。
- 不使用子 Agent；不执行 `git add/commit/push/reset/restore/checkout/clean/stash`；不自行 `ACCEPTED`。
- 完成后状态改为 `REVIEW` 并冻结。中枢通过 `wait_threads` 主动收取；只向派发时注入的当前中枢发送一次≤160字符单行回执。

## 7. 协调记录

- 复杂路径对齐：采用“既有事务/交互节点 + 显式图片状态 + 专用静态 Sentry 子类”的最低风险迁移；不重构商店事务、不改通用敌人基类、不新增弹体体系。
- 执行对话与 Review 对话、实际模型/推理、worktree/cold root 和 `wait_threads` cursor 由中枢派发后回填。
