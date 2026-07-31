from __future__ import annotations

import argparse
from pathlib import Path


RECORD = """

## 13. VFX Agent 第二阶段交付记录（2026-07-30）

结论：第二阶段资产已按用户批准方向收口，任务提交 `REVIEW`；未自行标记 `ACCEPTED`。

### 13.1 稳定最终资产

- 六技能均已生成稳定 `icon.png`，无文字，目标 HUD 尺寸为 32×32 / 64×64。
- 元素弹沿用已接入的 `projectile_water_no_jitter_spritesheet.png` 与 `projectile_fire_no_jitter_spritesheet.png`，未修改 SpriteFrames 或场景接线。
- 元素之怒将用户选定的 8 帧候选像素不变提升为 `assets/generated/vfx/elemental_fury/burst_core.png`。
- 元素激光稳定交付水/火 64×24 可重复 Beam 段、8 帧 Tick 脉冲及 4 组精确 alpha 遮罩。
- 元素回收稳定交付水滴/火焰碎片循环粒子、敌人抽离标记和玩家汇聚闪光；轨迹由后续集成按敌人到玩家的运行时位置计算。
- 燃烧与不息稳定交付 12 帧敌人附着循环及 8 帧触发强调；锚点在 TestRoom QA 后冻结为敌人脚底/身体下缘 `(0.5, 0.84)`。
- 每技能均补齐稳定 `prompt.md` 与 `manifest.md`；总清单为 `docs/vfx/final_asset_manifest.md`，舍弃记录为 `docs/vfx/discarded_variants.md`。

### 13.2 Imagegen 与程序化生产

- 六个最终图标使用内置 `image_gen` 逐技能生成，纯色键背景经官方 `remove_chroma_key.py`、soft matte、despill 和 edge-contract 1 去背。
- 图标统一收口为 256×256 RGBA；严格色键检查发现并清除最后 13 个残余边缘像素。
- 激光、回收、燃烧和不息 VFX 使用 Python 3 + Pillow 12.2.0 确定性合成；生成脚本和最终化/QA 脚本保存在 `docs/vfx/tools/`。
- 回收图标首稿错误加入第三种灰色碎石，已废弃并保留在 `assets/generated/vfx/element_reclaim/discarded/`，最终图标只含水/火。

### 13.3 QA

- 自动 QA：25 个最终 PNG；六图标 256×256 RGBA、透明四角、主体覆盖率合格；可见色键残留 0。
- 激光颜色图/遮罩 4/4 尺寸一致且遮罩像素与颜色图 alpha 完全一致。
- 本版未选用黑底加法纹理；最终资产使用 RGBA alpha 或颜色图+遮罩，该项 N/A。
- Godot 4.7.1 实际运行 TestRoom，生成深色背景 100%/2× 粒子检查、32/64/128 图标缩放检查，以及 Fury 96/192、Beam 320×24、Reclaim 160 权威范围叠加。
- QA 证据位于 `docs/vfx/qa/`：`stage2_qa_report.md`、`stage2_qa_stats.json`、`stage2_icons_scale_qa.png`、`stage2_testroom_particles_qa.png`、`stage2_range_overlay_qa.png`、`stage2_final_overview.png`、`testroom_runtime_base.png`。
- Godot 最终扫描与主场景 smoke 无新增错误；日志仅有既有 combat/growth 脚本 warning，任务 17 未修改这些文件。

### 13.4 后续集成参数

- Fury：从 `burst_submitted(origin, radius, target_count)` 读取权威半径；基础 96、最大 192；一次动画不得产生额外命中窗。
- Laser：5×64×24 段组成 320×24；每个权威 0.5 秒 Tick 可提升整束亮度并在所有合法目标播放脉冲；`delivery_finished` 立即清理。
- Reclaim：权威查询半径 160；仅成功事务播放，每个消耗目标生成 2～4 粒子，建议 0.30～0.48 秒到达玩家。
- Burning/Unending：仅在拥有对应被动且目标存在对应火/水附着时显示循环；触发强调不表示层数消耗。

### 13.5 边界

- 未修改 `combat/**`、`growth/**`、`scripts/**`、Player、Enemy、Host、HUD、Delivery、碰撞、Catalog、SkillDefinition 或正式场景接线。
- 未执行 Git 命令。
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    path = args.project_root.resolve() / "docs" / "agent_tasks" / "pending" / "17_vfx_agent_first_skill_assets.md"
    text = path.read_text(encoding="utf-8")
    if text.count("状态：IN_PROGRESS") != 1:
        raise RuntimeError("Expected exactly one IN_PROGRESS status")
    if "## 13. VFX Agent 第二阶段交付记录" in text:
        raise RuntimeError("Stage 2 record already exists")
    updated = text.replace("状态：IN_PROGRESS", "状态：REVIEW", 1).rstrip() + RECORD + "\n"
    path.write_text(updated, encoding="utf-8")
    print(path)
    print("STATUS=REVIEW")


if __name__ == "__main__":
    main()
