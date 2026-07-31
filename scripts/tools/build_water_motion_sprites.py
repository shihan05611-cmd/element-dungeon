from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


FRAME_SIZE = (80, 64)

# Palette distilled from the Image-generated water references. The two
# original blue eye colors deliberately become amber/gold so the face remains
# readable against the blue body.
COLOR_MAP = {
    (230, 156, 105, 255): (26, 153, 222, 255),
    (191, 111, 74, 255): (0, 91, 172, 255),
    (246, 202, 159, 255): (104, 213, 242, 255),
    (255, 255, 255, 255): (245, 253, 255, 255),
    (199, 207, 221, 255): (177, 234, 246, 255),
    (146, 161, 185, 255): (83, 166, 211, 255),
    (138, 72, 54, 255): (0, 65, 125, 255),
    (245, 85, 93, 255): (245, 85, 93, 255),
    (137, 30, 43, 255): (137, 30, 43, 255),
    (0, 105, 170, 255): (146, 74, 0, 255),
    (246, 129, 135, 255): (255, 139, 144, 255),
    (0, 152, 220, 255): (255, 188, 32, 255),
}

WATER_DEEP = (0, 91, 172, 255)
WATER_BLUE = (26, 153, 222, 255)
WATER_CYAN = (104, 213, 242, 255)
WATER_FOAM = (225, 250, 255, 255)


def recolor_frame(frame: Image.Image) -> Image.Image:
    source = np.asarray(frame.convert("RGBA"))
    output = source.copy()
    for source_color, target_color in COLOR_MAP.items():
        matches = np.all(source == np.asarray(source_color, dtype=np.uint8), axis=2)
        output[matches] = np.asarray(target_color, dtype=np.uint8)

    alpha = source[:, :, 3] > 0
    ys, xs = np.where(alpha)
    if len(xs) == 0:
        return Image.fromarray(output, "RGBA")
    top, right = int(ys.min()), int(xs.max()) + 1
    yy, xx = np.indices(alpha.shape)

    # The pale tail tip becomes a foam cap without moving or deleting any
    # source pixel.
    tail_region = alpha & (xx >= right - 8) & (yy <= top + 14)
    original_white = np.all(
        source == np.asarray((255, 255, 255, 255), dtype=np.uint8), axis=2
    )
    original_light = np.all(
        source == np.asarray((199, 207, 221, 255), dtype=np.uint8), axis=2
    )
    original_shadow = np.all(
        source == np.asarray((146, 161, 185, 255), dtype=np.uint8), axis=2
    )
    output[tail_region & original_white] = WATER_FOAM
    output[tail_region & original_light] = WATER_CYAN
    output[tail_region & original_shadow] = WATER_BLUE
    return Image.fromarray(output, "RGBA")


def add_water_overflow(frame: Image.Image, frame_index: int) -> Image.Image:
    result = frame.copy()
    pixels = result.load()
    alpha = np.asarray(result.getchannel("A")) > 0
    ys, xs = np.where(alpha)
    if len(xs) == 0:
        return result
    left, top, right, bottom = (
        int(xs.min()),
        int(ys.min()),
        int(xs.max()) + 1,
        int(ys.max()) + 1,
    )

    def put(x: int, y: int, color: tuple[int, int, int, int]) -> None:
        if (
            0 <= x < FRAME_SIZE[0]
            and 0 <= y < FRAME_SIZE[1]
            and y < bottom - 8
            and pixels[x, y][3] == 0
        ):
            pixels[x, y] = color

    phase = frame_index % 4

    # Two small ear crests ripple with phase, while preserving the head.
    for ear_index, x in enumerate((left + 4, left + 14)):
        surface = np.where(alpha[:, min(x, FRAME_SIZE[0] - 1)])[0]
        ear_y = int(surface.min()) if len(surface) else top
        crest_x = x + (-1 if (phase + ear_index) % 3 == 0 else 0)
        put(crest_x, ear_y - 1, WATER_BLUE)
        put(crest_x + 1, ear_y - 1, WATER_CYAN)
        if (phase + ear_index) % 2 == 0:
            put(crest_x + 1, ear_y - 2, WATER_FOAM)

    # A sparse dorsal ripple reads as flowing water rather than fur.
    back_start = left + 17
    back_end = max(back_start, right - 10)
    for x in range(back_start + phase, back_end, 6):
        column = np.where(alpha[:, x])[0]
        if len(column) == 0:
            continue
        surface_y = int(column.min())
        if surface_y < bottom - 10:
            put(x, surface_y - 1, WATER_DEEP)
            put(x + 1, surface_y - 1, WATER_CYAN)

    # Tail foam and one detached droplet alternate sides. The detached pixel
    # is still well above the protected foot band.
    tail_start = max(left, right - 9)
    tail_points = np.argwhere(alpha[:, tail_start:right])
    if len(tail_points):
        tail_y = int(tail_points[:, 0].min())
        candidates = np.where(alpha[tail_y, tail_start:right])[0]
        tail_x = tail_start + int(candidates.max())
        direction = 1 if phase < 2 else -1
        put(tail_x, tail_y - 1, WATER_CYAN)
        put(tail_x + direction, tail_y - 1, WATER_FOAM)
        if phase in (1, 3):
            put(tail_x + direction * 2, tail_y - 2, WATER_CYAN)
    return result


def build_sheet(source_path: Path) -> tuple[Image.Image, list[Image.Image]]:
    source = Image.open(source_path).convert("RGBA")
    frame_count = source.width // FRAME_SIZE[0]
    sheet = Image.new(
        "RGBA", (FRAME_SIZE[0] * frame_count, FRAME_SIZE[1]), (0, 0, 0, 0)
    )
    frames: list[Image.Image] = []
    for index in range(frame_count):
        original = source.crop(
            (index * FRAME_SIZE[0], 0, (index + 1) * FRAME_SIZE[0], FRAME_SIZE[1])
        )
        frame = add_water_overflow(recolor_frame(original), index)
        frames.append(frame)
        sheet.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
    return sheet, frames


def make_contact_sheet(frames: list[Image.Image], output_path: Path) -> None:
    scale = 6
    columns = min(4, len(frames))
    rows = (len(frames) + columns - 1) // columns
    cell_width = FRAME_SIZE[0] * scale
    cell_height = FRAME_SIZE[1] * scale + 20
    preview = Image.new(
        "RGBA", (columns * cell_width, rows * cell_height), (19, 31, 43, 255)
    )
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate(frames):
        x = (index % columns) * cell_width
        y = (index // columns) * cell_height
        preview.alpha_composite(
            frame.resize(
                (FRAME_SIZE[0] * scale, FRAME_SIZE[1] * scale),
                Image.Resampling.NEAREST,
            ),
            (x, y),
        )
        draw.text((x + 5, y + FRAME_SIZE[1] * scale), f"F{index + 1}", fill="white")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    preview.convert("RGB").save(output_path)


def make_gif(frames: list[Image.Image], output_path: Path) -> None:
    rendered: list[Image.Image] = []
    for frame in frames:
        canvas = Image.new("RGBA", FRAME_SIZE, (17, 29, 40, 255))
        canvas.alpha_composite(frame)
        rendered.append(
            canvas.resize(
                (FRAME_SIZE[0] * 7, FRAME_SIZE[1] * 7),
                Image.Resampling.NEAREST,
            )
        )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    rendered[0].save(
        output_path,
        save_all=True,
        append_images=rendered[1:],
        duration=100,
        loop=0,
        disposal=2,
    )


def validate_structure(source_path: Path, output: Image.Image) -> None:
    source = Image.open(source_path).convert("RGBA")
    frame_count = source.width // FRAME_SIZE[0]
    for index in range(frame_count):
        source_frame = source.crop(
            (index * FRAME_SIZE[0], 0, (index + 1) * FRAME_SIZE[0], FRAME_SIZE[1])
        )
        output_frame = output.crop(
            (index * FRAME_SIZE[0], 0, (index + 1) * FRAME_SIZE[0], FRAME_SIZE[1])
        )
        source_alpha = np.asarray(source_frame.getchannel("A")) > 0
        output_alpha = np.asarray(output_frame.getchannel("A")) > 0
        missing = int(np.count_nonzero(source_alpha & ~output_alpha))
        foot_rows = np.indices(source_alpha.shape)[0] >= 43
        foot_changes = int(np.count_nonzero((source_alpha ^ output_alpha) & foot_rows))
        if missing or foot_changes:
            raise RuntimeError(
                f"Frame {index + 1} changed source structure: "
                f"missing={missing}, foot_changes={foot_changes}"
            )
    print(f"validated_frames={frame_count}")
    print("source_pixels_preserved=true")
    print("foot_shape_changes=0")
    print("eye_palette=amber_gold")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preview", required=True, type=Path)
    parser.add_argument("--gif", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    sheet, frames = build_sheet(args.source)
    validate_structure(args.source, sheet)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    make_contact_sheet(frames, args.preview)
    make_gif(frames, args.gif)
    print(args.output.resolve())


if __name__ == "__main__":
    main()
