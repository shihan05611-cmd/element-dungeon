# Tide-Ember Sovereign Boss 立绘 manifest v1

生成方式：Python + Pillow 程序化像素处理（本会话无 `image_gen` 图像生成工具）。基于 itch 购买素材 `Blood Monster_A` 做像素级重绘，见 `LICENSE_PROVENANCE.md`。

- 逻辑画布：`200×200`，RGBA，透明背景，`Image.NEAREST` 整数缩放，无 mipmap。
- 推荐世界显示倍数：**2×**（与玩家 2×、普通敌人 3×、潮汐哨兵 3× 同屏比较见 `docs/agent_tasks/evidence/task60/10_scale_comparison_player2x_enemy3x_sentry3x_boss2x.png`；Boss 在 2× 下已具备明显大于普通敌人/哨兵的存在感，取代 `scripts/enemy.gd:226-242` 运行时 1.7× 伪缩放 + 紫描边 shader 的做法——本任务不做该文件的工程改动，仅交付真实尺寸资产）。
- 共用锚点/基线：全部 11 张共用固定源坐标裁切窗口 `(38,30)-(74,60)`、整数 `4×` 放大、固定贴入偏移 `(28,50)`，基线像素行 `y=170`（阴影 `y=170~172`）。逐像素锚点核对见 `docs/agent_tasks/evidence/task60/02_anchor_baseline_overlay_3forms_x_3poses.png` 与 `02b_silhouette_overlay_*.png`。
- 描边分域：普通 `#1A161E`（深中性）、熔炽 `#3A1A18`（深棕紫）、潮涌 `#0E1426`（深蓝黑）。
- 结构性差异（非色相替换）：熔炽形态在肩背条纹区新增亮橙裂纹像素簇；潮涌形态对轮廓做半透明柔化环处理并在底部新增悬垂水滴像素。并排与去色剪影证明见 `docs/agent_tasks/evidence/task60/05_structural_difference_color_and_grayscale.png`。
- hurt / death 为三形态共享的中性版本（沿用普通形态调色板），不提供火/水变体，先例见 `assets/characters/cat/`（`cat_hurt` 无元素变体）。

## 文件表

| 文件 | 尺寸 | 模式 | 字节 | SHA-256 | Alpha bbox | Partial-alpha px | Opaque coverage |
|---|---|---|---:|---|---|---:|---:|
| `boss_plain_idle_v1.png` | 200×200 | RGBA | — | `8361760c7ff73de5...`（完整值见 `docs/agent_tasks/evidence/task60/stats_consolidated.json`） | (44,98,124,173) | 171 | 0.0756 |
| `boss_plain_walk_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (44,98,124,173) | 171 | 0.076 |
| `boss_plain_attack_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (36,58,160,173) | 261 | 0.1316 |
| `boss_ember_idle_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (44,98,124,173) | 171 | 0.0756 |
| `boss_ember_walk_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (44,98,124,173) | 171 | 0.076 |
| `boss_ember_attack_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (36,58,160,173) | 261 | 0.1316 |
| `boss_tide_idle_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (43,97,125,173) | 501 | 0.0756 |
| `boss_tide_walk_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (43,97,125,173) | 474 | 0.076 |
| `boss_tide_attack_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (35,57,161,173) | 963 | 0.1316 |
| `boss_hurt_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (40,98,120,173) | 171 | 0.0752 |
| `boss_death_v1.png` | 200×200 | RGBA | — | 见 stats_consolidated.json | (44,114,124,173) | 171 | 0.0656 |

完整字节数/SHA-256/精确 alpha 数据以 `docs/agent_tasks/evidence/task60/stats_consolidated.json` 为准（本表为摘要，避免手抄误差）。

## 用途与边界

美术资产不定义碰撞、AI、状态机切换或战斗数值；工程接线由 Task61 负责，本任务不做任何 `.tscn/.tres/.gd/project.godot/.import` 修改。
