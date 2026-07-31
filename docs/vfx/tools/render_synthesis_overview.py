from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageSequence


BG = (10, 15, 24, 255)
PANEL = (18, 25, 38, 255)
TEXT = (218, 228, 240, 255)
MUTED = (112, 130, 154, 255)


def gif_samples(path: Path, count: int = 4) -> list[Image.Image]:
    image = Image.open(path)
    frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(image)]
    indices = [round(i * (len(frames) - 1) / (count - 1)) for i in range(count)]
    return [frames[index] for index in indices]


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    output = Image.new("RGBA", size, BG)
    scale = min(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.NEAREST,
    )
    output.alpha_composite(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    rows = [
        ("ELEMENTAL FURY / accepted 8f", root / "assets/generated/vfx/elemental_fury/burst_core_neutral_v1_preview.gif"),
        ("ELEMENTAL LASER / simple water + fire", root / "assets/generated/vfx/elemental_laser/beam_preview_v1.gif"),
        ("ELEMENT RECLAIM / enemy to player", root / "assets/generated/vfx/element_reclaim/reclaim_motion_preview_v1.gif"),
        ("BURNING / enemy loop + tick", root / "assets/generated/vfx/burning/burning_preview_v1.gif"),
        ("UNENDING / enemy loop + trigger", root / "assets/generated/vfx/unending/unending_preview_v1.gif"),
    ]
    width = 1120
    row_height = 190
    margin = 24
    label_width = 248
    cell_width = (width - margin * 2 - label_width) // 4
    canvas = Image.new("RGBA", (width, margin * 2 + row_height * len(rows)), BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    font = ImageFont.load_default(size=16)
    small = ImageFont.load_default(size=13)
    for row_index, (label, path) in enumerate(rows):
        y = margin + row_index * row_height
        draw.rounded_rectangle(
            (margin, y, width - margin, y + row_height - 10),
            radius=8,
            fill=PANEL,
            outline=(42, 55, 76, 255),
            width=1,
        )
        draw.text((margin + 16, y + 58), label, fill=TEXT, font=font)
        draw.text((margin + 16, y + 87), "4 representative frames", fill=MUTED, font=small)
        samples = gif_samples(path)
        for column, sample in enumerate(samples):
            cell = contain(sample, (cell_width - 12, row_height - 34))
            x = margin + label_width + column * cell_width + 6
            canvas.alpha_composite(cell, (x, y + 12))
    output = root / "assets/generated/vfx/python_synthesis_overview_v1.png"
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite: {output}")
    canvas.save(output)
    print(output.relative_to(root).as_posix())


if __name__ == "__main__":
    main()
