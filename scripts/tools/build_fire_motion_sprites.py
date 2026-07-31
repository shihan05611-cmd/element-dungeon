from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


FRAME_SIZE = (80, 64)

# Palette sampled from the four Image-generated fire animation references.
COLOR_MAP = {
    (230, 156, 105, 255): (240, 96, 16, 255),
    (191, 111, 74, 255): (208, 48, 0, 255),
    (246, 202, 159, 255): (240, 176, 48, 255),
    (255, 255, 255, 255): (255, 250, 224, 255),
    (199, 207, 221, 255): (242, 220, 177, 255),
    (146, 161, 185, 255): (187, 145, 97, 255),
    (138, 72, 54, 255): (126, 31, 17, 255),
    (245, 85, 93, 255): (245, 70, 55, 255),
    (137, 30, 43, 255): (126, 25, 28, 255),
    (0, 105, 170, 255): (0, 105, 170, 255),
    (246, 129, 135, 255): (255, 132, 108, 255),
    (0, 152, 220, 255): (0, 152, 220, 255),
}

FLAME_DARK = (208, 48, 0, 255)
FLAME_ORANGE = (240, 96, 16, 255)
FLAME_GOLD = (240, 176, 48, 255)
FLAME_HOT = (255, 248, 188, 255)


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
    left, top, right = int(xs.min()), int(ys.min()), int(xs.max()) + 1

    # Convert the original pale tail tip into a hot flame core without
    # changing any of its source pixels or coordinates.
    tail_region = (
        alpha
        & (np.indices(alpha.shape)[1] >= right - 8)
        & (np.indices(alpha.shape)[0] <= top + 14)
    )
    original_white = np.all(
        source == np.asarray((255, 255, 255, 255), dtype=np.uint8), axis=2
    )
    original_light = np.all(
        source == np.asarray((199, 207, 221, 255), dtype=np.uint8), axis=2
    )
    original_shadow = np.all(
        source == np.asarray((146, 161, 185, 255), dtype=np.uint8), axis=2
    )
    output[tail_region & original_white] = FLAME_HOT
    output[tail_region & original_light] = FLAME_GOLD
    output[tail_region & original_shadow] = FLAME_ORANGE
    return Image.fromarray(output, "RGBA")


def add_flame_overflow(frame: Image.Image, frame_index: int) -> Image.Image:
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
    ear_specs = (
        (left + 4, top - 1 - (1 if phase == 1 else 0)),
        (left + 14, top - 1 - (1 if phase == 3 else 0)),
    )
    for ear_index, (x, y) in enumerate(ear_specs):
        put(x, y, FLAME_ORANGE)
        if (phase + ear_index) % 2 == 0:
            put(x, y - 1, FLAME_GOLD)
        if phase == ear_index:
            put(x + 1, y, FLAME_DARK)

    tail_x_start = max(left, right - 9)
    tail_points = np.argwhere(alpha[:, tail_x_start:right])
    if len(tail_points) > 0:
        tail_y = int(tail_points[:, 0].min())
        tail_x_candidates = np.where(alpha[tail_y, tail_x_start:right])[0]
        tail_x = tail_x_start + int(tail_x_candidates.max())
        put(tail_x, tail_y - 1, FLAME_ORANGE)
        put(tail_x + (1 if phase < 2 else -1), tail_y - 1, FLAME_GOLD)
        if phase in (1, 3):
            put(tail_x, tail_y - 2, FLAME_HOT)

    back_start = left + 17
    back_end = max(back_start, right - 10)
    for x in range(back_start + phase, back_end, 5):
        column = np.where(alpha[:, x])[0]
        if len(column) == 0:
            continue
        surface_y = int(column.min())
        if surface_y < bottom - 10:
            put(x, surface_y - 1, FLAME_DARK)
            if (x + frame_index) % 3 == 0:
                put(x, surface_y - 2, FLAME_ORANGE)
    return result


def build_sheet(source_path: Path) -> tuple[Image.Image, list[Image.Image]]:
    source = Image.open(source_path).convert("RGBA")
    frame_count = source.width // FRAME_SIZE[0]
    frames: list[Image.Image] = []
    sheet = Image.new(
        "RGBA", (FRAME_SIZE[0] * frame_count, FRAME_SIZE[1]), (0, 0, 0, 0)
    )
    for index in range(frame_count):
        original = source.crop(
            (index * FRAME_SIZE[0], 0, (index + 1) * FRAME_SIZE[0], FRAME_SIZE[1])
        )
        frame = add_flame_overflow(recolor_frame(original), index)
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
        "RGBA", (columns * cell_width, rows * cell_height), (28, 24, 22, 255)
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
        canvas = Image.new("RGBA", FRAME_SIZE, (35, 29, 26, 255))
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
        missing_source_pixels = int(np.count_nonzero(source_alpha & ~output_alpha))
        foot_rows = np.indices(source_alpha.shape)[0] >= 43
        foot_shape_changes = int(
            np.count_nonzero(
                (source_alpha ^ output_alpha) & foot_rows
            )
        )
        if missing_source_pixels != 0 or foot_shape_changes != 0:
            raise RuntimeError(
                f"Frame {index + 1} changed source structure: "
                f"missing={missing_source_pixels}, foot_changes={foot_shape_changes}"
            )
    print(f"validated_frames={frame_count}")
    print("source_pixels_preserved=true")
    print("foot_shape_changes=0")


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
