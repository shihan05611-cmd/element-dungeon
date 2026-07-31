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


def is_key_residual(red: int, green: int, blue: int, alpha: int) -> bool:
    if alpha == 0:
        return False
    green_key = green >= 230 and red <= 45 and blue <= 45
    magenta_key = red >= 230 and blue >= 230 and green <= 45
    return green_key or magenta_key


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve() / "assets" / "generated" / "vfx"
    total = 0
    for skill in SKILLS:
        path = root / skill / "icon.png"
        image = Image.open(path).convert("RGBA")
        pixels = image.load()
        cleaned = 0
        for y in range(image.height):
            for x in range(image.width):
                red, green, blue, alpha = pixels[x, y]
                if is_key_residual(red, green, blue, alpha):
                    pixels[x, y] = (0, 0, 0, 0)
                    cleaned += 1
        image.save(path, optimize=False)
        total += cleaned
        print(f"{skill}:cleaned={cleaned}")
    print(f"TOTAL_CLEANED={total}")


if __name__ == "__main__":
    main()
