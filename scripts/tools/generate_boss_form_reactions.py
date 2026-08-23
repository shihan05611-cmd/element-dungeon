from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / "assets/world/enemies/tide_ember_sovereign"

PLAIN_COLORS = (
    (26, 22, 30),
    (162, 43, 75),
    (98, 18, 50),
    (49, 19, 57),
    (222, 214, 214),
    (196, 188, 188),
    (214, 86, 98),
)
FORM_COLORS = {
    "ember": (
        (58, 26, 24),
        (191, 79, 32),
        (122, 34, 20),
        (61, 24, 20),
        (247, 201, 96),
        (222, 142, 54),
        (255, 168, 52),
    ),
    "tide": (
        (14, 20, 38),
        (43, 95, 158),
        (24, 54, 96),
        (20, 66, 74),
        (196, 232, 232),
        (150, 204, 214),
        (98, 206, 222),
    ),
}


def recolor(source: Image.Image, colors: tuple[tuple[int, int, int], ...]) -> Image.Image:
    mapping = dict(zip(PLAIN_COLORS, colors, strict=True))
    result = source.copy()
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            source_color = (red, green, blue)
            if alpha == 0 or source_color == (10, 8, 12):
                continue
            replacement = mapping.get(source_color)
            if replacement is None:
                nearest_index = min(
                    range(len(PLAIN_COLORS)),
                    key=lambda index: sum(
                        (source_color[channel] - PLAIN_COLORS[index][channel]) ** 2
                        for channel in range(3)
                    ),
                )
                replacement = colors[nearest_index]
            pixels[x, y] = (*replacement, alpha)
    return result


def main() -> None:
    for pose in ("hurt", "death"):
        source_path = ASSET_DIR / f"boss_{pose}_v2.png"
        source = Image.open(source_path).convert("RGBA")
        if source.size != (800, 200):
            raise ValueError(f"{source_path}: expected 800x200, got {source.size}")
        for form, colors in FORM_COLORS.items():
            output_path = ASSET_DIR / f"boss_{form}_{pose}_v1.png"
            recolor(source, colors).save(output_path)
            print(f"generated {output_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
