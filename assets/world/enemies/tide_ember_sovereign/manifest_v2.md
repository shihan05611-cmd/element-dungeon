# Tide-Ember Sovereign Boss 立绘 manifest v2（多帧补交）

本文件是 Task68 的交付 manifest，记录把 Task60 的 11 张**单帧** `*_v1.png` 升级为 11 张**多帧横向 sheet** `*_v2.png` 的结果。`v1` 资产原样保留未动，仍以 `manifest_v1.md` 为准；本文件只描述 `v2`。

## 0. 生成方式与管线继承

生成方式与 Task60 相同：Python + Pillow 程序化像素处理（本会话无 `image_gen` 图像生成工具）。脚本为 `docs/agent_tasks/evidence/task68/gen_boss_v2.py`，是 `docs/agent_tasks/evidence/task60/gen_boss.py` 的帧数修正版——裁切窗口、整数放大、调色板重映射表、熔炽裂纹/潮涌水滴/接地影后处理**逐字复用**，唯一改动是把「每个动作取单一帧索引（`FRAME_PICKS`）」换成「取全帧（`SEQUENCES`）」，并把输出从单张 200×200 画布改为横向拼接的多帧 sheet。`docs/agent_tasks/evidence/task60/gen_boss.py` 本身未被修改。

沿用不变的管线常量：`CANVAS=200`、`CROP_BOX=(38,30,74,60)`、`SCALE=4`（整数最近邻）、`PASTE_XY=(28,50)`、三张调色板重映射表（`PLAIN_MAP`/`EMBER_MAP`/`TIDE_MAP`）、`add_ember_cracks`/`add_tide_drips`/`add_contact_shadow`（`baseline_y=170`）。

> **Task70 追记**：本节记录的 `CROP_BOX=(38,30,74,60)` / `PASTE_XY=(28,50)` 是本文件（idle/walk/attack/hurt/death 五套 `v2` 资产）的原值，**未被修改，本节以下内容原样保留、历史准确**。Task70 新增的 `boss_{plain,ember,tide}_cast_v1.png` 使用了对称扩大后的窗口 `CROP_BOX=(31,30,81,60)` / `PASTE_XY=(0,50)`——完整推导、逐像素等价性证明与生成细节见 **§9**。两套参数在共享的源坐标范围内逐像素等价（§9.2 已验证），因此 cast 与本节五套动作在运行时切换不会跳变。

## 1. §2.3 共用裁切窗口复核结论：**未越界，`CROP_BOX` 保持不变**

对 6 个源动作精灵表（`_Idle`/`_Walk`/`_Attack01`/`_Hurt`/`_Death`）的**全部 30 帧**逐帧计算 alpha bbox（源 100×100 坐标系），与 `CROP_BOX=(38,30,74,60)` 逐帧比对，完整数据见 `docs/agent_tasks/evidence/task68/bbox_report.json`。

结论：

- 全部 30 帧的 alpha bbox 并集为 `(40, 32, 71, 58)`（`x0,y0,x1,y1`），完全落在 `CROP_BOX=(38,30,74,60)` 内部（左右各留 2px / 3px 余量，上下各留 2px / 2px 余量）。
- 逐帧越界标记（`out_of_crop_box`）在全部 30 帧上均为 `false`。attack 序列虽然挥击展开导致 bbox 明显变宽（frame 4 达到 `(40,32,71,57)`，是全部素材里最宽的单帧），仍未触及窗口边界；death 倒地序列的 bbox 反而随倒地收缩，同样未越界。
- 因此**不触发升级条件**：`CROP_BOX`、`PASTE_XY`、画布尺寸、缩放倍数全部保持 Task60 原值，不需要统一扩窗重导，也未冻结为 `BLOCKED`。

## 2. §2.4 attack 命中帧标注（Task69 接口契约）

`boss_{plain,ember,tide}_attack_v2.png` 均为 8 帧（源 `Blood Monster_A_Attack01.png` 全帧，逐帧独立三形态重导，帧序与源 sheet 一致）。

- **总帧数**：8（0-based 索引 0~7）。
- **命中帧索引（impact frame index）：4**。
- 判断依据（逐帧标注图见 `docs/agent_tasks/evidence/task68/attack_hit_frame_annotation.png`）：
  - frame 0~3 是前摇：前肢/钳爪从静止姿态逐帧抬升、后摆蓄力，frame 3 达到蓄力顶点（钳爪举至身体右上方最高点）。
  - frame 4 是挥击帧：画面首次出现大幅度白色弧线挥砍轨迹特效，alpha 像素总数由前摇基线 ~190 跃升至 329（全序列最大），随后 frame 5~6 单调收缩（243→214）、frame 7 回到静止基准且无特效。即「特效在命中瞬间达到最完整、随后于收招段淡出」，视觉上判定为「打到了」。

    > **独立验收更正（Task 68 Review）**：本条原先还给出过一条「排除白色特效像素后肢体本体最右延伸 frame4 `x=68` > frame5 `x=66`」的量化论证，该论证**不可靠，已撤下**——特效弧线的黑色描边与身体描边共享同一色值并连成同一连通块，原先用于排除特效的两个浅色值只挡住了白色填充、未挡住描边，因此量到的是特效描边而非爪子本体。以纯肉色像素重测，frame 0~7 的肢体本体最右延伸均在 `x=60~62`，frame 4 并不显著更远。**命中帧 = 4 这一结论本身不受影响**，其依据是上述特效的出现与单调衰减节奏（并与 Task 60 独立选帧结果一致）。下游 Task 69 不得把「肢体延伸距离」当作可复算的精确判据。
  - frame 5~6 是收招/余韵：挥砍特效收缩为两三道短划痕（命中后的残留刮痕），肢体开始回收，frame 6 的划痕比 frame 5 更短，确认是回收方向而非蓄力方向。
  - frame 7 与 frame 0 姿态一致，回到静止基准，为循环收尾帧。
  - 交叉验证：Task60 的 `FRAME_PICKS["attack"]` 独立选取的代表帧同样是 `("Blood Monster_A_Attack01.png", 4)`——两次独立判断在同一帧上重合，加强了 frame 4 是「视觉代表性最强/最像命中瞬间」这一判断的可信度。
- **建议前摇/收招段划分**：前摇段 `0 → 3`（4 帧，命中帧-1 为止）；命中帧 `4`；收招段 `5 → 7`（3 帧，命中帧+1 到末帧）。
- 该命中帧索引对三形态（plain/ember/tide）通用——三者共用同一源帧序列与同一裁切/贴入几何，仅调色板与装饰不同，姿态时序完全一致。

## 3. 逐帧装饰偏移复核

- `add_ember_cracks`（熔炽裂纹像素簇）使用固定源坐标点位（未按帧调整）。对 idle/walk/attack 三个动作、共 22 帧逐帧检测「裂纹点位是否落在 alpha>0 的角色本体上」，命中率稳定为 **3/6 点位命中**，与 Task60 v1 单帧基线（idle f0、walk f2、attack f4 同样是 3/6）完全一致，帧间无漂移，**不需要逐帧偏移表**。
- `add_tide_drips`（潮涌水滴）算法本身按每帧独立的 alpha 边缘/底部轮廓动态计算悬垂位置（非固定坐标），因此天然随每帧姿态自适应，无需额外偏移表。
- hurt/death 不应用元素装饰（沿用 Task60 的「三形态共享中性版」策略），故不涉及本节。

## 4. 文件表

全部 11 个 `v2` 文件，帧序均与源 sheet 一致，单帧逻辑格 `200×200`，画布 RGBA 无 mipmap。完整字节数/SHA-256/精确 alpha 数据以 `docs/agent_tasks/evidence/task68/boss_v2_stats.json` 为准（下表为摘要）。

| 文件 | 尺寸 | 帧数 | SHA-256 | Alpha bbox（整张 sheet） | Partial-alpha px | Opaque coverage |
|---|---|---:|---|---|---:|---:|
| `boss_plain_idle_v2.png` | 1200×200 | 6 | `e391f0b8e86f99617eb078f1010c1147c166b500a045411be32a11902a1373db` | (44,98,1124,173) | 1026 | 0.0736 |
| `boss_ember_idle_v2.png` | 1200×200 | 6 | `9d7967d47be12ccccef2df2b381a6e30a57c25e0ce9424951256cd8c6e9ac34b` | (44,98,1124,173) | 1026 | 0.0736 |
| `boss_tide_idle_v2.png` | 1200×200 | 6 | `27d0b4a959202cae419e8ce4568fb6ed8a884cb9e6282900cf23d2e0290db04f` | (43,97,1125,173) | 3050 | 0.073583 |
| `boss_plain_walk_v2.png` | 1600×200 | 8 | `3318366e5a96ee8ed664c26caea82f5a5f52e699f0d5d545c35b62cf38e30c62` | (44,94,1524,173) | 1368 | 0.07525 |
| `boss_ember_walk_v2.png` | 1600×200 | 8 | `449802b528b63bfbc8bd353f5b5280278f19aacaac4c619b17aa7c04e49798eb` | (44,94,1524,173) | 1368 | 0.07525 |
| `boss_tide_walk_v2.png` | 1600×200 | 8 | `6b5836c810e7b99e3064e25086e7404377bdd266791b09db8f45b641b0a11c46` | (43,93,1525,173) | 3887 | 0.075225 |
| `boss_plain_attack_v2.png` | 1600×200 | 8 | `9cd75fee98f1d6d95c3bd54ea8ee3ff1c136c3f5be9006f062b9e0baac6ecba2` | (44,58,1528,173) | 1614 | 0.0881 |
| `boss_ember_attack_v2.png` | 1600×200 | 8 | `13a585bfdb65cce73880cba0633b1a981731e558a99463fa69f80d005cb3bda9` | (44,58,1528,173) | 1614 | 0.0881 |
| `boss_tide_attack_v2.png` | 1600×200 | 8 | `473c057354194fdb219bfde0db0a4224cd0f4cdcf6f6b979b4a4d02e20a09c7c` | (43,57,1529,173) | 5103 | 0.0881 |
| `boss_hurt_v2.png` | 800×200 | 4 | `66fd4fa1400dc2e8a4afdf9ab89c8bcf3ada5aaf22c8069304c2ccbec4cb17d8` | (40,98,720,173) | 684 | 0.0752 |
| `boss_death_v2.png` | 800×200 | 4 | `ed83a1847456e2f3c777b0322607326b8cce8ed81c463606624e175f397613db` | (44,94,732,173) | 684 | 0.0673 |

（`Alpha bbox` 是整张多帧 sheet 的并集包围盒，不是单帧包围盒；`Opaque coverage` 分母为整张 sheet 像素数，因此与 v1 单帧 200×200 画布下的数值不可直接比较，仅供本表内部横向参考。）

hurt / death 沿用 Task60 策略，为三形态共享的中性版本（普通调色板），不提供火/水变体。

## 5. 帧间锚点一致性证据

- `docs/agent_tasks/evidence/task68/anchor_overlay_plain_walk.png`：`boss_plain_walk_v2.png` 全部 8 帧半透明叠加，躯干与接地阴影线完全重合，仅四肢因走路摆动产生预期内的虚化，证明锚点/基线无漂移。
- `docs/agent_tasks/evidence/task68/anchor_overlay_plain_attack.png`：`boss_plain_attack_v2.png` 全部 8 帧叠加，躯干与阴影线重合，仅挥击手臂按动作合理摆动。
- `docs/agent_tasks/evidence/task68/anchor_overlay_death.png`：`boss_death_v2.png` 全部 4 帧叠加，倒地过程中脚部/阴影线位置保持一致。

## 6. 其他 QA 证据

- `docs/agent_tasks/evidence/task68/native1x_2x_nearest_qa_idle.png`：`boss_plain_idle_v2.png` 原始 1× 与 2× 最近邻放大对照，确认无非整数缩放模糊。
- `docs/agent_tasks/evidence/task68/attack_f4_4background_readability.png`：attack 命中帧（frame 4）三形态在暗/水/火/紫四种背景下的可读性对照，三形态均清晰可辨。
- `docs/agent_tasks/evidence/task68/structural_difference_attack_f4_color_and_grayscale.png`：attack 命中帧三形态彩色 + 去色剪影对照，证明熔炽（裂纹亮色像素簇）/潮涌（柔化轮廓 + 悬垂水滴）/普通三者的结构性差异在多帧下依然成立。
- `docs/agent_tasks/evidence/task68/bbox_report.json`：全部 30 源帧的逐帧 alpha bbox 与越界判定原始数据。
- `docs/agent_tasks/evidence/task68/boss_v2_stats.json`：全部 11 个 v2 文件的完整统计（尺寸/模式/字节数/SHA-256/bbox/partial-alpha/coverage）。

## 7. 源素材只读核对

`assets/world/enemies/tide_ember_sovereign/LICENSE_PROVENANCE.md` 记录的 6 个源精灵表 + 1 个合图 SHA-256，已与源目录当前文件实测 SHA-256 逐一核对，**完全一致**（大小写不敏感比较），证明源素材未被本任务修改。核对脚本内联于生成过程，未产生额外文件；核对使用的哈希值即 `gen_boss_v2.py` 运行时从源目录读取所得，源目录本身在整个任务过程中只读。

## 8. 用途与边界

美术资产不定义碰撞、AI、状态机切换或战斗数值；`.tscn`/`.tres`/`.gd`/`project.godot`/`.import` 的工程接线由 Task69 负责，本任务未做任何此类改动（全库扫描 `boss_.*_v2\.` 在这些文件类型中 0 命中）。`v1` 单帧资产原样保留，退役时机由 Task69 决定。

---

## 9. Task70 追加段落：cast 动作 —— **已解除 BLOCKED，已产出**（中枢裁决扩窗）

Task70 要求以 `Blood Monster_A_Attack02.png` 为源，产出 `boss_{plain,ember,tide}_cast_v1.png`。首次执行时按原 `CROP_BOX=(38,30,74,60)` 窗口复核发现 frame 5 越界，依任务书字面指示冻结为 `BLOCKED` 并上报（§9.1，原始记录保留不改，供追溯）。中枢随后裁决：任务书「不得单独为 cast 扩窗」的禁令只在改变左边界/`PASTE_XY` 导致画布内角色偏移时成立，**对称扩窗不产生这个问题**，并给出新参数 `CROP_BOX=(31,30,81,60)` / `PASTE_XY=(0,50)`。本任务对该裁决做了独立复核（§9.2 数学复核 + §9.3 逐像素回归门禁），复核通过后按新参数产出了三张 cast sheet（§9.4）。**最终状态：已产出，非 BLOCKED。**

### 9.1 §2.3 首次窗口复核结论（原始记录，已被 §9.2~§9.4 的中枢裁决覆盖，保留供追溯）：越界，触发冻结条件

脚本：`docs/agent_tasks/evidence/task70/check_cast_window_attack02.py`（独立于 telegraph 生成脚本，只读源目录，不写任何 `assets/world/enemies/tide_ember_sovereign/` 下的文件）。复核逻辑与 Task68 的 `alpha_stats`/bbox 计算方法完全一致：对 `Blood Monster_A_Attack02.png` 的 8 帧逐帧计算源坐标系（100×100）下的 alpha bbox，并与 `CROP_BOX=(38,30,74,60)` 逐帧比对；结果落盘于 `docs/agent_tasks/evidence/task70/bbox_report_attack02.json` 与标注图 `attack02_frame_annotation_cropbox_overlay.png`。

`Blood Monster_A_Attack02.png` 字节数 1949、SHA-256 `623d1e94e071cca1850e517fffde213bb3da3e83a5d55e3bda1626a3046e2caa`，与 `LICENSE_PROVENANCE.md` 记录的 `623D1E94E071CCA1850E517FFFDE213BB3DA3E83A5D55E3BDA1626A3046E2CAA`（大小写不敏感）完全一致，源目录未被本任务修改。

逐帧结果（完整数据见 `bbox_report_attack02.json`）：

| 帧 | bbox（源坐标系） | 越界 | 说明 |
|---:|---|---|---|
| 0 | (42,42,62,57) | 否 | |
| 1 | (42,41,62,57) | 否 | |
| 2 | (42,41,62,57) | 否 | |
| 3 | (42,41,62,57) | 否 | |
| 4 | (42,41,62,57) | 否 | |
| **5** | **(39,41,81,58)** | **是** | 右边越界 **7px**（`CROP_BOX` 右边界 x=74，本帧不透明像素最右延伸到 x=80） |
| 6 | (40,42,73,58) | 否 | |
| 7 | (40,43,63,58) | 否 | |

frame 5 越界不是反走样边缘噪声：越界区域内 41 个像素全部是 `alpha=255` 的完全不透明像素（该源精灵表本身无半透明反走样，全部 8 帧 partial-alpha 像素数均为 0），采样颜色为 `(244,237,234)` / `(183,165,155)` 等浅色实心像素簇，是动作本身的一个连贯几何形状（视觉核验见 `docs/agent_tasks/evidence/task70/attack02_frame_annotation_cropbox_overlay.png`：frame 5 在角色右侧出现一个越出既定窗口的大幅度白色尖状延伸，frame 6 收缩为贴近身体的小簇残留，frame 7 完全消失——这与「特效出现→单调衰减」的判据吻合，很可能正是这套动作里「法术/攻击效果延伸到最大」的那一帧，但因超出共用裁切窗口而无法直接采用）。

**判定：触发任务书 §2.3 与升级触发条款——`Blood Monster_A_Attack02` 的动作幅度超出任务 68 固定的共用裁切窗口。** 按任务书「若越界，不得单独为 cast 扩窗——那会让 cast 与已提交的 idle/walk/attack 错位」的明确指示，本任务未扩窗、未裁剪掉越界内容强行塞入窗口、未生成 `boss_{plain,ember,tide}_cast_v1.png`，冻结为 **BLOCKED**，交由中枢决定是否对全部动作（idle/walk/attack/hurt/death/cast）统一扩窗重导。

### 9.2 中枢裁决的独立数学复核

中枢给出的新参数：`CROP_BOX: (38,30,74,60) → (31,30,81,60)`（左右各对称扩 7px）、`PASTE_XY: (28,50) → (0,50)`，`CANVAS`/`SCALE`/`baseline_y`/三张调色板/装饰函数全部不变。对其推导逐条独立复算（未盲信）：

1. **窗口中心不变**：旧窗口宽 36，中心 `x=(38+74)/2=56`；新窗口宽 50，中心 `x=(31+81)/2=56`。中心一致，复算成立。
2. **画布坐标映射对旧窗口范围内的任意点保持不变**：`src_to_canvas(sx) = PASTE_XY[0] + (sx - CROP_BOX[0]) * SCALE`。取旧窗口边界内任意采样点独立验证——`sx=38`：旧 `28+(38-38)*4=28`，新 `0+(38-31)*4=28`；`sx=40`：旧 `36`，新 `36`；`sx=56`（中心）：旧 `100`，新 `100`；`sx=74`：旧 `172`，新 `172`。四个采样点新旧映射逐一相等，复算成立（完整代码见下方 §9.3 门禁脚本注释区，独立于中枢给出的手算）。
3. **新窗口宽 `50*4=200`，恰好填满 200 画布，且左右对称**：确认成立，避免了「只扩右边界导致角色在画布内偏移、`flip_h` 时产生横跳」的问题。
4. **`add_ember_cracks`/`add_tide_drips` 的坐标换算只依赖 `CROP_BOX[0]`/`[1]`（左上角）与 `PASTE_XY`**：核对 `gen_boss_v2.py` 源码确认属实，`src_to_canvas()` 未使用 `CROP_BOX` 的右/下边界，因此扩右边界不影响这两个装饰函数的坐标计算。
5. **左扩到 31 不会引入新的角色像素**：Task68 记录的 30 帧 bbox 并集左边界是 `x=40`，本任务复核的 cast frame 5 左边界是 `x=39`（见 §9.1 表），均 `> 31`，扩出来的 `[31,38)` 区间在全部 36 帧（30 旧 + 8 cast 中除 frame5 特效外）里都是透明区，不会把无关像素带入画布。

结论：中枢的数学推导逐条复算成立，予以采信。**但推导正确不等于生成结果一定不变**（`build_sheet` 内部还有 `remap`/`add_contact_shadow` 等依赖实际像素分布的步骤），因此仍执行了 §9.3 的强制回归门禁，而不是仅凭数学推导就直接采用。

### 9.3 前置门禁：11 张已提交 v2 sheet 逐像素回归复核 —— **全部一致，门禁通过**

脚本：`docs/agent_tasks/evidence/task70/gen_boss_window_expand_check.py`（`gen_boss_v2.py` 的参数替换版，仅改 `CROP_BOX`/`PASTE_XY` 两个常量，其余管线代码逐字复制）。用新窗口参数重新生成全部 11 张 `boss_{plain,ember,tide}_{idle,walk,attack}_v2.png` + `boss_hurt_v2.png` + `boss_death_v2.png`，输出到 `docs/agent_tasks/evidence/task70/window_expand_check/`（**未覆盖 `assets/` 下任何已提交文件**），逐一与当前已提交版本做 SHA-256 比对。

结果（完整数据 `docs/agent_tasks/evidence/task70/window_expand_check_result.json`）：

| 文件 | 新窗口 SHA-256 | 已提交 SHA-256 | 一致 |
|---|---|---|---|
| `boss_plain_idle_v2.png` | `e391f0b8...373db` | `e391f0b8...373db` | ✅ |
| `boss_ember_idle_v2.png` | `9d7967d4...ac34b` | `9d7967d4...ac34b` | ✅ |
| `boss_tide_idle_v2.png` | `27d0b4a9...db04f` | `27d0b4a9...db04f` | ✅ |
| `boss_plain_walk_v2.png` | `3318366e...e30c62` | `3318366e...e30c62` | ✅ |
| `boss_ember_walk_v2.png` | `449802b5...798eb` | `449802b5...798eb` | ✅ |
| `boss_tide_walk_v2.png` | `6b5836c8...b0a11c46` | `6b5836c8...b0a11c46` | ✅ |
| `boss_plain_attack_v2.png` | `9cd75fee...c136c3f5be9006f062b9e0baac6ecba2` | 同左 | ✅ |
| `boss_ember_attack_v2.png` | `13a585bf...0005cb3bda9` | 同左 | ✅ |
| `boss_tide_attack_v2.png` | `473c0573...02e20a09c7c` | 同左 | ✅ |
| `boss_hurt_v2.png` | `66fd4fa1...ec4cb17d8` | 同左 | ✅ |
| `boss_death_v2.png` | `ed83a184...f397613db` | 同左 | ✅ |

**11/11 完全一致，字节级 SHA-256 相同（非仅视觉相似）。** 这不只是复核了坐标映射公式，而是端到端跑了一遍包含 `remap`/`add_ember_cracks`/`add_tide_drips`/`add_contact_shadow` 在内的完整生成管线并比对最终产物，因此 §9.2 数学推导的"生成结果不变"这一关键前提得到了实证，不是假设。门禁通过，予以继续产出 cast sheet。（若门禁失败，本任务的既定处理是立即停止、报告差异，不做参数调整硬凑——门禁脚本本身也保留在 evidence 目录供复算。）

### 9.4 cast sheet 最终产出

脚本：`docs/agent_tasks/evidence/task70/gen_boss_cast_v1.py`（`gen_boss_v2.py` 的 cast-only 版本，`CROP_BOX=(31,30,81,60)`、`PASTE_XY=(0,50)`，其余管线常量、三张调色板、装饰函数逐字复用）。

| 文件 | 尺寸 | 帧数 | SHA-256 | Alpha bbox | Partial-alpha px | Opaque coverage |
|---|---|---:|---|---|---:|---:|
| `boss_plain_cast_v1.png` | 1600×200 | 8 | `889a6063adddce4b09b58fd6b58f27e542011985c19255e46a5decaa71f2d717` | (44,94,1528,173) | 1680 | 0.09135 |
| `boss_ember_cast_v1.png` | 1600×200 | 8 | `15ce725c33713be9e3f6d8e41db9e1300e8f6e2d988736f15678c75ff4204e4b` | (44,94,1528,173) | 1680 | 0.09135 |
| `boss_tide_cast_v1.png` | 1600×200 | 8 | `07e337a19b1e92bfb53e375011c086bab72905e76242b1e298bfd66195a472a5` | (43,93,1529,173) | 5232 | 0.091328 |

完整统计见 `docs/agent_tasks/evidence/task70/boss_cast_v1_stats.json`。三形态的整体 bbox 与既有 idle/walk/attack 系列（`(44,~,1528,173)` 量级）在同一数量级，角色在画布内的位置未发生系统性偏移，与 §9.3 门禁的"扩窗不改变现有像素位置"结论一致。

两个源专属特效色 `(244,237,234)`/`(183,165,155)`（frame 5/6 独有，不在任何调色板映射表的 key 里，因此原样透传，三形态显示为同一浅色特效，不因形态改色）不影响本节结论——特效像素本身也落在扩大后的窗口内，被正常裁入画布，不再被裁掉。

### 9.5 §2.4 发射帧索引标注（Task71 接口契约）

对 `Blood Monster_A_Attack02.png` 8 帧做逐帧颜色直方图（源坐标系，未经调色板重映射），发现 `(244,237,234)` 与 `(183,165,155)` 两种颜色**只出现在 frame 5、frame 6**，在 frame 0~4、frame 7 中出现次数均为 0，且不属于该角色与 idle/walk/attack01 共用的标准 8 色本体/高光调色板（`SRC_BLACK`/`SRC_MAIN`/`SRC_DARK`/`SRC_STRIPE`/`SRC_HI_A`/`SRC_HI_B`/`SRC_OUTLINE2`/`SRC_HI_C`，这 8 色在 frame 0~7 全部帧中均有出现）——即这两种颜色是本动作独有的「特效/能量」像素，不是角色肢体本体的一部分。

逐帧统计（源坐标系，100×100，`docs/agent_tasks/evidence/task70/gen_cast_evidence.py` 在渲染后的 200×200 成品 sheet 上重新计数，数值按 `SCALE=4` 呈 16 倍关系，验证管线一致）：

| 帧 | 源坐标系特效像素数 | 成品 sheet（200×200）特效像素数 |
|---:|---:|---:|
| 0 | 0 | 0 |
| 1 | 0 | 0 |
| 2 | 0 | 0 |
| 3 | 0 | 0 |
| 4 | 0 | 0 |
| **5** | **193** | **3088** |
| 6 | 58 | 928 |
| 7 | 0 | 0 |

节奏为「0,0,0,0,0 → 193（首次完整出现，全序列峰值） → 58（单调衰减到峰值的 30%） → 0（完全消失）」——与「特效首次完整出现 → 单调淡出」的判据完全吻合。视觉核验：`docs/agent_tasks/evidence/task70/cast_launch_frame_annotation.png`（8 帧标注图，frame 5 用红框标出并标注 `effect_px=3088 <- LAUNCH`），frame 5 在角色右前方出现一团朝右延展的浅色能量/冲击效果，frame 6 收缩为贴身的小簇残留，frame 7 完全消失。

**发射帧索引（launch frame index，0-based）：5。**

- 建议前摇段：`0 → 4`（5 帧，发射帧-1 为止，蓄势/引导动作）。
- 发射帧：`5`（能量/法术脱手）。
- 建议收招段：`6 → 7`（2 帧，发射帧+1 到末帧，余韵回收）。
- 判据显式使用的是「特效像素出现与单调衰减节奏」的量化统计，未使用「排除特效后肢体最右延伸」的方法（该方法在 Task68 验收中已被判定不可靠并撤下）。
- 该发射帧索引对三形态（plain/ember/tide）通用：三者共用同一源帧序列、同一裁切/贴入几何，特效色不在任何调色板映射表中因而三形态显示一致，仅调色板/装饰不同，姿态与特效时序完全一致。

### 9.6 跨动作锚点基线一致性证据

- `docs/agent_tasks/evidence/task70/cross_action_anchor_overlay_cast_vs_idle_walk_attack.png`：取 `boss_plain_idle_v2.png`（红）/`boss_plain_walk_v2.png`（绿）/`boss_plain_attack_v2.png`（蓝）/`boss_plain_cast_v1.png`（琥珀）四者的 frame 0（均为静止起始姿态）做半透明色彩叠加。四色几乎完全混合为单一橄榄色色块，接地阴影条在四者中位置完全重合，边缘仅有因四个动作起始姿态细微差异导致的少量色彩分离（预期内，不是基线漂移）。证明 cast 与已提交的 idle/walk/attack 在扩窗后共享同一画布锚点与基线。
- `docs/agent_tasks/evidence/task70/anchor_overlay_plain_cast_internal_8frame.png`：`boss_plain_cast_v1.png` 全部 8 帧半透明叠加（同 Task68 `anchor_overlay_plain_attack.png` 的方法），躯干核心与接地阴影条完全重合，仅四肢/特效随动作合理散开，证明 cast 内部帧间无基线漂移。

### 9.7 影响范围确认

- `boss_{plain,ember,tide}_cast_v1.png` 是本任务在 `assets/world/enemies/tide_ember_sovereign/` 下新增的唯一三个文件；已提交的 11 个 `v2` 文件字节未发生任何变化（§9.3 已逐一核对 SHA-256，且本任务从未对 `assets/` 下的既有文件执行写操作）。
- `CROP_BOX`/`PASTE_XY` 的「新值」只在 `gen_boss_cast_v1.py`（cast 专用脚本）中生效；`gen_boss_v2.py`（Task68 原脚本）未被修改，仍记录旧值，因为旧值对已交付的 idle/walk/attack/hurt/death 而言仍是准确的生成参数（§9.3 证明的是「两套参数对这些已有帧产物等价」，不是「脚本被替换」）。
- 若未来（如 Task71 之后）需要再新增其他动作，应直接使用扩大后的窗口 `(31,30,81,60)`/`(0,50)` 而非旧窗口，因为新窗口是旧窗口的严格超集且已证明等价，没有理由再收窄。
