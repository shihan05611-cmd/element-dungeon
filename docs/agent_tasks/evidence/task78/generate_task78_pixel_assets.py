#!/usr/bin/env python3
"""Deterministic Task 78 pixel-art reconstruction and QA artifact builder.

Elemental Boss sheets are derived frame-for-frame from the shipped neutral
Boss sheets.  The transform keeps canvas, frame count, baseline, anchor, and
action timing stable while adding connected elemental silhouette geometry.
"""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
BOSS = ROOT / "assets/world/enemies/tide_ember_sovereign"
VFX = ROOT / "assets/generated/vfx/burning"
TELEGRAPH = ROOT / "assets/world/ui_world/telegraph"
EVIDENCE = ROOT / "docs/agent_tasks/evidence/task78"

FRAME_SIZE = 200
GRID = 4

ACTIONS = {
    "idle": ("boss_plain_idle_v2.png", 6, "v2"),
    "walk": ("boss_plain_walk_v2.png", 8, "v2"),
    "attack": ("boss_plain_attack_v2.png", 8, "v2"),
    "cast": ("boss_plain_cast_v1.png", 8, "v1"),
    "hurt": ("boss_hurt_v2.png", 4, "v1"),
    "death": ("boss_death_v2.png", 4, "v1"),
}

PALETTES = {
    "tide": [
        (8, 20, 38, 255),
        (13, 44, 78, 255),
        (24, 78, 132, 255),
        (38, 126, 181, 255),
        (86, 192, 220, 255),
        (202, 244, 246, 255),
    ],
    "ember": [
        (54, 15, 18, 255),
        (101, 25, 23, 255),
        (166, 43, 24, 255),
        (226, 75, 22, 255),
        (255, 151, 35, 255),
        (255, 229, 111, 255),
    ],
}


def snap(value: float) -> int:
    return int(round(value / GRID)) * GRID


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def subject_bbox(frame: Image.Image) -> tuple[int, int, int, int]:
    # Contact shadows occupy the final rows and are not part of the body.
    alpha = frame.getchannel("A")
    crop = alpha.crop((0, 0, frame.width, 168))
    bbox = crop.getbbox()
    if bbox is None:
        raise ValueError("frame has no visible Boss subject")
    return bbox


def luminance(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def recolor_neutral(frame: Image.Image, form: str) -> Image.Image:
    palette = PALETTES[form]
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    src = frame.load()
    dst = out.load()
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            if y >= 168 and luminance((r, g, b)) < 45:
                dst[x, y] = (10, 9, 14, a)
                continue
            value = luminance((r, g, b))
            if value < 28:
                index = 0
            elif value < 48:
                index = 1
            elif value < 82:
                index = 2
            elif value < 128:
                index = 3
            elif value < 190:
                index = 4
            else:
                index = 5
            color = palette[index]
            dst[x, y] = (color[0], color[1], color[2], a)
    return out


def masked_stream(frame: Image.Image, points: list[tuple[int, int]], color: tuple[int, int, int, int], width: int) -> None:
    overlay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.line(points, fill=color, width=width, joint="curve")
    body_mask = frame.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    overlay.putalpha(ImageChops.multiply(overlay.getchannel("A"), body_mask))
    frame.alpha_composite(overlay)


def add_tide_flow(frame: Image.Image, frame_index: int) -> Image.Image:
    x0, y0, x1, y1 = subject_bbox(frame)
    cx = snap((x0 + x1) / 2)
    phase = (0, 4, 4, 0, 0, -4, -4, 0)[frame_index % 8]
    draw = ImageDraw.Draw(frame)
    dark, deep, mid, bright, foam, white = PALETTES["tide"]

    # Short shoulder ripples remain attached and never exceed one 4px cell
    # beyond the neutral alpha bounds.
    ribbon_y = snap(y0 + (y1 - y0) * 0.48)
    right_tip = min(196, x1 + max(0, phase))
    left_tip = max(4, x0 + min(0, phase))
    draw.rectangle((x1 - 8, ribbon_y, right_tip, ribbon_y + GRID - 1), fill=mid)
    draw.rectangle((left_tip, ribbon_y + 4, x0 + 8, ribbon_y + 7), fill=deep)

    # A coherent internal current moves across the body without detached dots.
    inner_y = snap(y0 + (y1 - y0) * 0.58)
    masked_stream(
        frame,
        [(x0 + 20, inner_y + phase // 2), (cx - 8, inner_y - 4),
         (cx + 8, inner_y), (x1 - 20, inner_y - 4 - phase // 2)],
        bright,
        GRID,
    )
    masked_stream(
        frame,
        [(cx - 8, y0 + 16), (cx - 4 + phase // 2, y0 + 24), (cx, y0 + 28)],
        foam,
        GRID,
    )

    # Attached lower drips use one grid cell and retain the neutral baseline.
    for offset, length in [(-24, 4), (8, 8), (28, 4)]:
        x = max(x0 + 4, min(x1 - 4, cx + offset + phase // 2))
        top = y1 - GRID
        draw.rectangle((x, top, x + GRID - 1, min(167, top + length)), fill=deep)
    return frame


def add_ember_flow(frame: Image.Image, frame_index: int) -> Image.Image:
    x0, y0, x1, y1 = subject_bbox(frame)
    cx = snap((x0 + x1) / 2)
    phase = (0, 4, 4, 0, 0, -4, -4, 0)[frame_index % 8]
    draw = ImageDraw.Draw(frame)
    dark, deep, red, orange, gold, white = PALETTES["ember"]

    # One narrow connected crown tongue; its base stays inside the neutral
    # head and its tip extends at most two grid cells.
    center_flame = [
        (cx - 8, y0 + 8),
        (cx - 4, y0),
        (cx, y0 - 4 + phase),
        (cx + 4, y0 + 4),
        (cx + 8, y0 + 8),
    ]
    draw.polygon(center_flame, fill=orange)
    draw.line([(cx, y0 + 4), (cx, y0)], fill=gold, width=GRID)

    # Shoulder flames rise from existing mass and do not form horizontal flags.
    shoulder_y = snap(y0 + (y1 - y0) * 0.52)
    left_flame = [
        (x0 + 8, shoulder_y + 4),
        (x0 + 8, shoulder_y - 4 + min(phase, 0)),
        (x0 + 12, shoulder_y),
        (x0 + 16, shoulder_y + 4),
    ]
    right_flame = [
        (x1 - 16, shoulder_y + 4),
        (x1 - 12, shoulder_y - 4 - max(phase, 0)),
        (x1 - 8, shoulder_y),
        (x1 - 8, shoulder_y + 4),
    ]
    draw.polygon(left_flame, fill=red)
    draw.polygon(right_flame, fill=orange)
    draw.point((x1 - 12, shoulder_y - 4), fill=gold)

    # Hot channels are contained inside the body: no isolated bright points.
    inner_y = snap(y0 + (y1 - y0) * 0.62)
    masked_stream(
        frame,
        [(x0 + 24, inner_y + 4), (cx - 8, inner_y),
         (cx + 8, inner_y + 4), (x1 - 24, inner_y)],
        orange,
        GRID,
    )
    masked_stream(
        frame,
        [(cx - 4, y0 + 20), (cx + phase // 2, y0 + 28), (cx + 4, y0 + 36)],
        gold,
        GRID,
    )
    return frame


def build_boss_sheets() -> dict[str, dict]:
    report: dict[str, dict] = {}
    for action, (neutral_name, frame_count, version) in ACTIONS.items():
        neutral_path = BOSS / neutral_name
        neutral_sheet = Image.open(neutral_path).convert("RGBA")
        expected = (FRAME_SIZE * frame_count, FRAME_SIZE)
        if neutral_sheet.size != expected:
            raise ValueError(f"{neutral_name}: expected {expected}, got {neutral_sheet.size}")
        neutral_hash = sha256(neutral_path)
        for form in ("tide", "ember"):
            output = Image.new("RGBA", neutral_sheet.size, (0, 0, 0, 0))
            frame_bboxes = []
            for index in range(frame_count):
                box = (index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE)
                neutral_frame = neutral_sheet.crop(box)
                elemental = recolor_neutral(neutral_frame, form)
                elemental = add_tide_flow(elemental, index) if form == "tide" else add_ember_flow(elemental, index)
                output.alpha_composite(elemental, (index * FRAME_SIZE, 0))
                frame_bboxes.append(list(subject_bbox(elemental)))
            output_name = f"boss_{form}_{action}_{version}.png"
            output_path = BOSS / output_name
            output.save(output_path, optimize=True)
            report[output_name] = {
                "source": neutral_name,
                "source_sha256": neutral_hash,
                "sha256": sha256(output_path),
                "size": list(output.size),
                "frame_count": frame_count,
                "frame_bboxes": frame_bboxes,
            }
    return report


def draw_spark(frame: Image.Image, x: int, y: int, age: int, hot: bool = False) -> None:
    if not (2 <= x <= 61 and 2 <= y <= 61):
        return
    palette = [(126, 28, 20, 255), (225, 65, 20, 255), (255, 145, 29, 255), (255, 228, 98, 255)]
    color = palette[max(0, min(3, 3 - age // 2))]
    if hot:
        color = palette[min(3, max(2, 3 - age // 3))]
    draw = ImageDraw.Draw(frame)
    draw.rectangle((x, y, x + 1, y + 1), fill=color)
    if age <= 3:
        draw.point((x, y - 1), fill=palette[3])
    if age <= 2:
        draw.point((x - 1, y + 1), fill=palette[1])


def build_burning_vfx() -> dict[str, dict]:
    # Particle births are staggered; each ember rises, drifts, changes color,
    # and expires before re-entering the 12-frame loop.
    particles = [
        (0, 10, 53, -1, -2),
        (2, 22, 57, 1, -3),
        (4, 34, 55, -1, -2),
        (6, 46, 56, 1, -3),
        (8, 54, 52, -1, -2),
        (10, 16, 50, 1, -3),
    ]
    loop_sheet = Image.new("RGBA", (64 * 12, 64), (0, 0, 0, 0))
    for frame_index in range(12):
        frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        for birth, x0, y0, drift, rise in particles:
            age = (frame_index - birth) % 12
            if age > 7:
                continue
            sway = (0, 1, 1, 0, -1, -1, 0, 1)[age]
            x = x0 + drift * (age // 2) + sway
            y = y0 + rise * age
            draw_spark(frame, x, y, age, hot=(birth % 4 == 0))
            if 1 <= age <= 4:
                ImageDraw.Draw(frame).point((x - drift, y + 3), fill=(205, 52, 19, 255))
        loop_sheet.alpha_composite(frame, (frame_index * 64, 0))

    loop_path = VFX / "burning_enemy_loop.png"
    loop_sheet.save(loop_path, optimize=True)

    trigger_sheet = Image.new("RGBA", (64 * 8, 64), (0, 0, 0, 0))
    for frame_index in range(8):
        frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        for particle_index, angle_seed in enumerate((-3, -2, -1, 1, 2, 3)):
            age = frame_index
            x = 32 + angle_seed * (2 + age)
            y = 52 - age * (4 + particle_index % 2) + abs(angle_seed) * 2
            draw_spark(frame, x, y, age, hot=True)
        trigger_sheet.alpha_composite(frame, (frame_index * 64, 0))

    trigger_path = VFX / "burning_tick.png"
    trigger_sheet.save(trigger_path, optimize=True)
    return {
        loop_path.name: {"size": list(loop_sheet.size), "frame_count": 12, "sha256": sha256(loop_path)},
        trigger_path.name: {"size": list(trigger_sheet.size), "frame_count": 8, "sha256": sha256(trigger_path)},
    }


def recolor_exclamation(source: Path, target: Path) -> dict:
    image = Image.open(source).convert("RGBA")
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src = image.load()
    dst = out.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            value = luminance((r, g, b))
            color = (255, 92, 76) if value > 170 else ((210, 37, 48) if value > 70 else (92, 13, 25))
            dst[x, y] = (*color, a)
    out.save(target, optimize=True)
    return {
        "source": source.name,
        "size": list(out.size),
        "sha256": sha256(target),
        "alpha_matches_source": list(out.getchannel("A").getdata()) == list(image.getchannel("A").getdata()),
    }


def build_melee_telegraph() -> dict[str, dict]:
    return {
        "telegraph_melee_v1.png": recolor_exclamation(
            TELEGRAPH / "telegraph_alert_v1.png",
            TELEGRAPH / "telegraph_melee_v1.png",
        ),
        "telegraph_melee_static_v1.png": recolor_exclamation(
            TELEGRAPH / "telegraph_alert_static_v1.png",
            TELEGRAPH / "telegraph_melee_static_v1.png",
        ),
    }


def preview_strip(source: Image.Image, frame_count: int, display_frame: int = 72) -> Image.Image:
    out = Image.new("RGBA", (display_frame * frame_count, display_frame), (13, 15, 23, 255))
    for index in range(frame_count):
        frame = source.crop((index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE))
        frame = frame.resize((display_frame, display_frame), Image.Resampling.NEAREST)
        out.alpha_composite(frame, (index * display_frame, 0))
    return out


def build_overview() -> None:
    font = ImageFont.load_default()
    rows = []
    labels = []
    max_width = 0
    for form in ("plain", "tide", "ember"):
        for action, (neutral_name, count, version) in ACTIONS.items():
            name = neutral_name if form == "plain" else f"boss_{form}_{action}_{version}.png"
            sheet = Image.open(BOSS / name).convert("RGBA")
            strip = preview_strip(sheet, count)
            rows.append(strip)
            labels.append(f"{form.upper()} / {action}")
            max_width = max(max_width, strip.width)
    row_height = 88
    overview = Image.new("RGBA", (140 + max_width, row_height * len(rows) + 16), (10, 12, 20, 255))
    draw = ImageDraw.Draw(overview)
    for row_index, strip in enumerate(rows):
        y = 8 + row_index * row_height
        draw.text((8, y + 28), labels[row_index], font=font, fill=(230, 235, 244, 255))
        overview.alpha_composite(strip, (132, y))
    overview.save(EVIDENCE / "boss_three_form_all_actions_overview.png", optimize=True)

    burning = Image.open(VFX / "burning_enemy_loop.png").convert("RGBA")
    burning_big = burning.resize((burning.width * 3, burning.height * 3), Image.Resampling.NEAREST)
    burning_big.save(EVIDENCE / "burning_sparks_loop_nearest_preview.png", optimize=True)


def main() -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    report = {
        "boss": build_boss_sheets(),
        "burning": build_burning_vfx(),
        "melee_telegraph": build_melee_telegraph(),
    }
    build_overview()
    (EVIDENCE / "asset_manifest.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
