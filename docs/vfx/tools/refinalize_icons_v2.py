from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


SKILLS = (
    "element_bolt",
    "elemental_fury",
    "elemental_laser",
    "element_reclaim",
    "burning",
    "unending",
)


def finalize(source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"Fully transparent source: {source}")
    cropped = image.crop(bbox)
    scale = min(220 / cropped.width, 220 / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((256 - resized.width) // 2, (256 - resized.height) // 2))
    canvas.save(output, optimize=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve() / "assets" / "generated" / "vfx"
    for skill in SKILLS:
        source = root / skill / "_sources" / "icon_alpha_full_v2.png"
        output = root / skill / "icon.png"
        finalize(source, output)
        print(output)


if __name__ == "__main__":
    main()
