# 任务 17：许可源素材候选清单

状态：SOURCE CANDIDATE。以下文件已进入项目，但不是最终图标、最终 VFX 尺寸或已接线资源。

本文件是 2026-07-23 授权确认后的最新状态，取代 `free_asset_screening.md` 中“尚未复制外部原图”的预授权说明。用户已确认项目不商用、素材来自正式下载渠道，并允许在本项目中使用。

## 提取规则

- 原图位于 `assets/generated/vfx/_licensed_source/bdragon1727/`。
- 每格 64×64，原图纵向包含 9 套颜色。
- 动态四技能抽取第 6 行（索引 5）的中性白条带，供 Godot 以锁定元素着色。
- `burning` 抽取第 1 行（索引 0）的固定火色。
- `unending` 抽取第 3 行（索引 2）的固定水色。
- 所有候选保留原始 alpha，不进行缩放、插值、补帧或时序修改。

## 技能候选

| 技能 | 候选条带 | 帧数 | 候选用途 |
|---|---|---:|---|
| `element_bolt` | `element_bolt/source_candidates/bolt_projectile_neutral_candidate.png` | 8 | 可着色弹体核心/短拖尾 |
|  | `element_bolt/source_candidates/bolt_straight_neutral_candidate.png` | 14 | 更直、更窄的弹体备选 |
|  | `element_bolt/source_candidates/hit_spark_neutral_candidate.png` | 8 | 命中闪光 |
| `elemental_fury` | `elemental_fury/source_candidates/burst_core_neutral_candidate.png` | 8 | 主爆发核心 |
|  | `elemental_fury/source_candidates/shock_ring_neutral_candidate.png` | 11 | 可校准冲击环 |
|  | `elemental_fury/source_candidates/dissipate_neutral_candidate.png` | 10 | 消散余辉 |
| `elemental_laser` | `elemental_laser/source_candidates/origin_charge_neutral_candidate.png` | 8 | 起点聚能 |
|  | `elemental_laser/source_candidates/hit_pulse_neutral_candidate.png` | 9 | 每 0.5 秒 Tick 命中闪光 |
| `element_reclaim` | `element_reclaim/source_candidates/vortex_neutral_candidate.png` | 13 | 成功汇聚旋涡；需要复核播放方向 |
|  | `element_reclaim/source_candidates/particle_ring_neutral_candidate.png` | 9 | 目标抽离/环形粒子 |
|  | `element_reclaim/source_candidates/orbit_neutral_candidate.png` | 10 | 内收轨迹备选；需要复核反播 |
| `burning` | `burning/source_candidates/fire_marker_color_candidate.png` | 10 | 固定火层小标记 |
| `unending` | `unending/source_candidates/ripple_color_candidate.png` | 12 | 固定水恢复涟漪 |
|  | `unending/source_candidates/splash_color_candidate.png` | 11 | 液滴/溅水关键帧 |

## 未解决项

- 激光没有合格的可平铺 Beam 主体，仍需自制颜色图 + 灰度遮罩。
- 任务 15 仍为 `PENDING`；元素之怒、激光和回收不得冻结最终显示尺寸、锚点与时序。
- 图标仍处于概念阶段；用户确认风格后再生成最终 alpha 图标。
- 回收候选必须在游戏中确认播放方向，确保表现明确向玩家内收。
- 任务 16/12 的集成 Agent 负责材质、帧动画、粒子和正式场景接线。
