# 任务 70：Boss 远程施法动作与多型预警图标集

状态：ACCEPTED（2026-08-20 独立验收 PASS）
负责人：待指派（美术职责对话）
依赖：任务 68（已 ACCEPTED，本任务沿用其管线常量）。任务 71（工程接线）依赖本任务。
Git 基线：`boss/task68-69-multiframe-and-timing` HEAD `1cfb1c8`
Review Level：L2
升级触发：`Blood Monster_A_Attack02` 的动作幅度超出任务 68 已固定的共用裁切窗口，以致必须改变画布/锚点/基线（会破坏与 idle/walk/attack 的对齐）时，冻结为 `BLOCKED` 上报；三型预警图标无法在去色后靠形状区分时同样冻结，不得靠降低区分度交付。

## 0. 阅读方式

两块互不相关的资产，可并行做：§2 是 Boss 的远程施法动作，§3 是三型预警图标。

§2 与任务 68 是同一条管线，常量一律沿用，不重新调参。唯一要动脑的是窗口复核与发射帧标注——和任务 68 的做法完全一样。

---

## 1. 背景事实（已验证）

### 1.1 远程攻击目前在借用近战动作

任务 69 让远程攻击第一次有了动画，但用的是**近战 attack 剪辑的前摇段 + `speed_scale` 拉伸**（熔炽 0.889 / 潮涌 0.800 / 普通 1.000），并在发射帧 snap 到 attack 的命中帧 4。这是当时没有施法资产的权宜之计，用户反馈要求远程「自然地释放，不要调用近战攻击动作」。

### 1.2 源素材有一套完全未使用的攻击动作

任务 60/68 用的都是 `Blood Monster_A_Attack01.png`。同目录的 **`Blood Monster_A_Attack02.png`（800×100，8 帧）从未被使用**，是同一角色的第二套攻击动作，风格、骨架、基线天然一致——用作远程施法动作不需要任何新美术风格决策。

源目录（itch 购买，许可记录见 `assets/world/enemies/tide_ember_sovereign/LICENSE_PROVENANCE.md`）：
```
Characters(100x100 split)\Blood Monster_A\Blood Monster_A\Blood Monster_A_Attack02.png
```

### 1.3 预警图标交付了但从未被接线

任务 60 交付了 `assets/world/ui_world/telegraph/`：

| 文件 | 尺寸 | 说明 |
|---|---|---|
| `telegraph_alert_v1.png` | 96×32（3 帧 × 32×32） | 轻微弹跳序列 |
| `telegraph_alert_static_v1.png` | 32×32 | reduced-motion 降级版 |

其 `manifest_v1.md` 末行写着「工程接线由后续任务负责」，**而那个后续任务从未派发**。全库 `grep telegraph_alert` 命中 0：游戏里现在显示的感叹号是 `scenes/combat/enemy_telegraph_indicator.tscn` 里一个 `font_size = 40`、`text = "!"` 的 **Label**。接线是任务 71 的职责，本任务只补齐缺失的图标类型。

### 1.4 预警不分类型，玩家无法判断该做什么

近战、远程、召唤三种攻击共用同一个黄色 `!`。玩家看到它无法判断该后退、侧闪还是抢打断。（召唤目前甚至完全没有预警——`_start_summon()` 是瞬发的。）

---

## 2. 改动需求 A：Boss 远程施法动作

### 2.1 交付内容

| 输出 | 帧数 | 尺寸 | 源 |
|---|---:|---|---|
| `boss_plain_cast_v1.png` | 8 | 1600×200 | `Blood Monster_A_Attack02.png` 全帧 |
| `boss_ember_cast_v1.png` | 8 | 1600×200 | 同上 |
| `boss_tide_cast_v1.png` | 8 | 1600×200 | 同上 |

横向 sheet，每帧 200×200，帧序与源一致。`hurt`/`death` 已有共享中性版，本任务不重复交付。

命名用 `v1`（这是该动作的首版，不是 v2 的补交）。

### 2.2 沿用任务 68 的全部管线常量

复用 `docs/agent_tasks/evidence/task68/gen_boss_v2.py`：`CANVAS = 200`、`CROP_BOX`、`SCALE = 4`、`PASTE_XY`、三张调色板重映射表、熔炽裂纹、潮涌水滴、接地影，**一律不重新调参**。脚本副本写到 `docs/agent_tasks/evidence/task70/`，不改动 task68 的脚本。

⚠️ **这一条是硬要求**：cast 与 idle/walk/attack 会在运行时互相切换，共用画布与基线是「切换不跳变」的唯一保证。

### 2.3 窗口复核（同任务 68 §2.3）

`CROP_BOX` 是按 idle 静止姿势定的。Attack02 是另一套动作，幅度未知。逐帧计算 alpha bbox 与窗口比对，产出越界报告。

**若越界，不得单独为 cast 扩窗**——那会让 cast 与已提交的 idle/walk/attack 基线错位。此时冻结为 `BLOCKED` 上报，由中枢决定是否重导全套。

> **中枢事后修正（本任务执行中触发）**：上面这条禁令写得过于笼统，实际执行中确实触发了 BLOCKED（`Attack02` frame 5 右侧越界 7px），裁决后证明**对称扩窗并不会错位**，禁令应精确表述为：
> - **单边扩窗**才会出问题——不是因为基线错位，而是因为角色不再居于画布中央，`flip_h` 转身时会横跳（本例中会跳 28px）；
> - **对称扩窗**（左右扩同样多，`PASTE_XY` 相应左移）保持窗口中心不变，角色在画布中的映射坐标完全不变，对已交付资产是**字节级 no-op**。本例实测：`CROP_BOX (38,30,74,60) → (31,30,81,60)`、`PASTE_XY (28,50) → (0,50)`，用新参数从零重导 11 张已提交 v2 sheet，SHA-256 **11/11 逐字节相同**（独立验收方另行从零转录管线复算 14/14 一致）。
> - 另需注意 `gen_boss_v2.py` 的 `src_to_canvas()` 只依赖 `CROP_BOX` 的左上角，装饰（熔炽裂纹/潮涌水滴）坐标不受右边界影响。
>
> 后续同类任务可直接采用对称扩窗，无需再冻结上报；仅当对称扩窗后仍装不下、或必须改变基线/画布/缩放倍数时才需 `BLOCKED`。

（参考：任务 68 实测 6 个动作 30 帧的 bbox 并集为 `(40,32,71,58)`，窗口 `(38,30,74,60)` 四边余量仅 2~3px，余量不大。）

### 2.4 发射帧索引标注（与任务 71 的接口契约）

同任务 68 的命中帧契约。manifest 必须声明 `boss_*_cast_v1.png` 的：

- 总帧数；
- **发射帧索引（launch frame index）**，0-based：施法动作里「法术脱手 / 能量放出」的那一帧，任务 71 会把弹体生成对齐到它；
- 建议的前摇段（0 → 发射帧-1）与收招段（发射帧+1 → 末帧）划分。

附逐帧标注图供独立复核。

> **任务 68 的教训**：当时用「排除特效像素后肢体最右延伸」做量化论证，验收发现特效描边与身体描边共享色值连成同一连通块，量到的是特效而非肢体，论证被撤下。**本任务不要重复这个方法**。可靠判据是特效/能量像素的出现与衰减节奏（首次完整出现 → 单调淡出），请直接用它。

---

## 3. 改动需求 B：三型预警图标集

### 3.1 交付内容

| 类型 | 弹跳序列（96×32，3 帧） | 静态降级（32×32） | 状态 |
|---|---|---|---|
| 远程 | `telegraph_alert_v1.png` | `telegraph_alert_static_v1.png` | **已存在，不重做、不修改** |
| 近战 | `telegraph_melee_v1.png` | `telegraph_melee_static_v1.png` | 新增 |
| 召唤 | `telegraph_summon_v1.png` | `telegraph_summon_static_v1.png` | 新增 |

新增两型必须与既有黄色感叹号**同规格**：32×32 逻辑画布、3 帧轻微弹跳（位移幅度与既有一致）、配套单帧静态版、同一描边厚度与颗粒度。

### 3.2 区分度要求（硬门禁）

- **配色**：近战偏红警示色系，召唤偏紫，远程保持既有高饱和黄。三者在暗/水/火/紫四种背景上都必须清晰可读（沿用任务 60 §5.5 的四背景验证方法）。
- **形状**：三型**必须在完全去色后仅凭剪影区分**。只做颜色替换不予通过——颜色不能是唯一的区分维度（色盲玩家、以及战斗中背景本身就是彩色的）。
  - 建议方向：近战用向内收拢的尖锐楔形/交叉刃形（读作「它要打到你身上」），召唤用环形/多点星芒（读作「场上要多出东西」），远程保持感叹号。方向可自行调整，但去色剪影可分辨是硬要求。
- 32px 下必须通过剪影检查（规范 §2.1 图标基准）。

### 3.3 manifest

`assets/world/ui_world/telegraph/manifest_v1.md` 更新（或新建 `manifest_v2.md` 并保持引用自洽）：新增两型的尺寸、模式、SHA-256、alpha bbox/coverage、帧数、弹跳位移量，以及 §3.2 的去色剪影区分证明。

---

## 4. 精确输出 allowlist

```
assets/world/enemies/tide_ember_sovereign/
    boss_plain_cast_v1.png / boss_ember_cast_v1.png / boss_tide_cast_v1.png
    manifest_v2.md（更新，追加 cast 段落）
assets/world/ui_world/telegraph/
    telegraph_melee_v1.png / telegraph_melee_static_v1.png
    telegraph_summon_v1.png / telegraph_summon_static_v1.png
    manifest_v1.md（更新）或 manifest_v2.md（新建）
docs/agent_tasks/pending/70_boss_cast_action_and_telegraph_icon_set.md
docs/agent_tasks/evidence/task70/**
```

范围外全部只读。

---

## 5. 禁止事项

- **不做任何工程接线**：不创建或修改 `.tscn` / `.tres` / `.gd` / `project.godot` / `.import`。接线是任务 71 的职责。
- 不修改、覆盖、删除任何既有正式资产，包括 `telegraph_alert_v1.png` / `telegraph_alert_static_v1.png` 与全部 `boss_*_v1/v2.png`。
- 不改变画布尺寸、锚点、基线、缩放倍数、三形态配色方向（§2.3 越界时冻结上报，不自行处理）。
- 不使用非整数缩放；不用高分辨率母版缩小冒充最终资产。
- 源素材目录只读。
- 不读取或修改 `tmp/**`；不碰 `global_instakill` 相关文件。
- **不执行任何 git 写操作。**
- 不自行标记 `ACCEPTED`；完成后置为 `REVIEW` 并冻结。

---

## 6. 验收条件

1. 3 张 cast sheet + 4 张预警图标全部产出，尺寸/帧数/SHA-256 与 manifest 一致；
2. **cast 与既有 idle/walk/attack 的锚点基线一致**：跨动作逐帧叠加对照图（不只是 cast 内部各帧之间）；
3. §2.3 逐帧 bbox 越界报告完整，结论明确；
4. §2.4 发射帧索引已声明并附逐帧标注图，且判据用的是特效出现/衰减节奏而非肢体延伸距离；
5. **§3.2 三型去色剪影区分证明**：三个图标并排的灰度图，不看颜色能说出哪个是哪个；
6. 三型在暗/水/火/紫四背景下的可读性对照；原尺寸 + 2× Nearest QA；
7. 全库扫描证明本任务新资产被 `.tscn`/`.tres`/`.gd` 引用数为 0；`.import` 产出为 0；Git 写操作为 0；
8. 源素材 SHA-256 与 `LICENSE_PROVENANCE.md` 记录一致。

L2 Review 复算尺寸、哈希、帧数、bbox、跨动作锚点叠加，并**独立判断发射帧索引与三型剪影区分度**——前者是任务 71 的输入契约，后者是本任务的核心玩家价值，两项存疑均不得放行。

---

## 执行结果摘要（Task70 Agent，状态 → REVIEW）

两块资产互不相关。A 部分经历了一次「首次冻结 BLOCKED → 中枢裁决解除 → 独立复核通过 → 产出」的过程，B 部分一次性完成。

### A. Boss 远程施法动作 —— **首次 BLOCKED，中枢裁决扩窗后已产出**

**第一轮**：对 `Blood Monster_A_Attack02.png` 的 8 帧逐帧计算源坐标系 alpha bbox 并与原共用 `CROP_BOX=(38,30,74,60)` 比对，**frame 5 在右侧越界 7px**（41 个完全不透明像素落在窗口外，非反走样噪声）。按任务书 §2.3「若越界，不得单独为 cast 扩窗……冻结为 BLOCKED」的字面指示，冻结上报，未生成任何 cast 文件。

**中枢裁决**：任务书该条禁令写得过于笼统，只在改变左边界/`PASTE_XY` 导致角色在画布内偏移时成立；对称扩窗不会。裁决新参数 `CROP_BOX=(31,30,81,60)`、`PASTE_XY=(0,50)`（左右各对称扩 7px，窗口中心、画布内角色位置均不变），`SCALE`/`CANVAS`/`baseline_y`/调色板/装饰函数不变。

**独立复核（未盲信）**：

1. 数学复核：窗口中心 `x=56` 不变；对旧窗口内 4 个采样点（`x=38/40/56/74`）逐一验证新旧映射公式给出相同画布坐标；新窗口宽 `50*4=200` 恰好填满画布且左右对称；`add_ember_cracks`/`add_tide_drips` 的坐标换算只依赖 `CROP_BOX` 左上角，不受右边界影响；左扩到 31 不会带入新像素（现有 30+8 帧的 bbox 左边界均 `>31`）。五条逐一复算成立。
2. **前置门禁（强制，非可选）**：用新参数重新完整跑一遍 `gen_boss_v2.py` 管线（含 `remap`/`add_ember_cracks`/`add_tide_drips`/`add_contact_shadow`），重新生成全部 11 张已提交的 `idle`/`walk`/`attack`/`hurt`/`death` `v2` sheet，输出到 `docs/agent_tasks/evidence/task70/window_expand_check/`（**未覆盖 `assets/` 下任何已提交文件**），与当前已提交版本逐一 SHA-256 比对：**11/11 完全一致**（`window_expand_check_result.json`）。这不是理论推导，是端到端产物字节级复核，证明扩窗对已交付资产是真正的无操作（no-op）。

门禁通过后，用新参数产出：

| 文件 | 尺寸 | 帧数 | SHA-256 |
|---|---|---:|---|
| `boss_plain_cast_v1.png` | 1600×200 | 8 | `889a6063adddce4b09b58fd6b58f27e542011985c19255e46a5decaa71f2d717` |
| `boss_ember_cast_v1.png` | 1600×200 | 8 | `15ce725c33713be9e3f6d8e41db9e1300e8f6e2d988736f15678c75ff4204e4b` |
| `boss_tide_cast_v1.png` | 1600×200 | 8 | `07e337a19b1e92bfb53e375011c086bab72905e76242b1e298bfd66195a472a5` |

**发射帧索引（launch frame index，0-based）= 5**。判据：对源帧做逐帧颜色直方图，`(244,237,234)`/`(183,165,155)` 两种颜色只出现在 frame 5/6（不属于该角色 idle/walk/attack01 共用的标准 8 色本体/高光调色板），呈现「0,0,0,0,0 → 193（峰值）→ 58（衰减到峰值 30%）→ 0（消失）」的节奏——特效首次完整出现后单调淡出，与 Task68 教训一致，**未使用**「排除特效后肢体最右延伸」的方法。跨动作锚点叠加（`cross_action_anchor_overlay_cast_vs_idle_walk_attack.png`）证明 cast 与 idle/walk/attack 在扩窗后共享同一画布锚点/基线，接地阴影条位置完全重合。

完整推导、逐像素回归门禁原始数据、发射帧统计表全部写入 `assets/world/enemies/tide_ember_sovereign/manifest_v2.md` §9（已从「§9 BLOCKED」改写为「§9 已产出」，原始 BLOCKED 记录保留在 §9.1 供追溯，不删除）。

### B. 三型预警图标集 —— **已完成**（未改动，保持原样）

新增 `telegraph_melee_v1.png` / `telegraph_melee_static_v1.png`（红色对撞双三角楔形）与 `telegraph_summon_v1.png` / `telegraph_summon_static_v1.png`（紫色镂空六角星环），规格（32×32 逻辑画布、3 帧 1px 弹跳、1px 硬边描边、partial-alpha=0）与既有远程型 `telegraph_alert_v1.png` 逐项核对一致。去色剪影区分用 4-连通域 flood-fill 做了量化拓扑证明（召唤是三者中唯一带镂空孔洞、唯一单连通的形状；近战与远程虽同为 2 个不相连色块，但矩形+圆点 vs 对撞三角的基本形状范畴不同），而非仅目测判断。既有远程型两个文件的字节与 SHA-256 复核后确认未发生任何变化。完整记录见 `assets/world/ui_world/telegraph/manifest_v2.md`。

### 证据目录：`docs/agent_tasks/evidence/task70/`

| 文件 | 用途 |
|---|---|
| `check_cast_window_attack02.py` | A 部分第一轮：原窗口 Attack02 越界复核脚本（产出下两项） |
| `bbox_report_attack02.json` | A 部分：8 帧逐帧 alpha bbox / 越界判定原始数据（原窗口） |
| `attack02_frame_annotation_cropbox_overlay.png` | A 部分：8 帧 4× 放大 + 原 `CROP_BOX` 红框标注，供独立目视复核 frame 5 越界 |
| `gen_boss_window_expand_check.py` | A 部分门禁：新窗口参数重导 11 张已提交 v2 sheet 的脚本 |
| `window_expand_check_result.json` | A 部分门禁：11 张 sheet 新旧 SHA-256 逐一比对结果（11/11 一致） |
| `window_expand_check/` | A 部分门禁：新窗口重导出的 11 张 sheet 本体（仅供比对，非交付物） |
| `gen_boss_cast_v1.py` | A 部分：cast sheet 最终生成脚本（新窗口） |
| `boss_cast_v1_stats.json` | A 部分：3 张 cast sheet 的尺寸/帧数/SHA-256/bbox/coverage |
| `gen_cast_evidence.py` | A 部分：发射帧标注图 + 跨动作/内部锚点叠加图生成脚本 |
| `cast_launch_frame_annotation.png` | A 部分：8 帧标注图，frame 5 红框标出 `effect_px=3088 <- LAUNCH` |
| `cross_action_anchor_overlay_cast_vs_idle_walk_attack.png` | A 部分：cast 与 idle/walk/attack frame0 四色叠加，验证跨动作锚点一致 |
| `anchor_overlay_plain_cast_internal_8frame.png` | A 部分：cast 内部 8 帧叠加，验证帧间无基线漂移 |
| `gen_telegraph_v1.py` | B 部分：近战/召唤图标生成脚本 |
| `telegraph_v1_stats.json` | B 部分：4 个新文件的尺寸/模式/字节数/SHA-256/bbox/coverage |
| `telegraph_silhouette_topology.json` | B 部分：三型去色剪影的连通域/孔洞数量化拓扑证明 |
| `telegraph_desaturated_silhouette_comparison.png` | B 部分：三型彩色 + 逐像素去色对照（§3.2 硬门禁核心证据） |
| `telegraph_melee_summon_4background_readability.png` / `..._4x_zoom.png` | B 部分：暗/水/火/紫四背景可读性对照（原尺寸 + 4× 放大） |
| `telegraph_melee_summon_native1x_2x_nearest_qa.png` | B 部分：原始 1× + 2× 最近邻 QA |
| `telegraph_melee_10x_zoom_static.png` / `telegraph_summon_10x_zoom_static.png` | B 部分：单帧 10× 放大逐像素复核图 |

### 存疑点，建议 Review 重点复核

1. **中枢裁决的扩窗数学是否真的对所有未来场景都安全**：本任务复核的是「现有 5 套动作 + cast」这一具体集合下扩窗无操作，结论不能自动外推到「任意未来新动作都不会在扩大后的窗口下越界」——扩大后的窗口仍是有限的 `(31,30,81,60)`，只是把边界推远了，不是取消了边界。
2. **B 部分的「近战/远程同为 2 连通分量」是否构成区分度不足**：论证依据是「分量数相同但单个色块的基本几何形状不同（矩形长条+圆点 vs 两个对撞三角）」，而非分量数本身；Review 应独立判断这一形状级别的区别在 32px 缩略图观感下是否确实「一眼可辨」。
3. **召唤图标的镂空孔洞在移动中/小尺寸/模糊渲染场景下是否会被误判为普通实心图标**——本任务只验证了原尺寸与 2× 最近邻两档，未测试引擎实际渲染管线下的中间缩放/后处理效果，因为那已属于任务 71 的接线与运行时验证范畴。
4. **cast frame 5/6 的特效透传行为**：两个特效色不在任何调色板映射表 key 中，因此三形态（plain/ember/tide）显示为同一浅色特效、不随形态改色——这是刻意保留的行为（因为特效在 attack01 里本来就是这样处理的），但 Review 应确认这个「特效不随形态变色」的观感是否符合预期，还是应该在 Task71 或后续任务里让特效也按形态染色。


---

## 7. 验收记录（2026-08-20）

Result：**PASS**。由未参与执行的独立验收 Agent 完成。

### 7.1 执行过程摘要

A 部分中途因 `Attack02` frame 5 右侧越界 7px（41 个 `alpha=255` 实像素，非反走样噪声）按 §2.3 冻结为 `BLOCKED`——该处理正确。中枢裁决改用**对称扩窗**解除（详见 §2.3 的事后修正块），执行者在动手前自行重推了坐标数学并跑完前置门禁才继续。

### 7.2 独立复算结论

- **对称扩窗数学**：新旧窗口中心均为源坐标 `x=56`；新宽 `50*4=200` 恰好铺满画布且左右对称，不存在单边扩窗导致的 `flip_h` 横跳。
- **前置门禁（分量最重的一项）**：验收方**未采用比对执行者两批成品的做法**，而是逐函数重新转录整条生成管线（调色板表、`add_ember_cracks`/`add_tide_drips`/`add_contact_shadow`、窗口映射），指向同一只读源目录从零重新生成 11 张已提交 v2 + 3 张新 cast，与 `assets/` 下文件逐一比对 SHA-256：**14/14 完全一致**。证明扩窗对已交付资产是真正的字节级 no-op，且 cast 生成过程可复现、非偶然。
- **cast 资产**：3 张 1600×200 / 8 帧，尺寸、帧数、SHA-256、alpha bbox、partial-alpha、opaque coverage 与 manifest §9.4 逐项一致。
- **发射帧索引 = 5**：独立复算 bbox 与颜色直方图，`(244,237,234)` / `(183,165,155)` 两色仅出现于 frame 5（193px）与 frame 6（58px），其余帧为 0；并额外验证该角色标准 8 色调色板在这两帧中完整存在（特效未"顶替"本体色），排除取样误差。视觉核验节奏为 frame 0–4 蓄力无特效 → frame 5 能量爆发 → frame 6 贴身残留 → frame 7 消失。**验收方独立认可 = 5**。
- **方法论评估**：本任务改用「特效色排他性」替代 Task 68 被否决的「排除特效后肢体最右延伸」，从根本上绕开了那个坑——不再依赖能否把特效像素从连通块里摘干净，而是直接判断颜色是否属于跨动作共享的本体调色板，逻辑更稳固。
- **跨动作锚点**：idle/walk/attack/cast 四个 frame0 叠加后主体融合、接地阴影条重合，仅足部因起始姿态天然差异有少量分离（预期内）。
- **B 部分规格**：4 个新图标的尺寸/模式/SHA-256/bbox/partial-alpha/coverage 与 manifest 一致；3 帧弹跳位移（`frame0 == frame2`、1px 上移）三型一致。既有远程型两文件与 Task 60 `stats_consolidated.json` 原始记录**字节级一致**，确未被触碰。
- **去色剪影区分度**：独立实现 4-邻域连通域 + 孔洞 flood-fill，得远程 2 分量/0 孔洞、近战 2 分量/0 孔洞、召唤 1 分量/1 孔洞，与 manifest 拓扑表一致。
- **HEAD** 仍为 `1cfb1c8`，`git stash list` 空；`.import` 无新增（boss 目录 22、telegraph 目录 2）；新资产代码引用数 0；无任何 `.tscn`/`.tres`/`.gd`/`project.godot` 改动。
- 源 `Blood Monster_A_Attack02.png` SHA-256 与 `LICENSE_PROVENANCE.md` 一致。

### 7.3 对执行者两个存疑点的裁定

| 存疑点 | 裁定 |
|---|---|
| 近战与远程同为 2 连通分量，区分依赖形状范畴而非拓扑 | **真实可辨，接受**。去色后感叹号是「细长竖条 + 小圆点」，近战是「两个宽底三角对撞夹一道窄缝」，长宽比与边缘直/弧特征差异明显，在验收方独立生成的灰度图上一眼可辨。区分强度确实弱于召唤（后者有拓扑级差异），与执行者的坦诚披露一致，不构成缺陷。 |
| 召唤镂空孔洞在中间缩放下是否被视觉合并 | **不会，接受**。验收方补做了执行者未覆盖的场景：`32 → 77（双线性放大）→ 32（双线性缩小）` 模拟非整数缩放与轻度模糊，孔洞仍清晰可辨为透空区。孔洞内径 6px（约占 32px 画布 1/5），冗余度足以抵抗常见运行时缩放模糊。 |

补充记录：近战图标在「火」背景下对比度偏低（红色主体与暖棕背景接近），但深色描边仍提供连续边界，属可接受的已知情况，与执行者披露一致。

### 7.4 工作树中 allowlist 外的改动（已核查，与本任务无关）

`CENTRAL_REVIEW_RULES.md`（修改）、`65_*.md`（改名）、`PROMPT_allowlist_cost_model.md`（新增）、`71_*.md`（新增，下一任务任务书）、`run_task69_*.gd.uid`（Godot 为已提交测试脚本自动生成的 uid 元数据，非对 `.gd` 本身的修改）。经内容核查全部与本任务的美术资产工作无关，Task 70 的证据脚本均不写这些路径，判定为同一工作树中其他流程活动的未提交状态，不构成对本任务的否决理由。
