from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


FRAME_WIDTH = 80
FRAME_HEIGHT = 64
CANVAS_WIDTH = 1536
CANVAS_HEIGHT = 768
KEY_COLOR = (0, 255, 0)
DISPLAY_SCALE = 8
BASELINE_Y = 560


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--group-size", type=int, default=4)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--prefix", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = Image.open(args.source).convert("RGBA")
    frame_count = source.width // FRAME_WIDTH
    args.output_dir.mkdir(parents=True, exist_ok=True)

    for group_start in range(0, frame_count, args.group_size):
        group_end = min(frame_count, group_start + args.group_size)
        group_count = group_end - group_start
        canvas = Image.new("RGB", (CANVAS_WIDTH, CANVAS_HEIGHT), KEY_COLOR)
        cell_width = CANVAS_WIDTH / group_count

        for local_index, frame_index in enumerate(range(group_start, group_end)):
            frame = source.crop(
                (
                    frame_index * FRAME_WIDTH,
                    0,
                    (frame_index + 1) * FRAME_WIDTH,
                    FRAME_HEIGHT,
                )
            )
            bbox = frame.getchannel("A").getbbox()
            if bbox is None:
                continue
            subject = frame.crop(bbox).resize(
                (
                    (bbox[2] - bbox[0]) * DISPLAY_SCALE,
                    (bbox[3] - bbox[1]) * DISPLAY_SCALE,
                ),
                Image.Resampling.NEAREST,
            )
            center_x = int(round(cell_width * (local_index + 0.5)))
            x = center_x - subject.width // 2
            y = BASELINE_Y - subject.height
            canvas.paste(subject.convert("RGB"), (x, y), subject.getchannel("A"))

        group_number = group_start // args.group_size + 1
        output = args.output_dir / f"{args.prefix}_group_{group_number}.png"
        canvas.save(output)
        print(output.resolve())


if __name__ == "__main__":
    main()
