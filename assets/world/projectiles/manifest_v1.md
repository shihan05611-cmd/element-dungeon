# 弹体 / 命中特效 manifest v1

生成方式：原创几何像素绘制（Python + Pillow，4× 超采样多边形绘制后阈值化 alpha + 整数最近邻降采样），不基于任何外部素材源，无授权问题。本会话无 `image_gen` 图像生成工具。

- **朝向**：全部弹体统一为 **Right-facing**（尖端朝右，匹配 `Vector2.RIGHT` 默认方向）。这与现有 `assets/generated/vfx/boss_arc_projectile/`（Left-facing，见其 `manifest.md:5`）方向相反，属任务书 §5.4 明确要求的基准朝向修正，减少 Task61 的代码侧翻转需求。
- 逻辑画布：弹体 `32×16`，命中特效 `24×24`/帧（4 帧横向拼接，共 `96×24`）。RGBA 透明背景，硬边 alpha（0 或 255，无羽化边缘），`Image.NEAREST` 整数处理。
- 描边分域：熔炽弹 `#3A1A18`、潮涌弹与哨兵弹 `#0E1426` / `#0A2836`、普通弹 `#1A161E`。
- 四背景可读性核对：`docs/agent_tasks/evidence/task60/06_projectile_4background_readability.png`。
- 原尺寸 + 2× QA：`docs/agent_tasks/evidence/task60/07_projectile_telegraph_native_and_2x_qa.png`。

## 文件表

| 文件 | 尺寸 | 模式 | Alpha bbox | Opaque coverage | 朝向 |
|---|---|---|---|---:|---|
| `boss_ember_bolt_v1.png` | 32×16 | RGBA | (1,1,31,14) | 0.5078 | Right |
| `boss_tide_bolt_v1.png` | 32×16 | RGBA | (1,1,31,14) | 0.5078 | Right |
| `boss_plain_bolt_v1.png` | 32×16 | RGBA | (1,1,31,14) | 0.5078 | Right |
| `sentry_tide_bolt_v1.png` | 32×16 | RGBA | (1,1,31,14) | 0.5078 | Right |
| `bolt_impact_v1.png` | 96×24（4 帧×24×24） | RGBA | (5,2,92,22) | 0.4340 | 对称，无朝向依赖 |

完整字节数/SHA-256 见 `docs/agent_tasks/evidence/task60/stats_consolidated.json`。

## 用途与边界

美术资产不定义碰撞、飞行速度/弧线、命中判定或伤害数值；工程接线由后续任务负责，本任务不做任何 `.tscn/.tres/.gd/project.godot/.import` 修改。
