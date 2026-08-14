# 任务 57：完整房间背景、远景相机与平台碰撞迁移

状态：PENDING
负责人：独立场景/玩法工程执行任务（中枢派发）
依赖：任务 49、51、53（ACCEPTED）；用户已接受本任务五张美术母版
Git 基线：`main` HEAD `b080de734d8a9dd321a62ec13a4152b00b8989f7`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L3
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级/停线触发：必须修改 `project.godot`、Player/Enemy/HUD/经济/流程权威代码、素材像素内容、正式五阶段顺序或 allowlist 外生产文件；无法用固定基线 + 精确 overlay 构建候选；平台碰撞/出生点出现帧序或随机不稳定；或共享用户 `global_instakill` 无法与候选隔离时，立即停线并交付 `BLOCKED`，不得自行扩域。

## 1. 用户冻结决定与可观察目标

1. 正式地图不再使用 TileSet/TileMapLayer，也不再使用 Task55 分层背景方案；采用**一张完整房间背景图 + 对图中地面/平台绘制真实碰撞体**。
2. 地图视野放远、房间整体扩大。完整房间的 authored world 为 `1536×832`，不得把图片压缩回旧 `1152×648` 房间冒充扩容。
3. 正式五阶段 `战斗 → 战斗 → 商店 → 战斗 → Boss` 使用本轮已选房间美术：
   - 战 1：Battle Room 01；
   - 战 2：Battle Room 02；
   - 战 3：复用 Battle Room 01（允许复用，但不得连续两战同背景）；
   - 商店：Shop Room；
   - Boss：Boss Room。
4. Battle Room 01/02 中画出的平台必须有对应单向碰撞，视觉顶线与碰撞顶线误差不超过 `2 world px`；地面、左右边界同样匹配画面。
5. Boss 图明确没有平台：删除旧 `BossDais` 的正式视觉与碰撞语义，Boss 从主地面开始战斗；不得保留透明/不可见平台。
6. 背景是一张完整图，不拆分背景墙、装饰、平台或前景层；玩家、敌人、宝箱、传送门、皇冠、弹体和 HUD 仍为独立 gameplay 节点，不烘进背景。

## 2. 已选美术输入（冻结）

以下五张已由用户明确允许入库，并已提交到 Git；前四张为本任务运行输入，第五张许愿皇冠只冻结供后续 Task58 使用，本任务不得接线皇冠交互：

| 角色 | 路径 | 尺寸 | SHA-256 |
|---|---|---:|---|
| Battle Room 01 | `assets/art_preview/scene_preview/full_room_trials/tidal_battle_room_01_full_v1.png` | 1536×832 RGBA | `6D1BBBA738358D0AB2C2F4FD517D3D6B2E3B488DF95884C801957D6BAC09C1C2` |
| Battle Room 02 | `assets/art_preview/scene_preview/full_room_trials/tidal_battle_room_02_full_v1.png` | 1536×832 RGBA | `833258D65127A96F1016C7A71D0EDC0296C698675DC885063833F83F18BF4A67` |
| Shop Room | `assets/art_preview/scene_preview/full_room_trials/tidal_shop_room_full_v1.png` | 1536×832 RGBA | `AAD8EEDF06B566E5EFBDDB6ABC7EC1A0B3607095F0D972FE4041324F44688728` |
| Boss Room | `assets/art_preview/scene_preview/full_room_trials/tidal_boss_room_full_v1.png` | 1536×832 RGBA | `F2091EB108E93B48465EFF41FFCB899D5899DACC37E2818DA93B1B941DC94220` |
| Wishing Crown（后续任务） | `assets/art_preview/world_objects/wishing_crown_v1.png` | 160×128 RGBA | `3CC3557EAA97349116A7EF5251ABD0586AEBD9F3E3BB283B89585C5E76FD7095` |

`tidal_battle_room_01_player_scale_preview.png` 与 `tidal_shop_room_wishing_crown_preview.png` 仅为视觉 QA，不是运行素材，不得接线。

执行者把四张房间母版精确复制到新的正式运行目录 `assets/world/rooms/tidal_dungeon/full_rooms/`，文件内容 SHA 必须与母版一致。不得重采样、裁切、补画或覆盖 art_preview 母版。

## 3. 实现路径与不可妥协约束

### 3.1 推荐的最低风险路径

1. 保持窗口/HUD 基准和 `project.godot` 不变，只在正式 `RunGame` 的 Camera2D 与房间世界坐标中完成扩容。
2. Camera2D 使用**统一缩放**，不得非等比拉伸背景。推荐中心 `(768,416)`、统一 zoom `0.75`：在现有 16:9 视口完整展示 1536px 水平范围，上下各约 16px 由与背景边缘相容的纯暗色 backing 填充；不得出现亮边、透明洞或可见黑色断层。
3. 复用现有 `CombatRoomDefinition.room_scene` 选择不同模板：Battle 01 可迁移现有 flat 模板；新增 Battle 02 模板，并把正式战 2 指向 Battle 02、战 3 指回 Battle 01。
4. 房间模板提供明确的 `PlayerSpawn`、敌人/援军落点、`RewardChestSpawn`、`RoutePortalSpawn` 等 authored markers。若现有运行脚本需要消费 marker，只允许做窄的“marker 存在则使用、缺失则配置失败”迁移；不得继续散落 `760/501`、`1000/454` 等旧房间硬编码。
5. 平台采用 `StaticBody2D + CollisionShape2D` 的单向碰撞；视觉由完整背景承担，旧 Polygon2D 占位视觉删除。地面与边墙使用 WorldBlocker 层，保持 Player/Enemy 当前碰撞语义。

### 3.2 明确禁止

- 不使用 TileMap、TileSet、拆层图片、运行时自动切图或程序化拼贴。
- 不把 1536×832 背景缩放成 1152×648，也不通过非等比 Camera/Sprite scale 填满画面。
- 不修改玩家速度、跳跃、重力、闪避距离或敌人移动参数来迁就平台。
- 不在本任务接线许愿皇冠、正式宝箱/传送门新贴图或 Tidal Sentry；这些由后续 Task58 在本任务接受后接入。
- 不删除 Task54/55 取消产物、旧宝箱/传送门素材或 art_preview 源母版；待删除清单继续冻结。

## 4. 精确生产 allowlist

1. `assets/world/rooms/tidal_dungeon/full_rooms/tidal_battle_room_01_full_v1.png`
2. `assets/world/rooms/tidal_dungeon/full_rooms/tidal_battle_room_02_full_v1.png`
3. `assets/world/rooms/tidal_dungeon/full_rooms/tidal_shop_room_full_v1.png`
4. `assets/world/rooms/tidal_dungeon/full_rooms/tidal_boss_room_full_v1.png`
5. 上述四张 PNG 对应 `.import` **不得作为生产提交内容**；只允许出现在隔离候选缓存中。
6. `scenes/run/run_game.tscn`
7. `scenes/run/rooms/room_arena_flat.tscn`
8. `scenes/run/rooms/room_arena_tidal_battle_02.tscn`（新增）
9. `scenes/run/rooms/room_shop_formal.tscn`
10. `scenes/run/rooms/room_arena_boss.tscn`
11. `scripts/run/run_room_instance.gd`（仅 authored interactable markers 消费与配置校验）
12. `resources/run/rooms/combat_01_entry.tres`
13. `resources/run/rooms/combat_02_swarm.tres`
14. `resources/run/rooms/combat_04_validation.tres`
15. `resources/run/rooms/combat_06_final_boss.tres`

若正式商店皇冠交互需要修改 `scripts/run/run_shop_room_instance.gd` 或 Coordinator，属于 Task58，不得在本任务扩入。

## 5. 测试、capture 与 evidence allowlist

1. `combat/tests/run_task57_full_room_background_collision_tests.gd`（新增）
2. 对应 `.gd.uid`（仅冷副本 scan 自然生成时）
3. `combat/tests/capture_task57_full_room_backgrounds.gd`（新增）
4. 对应 `.gd.uid`（仅冷副本 scan 自然生成时）
5. `growth/tests/run_task41_physical_flow_waves_boss_tests.gd`
6. `growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd`
7. `combat/tests/run_task51_boss_projectile_spawn_clearance_tests.gd`
8. `combat/tests/run_task29_real_room_flow_tests.gd`
9. `combat/tests/run_task31_full_run_e2e_tests.gd`
10. `combat/tests/capture_task41_physical_flow_visuals.gd`
11. `combat/tests/capture_task43_combat_loadout_world_cleanup_visuals.gd`
12. `combat/tests/capture_task49_five_stage_demo_visuals.gd`
13. `docs/agent_tasks/57_full_room_background_camera_and_collision_migration.md`
14. `docs/agent_tasks/evidence/task57/**`

现有 runner/capture 只允许迁移旧 `1152×648` 几何、BossDais 和正式房间截图坐标的直接断言；不得削弱流程、波次、经济、奖励、配装、Boss 投射物或权威状态门禁。发现其他直接冻结旧坐标的消费者时停线，由中枢精确补充 allowlist。

## 6. L3 专项与视觉门禁

执行侧必须在固定基线导出的全新冷根和独立 profile 中完成：

1. cold-first editor scan；确认四张 runtime PNG 可加载，SHA 与母版一致，场景无丢失引用。
2. Task57 专项至少断言：
   - Camera 中心、统一 zoom、四张背景 1:1 world 尺寸且无非等比缩放；
   - 正式五阶段的房间映射为 Battle01 → Battle02 → Shop → Battle01 → Boss；
   - Battle01/02 的每个平台碰撞顶线与冻结图像量测坐标误差 ≤2px，并全部 one-way；
   - 地面/边墙完整阻挡，玩家可真实跳上每个必要平台并落回地面；
   - Player、全部初始/援军敌人、宝箱、传送门均出生在合法可达区域；
   - Boss 场景不存在 BossDais 或其他透明平台，Boss 在主地面稳定落地并正常发射弹体；
   - 房间切换仍只替换 RoomContainer，五阶段权威和结果不变。
3. 直接回归至少覆盖 Task41、Task43、Task51、Task29 与 Task31；旧几何断言只按本任务精确迁移。
4. 正式 `RunGame` 完整五阶段 smoke，不能只实例化单房。
5. 新鲜实际画面至少 5 张：Battle01、Battle02、Shop、复用后的第三战、Boss；另至少 1 张 1920×1080 带玩家/敌人的平台可玩画面。所有图必须来自本轮运行候选，不得使用 art_preview 静态图冒充。
6. 原尺寸检查：背景无裁切/拉伸/接缝，角色尺度可读，平台视觉/脚底吻合，HUD 不受 Camera 缩放，Boss 房无隐藏台，交互物不离地或埋地。
7. 主场景 180 帧 smoke、final editor scan；正式日志 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全 0。

独立 L3 Review 必须按 `REVIEW_L3_PLAYBOOK.md` 从固定基线 + 精确冻结 overlay 建第二套全新冷根，重跑专项、直接影响域、完整五阶段 smoke、重新生成并原尺寸检查截图，核对 allowlist、sidecar、manifest 和共享零漂移后输出 `PASS / FAIL / ESCALATE`。

## 7. 共享保护与 Git 禁止

- 用户 `global_instakill`：共享 `project.godot`、`scripts/player.gd`、专属 runner/UID/tmp 全部原样保护；不得读取其 runner、修改、运行、复制、删除、暂存或认领。
- Task56 在独立 worktree 并行修改 `scripts/player.gd`；Task57 与其生产 allowlist 零重叠，不得读取或整合 Task56 未验收候选。
- task12..34 历史 `.import` 删除、Task47、Task54/55 取消产物、translation/import/`.godot`/中文保护文档和其他未跟踪文件全部保护。
- Godot PID17624、godot-ai PID3964 为共享实例；禁止连接、关闭、重启、reload、reimport、保存或控制。
- 执行者不使用子 Agent，不执行 `git add/commit/push/reset/restore/checkout/clean/stash`，不自行 `ACCEPTED`。完成后更新为 `REVIEW` 并冻结；不得跨对话回传大段内容，中枢只通过 `wait_threads/read_thread` 收取。

## 8. 后续拆分（不属于 Task57）

Task57 接受后再立项 Task58，接线：

1. 正式宝箱关闭/开启与传送门锁定/激活素材，并在全库引用迁移验收后精确删除旧素材；
2. 商店许愿皇冠作为独立世界交互对象，打开既有商店 UI，不把皇冠烘入背景；
3. Tidal Sentry 静态远程敌人及平台放置。

Task58 会触及商店交互、敌人和正式 spawn 资源，与本任务房间/几何迁移存在依赖，不提前并发，避免重叠文件与坐标漂移。

## 9. 协调记录

- 路径对齐：用户已明确选择“完整背景 + 平台碰撞”，不再比较 TileSet/分层方案；本任务采用不改 `project.godot` 的统一 Camera zoom + 1536×832 authored world，为满足相同可观察目标的最低风险迁移。
- 执行职责候选审计：Task54 为已取消 TileSet 可行性且对话历史目标冲突；Task53 为美术 Review；均不复用。Task57 为跨公共房间模板的 L3 场景工程，创建全新独立执行任务，压力等级 `GREEN`。
- 执行对话 `threadId`/`hostId`、模型/推理与首个 `wait_threads` cursor：派发后由中枢回填。
- 独立 L3 Review 对话：执行冻结后另行创建、登记和主动跟踪。
