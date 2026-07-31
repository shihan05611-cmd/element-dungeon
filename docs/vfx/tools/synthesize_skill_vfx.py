from __future__ import annotations

import argparse
import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw


RGBA = tuple[int, int, int, int]
Point = tuple[float, float]

WATER_CORE: RGBA = (230, 255, 255, 255)
WATER_MID: RGBA = (72, 220, 255, 230)
WATER_EDGE: RGBA = (30, 110, 255, 150)
FIRE_CORE: RGBA = (255, 255, 220, 255)
FIRE_MID: RGBA = (255, 174, 36, 235)
FIRE_EDGE: RGBA = (255, 62, 20, 160)
NEUTRAL_CORE: RGBA = (255, 255, 255, 255)
NEUTRAL_MID: RGBA = (190, 208, 220, 220)
NEUTRAL_EDGE: RGBA = (92, 112, 132, 145)
PREVIEW_BG: RGBA = (10, 15, 24, 255)


def clamp_u8(value: float) -> int:
    return max(0, min(255, int(round(value))))


def with_alpha(color: RGBA, alpha: float) -> RGBA:
    return color[0], color[1], color[2], clamp_u8(color[3] * alpha)


def new_rgba(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def draw_pixel_glow(
    image: Image.Image,
    xy: tuple[int, int],
    radius: int,
    core: RGBA,
    mid: RGBA,
    edge: RGBA,
) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    x, y = xy
    draw.ellipse((x - radius - 3, y - radius - 3, x + radius + 3, y + radius + 3), fill=edge)
    draw.ellipse((x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1), fill=mid)
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=core)


def draw_water_drop(
    image: Image.Image,
    center: Point,
    size: float,
    angle: float = 0.0,
    alpha: float = 1.0,
) -> None:
    cx, cy = center
    points: list[tuple[int, int]] = []
    base = [
        (0.0, -1.35),
        (0.72, -0.22),
        (0.75, 0.42),
        (0.35, 0.95),
        (0.0, 1.1),
        (-0.48, 0.85),
        (-0.78, 0.25),
        (-0.62, -0.35),
    ]
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    for px, py in base:
        px *= size
        py *= size
        rx = px * cos_a - py * sin_a
        ry = px * sin_a + py * cos_a
        points.append((round(cx + rx), round(cy + ry)))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon(points, fill=with_alpha(WATER_EDGE, 0.70 * alpha))
    inset = [(round(cx + (x - cx) * 0.72), round(cy + (y - cy) * 0.72)) for x, y in points]
    draw.polygon(inset, fill=with_alpha(WATER_MID, alpha))
    draw.rectangle(
        (round(cx - size * 0.25), round(cy - size * 0.55), round(cx), round(cy - size * 0.25)),
        fill=with_alpha(WATER_CORE, alpha),
    )


def draw_fire_shard(
    image: Image.Image,
    center: Point,
    size: float,
    angle: float = 0.0,
    alpha: float = 1.0,
) -> None:
    cx, cy = center
    base = [(0.0, -1.45), (0.58, -0.1), (0.36, 1.0), (-0.22, 0.55), (-0.62, 0.9), (-0.48, -0.1)]
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    points: list[tuple[int, int]] = []
    for px, py in base:
        px *= size
        py *= size
        rx = px * cos_a - py * sin_a
        ry = px * sin_a + py * cos_a
        points.append((round(cx + rx), round(cy + ry)))
    draw = ImageDraw.Draw(image, "RGBA")
    draw.polygon(points, fill=with_alpha(FIRE_EDGE, 0.75 * alpha))
    inset = [(round(cx + (x - cx) * 0.72), round(cy + (y - cy) * 0.72)) for x, y in points]
    draw.polygon(inset, fill=with_alpha(FIRE_MID, alpha))
    inner = [(round(cx + (x - cx) * 0.38), round(cy + (y - cy) * 0.38)) for x, y in points]
    draw.polygon(inner, fill=with_alpha(FIRE_CORE, alpha))


def draw_ring(
    image: Image.Image,
    center: tuple[int, int],
    radius: int,
    width: int,
    color: RGBA,
) -> None:
    if radius <= 0:
        return
    draw = ImageDraw.Draw(image, "RGBA")
    cx, cy = center
    for offset in range(max(1, width)):
        r = radius + offset
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=1)


def sheet_from_frames(frames: list[Image.Image], output: Path) -> None:
    if not frames:
        raise ValueError(f"No frames for {output}")
    width, height = frames[0].size
    if any(frame.size != (width, height) for frame in frames):
        raise ValueError(f"Frame size mismatch for {output}")
    sheet = new_rgba((width * len(frames), height))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * width, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=False)


def save_preview(
    frames: list[Image.Image],
    output: Path,
    scale: int = 4,
    duration_ms: int = 80,
    background: RGBA = PREVIEW_BG,
) -> None:
    prepared: list[Image.Image] = []
    for frame in frames:
        canvas = Image.new("RGBA", frame.size, background)
        canvas.alpha_composite(frame)
        if scale != 1:
            canvas = canvas.resize((canvas.width * scale, canvas.height * scale), Image.Resampling.NEAREST)
        prepared.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE, colors=255))
    output.parent.mkdir(parents=True, exist_ok=True)
    prepared[0].save(
        output,
        save_all=True,
        append_images=prepared[1:],
        duration=duration_ms,
        loop=0,
        disposal=2,
        optimize=False,
    )


def split_horizontal_sheet(path: Path, frame_size: int = 64) -> list[Image.Image]:
    sheet = Image.open(path).convert("RGBA")
    if sheet.height != frame_size or sheet.width % frame_size != 0:
        raise ValueError(f"Unexpected sheet dimensions: {path} = {sheet.size}")
    return [
        sheet.crop((x, 0, x + frame_size, frame_size))
        for x in range(0, sheet.width, frame_size)
    ]


def make_beam_segment(element: str, phase: int = 0) -> Image.Image:
    image = new_rgba((64, 24))
    draw = ImageDraw.Draw(image, "RGBA")
    if element == "water":
        for x in range(64):
            wave = round(math.sin((x + phase * 3) * math.tau / 16.0))
            draw.point((x, 7 + wave), fill=WATER_EDGE)
            draw.point((x, 8 + wave), fill=WATER_MID)
            draw.point((x, 15 - wave), fill=WATER_EDGE)
            draw.point((x, 14 - wave), fill=WATER_MID)
            for y in range(9 + wave, 14 - wave):
                color = WATER_CORE if 11 <= y <= 12 else WATER_MID
                draw.point((x, y), fill=color)
        for x in range((phase * 7) % 18, 64, 18):
            draw.rectangle((x, 10, min(63, x + 4), 12), fill=WATER_CORE)
    else:
        rng = random.Random(4400 + phase)
        upper: list[tuple[int, int]] = []
        lower: list[tuple[int, int]] = []
        for x in range(0, 65, 4):
            jitter = rng.choice((-2, -1, 0, 1, 2))
            upper.append((min(63, x), 7 + jitter))
            lower.append((min(63, x), 16 - jitter))
        polygon = upper + list(reversed(lower))
        draw.polygon(polygon, fill=FIRE_EDGE)
        draw.rectangle((0, 8, 63, 15), fill=FIRE_MID)
        draw.rectangle((0, 10, 63, 13), fill=FIRE_CORE)
        for x in range((phase * 5) % 14, 64, 14):
            draw.polygon([(x, 8), (min(63, x + 5), 4), (min(63, x + 3), 9)], fill=FIRE_MID)
    # Exact first/last-column match keeps horizontal repetition clean.
    first = image.crop((0, 0, 1, image.height))
    image.paste(first, (63, 0))
    return image


def make_beam_tick_frames(element: str) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(8):
        image = new_rgba((64, 64))
        progress = index / 7.0
        alpha = max(0.0, 1.0 - progress)
        if element == "water":
            draw_ring(image, (32, 32), 6 + round(progress * 20), 2, with_alpha(WATER_MID, alpha))
            for p in range(5):
                angle = p * math.tau / 5.0 + progress * 0.7
                radius = 5 + progress * 23
                draw_water_drop(
                    image,
                    (32 + math.cos(angle) * radius, 32 + math.sin(angle) * radius),
                    2.8 - progress,
                    angle + math.pi / 2,
                    alpha,
                )
            if index < 3:
                draw_pixel_glow(image, (32, 32), 2 + index, WATER_CORE, WATER_MID, WATER_EDGE)
        else:
            draw = ImageDraw.Draw(image, "RGBA")
            for p in range(8):
                angle = p * math.tau / 8.0 + progress * 0.35
                inner = 4 + progress * 5
                outer = 9 + progress * 22 + (p % 2) * 3
                points = [
                    (round(32 + math.cos(angle - 0.12) * inner), round(32 + math.sin(angle - 0.12) * inner)),
                    (round(32 + math.cos(angle) * outer), round(32 + math.sin(angle) * outer)),
                    (round(32 + math.cos(angle + 0.12) * inner), round(32 + math.sin(angle + 0.12) * inner)),
                ]
                draw.polygon(points, fill=with_alpha(FIRE_MID, alpha))
            if index < 3:
                draw_pixel_glow(image, (32, 32), 2 + index, FIRE_CORE, FIRE_MID, FIRE_EDGE)
        frames.append(image)
    return frames


def make_beam_preview() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(12):
        canvas = new_rgba((384, 96))
        draw = ImageDraw.Draw(canvas, "RGBA")
        for row, element in enumerate(("water", "fire")):
            cy = 27 + row * 44
            draw.ellipse((12, cy - 9, 30, cy + 9), outline=(120, 140, 165, 255), width=2)
            for x in range(5):
                segment = make_beam_segment(element, index)
                canvas.alpha_composite(segment, (29 + x * 64, cy - 12))
            pulse = make_beam_tick_frames(element)[index % 8]
            canvas.alpha_composite(pulse, (300, cy - 32))
            draw.line((349, cy, 374, cy), fill=(80, 95, 115, 190), width=1)
        frames.append(canvas)
    return frames


def make_reclaim_particle_frames(element: str) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(8):
        image = new_rgba((32, 32))
        phase = index / 8.0
        pulse = 1.0 + math.sin(phase * math.tau) * 0.15
        if element == "water":
            draw_water_drop(image, (16, 16), 5.5 * pulse, phase * 0.35)
            draw = ImageDraw.Draw(image, "RGBA")
            draw.arc((6, 6, 26, 26), 210 + index * 15, 300 + index * 15, fill=with_alpha(WATER_EDGE, 0.55), width=1)
        else:
            draw_fire_shard(image, (16, 16), 5.2 * pulse, phase * math.tau)
            draw = ImageDraw.Draw(image, "RGBA")
            tail_angle = phase * math.tau + math.pi
            for distance, alpha in ((7, 0.60), (10, 0.35)):
                x = round(16 + math.cos(tail_angle) * distance)
                y = round(16 + math.sin(tail_angle) * distance)
                draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=with_alpha(FIRE_MID, alpha))
        frames.append(image)
    return frames


def make_reclaim_extract_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(8):
        image = new_rgba((64, 64))
        progress = index / 7.0
        radius = round(23 - progress * 13)
        draw_ring(image, (32, 32), radius, 2, with_alpha(NEUTRAL_MID, 1.0 - progress * 0.75))
        for p in range(4):
            angle = p * math.tau / 4.0 + progress * 1.1
            r = radius + 4
            x = round(32 + math.cos(angle) * r)
            y = round(32 + math.sin(angle) * r)
            draw_pixel_glow(image, (x, y), 1, NEUTRAL_CORE, NEUTRAL_MID, with_alpha(NEUTRAL_EDGE, 0.6))
        frames.append(image)
    return frames


def make_reclaim_arrival_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(8):
        image = new_rgba((64, 64))
        progress = index / 7.0
        for p in range(6):
            angle = p * math.tau / 6.0 + progress * 0.5
            radius = max(2.0, 29.0 * (1.0 - progress))
            x = round(32 + math.cos(angle) * radius)
            y = round(32 + math.sin(angle) * radius)
            draw_pixel_glow(image, (x, y), 1, NEUTRAL_CORE, NEUTRAL_MID, NEUTRAL_EDGE)
        if index >= 5:
            flash = 1.0 - (index - 5) / 3.0
            draw_ring(image, (32, 32), 4 + (index - 5) * 4, 2, with_alpha(NEUTRAL_MID, flash))
            draw_pixel_glow(image, (32, 32), 2, NEUTRAL_CORE, NEUTRAL_MID, NEUTRAL_EDGE)
        frames.append(image)
    return frames


def quadratic_bezier(start: Point, control: Point, end: Point, t: float) -> Point:
    omt = 1.0 - t
    return (
        omt * omt * start[0] + 2.0 * omt * t * control[0] + t * t * end[0],
        omt * omt * start[1] + 2.0 * omt * t * control[1] + t * t * end[1],
    )


def make_reclaim_preview() -> list[Image.Image]:
    frames: list[Image.Image] = []
    water_particles = make_reclaim_particle_frames("water")
    fire_particles = make_reclaim_particle_frames("fire")
    for index in range(18):
        canvas = new_rgba((384, 176))
        draw = ImageDraw.Draw(canvas, "RGBA")
        for row, element in enumerate(("water", "fire")):
            cy = 47 + row * 82
            start = (56.0, float(cy))
            end = (326.0, float(cy))
            control = (190.0, float(cy - 48 if row == 0 else cy + 48))
            draw.ellipse((36, cy - 24, 76, cy + 24), outline=(92, 106, 126, 255), width=2)
            draw.ellipse((308, cy - 20, 344, cy + 20), outline=(142, 154, 174, 255), width=2)
            draw.arc((48, cy - 31, 340, cy + 31), 190, 350, fill=(48, 62, 82, 150), width=1)
            particle_frames = water_particles if element == "water" else fire_particles
            for particle_index in range(4):
                t = ((index - particle_index * 3) % 18) / 17.0
                if index < particle_index * 2:
                    continue
                x, y = quadratic_bezier(start, control, end, t)
                particle = particle_frames[(index + particle_index * 2) % 8]
                canvas.alpha_composite(particle, (round(x - 16), round(y - 16)))
            if index >= 14:
                ring_color = WATER_MID if element == "water" else FIRE_MID
                draw_ring(canvas, (round(end[0]), round(end[1])), 5 + (index - 14) * 3, 2, with_alpha(ring_color, 1.0 - (index - 14) / 5.0))
        frames.append(canvas)
    return frames


def make_burning_loop_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    seeds = [(11, 0), (23, 3), (39, 6), (51, 9), (31, 1), (46, 5)]
    for index in range(12):
        image = new_rgba((64, 64))
        draw = ImageDraw.Draw(image, "RGBA")
        # Restrained tongues around the enemy footprint, leaving the center readable.
        for base_x, height, lean in ((14, 11, -2), (22, 8, 2), (42, 10, -1), (50, 13, 2)):
            flicker = round(math.sin((index + base_x) * 0.9) * 2)
            y = 54
            points = [
                (base_x - 4, y),
                (base_x - 2, y - height // 2),
                (base_x + lean + flicker, y - height),
                (base_x + 3, y - height // 3),
                (base_x + 5, y),
            ]
            draw.polygon(points, fill=FIRE_EDGE)
            inner = [(round(base_x + (x - base_x) * 0.55), round(y + (py - y) * 0.70)) for x, py in points]
            draw.polygon(inner, fill=FIRE_MID)
        for base_x, offset in seeds:
            age = (index + offset) % 12
            y = 53 - age * 3
            x = base_x + round(math.sin((age + base_x) * 0.8) * 3)
            alpha = 1.0 - age / 12.0
            if y > 10:
                if base_x % 2:
                    draw_fire_shard(image, (x, y), 2.0, age * 0.28, alpha)
                else:
                    draw.rectangle((x, y, x + 1, y + 1), fill=with_alpha(FIRE_MID, alpha))
        frames.append(image)
    return frames


def make_burning_tick_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(8):
        image = new_rgba((64, 64))
        progress = index / 7.0
        draw = ImageDraw.Draw(image, "RGBA")
        for p in range(9):
            angle = -math.pi + p * math.pi / 8.0
            radius = 8 + progress * 24 + (p % 3) * 2
            x = 32 + math.cos(angle) * radius
            y = 43 + math.sin(angle) * radius
            draw_fire_shard(image, (x, y), max(1.4, 3.6 - progress * 2.0), angle + math.pi / 2, 1.0 - progress)
        if index <= 3:
            draw.arc((16, 26, 48, 58), 190, 350, fill=with_alpha(FIRE_MID, 1.0 - progress * 0.5), width=2)
        frames.append(image)
    return frames


def make_burning_preview() -> list[Image.Image]:
    loop = make_burning_loop_frames()
    tick = make_burning_tick_frames()
    frames: list[Image.Image] = []
    for index in range(16):
        frame = loop[index % len(loop)].copy()
        if 7 <= index < 15:
            frame.alpha_composite(tick[index - 7])
        frames.append(frame)
    return frames


def make_unending_loop_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    bubbles = [(10, 0, 2), (20, 4, 3), (43, 7, 2), (53, 2, 3), (32, 8, 2)]
    for index in range(12):
        image = new_rgba((64, 64))
        draw = ImageDraw.Draw(image, "RGBA")
        for base_x, offset, radius in bubbles:
            age = (index + offset) % 12
            y = 53 - age * 3
            x = base_x + round(math.sin((age + offset) * 0.55) * 4)
            alpha = 1.0 - age / 13.0
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=with_alpha(WATER_MID, alpha), width=1)
            if radius >= 3:
                draw.point((x - 1, y - 1), fill=with_alpha(WATER_CORE, alpha))
        for p in range(3):
            angle = index * 0.20 + p * math.tau / 3.0
            x = 32 + math.cos(angle) * 22
            y = 40 + math.sin(angle) * 9
            draw_water_drop(image, (x, y), 2.5, angle, 0.75)
        frames.append(image)
    return frames


def make_unending_trigger_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []
    for index in range(8):
        image = new_rgba((64, 64))
        progress = index / 7.0
        draw_ring(image, (32, 43), 5 + round(progress * 22), 2, with_alpha(WATER_MID, 1.0 - progress))
        for p in range(5):
            angle = p * math.tau / 5.0 + 0.4
            radius = 17 * (1.0 - progress) + 2
            x = 32 + math.cos(angle) * radius
            y = 38 + math.sin(angle) * radius - progress * 12
            draw_water_drop(image, (x, y), max(1.6, 3.3 - progress), angle, 1.0 - progress * 0.6)
        if index <= 2:
            draw_pixel_glow(image, (32, 40), 2 + index, WATER_CORE, WATER_MID, WATER_EDGE)
        frames.append(image)
    return frames


def make_unending_preview() -> list[Image.Image]:
    loop = make_unending_loop_frames()
    trigger = make_unending_trigger_frames()
    frames: list[Image.Image] = []
    for index in range(16):
        frame = loop[index % len(loop)].copy()
        if 7 <= index < 15:
            frame.alpha_composite(trigger[index - 7])
        frames.append(frame)
    return frames


def save_asset_set(project_root: Path) -> list[Path]:
    vfx_root = project_root / "assets" / "generated" / "vfx"
    written: list[Path] = []

    fury_dir = vfx_root / "elemental_fury"
    accepted_source = fury_dir / "source_candidates" / "burst_core_neutral_candidate.png"
    accepted_output = fury_dir / "burst_core_neutral_v1.png"
    if not accepted_source.exists():
        raise FileNotFoundError(accepted_source)
    if accepted_output.exists():
        raise FileExistsError(f"Refusing to overwrite: {accepted_output}")
    shutil.copyfile(accepted_source, accepted_output)
    fury_frames = split_horizontal_sheet(accepted_output)
    fury_preview = fury_dir / "burst_core_neutral_v1_preview.gif"
    save_preview(fury_frames, fury_preview, scale=4, duration_ms=80)
    written.extend((accepted_output, fury_preview))

    laser_dir = vfx_root / "elemental_laser"
    for element in ("water", "fire"):
        segment = make_beam_segment(element)
        segment_path = laser_dir / f"beam_segment_{element}_v1.png"
        segment_path.parent.mkdir(parents=True, exist_ok=True)
        segment.save(segment_path)
        tick_frames = make_beam_tick_frames(element)
        tick_path = laser_dir / f"beam_tick_{element}_v1.png"
        sheet_from_frames(tick_frames, tick_path)
        written.extend((segment_path, tick_path))
    beam_preview = laser_dir / "beam_preview_v1.gif"
    save_preview(make_beam_preview(), beam_preview, scale=2, duration_ms=80)
    written.append(beam_preview)

    reclaim_dir = vfx_root / "element_reclaim"
    for element in ("water", "fire"):
        particle_frames = make_reclaim_particle_frames(element)
        particle_path = reclaim_dir / f"reclaim_particle_{element}_v1.png"
        sheet_from_frames(particle_frames, particle_path)
        written.append(particle_path)
    extract_frames = make_reclaim_extract_frames()
    arrival_frames = make_reclaim_arrival_frames()
    extract_path = reclaim_dir / "reclaim_extract_neutral_v1.png"
    arrival_path = reclaim_dir / "reclaim_arrival_neutral_v1.png"
    sheet_from_frames(extract_frames, extract_path)
    sheet_from_frames(arrival_frames, arrival_path)
    reclaim_preview = reclaim_dir / "reclaim_motion_preview_v1.gif"
    save_preview(make_reclaim_preview(), reclaim_preview, scale=2, duration_ms=65)
    written.extend((extract_path, arrival_path, reclaim_preview))

    burning_dir = vfx_root / "burning"
    burning_loop = make_burning_loop_frames()
    burning_tick = make_burning_tick_frames()
    burning_loop_path = burning_dir / "burning_enemy_loop_v1.png"
    burning_tick_path = burning_dir / "burning_tick_v1.png"
    sheet_from_frames(burning_loop, burning_loop_path)
    sheet_from_frames(burning_tick, burning_tick_path)
    burning_preview = burning_dir / "burning_preview_v1.gif"
    save_preview(make_burning_preview(), burning_preview, scale=4, duration_ms=70)
    written.extend((burning_loop_path, burning_tick_path, burning_preview))

    unending_dir = vfx_root / "unending"
    unending_loop = make_unending_loop_frames()
    unending_trigger = make_unending_trigger_frames()
    unending_loop_path = unending_dir / "unending_enemy_loop_v1.png"
    unending_trigger_path = unending_dir / "unending_trigger_v1.png"
    sheet_from_frames(unending_loop, unending_loop_path)
    sheet_from_frames(unending_trigger, unending_trigger_path)
    unending_preview = unending_dir / "unending_preview_v1.gif"
    save_preview(make_unending_preview(), unending_preview, scale=4, duration_ms=70)
    written.extend((unending_loop_path, unending_trigger_path, unending_preview))

    return written


def validate_outputs(paths: list[Path]) -> None:
    for path in paths:
        if not path.exists() or path.stat().st_size <= 0:
            raise RuntimeError(f"Missing or empty output: {path}")
        image = Image.open(path)
        if path.suffix.lower() == ".png":
            rgba = image.convert("RGBA")
            alpha = rgba.getchannel("A")
            if alpha.getextrema() == (255, 255):
                raise RuntimeError(f"PNG has no transparency: {path}")
            if alpha.getbbox() is None:
                raise RuntimeError(f"PNG is fully transparent: {path}")
            corners = [rgba.getpixel((0, 0))[3], rgba.getpixel((rgba.width - 1, 0))[3]]
            if any(corner != 0 for corner in corners):
                raise RuntimeError(f"PNG top corners are not transparent: {path}")
        elif path.suffix.lower() == ".gif":
            frame_count = getattr(image, "n_frames", 1)
            if frame_count < 2:
                raise RuntimeError(f"GIF is not animated: {path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Synthesize deterministic first-batch skill VFX.")
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    paths = save_asset_set(root)
    validate_outputs(paths)
    for path in paths:
        print(path.relative_to(root).as_posix())
    print(f"VALIDATED={len(paths)}/{len(paths)}")


if __name__ == "__main__":
    main()
