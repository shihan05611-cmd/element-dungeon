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
    qa_root = root / "docs" / "vfx" / "qa"
    base = qa.rgba(qa_root / "testroom_runtime_base.png").resize((1152, 648), Image.Resampling.LANCZOS)
    crop = base.crop((700, 300, 1110, 590))
    canvas = Image.new("RGBA", (1152, 720), qa.BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((30, 22), "TestRoom 深色背景 · 敌人附着粒子 QA", fill=qa.TEXT, font=qa.font(30))
    draw.text((30, 62), "上排 100% 世界尺寸；下排 2×审查缩放。只用于视觉核验，不代表场景已接线。", fill=qa.MUTED, font=qa.font(17))
    panels = [
        ("燃烧 100%", "burning", 1.0),
        ("不息 100%", "unending", 1.0),
        ("燃烧 2×", "burning", 2.0),
        ("不息 2×", "unending", 2.0),
    ]
    for index, (label, skill, scale) in enumerate(panels):
        column = index % 2
        row = index // 2
        x = 34 + column * 558
        y = 104 + row * 292
        panel = crop.resize((520, 240), Image.Resampling.LANCZOS)
        canvas.alpha_composite(panel, (x, y))
        draw.rectangle((x, y, x + 520, y + 240), outline=(67, 84, 108, 255), width=2)
        draw.rounded_rectangle((x + 12, y + 12, x + 155, y + 46), 8, fill=(4, 9, 16, 220))
        draw.text((x + 22, y + 18), label, fill=qa.TEXT, font=qa.font(16))
        if skill == "burning":
            frame = qa.split_sheet(vfx_root / skill / "burning_enemy_loop.png", 64, 64)[4]
        else:
            frame = qa.split_sheet(vfx_root / skill / "unending_enemy_loop.png", 64, 64)[4]
        frame = frame.resize((round(64 * scale), round(64 * scale)), Image.Resampling.NEAREST)
        # The particle frame is authored bottom-heavy. Align its lower edge to
        # the enemy feet/platform rather than centering it on the body.
        center_y = 143 if scale == 1.0 else 119
        qa.composite_center(canvas, frame, (x + 200, y + center_y))
    canvas.save(qa_root / "stage2_testroom_particles_qa.png")
    print("UPDATED=docs/vfx/qa/stage2_testroom_particles_qa.png")


if __name__ == "__main__":
    main()
