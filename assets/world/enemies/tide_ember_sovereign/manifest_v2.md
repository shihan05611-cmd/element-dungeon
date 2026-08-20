# Tide-Ember Sovereign Boss 立绘 manifest v2（多帧补交）

本文件是 Task68 的交付 manifest，记录把 Task60 的 11 张**单帧** `*_v1.png` 升级为 11 张**多帧横向 sheet** `*_v2.png` 的结果。`v1` 资产原样保留未动，仍以 `manifest_v1.md` 为准；本文件只描述 `v2`。

## 0. 生成方式与管线继承

生成方式与 Task60 相同：Python + Pillow 程序化像素处理（本会话无 `image_gen` 图像生成工具）。脚本为 `docs/agent_tasks/evidence/task68/gen_boss_v2.py`，是 `docs/agent_tasks/evidence/task60/gen_boss.py` 的帧数修正版——裁切窗口、整数放大、调色板重映射表、熔炽裂纹/潮涌水滴/接地影后处理**逐字复用**，唯一改动是把「每个动作取单一帧索引（`FRAME_PICKS`）」换成「取全帧（`SEQUENCES`）」，并把输出从单张 200×200 画布改为横向拼接的多帧 sheet。`docs/agent_tasks/evidence/task60/gen_boss.py` 本身未被修改。

沿用不变的管线常量：`CANVAS=200`、`CROP_BOX=(38,30,74,60)`、`SCALE=4`（整数最近邻）、`PASTE_XY=(28,50)`、三张调色板重映射表（`PLAIN_MAP`/`EMBER_MAP`/`TIDE_MAP`）、`add_ember_cracks`/`add_tide_drips`/`add_contact_shadow`（`baseline_y=170`）。

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
