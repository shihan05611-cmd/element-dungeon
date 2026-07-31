from __future__ import annotations

import argparse
import math
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


FRAME_SIZE = (80, 64)
TARGET_MAIN_HEIGHT = 38
TARGET_FOOT_X = 36.0
TARGET_BASELINE_Y = 48


def fit_background(rgb: np.ndarray) -> np.ndarray:
    height, width, _ = rgb.shape
    yy, xx = np.mgrid[0:height:4, 0:width:4]
    samples = rgb[0:height:4, 0:width:4].astype(np.float32)
    x = xx.astype(np.float32) / max(width - 1, 1)
    y = yy.astype(np.float32) / max(height - 1, 1)
    features = np.stack(
        (np.ones_like(x), x, y, x * x, y * y, x * y), axis=-1
    ).reshape(-1, 6)
    values = samples.reshape(-1, 3)
    dark = values.max(axis=1) < 105
    coefficients, *_ = np.linalg.lstsq(features[dark], values[dark], rcond=None)

    full_y, full_x = np.mgrid[0:height, 0:width]
    full_x = full_x.astype(np.float32) / max(width - 1, 1)
    full_y = full_y.astype(np.float32) / max(height - 1, 1)
    full_features = np.stack(
        (
            np.ones_like(full_x),
            full_x,
            full_y,
            full_x * full_x,
            full_y * full_y,
            full_x * full_y,
        ),
        axis=-1,
    )
    return np.clip(full_features @ coefficients, 0, 255)


def remove_background(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    background = fit_background(rgb)
    difference = np.linalg.norm(rgb - background, axis=2)

    strong = Image.fromarray((difference > 27).astype(np.uint8) * 255, "L")
    nearby = np.asarray(strong.filter(ImageFilter.MaxFilter(13))) > 0
    alpha = ((difference > 10) & nearby).astype(np.uint8) * 255

    rgba = np.dstack((rgb.astype(np.uint8), alpha))
    return Image.fromarray(rgba, "RGBA")


def connected_components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    height, width = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or visited[y, x]:
                continue
            queue = deque([(x, y)])
            visited[y, x] = True
            component: list[tuple[int, int]] = []
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for offset_y in (-1, 0, 1):
                    for offset_x in (-1, 0, 1):
                        next_x = current_x + offset_x
                        next_y = current_y + offset_y
                        if (
                            0 <= next_x < width
                            and 0 <= next_y < height
                            and mask[next_y, next_x]
                            and not visited[next_y, next_x]
                        ):
                            visited[next_y, next_x] = True
                            queue.append((next_x, next_y))
            components.append(component)
    return components


def component_bbox(component: list[tuple[int, int]]) -> tuple[int, int, int, int]:
    xs = [point[0] for point in component]
    ys = [point[1] for point in component]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def main_component(image: Image.Image) -> list[tuple[int, int]]:
    alpha = np.asarray(image.getchannel("A")) > 0
    components = connected_components(alpha)
    if not components:
        raise RuntimeError("No foreground component was extracted")
    return max(components, key=len)


def crop_to_foreground(image: Image.Image, margin: int = 3) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("No foreground pixels found")
    left = max(0, bbox[0] - margin)
    top = max(0, bbox[1] - margin)
    right = min(image.width, bbox[2] + margin)
    bottom = min(image.height, bbox[3] + margin)
    return image.crop((left, top, right, bottom))


def resize_nearest(image: Image.Image, scale: float) -> Image.Image:
    size = (
        max(1, int(round(image.width * scale))),
        max(1, int(round(image.height * scale))),
    )
    return image.resize(size, Image.Resampling.NEAREST)


def foot_anchor(image: Image.Image, component: list[tuple[int, int]]) -> tuple[float, int]:
    rgba = np.asarray(image)
    left, top, right, bottom = component_bbox(component)
    height = bottom - top
    points: list[tuple[int, int]] = []
    for x, y in component:
        red, green, blue, _ = rgba[y, x]
        if (
            y >= top + math.floor(height * 0.72)
            and red >= 155
            and green >= 125
            and blue >= 85
            and int(max(red, green, blue)) - int(min(red, green, blue)) <= 105
        ):
            points.append((x, y))
    if not points:
        points = [(x, y) for x, y in component if y >= bottom - 4]
    anchor_x = float(np.median([point[0] for point in points]))
    baseline = max(point[1] for point in component) + 1
    return anchor_x, baseline


def extract_frames(sheet_paths: list[Path]) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for sheet_path in sheet_paths:
        sheet = Image.open(sheet_path).convert("RGB")
        for index in range(4):
            left = round(sheet.width * index / 4)
            right = round(sheet.width * (index + 1) / 4)
            panel = sheet.crop((left, 0, right, sheet.height))
            frames.append(crop_to_foreground(remove_background(panel)))
    return frames


def stabilize_frame(image: Image.Image, scale: float) -> tuple[Image.Image, dict[str, float]]:
    resized = resize_nearest(image, scale)
    component = main_component(resized)
    anchor_x, baseline = foot_anchor(resized, component)
    offset_x = int(round(TARGET_FOOT_X - anchor_x))
    offset_y = TARGET_BASELINE_Y - baseline

    frame = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    frame.alpha_composite(resized, (offset_x, offset_y))
    final_component = main_component(frame)
    final_anchor_x, final_baseline = foot_anchor(frame, final_component)
    bbox = component_bbox(final_component)
    return frame, {
        "foot_x": final_anchor_x,
        "baseline": float(final_baseline),
        "main_left": float(bbox[0]),
        "main_top": float(bbox[1]),
        "main_right": float(bbox[2]),
        "main_bottom": float(bbox[3]),
    }


def make_preview(frames: list[Image.Image], output_path: Path) -> None:
    scale = 5
    padding = 12
    label_height = 22
    cell_width = FRAME_SIZE[0] * scale
    cell_height = FRAME_SIZE[1] * scale
    preview = Image.new(
        "RGBA",
        (padding + 4 * (cell_width + padding), padding + 2 * (cell_height + label_height + padding)),
        (26, 23, 22, 255),
    )
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate(frames):
        row, column = divmod(index, 4)
        x = padding + column * (cell_width + padding)
        y = padding + row * (cell_height + label_height + padding)
        enlarged = frame.resize((cell_width, cell_height), Image.Resampling.NEAREST)
        preview.alpha_composite(enlarged, (x, y))
        draw.text((x + 4, y + cell_height + 2), f"F{index + 1}", fill=(255, 226, 170, 255))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    preview.convert("RGB").save(output_path)


def make_gif(frames: list[Image.Image], output_path: Path) -> None:
    background = (35, 29, 26, 255)
    rendered: list[Image.Image] = []
    for frame in frames:
        canvas = Image.new("RGBA", FRAME_SIZE, background)
        canvas.alpha_composite(frame)
        rendered.append(
            canvas.resize((FRAME_SIZE[0] * 6, FRAME_SIZE[1] * 6), Image.Resampling.NEAREST)
        )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    rendered[0].save(
        output_path,
        save_all=True,
        append_images=rendered[1:],
        duration=125,
        loop=0,
        disposal=2,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet-a", required=True, type=Path)
    parser.add_argument("--sheet-b", required=True, type=Path)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preview", required=True, type=Path)
    parser.add_argument("--gif", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    frames = extract_frames([args.sheet_a, args.sheet_b])
    main_heights = []
    for frame in frames:
        bbox = component_bbox(main_component(frame))
        main_heights.append(bbox[3] - bbox[1])

    reference = crop_to_foreground(remove_background(Image.open(args.reference).convert("RGB")))
    reference_bbox = component_bbox(main_component(reference))
    reference_height = reference_bbox[3] - reference_bbox[1]

    common_scale = TARGET_MAIN_HEIGHT / float(np.median(main_heights))
    stabilized: list[Image.Image] = []
    measurements: list[dict[str, float]] = []
    for frame in frames:
        result, measurement = stabilize_frame(frame, common_scale)
        stabilized.append(result)
        measurements.append(measurement)

    sheet = Image.new("RGBA", (FRAME_SIZE[0] * len(stabilized), FRAME_SIZE[1]), (0, 0, 0, 0))
    for index, frame in enumerate(stabilized):
        sheet.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    make_preview(stabilized, args.preview)
    make_gif(stabilized, args.gif)

    print(f"reference_main_height={reference_height}")
    print(f"source_main_heights={main_heights}")
    print(f"common_scale={common_scale:.6f}")
    for index, measurement in enumerate(measurements, start=1):
        print(f"F{index}: {measurement}")


if __name__ == "__main__":
    main()
