# 黄色感叹号预警图标 manifest v1

生成方式：原创几何像素绘制（Python + Pillow，4× 超采样绘制后阈值化 alpha + 整数最近邻降采样），无外部素材依赖。本会话无 `image_gen` 图像生成工具。

- 逻辑画布：`32×32`（规范 §2.1 图标基准），世界层资产（非 UI 图标缩小挪用，颗粒度与角色资产一致处理流程）。
- 配色：高饱和黄 `#FFD620` 主体 + 浅黄高光 `#FFF096` 单一小簇 + 深棕黑描边 `#2E220A`。
- 四背景可读性（暗/水/火/紫）单独验证：`docs/agent_tasks/evidence/task60/08_telegraph_4background_readability.png`。四种背景下轮廓与描边均清晰可辨。
- 原尺寸 + 2× QA：`docs/agent_tasks/evidence/task60/07_projectile_telegraph_native_and_2x_qa.png`。

## 文件表

| 文件 | 尺寸 | 模式 | Alpha bbox | Opaque coverage | 说明 |
|---|---|---|---|---:|---|
| `telegraph_alert_v1.png` | 96×32（3 帧×32×32） | RGBA | (12,2,84,29) | 0.1660 | 轻微弹跳序列（上移 1px→回落→上移 1px），供非 reduced-motion 播放 |
| `telegraph_alert_static_v1.png` | 32×32 | RGBA | (12,3,20,29) | 0.1660 | 单帧静态版，reduced-motion 降级使用 |

完整字节数/SHA-256 见 `docs/agent_tasks/evidence/task60/stats_consolidated.json`。

## 用途与边界

美术资产不定义预警触发时机、持续时长或绑定逻辑；工程接线由后续任务负责，本任务不做任何 `.tscn/.tres/.gd/project.godot/.import` 修改。
