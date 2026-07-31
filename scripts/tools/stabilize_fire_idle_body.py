from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from stabilize_fire_idle import (
    FRAME_SIZE,
    TARGET_MAIN_HEIGHT,
    component_bbox,
    connected_components,
    crop_to_foreground,
    extract_frames,
    main_component,
    make_gif,
    make_preview,
    remove_background,
    stabilize_frame,
)


def reference_frame(image: Image.Image) -> Image.Image:
    bbox = component_bbox(main_component(image))
    scale = TARGET_MAIN_HEIGHT / float(bbox[3] - bbox[1])
    frame, _ = stabilize_frame(image, scale)
    return frame


def compose_stable_body(reference: Image.Image, moving: Image.Image) -> Image.Image:
    reference_rgba = np.asarray(reference)
    moving_rgba = np.asarray(moving)
    reference_alpha = reference_rgba[:, :, 3] > 0
    moving_alpha = moving_rgba[:, :, 3] > 0

    moving_components = connected_components(moving_alpha)
    moving_main = max(moving_components, key=len)
    moving_main_mask = np.zeros_like(moving_alpha)
    for x, y in moving_main:
        moving_main_mask[y, x] = True
    particles = moving_alpha & ~moving_main_mask

    height, width = moving_alpha.shape
    yy, xx = np.mgrid[0:height, 0:width]
    red = moving_rgba[:, :, 0].astype(np.int16)
    green = moving_rgba[:, :, 1].astype(np.int16)
    blue = moving_rgba[:, :, 2].astype(np.int16)
    fire_color = (red >= 165) & (red >= green + 20) & (blue <= 145)

    # The reference owns the body silhouette. Source frames only provide
    # flame-cap color motion, flame extensions, and disconnected sparks.
    head_flame = (yy <= 18) & (xx <= 49) & fire_color
    tail_flame = (yy <= 32) & (xx >= 47) & fire_color
    dilated_reference = np.asarray(
        Image.fromarray(reference_alpha.astype(np.uint8) * 255, "L").filter(
            ImageFilter.MaxFilter(5)
        )
    ) > 0
    effect_zone = (yy <= 34) & ((xx <= 50) | (xx >= 45))
    flame_extensions = moving_alpha & ~dilated_reference & effect_zone
    dynamic_mask = moving_alpha & (particles | head_flame | tail_flame | flame_extensions)

    result = reference.copy()
    overlay = np.zeros_like(moving_rgba)
    overlay[dynamic_mask] = moving_rgba[dynamic_mask]
    result.alpha_composite(Image.fromarray(overlay, "RGBA"))
    return result


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
    source_frames = extract_frames([args.sheet_a, args.sheet_b])
    main_heights = []
    for frame in source_frames:
        bbox = component_bbox(main_component(frame))
        main_heights.append(bbox[3] - bbox[1])
    common_scale = TARGET_MAIN_HEIGHT / float(np.median(main_heights))

    moving_frames = [
        stabilize_frame(frame, common_scale)[0] for frame in source_frames
    ]
    reference = crop_to_foreground(
        remove_background(Image.open(args.reference).convert("RGB"))
    )
    stable_reference = reference_frame(reference)
    stabilized = [
        compose_stable_body(stable_reference, moving) for moving in moving_frames
    ]

    sheet = Image.new(
        "RGBA", (FRAME_SIZE[0] * len(stabilized), FRAME_SIZE[1]), (0, 0, 0, 0)
    )
    for index, frame in enumerate(stabilized):
        sheet.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    make_preview(stabilized, args.preview)
    make_gif(stabilized, args.gif)

    reference_alpha = np.asarray(stable_reference.getchannel("A"))
    print(f"common_scale={common_scale:.6f}")
    print(f"stable_body_pixels={int(np.count_nonzero(reference_alpha))}")
    for index, frame in enumerate(stabilized, start=1):
        alpha = np.asarray(frame.getchannel("A"))
        print(f"F{index}: foreground_pixels={int(np.count_nonzero(alpha))}")


if __name__ == "__main__":
    main()
