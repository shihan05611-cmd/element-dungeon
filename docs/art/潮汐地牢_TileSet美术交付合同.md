# 潮汐地牢 TileSet 美术交付合同

状态：Task53 精确 atlas 与 QA 已完成，等待独立复核；Godot TileSet 尚未配置  
默认工程方案：Godot `TileSet + TileMapLayer`  
本文件边界：定义可切片、可平铺的美术资产合同；不创建 `.tres`、不配置 TileMapLayer、不接场景、不删除旧素材  
明确排除：Task49、Task52

## 1. 冻结决定

潮汐地牢采用以下视觉母版作为正式瓦片方向：

`C:\Users\heliashi\Documents\元素地牢-4.7\assets\art_preview\tiles\dungeon_tileset_v1.png`

- 状态：`FINAL SELECTED VISUAL MASTER`；
- 当前尺寸：1254×1254 RGBA；
- SHA-256：`44508C796CD7D4D4D5DE7F181F84A51F382C7E208604103033268E659EE7E8D6`；
- 内容：4×4 概念集合，包含墙面、地面、平台、角块、碎石与晶体灯；
- 用途：冻结颜色、材质、像素颗粒、左上光源和构件语言；
- 限制：该冻结母版不是精确 32×32 atlas，不允许直接配置为 Godot TileSet；Task53 正式 atlas 位于 `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`。

Task53 已以此母版为视觉依据整理到固定 32×32 网格。除非工程预研证明 TileSet + TileMapLayer 的实际代价明显过高，并由新中枢回报用户重新对齐，否则不得改用大量 Polygon2D、独立 Sprite2D 拼墙或其他临时方案代替正式瓦片地图。

## 2. 基准尺寸与显示比例

| 项目 | 冻结值 |
|---|---:|
| 逻辑 tile | 32×32 px |
| 推荐世界显示 | 2×，即每格 64×64 world pixels |
| 可选显示 | 1× / 3× / 4×整数倍 |
| 禁止显示 | 任意非整数缩放、双线性过滤 |
| TileSet tile size | 32×32 |
| Atlas texture region size | 32×32 |
| Atlas margin | 0 |
| Atlas separation | 0 |
| Filter | Nearest / Disabled |
| Mipmaps | Disabled |
| Repeat | Disabled |
| 压缩 | Lossless |

所有构件边界必须落在 32px 网格上。需要越格的拱门、立柱、藤蔓、前景石块等装饰使用 32px 整数倍区域，例如 32×64、64×64、64×96；不得使用 45×61 等任意尺寸后再缩放。

## 3. 正式 atlas 结构

建议正式运行 atlas：

`assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`

冻结规格：

- 512×512 RGBA；
- 16列×16行；
- 单元格严格 32×32；
- 原点左上角 `(0,0)`；
- 单元格坐标使用 `(column,row)`；
- 空白格保持全透明；
- 不设置图块间 gutter；最近邻、无 mipmap 条件下避免 TileMap 拼缝；
- 所有像素必须在对应格内，普通 tile 不得越界污染相邻格。

### 3.1 atlas 分区

| 行范围 | 用途 | 碰撞 | 主要内容 |
|---|---|---|---|
| `0–3` | 背景墙与远景 | 无 | 深色砖墙、破损墙、凹槽、暗拱墙、低对比变体 |
| `4–7` | 实心地面/墙体 Terrain | 有 | 地面顶边、墙体、内外角、墙脚、上下左右邻接组合 |
| `8–10` | 单向平台 | 单向 | 左端、中心、右端、破损中心、上下装饰边 |
| `11–12` | 前景遮挡 | 默认无 | 前景石沿、近景碎岩、短立柱、悬垂边 |
| `13–15` | 独立装饰 | 默认无 | 碎石、裂缝、晶体壁灯、暗晶簇、墙钉/支架 |

每个分区内部仍按 32×32 单元排列。64×64 或更大的装饰必须占用连续矩形单元，并在清单中声明其 atlas region。

## 4. Terrain 与邻接资产

### 4.1 实心地形 Terrain Set

正式地面/墙体使用一个主 Terrain Set：`tidal_stone_solid`。美术至少交付以下邻接：

- 独立块；
- 四向实心中心；
- 上边、下边、左边、右边；
- 左上、右上、左下、右下外角；
- 左上、右上、左下、右下内角；
- 横向细段、纵向细段；
- T 形三向连接四种；
- 十字连接；
- 地面顶边到墙体的过渡；
- 墙脚到地面的过渡。

如果工程使用完整 3×3 Terrain peering bits，优先制作完整 47-tile 邻接集合；不得只交付截图中 16 个概念块后让工程通过旋转、镜像或拉伸补齐。石块受左上光影响，默认不允许自动旋转替代独立角块。

### 4.2 平台集合

单向平台不强行塞入实心 Terrain Set，作为独立 atlas tile 集合交付：

- `platform_left_cap`；
- `platform_center_a/b/c`；
- `platform_right_cap`；
- `platform_broken_left/right`；
- `platform_support_short/tall`，仅装饰；
- 可选 `platform_underhang_a/b`，不改变碰撞上沿。

平台中心变体的左右边界像素必须完全一致，允许随机交替；左右端帽只改变外侧轮廓，连接侧必须与中心块逐像素一致。

## 5. TileMapLayer 分层建议

美术文件按以下视觉职责准备；工程可调整节点名，但不能合并导致碰撞、遮挡和调色失去独立控制：

| 建议 TileMapLayer | 视觉职责 | 建议 z | 碰撞 |
|---|---|---:|---|
| `FarBackdrop` | 最远纯色/大块轮廓 | -30 | 无 |
| `BackgroundWall` | 可平铺砖墙、暗拱、凹槽 | -20 | 无 |
| `BackDecor` | 壁灯、暗晶、墙裂、后景支架 | -10 | 无 |
| `SolidTerrain` | 地面、墙体、实心台阶 | 0 | 实心 |
| `OneWayPlatform` | 可从下方穿过的平台 | 1 | 单向 |
| `FrontDecor` | 前景石沿、近景碎岩、悬垂遮挡 | 10 | 默认无 |

交互物不属于上述 TileMapLayer：

- 宝箱继续作为独立 `Node2D/Sprite2D` 交互对象；
- 传送门继续作为独立 `Node2D/Sprite2D` 交互对象；
- 敌人、玩家、弹体、掉落物和 VFX 均不进入地形 atlas；
- 不得为了减少节点数把宝箱或传送门烘焙进地形 tile。

## 6. 无缝边缘门禁

### 6.1 通用规则

- 所有可重复 tile 的对应边必须逐像素一致；
- 左/右循环 tile 在 `x=0` 与 `x=31` 处的结构、亮度和色相必须可连续；
- 上/下循环 tile 在 `y=0` 与 `y=31` 处必须可连续；
- 地面顶边保持至少 2 个逻辑像素连续，不被噪点切断；
- 砖缝可以跨格，但必须在邻格继续，不能在边界突然终止；
- 主高光不得固定出现在每格中心，否则连续铺设会形成灯串；
- 裂纹、缺口、亮砖只放在变体中，不进入基础中心 tile。

### 6.2 必做拼接测试

每次正式交付至少产出以下无 UI QA 图：

- `6×1` 地面中心连续铺设；
- `1×6` 竖墙连续铺设；
- `6×4` 背景墙矩形铺设；
- 左端 + 4中心 + 右端的平台；
- 四个外角围合；
- 四个内角凹室；
- 实心地面与墙脚连续 8 格；
- 在 100%、200%、300% 最近邻显示下分别检查一次。

任何肉眼可见的亮线、黑缝、砖缝断裂或固定重复节拍均不得进入正式 atlas。

## 7. 可重复变体

### 7.1 背景墙

至少提供：

- 4个基础砖墙变体；
- 2个轻微裂纹变体；
- 1个深凹槽变体；
- 1个暗拱/封门变体；
- 1个低频大色块变体。

推荐权重：基础变体合计 70%，裂纹 15%，凹槽/暗拱 10%，其他 5%。变体只改变内部纹理，四边无缝接口必须一致。

### 7.2 实心地面

- 每种中心邻接至少 3个内部纹理变体；
- 端点和角块至少 2个变体；
- 不允许变体改变地面顶线或碰撞轮廓；
- 高亮青色顶边的亮点位置应错开，避免周期性重复。

### 7.3 平台

- 中心块至少 3个变体；
- 破损平台作为显式构件，不参与普通随机替换；
- 支撑件和下挂装饰不影响单向碰撞。

## 8. 碰撞轮廓建议

碰撞最终由工程配置，美术必须提供清楚、稳定、可映射的视觉轮廓：

| 类型 | 建议碰撞 |
|---|---|
| 完整实心墙/地面 | 32×32 整格矩形 |
| 有青色顶边的地面 | 顶面碰撞固定在统一 y，不追随小缺口 |
| 单向平台 | 仅顶部水平线/窄矩形；统一高度；启用 one-way |
| 左右端帽 | 与中心平台使用相同顶部碰撞，不按装饰突起扩张 |
| 破损平台 | 若仍可站立，碰撞保持完整；若真实缺口可掉落，必须做独立 tile 和独立 collision，不靠随机变体 |
| 背景墙/裂纹/壁灯 | 无碰撞 |
| 碎石、暗晶等小装饰 | 默认无碰撞 |
| 前景遮挡 | 默认无碰撞，避免玩家被不可见边缘卡住 |

视觉顶线与碰撞顶线偏差不得超过 1 个逻辑像素。不得为了匹配细小石块锯齿制作复杂碰撞多边形。

## 9. 装饰件交付

装饰件与基础 tile 使用同一 32px 模数，但独立于 Terrain 随机铺设：

- 32×32：小碎石、单裂纹、墙钉、微型晶体；
- 32×64：晶体壁灯、窄立柱、垂挂构件；
- 64×32：碎石堆、墙脚残片；
- 64×64：暗拱、封门、较大晶簇；
- 64×96：前景短柱或大型墙饰，仅在不遮挡角色识别时使用。

装饰亮度低于交互物。晶体壁灯允许局部青色亮心，但不得比激活传送门更亮；单屏建议 1–3 个发光装饰，避免把墙面变成均匀灯带。

## 10. 独立宝箱与传送门

宝箱和传送门继续遵守：

`docs/art/宝箱与传送门正式采纳交接清单.md`

它们不进入 `tidal_dungeon_atlas_v1.png`：

- 宝箱：关闭/开启两张独立 RGBA Sprite，推荐 80×72 逻辑画布；
- 传送门：锁定/激活两张独立 RGBA Sprite，推荐 64×96 逻辑画布；
- 共同使用 bottom-center 锚点；
- 可随房间类型做整体色调适配，但不能改变轮廓、状态语义或像素颗粒；
- TileMapLayer 只提供它们站立的地面，不持有交互状态。

## 11. Task53 正式美术交付物

Task53 已交付：

1. `tidal_dungeon_atlas_v1.png`：512×512 RGBA，16×16 严格网格；
2. `tidal_dungeon_atlas_v1_manifest.md`：逐格 atlas 坐标、名称、层级、Terrain/装饰类型；
3. `tidal_dungeon_collision_guide.png`：碰撞上沿与整格/单向建议示意；
4. `tidal_dungeon_seam_qa.png`：无缝门禁组合图；
5. `tidal_dungeon_room_preview_v2.png`：使用精确 tile 拼出的组合预览；
6. 原尺寸逐格检查与 2×/3×最近邻检查记录；
7. SHA-256、尺寸、alpha、空白格和越格占用清单。

正式 atlas 精确信息：

- 路径：`assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`；
- SHA-256：`2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519`；
- 规格：`512×512 RGBA`，`16×16` 网格，cell `32×32`，margin/separation 均为 `0`；
- 行职责：`0–3 BackgroundWall`、`4–7 SolidTerrain`、`8–10 OneWayPlatform`、`11–12 FrontDecor`、`13–15 BackDecor/blank reservations`；
- `SolidTerrain` 包含全部 `47/47` 合法 8 邻接 mask，逐格独立绘制，不依赖旋转/镜像；
- Terrain、平台、前景与装饰像素直接来自冻结母版 16 个 raster swatch 的 32px 目标尺寸提取；背景行 `0–3` 使用九类独立辅助绘制母版（4 基础、2 裂纹、深沟槽、暗拱、低频宏观墙）并匹配冻结母版色板，脚本只承担切片、色板约束、无缝边、atlas 排列与 QA；
- 背景为 `64/64` 原始 RGBA 像素哈希唯一，关键九类为 `9/9` 唯一，最大重复组为 `1`；24×12 预览使用 `64/64` 个精确背景 tile，单 tile 最大频次 `10/288`，同一精确 tile 的水平/垂直直邻均为 `0`；
- 逐格名称、层级、碰撞建议、随机规则与空白标记：`assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1_manifest.md`；
- 原尺寸、2×、3×、母版 32px 提取对照、拼缝、碰撞和 `24×12` 精确大房间预览：`docs/agent_tasks/evidence/task53/qa/`；
- 背景专项复核：`docs/agent_tasks/evidence/task53/reports/background_variation_summary.md`、`background_uniqueness.csv`、`background_duplicate_groups.csv`、`preview_background_usage.csv`；
- 机器检查：`docs/agent_tasks/evidence/task53/reports/automated_gate_results.csv`，Task53 美术门禁 `23/23 PASS`。

美术交付不包括 `.tres`、TileSet terrain peering 配置、TileMapLayer 场景接线或碰撞资源写入；这些由新中枢另派工程对话完成。

## 12. 验收清单

- [x] atlas 为 512×512 RGBA；
- [x] 单格严格 32×32，原点/行列无偏移；
- [x] 基础 tile 无越格像素；
- [x] 所有循环边通过无缝测试；
- [x] 实心 Terrain 邻接完整；
- [x] 平台端帽/中心连接逐像素一致；
- [x] 背景、实心、单向、前景与装饰职责可分层；
- [x] 变体不改变碰撞轮廓；
- [x] 背景亮度低于角色与交互物；
- [x] 宝箱和传送门未进入 atlas；
- [x] 未修改任何工程场景、脚本、资源配置或正式旧素材；
- [x] 未触碰 Task49、Task52。

以上勾选只代表 Task53 美术自检完成，不代表独立复核 `ACCEPTED`，也不代表 Godot `.tres`、Terrain peering bits、碰撞或 TileMapLayer 已配置。
