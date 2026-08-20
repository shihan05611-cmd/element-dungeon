# Task68 证据索引

生成方式声明：本次执行会话没有 `image_gen` 等图像生成工具，全部资产由 Python + Pillow 程序化像素处理产出，脚本为本目录 `gen_boss_v2.py`——它是 `docs/agent_tasks/evidence/task60/gen_boss.py`（未被本任务修改）的帧数修正版：裁切窗口/整数放大/调色板重映射/熔炽裂纹/潮涌水滴/接地影全部逐字复用，唯一改动是把「每动作取单帧」换成「取全帧并横向拼接为 sheet」。

## 文件清单

| 文件 | 内容 |
|---|---|
| `gen_boss_v2.py` | 本任务的生成脚本（task60 `gen_boss.py` 的帧数修正版，独立副本，未改动原脚本） |
| `bbox_report.json` | §2.3 复核：6 个源动作、全部 30 帧逐帧 alpha bbox 与 `CROP_BOX` 越界判定原始数据；`union_bbox` 为全部帧并集 |
| `boss_v2_stats.json` | 全部 11 个 `v2` 输出文件的尺寸/模式/字节数/SHA-256/帧数/alpha bbox/partial-alpha/opaque coverage |
| `attack_hit_frame_annotation.png` | §2.4 命中帧标注：`boss_plain_attack_v2.png` 8 帧逐帧标签图，frame 4 高亮标注为命中帧，供 Review 独立目视复核 |
| `anchor_overlay_plain_walk.png` | `boss_plain_walk_v2.png` 全 8 帧半透明叠加，验证帧间锚点/基线无漂移 |
| `anchor_overlay_plain_attack.png` | `boss_plain_attack_v2.png` 全 8 帧半透明叠加，验证帧间锚点/基线无漂移（含挥击运动包络） |
| `anchor_overlay_death.png` | `boss_death_v2.png` 全 4 帧半透明叠加，验证倒地过程基线不漂移 |
| `native1x_2x_nearest_qa_idle.png` | `boss_plain_idle_v2.png` 原始 1× + 2× Nearest 放大 QA |
| `attack_f4_4background_readability.png` | attack 命中帧（frame 4）三形态在暗/水/火/紫四背景下的可读性对照 |
| `structural_difference_attack_f4_color_and_grayscale.png` | attack 命中帧三形态彩色并排 + 去色剪影对照，证明多帧下结构性差异仍成立 |
| `reference_scan_and_git_ops.md` | 全库引用扫描=0、`.import`=0、Git 写操作=0、源素材 SHA 未变的核对结论 |

manifest 正文见 `assets/world/enemies/tide_ember_sovereign/manifest_v2.md`（含 §2.3 窗口复核结论、§2.4 命中帧声明、文件表、锚点一致性与源只读核对的完整叙述）。
