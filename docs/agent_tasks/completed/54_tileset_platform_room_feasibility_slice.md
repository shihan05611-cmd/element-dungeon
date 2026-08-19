# 任务 54：共享 TileSet 与平台房工程可行性切片

状态：CANCELLED_BY_USER
负责人：地图/场景工程职责对话 `threadId=019ffe96-ad0f-7242-9ac1-4d77f862d445`，`hostId=local`
依赖：Task53 `ACCEPTED`
Git 基线：`5c0f2ee24ab8c1e494e1e185666c94edd7b79228`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L3
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级/停线触发：Task53 atlas/manifest 不完整或哈希不一致、Godot 4.7.1 无法稳定导入 32×32 atlas、Terrain peering 与 manifest 无法一一映射、TileSet 碰撞不能保持现有 WorldBlocker 语义、必须改 Player/CombatReceiver/RunSession/正式 flow，或共享 Godot 无法保持被动时，立即冻结为 `BLOCKED`。

## 1. 目标与边界

本任务只证明用户冻结的 `Godot TileSet + TileMapLayer` 路径在现有工程可稳定落地，并把既有平台模板迁移为第一个真实瓦片房。它不扩大正式流程、不调整 Camera/整体房间尺度、不新增远程怪、不替换宝箱/传送门，也不把其他房间机械迁移进本任务。

玩家可观察结果：平台房使用正式潮汐背景、地形、单向平台和前景遮挡层；现有玩家能够在真实物理下站地、跳上首个平台、从下穿过单向平台，且遮挡不影响角色识别。

## 2. 不可妥协约束

- 共享 `TileSet` 是唯一瓦片配置源；不得用大量 `Polygon2D`、独立 `Sprite2D` 拼墙或保留重复碰撞作为正式 fallback。
- 分层至少为 `FarBackdrop / BackgroundWall / BackDecor / SolidTerrain / OneWayPlatform / FrontDecor`；碰撞仅由 `SolidTerrain` 与 `OneWayPlatform` 的 TileSet physics layer 承载。
- atlas source 严格 `32×32`、margin/separation 0、Nearest；Terrain peering 与 Task53 manifest 一致。
- 现有 WorldBlocker 物理层（项目 layer 3，位值 4）、玩家跳跃和重力参数保持不变。
- `room_arena_platforms.tscn` 继续提供 `PlayerSpawn`、`EnemyContainer`、`template_id=arena_platforms` 与 `RunRoomInstance` 接口；本任务不改变 RunSession/Coordinator 生命周期。

## 3. 预期 allowlist

1. `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png.import`
2. `resources/run/tilesets/tidal_dungeon_tileset_v1.tres`
3. `scenes/run/rooms/room_arena_platforms.tscn`
4. `combat/tests/run_task54_tileset_platform_slice_tests.gd`
5. 对应 `.gd.uid`（仅隔离 scan 确实生成且 UID 唯一时）
6. `combat/tests/capture_task54_tileset_platform_slice_visuals.gd`
7. 对应 `.gd.uid`（同上）
8. `docs/agent_tasks/pending/54_tileset_platform_room_feasibility_slice.md`
9. `docs/agent_tasks/evidence/task54/**`

Task53 正式 PNG/manifest 只读；除上述范围外全部只读。执行前须由中枢根据 Task53 最终 manifest 复核并冻结 TileSet 资源字段与 atlas 坐标。

### 3.1 中枢冻结的 TileSet 资源合同

- 唯一 atlas：`res://assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`，SHA-256 `2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519`。
- `TileSet.tile_size=Vector2i(32,32)`；唯一 `TileSetAtlasSource` 使用稳定 source id `0`，`texture_region_size=Vector2i(32,32)`，margin/separation `0`；不得开启 texture padding、旋转或镜像替代。
- atlas 行职责严格冻结：`0–3 BackgroundWall`、`4–7 SolidTerrain`、`8–10 OneWayPlatform`、`11–12 FrontDecor`、`13–15 BackDecor`；reserved/blank 格不得创建成可随机选择的有效绘制 tile。
- Terrain Set 稳定 id `0`、名称 `tidal_stone_solid`、connect mode 使用完整 3×3 peering；terrain 稳定 id `0`。rows `4–6` 的 47 个 `terrain_47_blob` 坐标与 manifest 的 mask 名称逐项映射，禁止旋转/镜像；row `7` 仅作为显式 auxiliary，不伪装成缺失 peering。
- TileSet physics layer 只承载 WorldBlocker 语义，collision layer 位值 `4`；`SolidTerrain` 使用整格 `32×32` 矩形，视觉顶线与碰撞顶线误差不超过 1 逻辑像素。
- One-way 可站立 tile 仅使用 manifest 中 `(0..6,8)`，统一碰撞顶线 `y=10`、完整 32px 可站立跨度并启用单向语义；`(7..10,8)` support/underhang 为装饰且无碰撞。若 Godot 4.7.1 的 TileSet 单向字段无法稳定表达，必须 `BLOCKED` 并给出证据，不得用重复 StaticBody fallback。
- 六个 `TileMapLayer` 名称和 z-index 冻结为：`FarBackdrop(-30)`、`BackgroundWall(-20)`、`BackDecor(-10)`、`SolidTerrain(0)`、`OneWayPlatform(1)`、`FrontDecor(10)`；仅后两层按上条合同带碰撞，其他层默认无碰撞。
- 当前切片仍保持既有房间逻辑边界与 spawn/container 接口；不得借机引入跟随相机、滚屏房、随机拼房或正式流程修改。

## 4. L3 执行与验收门禁

- 执行者先完整读取 `CENTRAL_REVIEW_RULES.md`、`REVIEW_AGENT_RULES.md`、`REVIEW_L3_PLAYBOOK.md`、Task53 交付及 TileSet 美术合同。
- 在固定 Git 基线导出的全新隔离根与独立 profile 中，第一条 Godot 命令为 4.7.1 headless editor scan。
- 专项必须证明：atlas/region/tile size、47 片 Terrain 映射、各层 z/碰撞职责、实心碰撞、单向穿越/落地、PlayerSpawn/EnemyContainer/template 合同、现有跳跃真实到达首平台、FrontDecor 无碰撞。
- 直接回归至少包括 Task43 平台可达性与 Task29 真实房间实例接口；若现有 runner 因固定 Polygon 节点名失败，先停线请求中枢精确迁移测试 allowlist，不得删除行为断言。
- 实际 capture 至少 `1920×1080`、`2560×1440`，原尺寸检查瓦片拼缝、重复节拍、平台顶线、角色/敌人可读性和前景遮挡。
- 正式日志五类标记为 0；final editor scan、allowlist、import/UID、evidence manifest 和共享工作区零漂移通过。

## 5. 保护与交付

- 用户 `global_instakill`、历史 `.import` 删除、Task20、Task47 未跟踪文档、Task49/52、Task53 母版及所有任务外生成物原样保护。
- 禁止连接、关闭、reload、reimport 或控制共享 Godot/editor/godot-ai；只使用隔离进程和 profile。
- 不使用子 Agent；不做 Git 写操作；不自行 `ACCEPTED`。
- 完成后仅在本任务对话及任务书交付 `REVIEW/BLOCKED` 并冻结，不跨对话回传；中枢用 `wait_threads/read_thread` 收取。

## 6. 协调记录

- 2026-08-14 新建独立地图/场景工程执行对话，显式 `model=gpt-5.6-sol`、`thinking=high`；共享项目 direct-local 是为了让精确 allowlist overlay 回流同一工作树，所有 Godot 执行仍强制在固定基线冷根与独立 profile 完成。
- 执行对话：`threadId=019ffe96-ad0f-7242-9ac1-4d77f862d445`，`hostId=local`；中枢仅用 `wait_threads/read_thread` 主动跟踪，不要求跨对话回传。

## 7. 用户停线与归档（2026-08-14）

- 用户在 Task54 正式回流前明确判断瓦片构建地图不适合当前项目，要求改为“分层背景图片 + 独立平台/碰撞”；背景墙去除烘焙灯光，背景墙与装饰物分开生成。
- Task54 因架构方向变更标记为 `CANCELLED_BY_USER`，不是实现失败，也不得继续 Review/ACCEPTED。
- 执行对话已停止所有 Godot、runner、capture 与 final scan；冷根中的候选 `.import/.tres/.tscn/runner/evidence` 未回流共享工作树，当前无隔离 Godot 进程。
- 共享工作树没有 Task54 工程实现 overlay；只归档本任务书。Task53 已接受的 atlas 与 QA 作为美术研究/追溯输入保留，但不再构成运行时 TileSet 路径承诺。
- 后续任务必须采用固定房间分层整图：无烘焙灯光的 `BackgroundWall`、透明 `BackDecor/FrontDecor`、独立平台/地面视觉与独立场景碰撞；不得继续创建 TileSet/TileMapLayer。
