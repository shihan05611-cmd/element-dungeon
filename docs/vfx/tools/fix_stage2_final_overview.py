from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

import run_stage2_qa as qa


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    vfx_root = root / "assets" / "generated" / "vfx"
    output = root / "docs" / "vfx" / "qa" / "stage2_final_overview.png"
    canvas = Image.new("RGBA", (1152, 900), qa.BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((32, 24), "任务 17 第二阶段最终资产总览", fill=qa.TEXT, font=qa.font(32))
    draw.text((32, 68), "稳定 icon.png + 代表帧；候选与源稿保留在各技能目录", fill=qa.MUTED, font=qa.font(17))
    bolt_sheet = qa.rgba(vfx_root / "element_bolt" / "projectile_water_no_jitter_spritesheet.png")
    bolt_frame = bolt_sheet.crop((384, 0, 768, 160))
    rows = [
        ("element_bolt", bolt_frame),
        ("elemental_fury", qa.split_sheet(vfx_root / "elemental_fury" / "burst_core.png", 64, 64)[3]),
        ("elemental_laser", qa.rgba(vfx_root / "elemental_laser" / "beam_segment_water.png")),
        ("element_reclaim", qa.split_sheet(vfx_root / "element_reclaim" / "reclaim_particle_water.png", 32, 32)[2]),
        ("burning", qa.split_sheet(vfx_root / "burning" / "burning_enemy_loop.png", 64, 64)[4]),
        ("unending", qa.split_sheet(vfx_root / "unending" / "unending_enemy_loop.png", 64, 64)[4]),
    ]
    for index, (skill, sample) in enumerate(rows):
        column = index % 3
        row = index // 3
        x = 30 + column * 372
        y = 110 + row * 370
        qa.draw_card(draw, (x, y, x + 350, y + 340), qa.SKILL_LABELS[skill])
        icon = qa.rgba(vfx_root / skill / "icon.png").resize((160, 160), Image.Resampling.LANCZOS)
        qa.composite_center(canvas, icon, (x + 96, y + 150))
        sample_box = qa.fit(sample, (130, 130))
        qa.composite_center(canvas, sample_box, (x + 266, y + 150))
        draw.text((x + 28, y + 282), "ICON", fill=qa.MUTED, font=qa.font(14))
        draw.text((x + 238, y + 282), "VFX", fill=qa.MUTED, font=qa.font(14))
    canvas.save(output)
    print(f"UPDATED={output}")


if __name__ == "__main__":
    main()
