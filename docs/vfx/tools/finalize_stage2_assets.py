from __future__ import annotations

import argparse
import shutil
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

PROMOTIONS = {
    "elemental_fury": {
        "burst_core_neutral_v1.png": "burst_core.png",
    },
    "elemental_laser": {
        "beam_segment_water_v1.png": "beam_segment_water.png",
        "beam_segment_fire_v1.png": "beam_segment_fire.png",
        "beam_tick_water_v1.png": "beam_tick_water.png",
        "beam_tick_fire_v1.png": "beam_tick_fire.png",
    },
    "element_reclaim": {
        "reclaim_particle_water_v1.png": "reclaim_particle_water.png",
        "reclaim_particle_fire_v1.png": "reclaim_particle_fire.png",
        "reclaim_extract_neutral_v1.png": "reclaim_extract_neutral.png",
        "reclaim_arrival_neutral_v1.png": "reclaim_arrival_neutral.png",
    },
    "burning": {
        "burning_enemy_loop_v1.png": "burning_enemy_loop.png",
        "burning_tick_v1.png": "burning_tick.png",
    },
    "unending": {
        "unending_enemy_loop_v1.png": "unending_enemy_loop.png",
        "unending_trigger_v1.png": "unending_trigger.png",
    },
}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Image is fully transparent")
    return bbox


def finalize_icon(source: Path, output: Path, canvas_size: int = 256, subject_size: int = 220) -> None:
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite: {output}")
    image = Image.open(source).convert("RGBA")
    bbox = alpha_bbox(image)
    cropped = image.crop(bbox)
    scale = min(subject_size / cropped.width, subject_size / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((canvas_size - resized.width) // 2, (canvas_size - resized.height) // 2),
    )
    canvas.save(output, optimize=False)


def promote(source: Path, output: Path) -> None:
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite: {output}")
    if not source.exists():
        raise FileNotFoundError(source)
    shutil.copyfile(source, output)


def make_mask(source: Path, output: Path) -> None:
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite: {output}")
    image = Image.open(source).convert("RGBA")
    image.getchannel("A").save(output, optimize=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    vfx_root = root / "assets" / "generated" / "vfx"
    written: list[Path] = []

    for skill in SKILLS:
        directory = vfx_root / skill
        source = directory / "_sources" / "icon_alpha_full_v1.png"
        output = directory / "icon.png"
        finalize_icon(source, output)
        written.append(output)

    for skill, pairs in PROMOTIONS.items():
        directory = vfx_root / skill
        for source_name, output_name in pairs.items():
            output = directory / output_name
            promote(directory / source_name, output)
            written.append(output)

    laser_dir = vfx_root / "elemental_laser"
    for filename in (
        "beam_segment_water.png",
        "beam_segment_fire.png",
        "beam_tick_water.png",
        "beam_tick_fire.png",
    ):
        output = laser_dir / filename.replace(".png", "_mask.png")
        make_mask(laser_dir / filename, output)
        written.append(output)

    for path in written:
        print(path.relative_to(root).as_posix())
    print(f"FINALIZED={len(written)}")


if __name__ == "__main__":
    main()
