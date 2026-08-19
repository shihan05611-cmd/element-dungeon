# Task60 证据索引

生成方式声明：本次执行会话没有 `image_gen` 等图像生成工具，全部资产由 Python + Pillow 程序化像素处理产出（脚本见 `gen_boss.py`、`gen_projectiles.py`，均在本目录）。Boss 三形态基于 itch 购买素材 `Blood Monster_A` 做像素级重绘（调色板重映射 + 结构化新增像素，见 `LICENSE_PROVENANCE.md` 派生规则）；弹体与感叹号为原创几何像素绘制，不基于任何外部素材。

## 文件清单

| 编号 | 文件 | 内容 |
|---|---|---|
| 1 | `stats_consolidated.json` | 全部正式 PNG 的尺寸/模式/SHA-256/alpha bbox/coverage/partial-alpha |
| 2 | `02_anchor_baseline_overlay_3forms_x_3poses.png` | 三形态×三姿态共用画布标注图（绿线=共享基线 y=170，蓝线=参考竖直锚线） |
| 2b | `02b_silhouette_overlay_red_plain_green_ember_blue_tide.png` | 三形态 idle 半透明叠加，验证锚点/基线像素级重合 |
| 3 | `03_boss_native1x_and_2x_nearest_qa.png` | 全部 11 个 Boss 立绘的原尺寸 + 2× Nearest QA |
| 4 | `04_boss_4background_readability.png` | 三形态 idle 在暗/水/火/紫四背景下的可读性 |
| 5 | `05_structural_difference_color_and_grayscale.png` | 火/水相对普通形态并排对照 + 去色剪影仍可区分 |
| 6 | `06_projectile_4background_readability.png` | 四种弹体在四背景下的可读性 |
| 7 | `07_projectile_telegraph_native_and_2x_qa.png` | 弹体/命中特效/感叹号原尺寸 + 2× QA |
| 8 | `08_telegraph_4background_readability.png` | 感叹号单独四背景可读性（任务书 §7.4 要求单独做） |
| 9 | `spec_checklist_self_review.md` | 规范 §9 全部 12 项逐条自检结论 |
| 10 | `10_scale_comparison_player2x_enemy3x_sentry3x_boss2x.png` | 与玩家2×/普通敌人3×/潮汐哨兵3×同屏尺度复核（QA 合成图，非游戏截图） |
| 11 | `reference_scan_and_git_ops.md` | 全库引用扫描=0、`.import`=0、Git 写操作=0、源素材 SHA 未变的核对结论 |
