# 任务 68：Boss 多帧动画补齐

状态：ACCEPTED（2026-08-19 独立验收 PASS）
负责人：待指派（美术职责对话）
依赖：无。任务 69（工程接线）依赖本任务。
Git 基线：`main` HEAD `3184f4f`
Review Level：L2
升级触发：共用裁切窗口 `CROP_BOX` 无法容纳 attack / death 的全部帧（角色动作幅度挥出窗口），以致必须改变画布尺寸或锚点时，立即冻结为 `BLOCKED` 并报告，**不得自行改锚点或对个别姿势用不同窗口**；源素材实际内容与 `LICENSE_PROVENANCE.md` 记录不一致时同样冻结。

## 0. 阅读方式

这是任务 60 的**缺帧补交**，不是重做。画布、锚点、裁切窗口、调色板、元素结构差异、接地影全部沿用既有管线；唯一的实质变化是把「每个动作取 1 帧」改成「取全部帧」。

没有风格决策要做。需要动脑的只有两处：§2.3 的共用窗口复核，和 §2.4 的命中帧标注。

---

## 1. 背景事实（已验证）

### 1.1 现状：Boss 是全项目唯一的单帧角色

| 角色 | idle | walk | attack | 来源 |
|---|---|---|---|---|
| 玩家 | 8 帧 | 12 帧 | 8 帧 @20fps | `resources/animations/player_frames.tres` |
| 普通敌人 | 6 帧 | 8 帧 | 6 帧 @11fps | `resources/animations/enemy_frames.tres` |
| **Boss** | **1 帧** | **1 帧** | **1 帧** | `resources/animations/boss_tide_ember_frames.tres` |

Boss 的 11 个动画每个只挂一张 200×200 静态 PNG。直接后果有两个，都已由用户在实机观察到：

- **移动表现为平移**：`*_walk` 无迈步循环，只剩位置位移；
- **近战攻击时序不可读**：单帧 attack 图没有前摇段，`sprite.play()` 那一刻即定格为「已挥出」姿势，必然早于 `melee_telegraph_duration`（0.4~0.45s）之后才生效的判定。任务 69 无法在单帧资产上修好这一点。

### 1.2 缺帧的确切成因

`docs/agent_tasks/completed/60_boss_projectile_and_telegraph_art.md` §5.1 交付口径写的是「11 **套**」，未规定每套帧数；§5.5 对感叹号图标则明确写了「提供 2~3 帧轻微弹跳序列」。Boss 立绘这节漏掉帧数要求，执行侧按字面理解交付单帧，L2 Review 未拦截（该任务 §11.1 说明 Review 明细未进任务书）。

具体位置在 `docs/agent_tasks/evidence/task60/gen_boss.py:19-25`：

```python
FRAME_PICKS = {
    "idle":  ("Blood Monster_A_Idle.png", 0),
    "walk":  ("Blood Monster_A_Walk.png", 2),
    "attack":("Blood Monster_A_Attack01.png", 4),
    "hurt":  ("Blood Monster_A_Hurt.png", 0),
    "death": ("Blood Monster_A_Death.png", 2),
}
```

每个动作**写死了单一帧索引**。管线其余部分（裁切、4× 放大、调色板重映射、熔炽裂纹、潮涌水滴、接地影、alpha/SHA 统计）逐帧可复用，无需重写。

### 1.3 源素材本身是完整多帧的

`Characters(100x100 split)\Blood Monster_A\Blood Monster_A\`（无投影版，与任务 60 同一目录）实测：

| 源文件 | 尺寸 | 帧数 |
|---|---|---:|
| `Blood Monster_A_Idle.png` | 800×100 → 600×100 段 | 6 |
| `Blood Monster_A_Walk.png` | 800×100 | 8 |
| `Blood Monster_A_Attack01.png` | 800×100 | 8 |
| `Blood Monster_A_Attack02.png` | 800×100 | 8 |
| `Blood Monster_A_Hurt.png` | 400×100 | 4 |
| `Blood Monster_A_Death.png` | 400×100 | 4 |

（执行者须自行复核每张 sheet 的实际宽度并按 100px 步长切分，以上帧数为中枢按宽度推算，不作为免核依据。）

### 1.4 锚点一致性天然成立

`gen_boss.py:15-17` 的 `CROP_BOX = (38, 30, 74, 60)` 与 `PASTE_XY = (28, 50)` 是**所有帧共用的固定源空间窗口与固定画布偏移**。沿用同一组常量逐帧导出，多帧之间的锚点/基线一致性自动保持，不会引入帧间抖动。这是本任务能低风险完成的前提，**不得为个别帧调整这两个常量**。

### 1.5 项目多帧动画的引用惯例

`player_frames.tres`（97 个 AtlasTexture）与 `enemy_frames.tres`（24 个）的做法一致：**一个动作 = 一张横向 sprite sheet PNG**，`SpriteFrames` 用 `AtlasTexture` 的 `region` 切帧。本任务须遵循同一惯例，交付横向 sheet，不交付逐帧散图。

---

## 2. 改动需求

### 2.1 交付内容

沿用任务 60 的三形态策略（普通=原始配色，熔炽/潮涌为元素变体，hurt/death 用共享中性版），把 11 套单帧升级为 11 套**多帧横向 sheet**：

| 输出 sheet | 帧数 | 尺寸 | 源 |
|---|---:|---|---|
| `boss_{plain,ember,tide}_idle_v2.png` | 6 | 1200×200 | `_Idle.png` 全帧 |
| `boss_{plain,ember,tide}_walk_v2.png` | 8 | 1600×200 | `_Walk.png` 全帧 |
| `boss_{plain,ember,tide}_attack_v2.png` | 8 | 1600×200 | `_Attack01.png` 全帧 |
| `boss_hurt_v2.png` | 4 | 800×200 | `_Hurt.png` 全帧 |
| `boss_death_v2.png` | 4 | 800×200 | `_Death.png` 全帧 |

每帧仍为 200×200 逻辑格，横向等距排列，帧序与源 sheet 一致。

**`v2` 后缀是硬要求**：`v1` 单帧资产保持原样不动（`docs/agent_tasks/README.md` 禁止覆盖既有正式资产），其退役由任务 69 接线完成后决定。

### 2.2 沿用不变的管线常量

`CANVAS = 200`、`CROP_BOX = (38, 30, 74, 60)`、`SCALE = 4`、`PASTE_XY = (28, 50)`、三张调色板重映射表、`add_ember_cracks` / `add_tide_drips` / `add_contact_shadow` 全部沿用 `gen_boss.py` 既有实现与参数。

熔炽裂纹与潮涌水滴的像素簇坐标是按 `src_to_canvas()` 从源空间换算的（`gen_boss.py:95-96`），逐帧应用时须确认这些装饰在**每一帧的角色身体上**都落在合理位置，而不是浮在空处；若某些帧因姿势变化导致装饰脱离身体，须按该帧重新定位装饰坐标，并在 manifest 记录逐帧偏移表。

### 2.3 共用窗口复核（本任务唯一真实风险）

`CROP_BOX` 是 36×30 的源空间窗口，是按 idle 的静止身体范围定的。attack（挥击展开）与 death（倒地）的动作幅度更大，部分帧可能超出该窗口而被裁掉肢体。

执行者须：

1. 对全部 6 个源动作的**每一帧**计算 alpha bbox，与 `CROP_BOX` 比对，产出逐帧越界报告；
2. 若存在越界，**统一扩大 `CROP_BOX` 到能容纳所有帧的最小窗口**，并相应调整 `PASTE_XY` 使基线（`add_contact_shadow` 的 `baseline_y=170`）保持在原位置，然后**全部 11 套一起重导**；
3. 若扩大后 200×200 画布无法容纳，冻结为 `BLOCKED` 上报，不得自行放大画布或改用非整数缩放。

### 2.4 attack 命中帧标注（与任务 69 的接口契约）

任务 69 需要把 attack 动画的前摇帧段对齐 `melee_telegraph_duration`、命中帧对齐伤害判定。因此 manifest **必须声明** `boss_*_attack_v2.png` 的：

- 总帧数；
- **命中帧索引**（impact frame index）：武器/肢体最前伸、视觉上「打到了」的那一帧，0-based；
- 建议的前摇段（0 → 命中帧-1）与收招段（命中帧+1 → 末帧）帧数划分。

同时提供一张逐帧标注图作为证据，让 Review 可以独立复核该索引判断。这是本任务给下游的唯一接口，标错会直接导致任务 69 白做。

### 2.5 manifest

更新 `assets/world/enemies/tide_ember_sovereign/manifest_v1.md`（或新建 `manifest_v2.md`，任选其一并保持内部引用自洽），须含：全部 v2 PNG 的尺寸、模式、SHA-256、帧数、单帧逻辑格尺寸、alpha bbox/coverage、partial-alpha 像素数、§2.4 的命中帧声明、§2.3 的窗口复核结论、以及若有的逐帧装饰偏移表。

---

## 3. 精确输出 allowlist

```
assets/world/enemies/tide_ember_sovereign/
    boss_plain_idle_v2.png / boss_plain_walk_v2.png / boss_plain_attack_v2.png
    boss_ember_idle_v2.png / boss_ember_walk_v2.png / boss_ember_attack_v2.png
    boss_tide_idle_v2.png  / boss_tide_walk_v2.png  / boss_tide_attack_v2.png
    boss_hurt_v2.png / boss_death_v2.png
    manifest_v1.md（更新）或 manifest_v2.md（新建）
docs/agent_tasks/pending/68_boss_multiframe_animation_art.md
docs/agent_tasks/evidence/task68/**
```

范围外全部只读。

---

## 4. 禁止事项

- **不做任何工程接线**：不创建或修改 `.tscn` / `.tres` / `.gd` / `project.godot` / `.import`。`boss_tide_ember_frames.tres` 由任务 69 负责。
- 不修改、覆盖、删除任何 `v1` 资产或其他既有正式资产。
- 不改变画布尺寸、锚点、基线或缩放倍数（§2.3 的统一窗口扩大是唯一例外，且须全套重导）。
- 不改变三形态的既定配色方向与结构性差异手法；不重新生成风格备选。
- 不使用非整数缩放；不使用高分辨率母版缩小冒充最终资产（`docs/art/像素美术规范_v1.md:35`）。
- 不读取、运行或修改 `tmp/**` 历史冷副本与用户独立 `global_instakill` 相关文件。
- 不执行任何 Git 写操作。
- 不自行标记 `ACCEPTED`；完成后置为 `REVIEW` 并冻结。

---

## 5. 验收条件

1. 11 张 v2 sheet 全部产出，帧数、尺寸、SHA-256 与 manifest 一致；
2. **帧间锚点一致性**：任取一套 sheet，逐帧叠加对照图证明基线与锚点无漂移；
3. §2.3 的逐帧 alpha bbox 越界报告完整，结论（未越界 / 已统一扩窗重导）明确；
4. §2.4 的命中帧索引已声明，且附逐帧标注图；
5. 三形态结构性差异在多帧下仍成立：任取一帧做去色剪影对照，熔炽/潮涌/普通仍可区分；
6. 原尺寸 + 2× Nearest QA 图；暗/水/火/紫四背景可读性对照；
7. 全库扫描证明 v2 资产被 `.tscn` / `.tres` / `.gd` 引用数仍为 0（本任务不接线）；
8. 本任务产出 `.import` 数为 0；Git 写操作数为 0；
9. 源素材 SHA-256 与 `LICENSE_PROVENANCE.md` 记录一致，证明源只读未改。

L2 Review 复算尺寸、哈希、帧数、alpha 统计、锚点叠加图与命中帧标注。命中帧判断存疑时不得放行——它是任务 69 的输入契约。


---

## 6. 验收记录（2026-08-19）

Result：**PASS**。由未参与执行的独立验收 Agent 完成，全部数字独立重算。

- 11 张 v2 sheet 的尺寸/帧数/SHA-256/alpha 统计与 `manifest_v2.md` 逐项一致（bit-for-bit）；
- §2.3：独立从源素材重算 30 帧 alpha bbox，并集 `(40,32,71,58)`，落在 `CROP_BOX=(38,30,74,60)` 内（四边余量 2~3px），窗口无需扩大；attack frame 4 确为全序列最宽单帧；
- §2.4：独立认可**命中帧索引 = 4**，依据为特效首次完整出现（alpha 像素 190→329 为全序列峰值）并在 frame 5~6 单调衰减。**同时指出执行者原「肢体最右延伸 x=68」论证不可靠**（特效描边与身体描边共享色值连成同一连通块，排除色未覆盖描边），该论证已按验收意见从 `manifest_v2.md` 撤下并改述，结论本身不变；
- v1 资产及其 `.import` 未受污染；`.tscn`/`.tres`/`.gd`/`project.godot` 零改动；v2 引用数 0；`.import` 产出 0；
- git HEAD 仍为 `3184f4f`，无新 commit、无 stash；源素材 SHA-256 与 `LICENSE_PROVENANCE.md` 一致；
- 帧间锚点/基线无漂移（`anchor_overlay_*.png` 复核）。

熔炽裂纹 3/6 命中率为既有管线的既存局限（v1 基线即如此），验收方认可「非本任务职责」的表态，不作为否决理由；如需改善另立任务。
