# 预警图标 manifest v2（近战 / 召唤新增）

本文件是 Task70 的交付 manifest，只记录本任务新增的**近战**、**召唤**两型预警图标。**远程**型 `telegraph_alert_v1.png` / `telegraph_alert_static_v1.png` 未被本任务触碰，规格与哈希以 `manifest_v1.md` 为准（本任务复核过其字节与 SHA-256，与 `manifest_v1.md` 记录完全一致，未发生任何变化）。

## 0. 生成方式

与 `manifest_v1.md` 记载的方法一致：原创几何像素绘制（Python + Pillow），无外部素材依赖，本会话无 `image_gen` 图像生成工具。脚本：`docs/agent_tasks/evidence/task70/gen_telegraph_v1.py`。

流程：8× 超采样绘制几何形状 → `Image.BOX` 降采样求平均 alpha → 按 128 阈值二值化（因此三型与既有远程型一样 partial-alpha 像素数均为 0，颗粒度一致）→ 对二值化后的不透明区域做边界追踪，边界层（4 邻域内存在透明像素的不透明像素）着描边色，内部着主体色，并在一个视觉显著位置留一小簇（约 10~14px）高光色——这一整套着色规则是直接从既有 `telegraph_alert_v1.png` 的实测像素结构（见下）逆向复现的，不是另起一套风格。

### 0.1 与既有远程型的规格对齐核对（实测，非假设）

对 `telegraph_alert_v1.png` 做逐像素分析得到的既有规格，本次两型严格对齐：

- 逻辑画布 `32×32`，弹跳序列 `96×32`（3 帧横向拼接）+ 静态降级 `32×32`。
- 描边 1px，硬边缘（partial-alpha 像素数 = 0），描边色为「主色调 + 近黑」的深色（远程 `#2E220A`，本任务近战 `#2A0A0C`、召唤 `#1A0A2A`，均延续「近黑但带同色调倾向」的配方）。
- 主体色 + 单一小簇高光色（远程 `#FFD620` 主体 + `#FFF096` 高光；近战 `#E6202A` 主体 + `#FFA896` 高光；召唤 `#9620D6` 主体 + `#E0A8FF` 高光）。
- 弹跳机制：帧 1（0-based）= 帧 0 的整帧内容整体上移 1px（顶部被裁掉一行、底部空出一行），帧 2 与帧 0 完全相同像素。**实测确认**远程型帧 0/1/2 的 alpha bbox 分别为 `(12,3,20,29)` / `(12,2,20,28)` / `(12,3,20,29)`，本任务两型逐帧核对同一位移量：近战 `(10,3,22,29)`/`(10,2,22,28)`/`(10,3,22,29)`，召唤 `(4,3,28,29)`/`(4,2,28,28)`/`(4,3,28,29)`，且两型均验证 `frame0 == frame2`（像素级相等）。位移幅度与既有远程型一致（均为 1px），满足任务书「位移幅度与既有一致」要求。

## 1. 文件表

完整字节数/SHA-256/bbox/coverage 见 `docs/agent_tasks/evidence/task70/telegraph_v1_stats.json`（下表为摘要，逐项与该文件一致）。

| 文件 | 尺寸 | 模式 | 帧数 | SHA-256 | Alpha bbox | Partial-alpha px | Opaque coverage |
|---|---|---|---:|---|---|---:|---:|
| `telegraph_melee_v1.png` | 96×32 | RGBA | 3 | `c1d5f63c0eedd1038ad2c3f0abc6ee2a61826880b3dc312b89a7f9a47c68679c` | (10,2,86,29) | 0 | 0.140625 |
| `telegraph_melee_static_v1.png` | 32×32 | RGBA | 1 | `bd77386ba21cfaba09b85d9f1d922be7cf5224528fb6bb26a666575c5937f3cd` | (10,3,22,29) | 0 | 0.140625 |
| `telegraph_summon_v1.png` | 96×32 | RGBA | 3 | `939bfd39c12346b27e656a048942f5eff06e92196ddf20fe644a50716c6bd20a` | (4,2,92,29) | 0 | 0.248047 |
| `telegraph_summon_static_v1.png` | 32×32 | RGBA | 1 | `a2ccf069a642fb8ea6b230e424570275c0e505394c115eb2bcfad8d986058212` | (4,3,28,29) | 0 | 0.248047 |

## 2. 形状设计与 §3.2 去色剪影区分证明（硬门禁）

### 2.1 设计方向

- **近战** `telegraph_melee_v1.png`：两个尖锐三角楔形隔着窄缝相对而立（倒三角在上、正三角在下，尖端相向但不相接），读作「刃锋正从两侧收拢向你」。
- **召唤** `telegraph_summon_v1.png`：六角星芒环绕一个镂空圆环（外径 10px、内径 6px 的环带 + 6 个等角外凸尖刺），读作「场上要多出东西的召唤法阵」。
- **远程** `telegraph_alert_v1.png`：保持既有黄色感叹号，未改动。

### 2.2 量化剪影拓扑证明（非仅目测）

对三型的 `*_static_v1.png` 做 4-邻域连通域 flood-fill 计算（`docs/agent_tasks/evidence/task70/telegraph_silhouette_topology.json`，方法与结果均可独立复算）：

| 类型 | 连通分量数 | 被完全包围的镂空孔洞数 | 形状类别 |
|---|---:|---:|---|
| 远程（alert） | 2 | 0 | 1 根竖条（惊叹号主体）+ 1 个近圆点，互不相连 |
| 近战（melee） | 2 | 0 | 1 个倒三角 + 1 个正三角，互不相连，尖端隔窄缝相对 |
| 召唤（summon） | 1 | **1** | 单一连通色块，中心带完全封闭的透明孔洞（环形） |

结论：

- 召唤型是三者中唯一带镂空孔洞、且唯一单连通的形状——这是与另外两型最强的拓扑区分（孔洞的有无是二值属性，不依赖任何色彩感知）。
- 近战与远程虽同为「2 个不相连色块」，但基本形状范畴完全不同：远程是「矩形长条 + 圆点」的印刷体感叹号造型，近战是「两个对撞的尖锐三角」——即使不看连通数，仅看单个色块的几何形状（有无尖角、边是直线还是弧线、色块是细长还是等边三角）也能立即区分，不依赖矩形/三角形以外的任何色彩线索。
- `docs/agent_tasks/evidence/task70/telegraph_desaturated_silhouette_comparison.png`：三型彩色原图（上排）与逐像素亮度去色版本（下排，`L = 0.299R+0.587G+0.114B`，非简单去饱和度，确保色相差异不会残留为可辨的灰度差异线索）并排对照。去色后凭剪影仍可立即读出「感叹号 / 对撞三角 / 镂空环」三种不同图形，不依赖颜色。
- `docs/agent_tasks/evidence/task70/telegraph_melee_10x_zoom_static.png`、`telegraph_summon_10x_zoom_static.png`：两型静态帧的 10× 最近邻放大图，供逐像素复核描边/主体/高光分区与轮廓形状。

**§3.2 硬门禁判定：通过。** 三型未越过「仅靠颜色替换」的红线——近战与召唤都改变了基本几何形状与连通拓扑，其中召唤额外具备远程、近战都没有的镂空孔洞特征。

## 3. 四背景可读性（暗/水/火/紫，沿用任务 60 §5.5 方法）

背景色直接从 `docs/agent_tasks/evidence/task60/08_telegraph_4background_readability.png` 实测取样复用（暗 `#18141C`、水 `#143C64`、火 `#5A2414`、紫 `#3C145A`），与既有远程型验证使用的同一组背景色，保证跨型可比。

证据：`docs/agent_tasks/evidence/task70/telegraph_melee_summon_4background_readability.png`（原尺寸小图）+ `telegraph_melee_summon_4background_readability_4x_zoom.png`（4× 放大细看边缘）。

结论：近战（红）、召唤（紫）在四种背景下轮廓与描边均清晰可辨。近战在「火」背景（`#5A2414`，暖红棕色调）下主体色与背景色相近、对比度偏低，但深描边仍提供连续可辨边界——与任务 60 记录的「plain 形态在 fire 背景下对比度偏低但描边仍提供可辨边界，属于可接受范围」是同一等级的已知可接受情况，不构成不可读。召唤（紫）在全部四背景下对比度均良好，是四者中最清晰的一组。

## 4. 原尺寸 + 2× Nearest QA

`docs/agent_tasks/evidence/task70/telegraph_melee_summon_native1x_2x_nearest_qa.png`：两型静态帧原始 1× 与 2× 最近邻放大对照，确认无非整数缩放模糊，边缘保持硬边像素块。

## 5. 全库引用扫描

对仓库执行 `telegraph_melee` / `telegraph_summon` 关键字扫描（`*.tscn` / `*.tres` / `*.gd` / `project.godot`），命中 0。`assets/world/ui_world/telegraph/` 目录下未产生任何新增 `.import` 文件（该目录现有 `.import` 文件仍只有既有远程型的 2 个，均未改动）。

## 6. 用途与边界

美术资产不定义预警触发时机、持续时长或绑定逻辑；工程接线（含近战/召唤预警的实际触发条件、`.tscn`/`.tres`/`.gd` 修改）是任务 71 的职责，本任务未做任何此类改动。远程型 `telegraph_alert_v1.png` / `telegraph_alert_static_v1.png` 原样保留，本文件不覆盖 `manifest_v1.md` 对其的记录。
