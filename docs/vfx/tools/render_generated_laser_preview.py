"""Build a long-beam GIF preview from the generated two-row laser sheet."""

from pathlib import Path
import sys

from PIL import Image


SOURCE = Path(
    r"C:\Users\heliashi\.codex\generated_images\01a02824-b892-79a0-801a-4eda36e56b11\exec-c104f5f5-6652-4c0b-909e-ca2db187837e.png"
)
OUTPUT = Path("docs/vfx/qa/elemental_laser_generated_extended_preview.gif")
FRAME_COUNT = 8
CELL_WIDTH = 128
CELL_HEIGHT = 48
TILE_COUNT = 5
BACKGROUND = (7, 16, 27, 255)


def _row_frames(source: Image.Image, top: int, bottom: int) -> list[Image.Image]:
    frame_width = source.width / FRAME_COUNT
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        left = round(index * frame_width)
        right = round((index + 1) * frame_width)
        cell = source.crop((left, top, right, bottom))
        frames.append(cell.resize((CELL_WIDTH, CELL_HEIGHT), Image.Resampling.LANCZOS))
    return frames


def _render_frame(water: Image.Image, fire: Image.Image) -> Image.Image:
    width = CELL_WIDTH * TILE_COUNT + 80
    canvas = Image.new("RGBA", (width, 184), BACKGROUND)
    for tile_index in range(TILE_COUNT):
        x = 40 + tile_index * CELL_WIDTH
        canvas.alpha_composite(water, (x, 34))
        canvas.alpha_composite(fire, (x, 103))
    return canvas


def main() -> None:
    source_path = Path(sys.argv[1]) if len(sys.argv) > 1 else SOURCE
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else OUTPUT
    source = Image.open(source_path).convert("RGBA")
    water = _row_frames(source, 196, 316)
    fire = _row_frames(source, 518, 638)
    frames = [_render_frame(water[index], fire[index]) for index in range(FRAME_COUNT)]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=60,
        loop=0,
        disposal=2,
        optimize=False,
    )
    print(output_path.resolve())


if __name__ == "__main__":
    main()
