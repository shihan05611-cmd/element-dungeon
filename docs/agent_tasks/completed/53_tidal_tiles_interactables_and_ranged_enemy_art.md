# 任务 53：潮汐瓦片、交互物与静态远程怪正式美术资产

状态：ACCEPTED
负责人：美术专用职责对话 `019ffb00-0624-76a1-85b0-946bdce0f982`
依赖：Task49、Task52（均 ACCEPTED）；用户已冻结潮汐地牢视觉母版与 TileSet 路径
Git 基线：`main` HEAD `e4bb78d`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级触发：无法从已选母版稳定整理 32×32 精确 atlas、无缝/邻接门禁需要改变冻结规格、必须使用非整数世界缩放、需要修改工程 `.tscn/.tres/.gd/project.godot`、或输出会覆盖/删除既有正式资产时，立即冻结为 `BLOCKED`；不得自行改方案或接线。

## 1. 玩家可观察目标

1. 正式房间能够使用与现有角色、敌人一致的潮汐像素地牢瓦片，不再依赖纯色占位几何。
2. 宝箱与传送门使用用户已选 v2 造型，并具备关闭/开启、锁定/激活两组可直接接线的独立静态状态。
3. 新增第一版静态远程怪美术：无需行走、攻击或受击动画，但必须与现有角色/敌人像素颗粒、左上光源和潮汐地牢配色相容；工程后续以既有弹体链实现射击。

## 2. 不可妥协约束

- 地图默认使用 Godot `TileSet + TileMapLayer`；本任务只交付资产，不创建 `.tres` 或接场景。
- 逻辑 tile 为 `32×32`；正式 atlas 为 `512×512 RGBA / 16×16 grid`，margin/separation 均为 0。
- 宝箱与传送门是独立交互 Sprite，不进入 atlas。
- 所有运行图片使用整数逻辑画布、Nearest、无 mipmap；不得把 1448×1086 母版直接小数缩放后冒充最终资产。
- 不生成备选风格；沿用用户已经确认的唯一潮汐地牢、宝箱和传送门方向。
- 本任务不做工程接线、不删除旧资产、不运行或控制共享 Godot。

## 3. 权威只读输入

1. `docs/art/像素美术规范_v1.md`
2. `docs/art/宝箱与传送门正式采纳交接清单.md`
3. `docs/art/潮汐地牢_TileSet美术交付合同.md`
4. `assets/art_preview/world_objects/chest_states_v2.png`
   - SHA-256 `DF6934951CA303FC8144237C8B157BC8DF517B772F4ECBE58ECDF3D2F9517DA9`
5. `assets/art_preview/world_objects/portal_states_v2.png`
   - SHA-256 `8E6E6D190B4D1967CF407C7FC64D8DE12083E668656FF7ED1291A554F6990F40`
6. `assets/art_preview/tiles/dungeon_tileset_v1.png`
   - SHA-256 `44508C796CD7D4D4D5DE7F181F84A51F382C7E208604103033268E659EE7E8D6`
7. 现有 `scenes/player.tscn`、`scenes/enemy.tscn` 及其纹理只读，用于尺度/颗粒/轮廓对齐。

上述 `assets/art_preview/**` 与 `docs/art/**` 是美术对话既有、当前未跟踪交付；本任务可以读取并在允许的美术文档中补写最终交付事实，但不得改写或删除三张冻结母版和色键源。

## 4. 精确输出 allowlist

### 4.1 正式运行图片

1. `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`
2. `assets/world/interactables/run_reward_chest/chest_closed_v2.png`
3. `assets/world/interactables/run_reward_chest/chest_open_v2.png`
4. `assets/world/interactables/run_route_portal/portal_locked_v2.png`
5. `assets/world/interactables/run_route_portal/portal_active_v2.png`
6. `assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png`

### 4.2 Manifest 与 QA

1. `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1_manifest.md`
2. `assets/world/interactables/run_reward_chest/manifest_v2.md`
3. `assets/world/interactables/run_route_portal/manifest_v2.md`
4. `assets/world/enemies/tidal_sentry/manifest_v1.md`
5. `docs/art/宝箱与传送门正式采纳交接清单.md`
6. `docs/art/潮汐地牢_TileSet美术交付合同.md`
7. `docs/agent_tasks/pending/53_tidal_tiles_interactables_and_ranged_enemy_art.md`
8. `docs/agent_tasks/evidence/task53/**`

除上述范围外全部只读。不得创建或修改 `.import`；隔离验证意外生成的 sidecar 只能留在隔离输出，不得回流共享项目。

## 5. 资产合同

### 5.1 Tile atlas

- `512×512 RGBA`，严格 `16×16` 个 `32×32` 单元；基础 tile 不越格。
- 行 `0–3` 背景；`4–7` 实心 Terrain；`8–10` 单向平台；`11–12` 前景；`13–15` 装饰。
- 主 Terrain `tidal_stone_solid` 至少包含独立块、四边、内外角、T 形、十字、地面/墙脚过渡；若完整 47-tile 邻接不能稳定完成，必须明确 `BLOCKED`，不得用旋转/镜像隐藏缺口。
- 平台至少交付 left cap、center a/b/c、right cap、broken left/right、support/underhang；相接边逐像素一致。
- Manifest 必须逐格列出 atlas 坐标、稳定名称、层级、Terrain/平台/装饰类别、碰撞建议、允许随机变体与空白格。

### 5.2 宝箱与传送门

- 宝箱两态共同 `80×72 RGBA`、bottom-center；关闭/开启底线、箱体宽度和锁扣中心一致。
- 传送门两态共同 `64×96 RGBA`、bottom-center；锁定/激活外框、顶底线和中心一致。
- 必须有真实独立状态图；不得仅用 `modulate` 伪造锁定态。

### 5.3 静态远程怪

- 单张透明 RGBA 静态立绘，逻辑画布和推荐整数显示倍数写入 manifest。
- 与现有普通敌人保持相近轮廓重量，但必须从剪影或持械/能量核心上可识别为远程单位；不得只做普通敌人的色相替换。
- 不包含子弹；工程默认复用现有接受的 `ProjectileDelivery` 与 Boss 弹体资产，除非后续另立美术任务。

## 6. L2 执行与验收门禁

执行侧至少交付：

1. 全部运行 PNG 的尺寸、模式、SHA-256、alpha bbox/coverage、越格扫描；
2. `6×1` 地面、`1×6` 竖墙、`6×4` 背景、外角、内角、平台端帽+4中心+端帽、墙脚连续铺设 QA；
3. atlas 原尺寸逐格图，以及 `2×/3×` Nearest QA；
4. 使用精确 tile 组合的 room preview v2，同时放入玩家、普通敌人、静态远程怪、宝箱与传送门进行尺度复核；该图标记为 QA，不冒充游戏截图；
5. 宝箱两态和传送门两态的共同锚点/底线差异检查；
6. 全库扫描证明任何 `.tscn/.tres/.gd/project.godot` 对本任务新资产引用仍为 0；
7. 原冻结母版 SHA 不变，旧正式宝箱/传送门目录存在且未修改；
8. Git 写操作为 0。

独立 L2 Review 复算尺寸、哈希、alpha、逐格 manifest 和 seam 组合，原尺寸检查运行 PNG/QA；不连接共享 Godot，不建立发布级冷副本。若 atlas 邻接或像素资产无法由现有工具可靠验收，输出 `ESCALATE`，不降低门禁。

## 7. 保护项与禁止事项

- 用户独立 `global_instakill`：`project.godot`、`scripts/player.gd`、对应 runner/UID 和 `tmp/codex-global-instakill-validation-20260813/` 原样保护，不读取、不运行、不修改、不认领。
- `docs/agent_tasks/evidence/task12..34` 历史 `.import` 删除、Task47 未跟踪文档、translation/import/.godot/中文保护文档及其他生成物全部排除。
- 不修改 Task49/52 归档、流程、敌人逻辑、房间、碰撞、UI、资源引用或项目设置。
- 不使用子 Agent；不执行 `git add/commit/push/reset/restore/checkout/clean/stash`。
- 不自行 `ACCEPTED`。完成后只更新为 `REVIEW` 并在本美术对话内交付、冻结；禁止调用 `send_message_to_thread` 跨对话回传中枢。中枢使用 `wait_threads/read_thread` 主动收取。

## 8. 协调记录

- 2026-08-14 上下文压力审计：美术专用对话 idle，无旧任务占用、无压缩信号，既有母版与文档可由任务书完整重建，判定 `GREEN / 可复用`。
- 本任务是后续地图瓦片工程、静态远程怪接线和宝箱/传送门全库迁移的共同资产前置；工程任务不得在本任务 `ACCEPTED` 前消费尚未冻结的运行文件。
- 中枢登记执行对话：`threadId=019ffb00-0624-76a1-85b0-946bdce0f982`，`hostId=local`；派发后首次 `wait_threads(timeoutMs: 0)` cursor=`5eac0109-0137-44f3-8ec6-8736b0bd3f30:3`，状态 `active`。

## 9. Task53 执行交付（2026-08-14）

> 2026-08-14 用户复核退回：第一版精确 atlas 虽满足 47 邻接，但小砖密度过高、与冻结母版的大石块/宽暗面/留黑语言偏离；模拟房间也偏小。Terrain、平台、前景与装饰继续直接提取冻结母版 16 个 raster swatch；L2 返修仅重做背景行 `0–3`，新增九类真实可区分的背景绘制母版，并将 room preview 扩大为 `24×12` 手工宏观分区。下表为本轮返修后的唯一最终推荐。

### 9.1 正式 PNG

| 文件 | 尺寸 | SHA-256 | 状态 |
|---|---:|---|---|
| `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png` | 512×512 RGBA | `2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519` | REVIEW CANDIDATE / FINAL RECOMMENDED |
| `assets/world/interactables/run_reward_chest/chest_closed_v2.png` | 80×72 RGBA | `2714DAC5A5EC44B7C092A7D2F3574FB0E71A6529090138051DE1FA154C400D97` | REVIEW CANDIDATE |
| `assets/world/interactables/run_reward_chest/chest_open_v2.png` | 80×72 RGBA | `CBC4344454B8D0D969545046A53A1B037CDB354091A4D526B5009285E0F74D68` | REVIEW CANDIDATE |
| `assets/world/interactables/run_route_portal/portal_locked_v2.png` | 64×96 RGBA | `B9CFFEAC3D5037FEB793072E6A8317A01A8D2422A230ED9671FC5A59ACC30FFD` | REVIEW CANDIDATE |
| `assets/world/interactables/run_route_portal/portal_active_v2.png` | 64×96 RGBA | `0EDDAA9C484FEDB119C31DA6E081141549FCD4297E7823151C4A2BD330A7C2EA` | REVIEW CANDIDATE |
| `assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png` | 100×100 RGBA | `10C931DD8823F5DA24AA6A6EFC13D00944A0EB57F07BF7AAEE6EC531786F65F1` | REVIEW CANDIDATE |

### 9.2 美术门禁结果

- atlas：`16×16 / 32px` 精确网格，逐格 manifest 共 `256` 条；`47/47` 合法 8 邻接 mask 独立存在，不依赖旋转/镜像；
- 美术来源：Terrain、青色地沿、紫色平台、角块、碎石和晶灯继续以冻结母版 16 个 raster swatch 为像素源；背景使用九类独立辅助绘制母版并匹配冻结母版色板，生成脚本只做切片、色板约束、连接边和 atlas/QA 编排，不以名称或隐藏微点伪造变体；
- 分层：背景 `0–3`、实心 `4–7`、单向平台 `8–10`、前景 `11–12`、装饰/保留空白 `13–15`；
- 平台 center a/b/c 和左右端帽连接边通过逐像素签名检查；64 个背景变体循环边通过左右/上下签名检查；
- 六张正式 PNG 均为 exact RGBA、hard alpha，partial-alpha pixels 为 `0`；
- 宝箱共同可见底线 `y=70`；传送门共同可见底线 `y=92`；bottom-center 对照图完整；
- 同屏整数显示建议：玩家 `2×`、普通敌人 `3×`、Tidal Sentry `3×`、宝箱 `1×`、传送门 `1×`；
- seam QA 覆盖 `6×1` 地面、`1×6` 竖墙、`6×4` 背景、平台 6 格、外角、四内角与 8 格墙脚；
- 原尺寸 atlas、2×/3× Nearest、冻结母版 32px 提取对照、碰撞建议、`1536×832 / 24×12 tiles` room preview v2、锚点和尺度对照均在 `docs/agent_tasks/evidence/task53/qa/`；
- 背景逐格原始像素 SHA：`64/64` 唯一；关键九类 `9/9` 唯一；最大重复组 `1`。专项报告为 `background_uniqueness.csv`、`background_duplicate_groups.csv` 与 `background_variation_summary.md`；
- 24×12 preview 使用全部 `64/64` 个精确背景 tile，单 tile 最大 `10/288`，同一精确 tile 的水平/垂直直邻均为 `0`；宽暗面以手工 4×3 宏观分区聚合，背景构成为基础墙 `236/288`、裂纹 `16/288`、沟槽/暗拱/宏观/克制强调 `36/288`；使用频次见 `preview_background_usage.csv`；
- 自动结果 `docs/agent_tasks/evidence/task53/reports/automated_gate_results.csv`：`23/23 PASS`；逐格 bleed、边签名、尺寸/alpha/SHA、背景唯一性/使用频次、旧资产指纹与保护指纹均有独立 CSV；
- 允许读取的 runtime `.tscn/.tres/.gd` 引用扫描为 `0`；受保护 `project.godot` 已从当前及后续扫描排除；Task53 输出 `.import` 为 `0`；三张冻结母版 SHA 与任务书一致；旧宝箱/传送门文件仍存在，未删除。

### 9.3 边界声明

- 未创建或修改 `.tscn/.tres/.gd/project.godot/.import`；未执行或控制共享 Godot/editor；
- 未做任何工程接线、Terrain peering、碰撞配置、状态切换、引用迁移、兼容 fallback 或旧资产删除；
- 未执行任何 Git 写操作；未使用子 Agent；未调用跨对话回传；
- Task49/52 未写入；`global_instakill` 未运行、未修改、未认领。已知流程偏差：前四次构建的“新路径引用”只读扫描误包含 `project.godot`，结果为 0 命中且未写入；发现后已永久排除，本任务不声称该文件满足“从未读取”；
- 当前只进入 `REVIEW`，等待中枢派独立 L2 Review；本对话不得自行标记 `ACCEPTED`。

## 10. 独立 L2 Review 退回（2026-08-14）

- Reviewer：`threadId=019ffe70-184c-7a13-9ba2-2bcd59206a00`，`hostId=local`，`model=gpt-5.6-sol`，`thinking=high`。
- Result：`FAIL`；任务退回 `IN_PROGRESS`，Task54 保持依赖阻塞，禁止消费当前 atlas。
- 已通过并可保留：6 张正式 PNG 的尺寸/RGBA/SHA/alpha，`512×512 / 32px / 16×16` 结构，256 个唯一坐标/名称，47/47 Terrain 邻接且无旋转/镜像替代，平台连接边，seam、宝箱/传送门独立状态与锚点、Tidal Sentry 剪影和整数倍尺度。
- 阻塞项：manifest 声称 64 个背景变体，但独立逐格像素 SHA 仅有 4 个唯一图块，重复组为 `33 / 15 / 8 / 8`；`background_wall_base_a/c/d` 相同，`crack_a/b` 相同，`deep_groove/dark_arch` 相同，`macro_block` 与 `base_b` 相同。24×12 preview 的 288 格中有 186 格使用同一像素图块，仍呈现固定小砖网格与周期性暗斑，不满足背景变体合同及“不得出现机械生成器节拍”的视觉门禁。
- 精确返修范围：保留已通过的 Terrain、平台、宝箱、传送门和 Tidal Sentry；只重做真实像素可区分的背景基础/裂纹/凹槽/暗拱/低频大色块，并重新组织 24×12 房间节拍。更新 atlas、逐格 manifest、room preview、相关 QA/报告与本交付记录后再次进入 `REVIEW`。
- 已知流程偏差维持原记录：早期只读扫描误含 `project.godot`，0 命中、无写入；它不构成资产污染，也不是本次 FAIL 的原因。

### 10.1 L2 退回返修完成（2026-08-14）

- 精确返修只写 atlas 背景行 `0–3` 及其 manifest/QA/报告；Terrain、平台、前景与装饰的 atlas 行 `4–15` 原始像素区域 SHA 与退回前完全一致，详见 `reports/background_rework_protected_regions.csv`。
- 宝箱、传送门与 Tidal Sentry 未重画、未改写；五张文件 SHA 与退回前完全一致，详见 `reports/passed_asset_hashes.csv`。
- 新背景结果：`64/64` 像素唯一，关键九类 `9/9` 唯一，最大重复组 `1`；不再存在 `33/15/8/8` 重复组。
- 新 preview：288 格使用全部 64 个精确背景 tile，单块最高 `10/288`，不存在同一精确 tile 的水平/垂直直邻；采用宽暗面宏观分区，裂纹和拱门保持稀疏。
- 新增背景唯一像素、重复组、preview 使用频次和保护区报告，并将对应门禁纳入 `automated_gate_results.csv`；当前 `23/23 PASS`。
- 退回版本 atlas SHA `BCBFD9C748B95DD7C3DC39C34D386997B2C24B44169C65A0139D1E72E2CC0C24` 已被取代，不得冒充最终推荐；当前唯一 REVIEW 候选为 `2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519`。

## 12. 中枢验收与归档（2026-08-14）

- 第二轮独立 L2 Review：`threadId=019ffe70-184c-7a13-9ba2-2bcd59206a00`，`hostId=local`，`model=gpt-5.6-sol`，`thinking=high`，结果 `PASS`。
- 中枢结论：`ACCEPTED`。当前唯一接受 atlas SHA 为 `2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519`；旧 `BCBFD9...` 仅保留在历史退回记录中。
- 接受依据：6 张运行 PNG 尺寸/RGBA/SHA/alpha、256 格 manifest、47/47 Terrain、平台连接边、背景 `64/64` 唯一与九类 `9/9`、24×12 preview 频次和原尺寸视觉门禁、保护区哈希、引用 0、`.import` 0、冻结输入和旧资产完整性均由 Reviewer 独立复算通过。
- 已知只读流程偏差已留档：早期执行扫描误读 `project.godot`，0 命中、无写入；不构成资产污染或额外阻塞。
- 残余风险转交 Task54：Godot TileSet terrain peering、碰撞、one-way 平台和场景组合尚未验证，本任务不声称工程接线完成。
- 当前状态只置为 `REVIEW`，等待中枢再次派独立 L2 Review；本美术对话不自行 `ACCEPTED`。
