from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BG = (9, 14, 23, 255)
PANEL = (17, 24, 37, 235)
TEXT = (232, 239, 248, 255)
MUTED = (138, 157, 181, 255)
GUIDE = (255, 222, 92, 210)
WATER = (72, 220, 255, 255)
FIRE = (255, 142, 32, 255)

SKILL_LABELS = {
    "element_bolt": "元素弹 / ELEMENT BOLT",
    "elemental_fury": "元素之怒 / ELEMENTAL FURY",
    "elemental_laser": "元素激光 / ELEMENTAL LASER",
    "element_reclaim": "元素回收 / ELEMENT RECLAIM",
    "burning": "燃烧 / BURNING",
    "unending": "不息 / UNENDING",
}

EXPECTED_PNGS = {
    "element_bolt/icon.png": (256, 256),
    "element_bolt/projectile_fire_no_jitter_spritesheet.png": None,
    "element_bolt/projectile_water_no_jitter_spritesheet.png": None,
    "elemental_fury/icon.png": (256, 256),
    "elemental_fury/burst_core.png": (512, 64),
    "elemental_laser/icon.png": (256, 256),
    "elemental_laser/beam_segment_water.png": (64, 24),
    "elemental_laser/beam_segment_fire.png": (64, 24),
    "elemental_laser/beam_tick_water.png": (512, 64),
    "elemental_laser/beam_tick_fire.png": (512, 64),
    "elemental_laser/beam_segment_water_mask.png": (64, 24),
    "elemental_laser/beam_segment_fire_mask.png": (64, 24),
    "elemental_laser/beam_tick_water_mask.png": (512, 64),
    "elemental_laser/beam_tick_fire_mask.png": (512, 64),
    "element_reclaim/icon.png": (256, 256),
    "element_reclaim/reclaim_particle_water.png": (256, 32),
    "element_reclaim/reclaim_particle_fire.png": (256, 32),
    "element_reclaim/reclaim_extract_neutral.png": (512, 64),
    "element_reclaim/reclaim_arrival_neutral.png": (512, 64),
    "burning/icon.png": (256, 256),
    "burning/burning_enemy_loop.png": (768, 64),
    "burning/burning_tick.png": (512, 64),
    "unending/icon.png": (256, 256),
    "unending/unending_enemy_loop.png": (768, 64),
    "unending/unending_trigger.png": (512, 64),
}


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/seguisym.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default(size=size)


def rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def split_sheet(path: Path, frame_width: int, frame_height: int) -> list[Image.Image]:
    sheet = rgba(path)
    if sheet.height != frame_height or sheet.width % frame_width != 0:
        raise ValueError(f"Bad sheet dimensions: {path} {sheet.size}")
    return [
        sheet.crop((x, 0, x + frame_width, frame_height))
        for x in range(0, sheet.width, frame_width)
    ]


def fit(image: Image.Image, size: tuple[int, int], resample: Image.Resampling = Image.Resampling.NEAREST) -> Image.Image:
    scale = min(size[0] / image.width, size[1] / image.height)
    return image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        resample,
    )


def composite_center(canvas: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
    canvas.alpha_composite(image, (center[0] - image.width // 2, center[1] - image.height // 2))


def alpha_coverage(image: Image.Image) -> float:
    alpha = image.convert("RGBA").getchannel("A")
    histogram = alpha.histogram()
    nonzero = sum(histogram[1:])
    return nonzero / (image.width * image.height)


def key_pollution(image: Image.Image) -> int:
    count = 0
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha == 0:
            continue
        green_key = green > red + 80 and green > blue + 80 and green > 180
        magenta_key = red > green + 80 and blue > green + 80 and red > 180 and blue > 180
        if green_key or magenta_key:
            count += 1
    return count


def corner_alpha(image: Image.Image) -> list[int]:
    image = image.convert("RGBA")
    return [
        image.getpixel((0, 0))[3],
        image.getpixel((image.width - 1, 0))[3],
        image.getpixel((0, image.height - 1))[3],
        image.getpixel((image.width - 1, image.height - 1))[3],
    ]


def draw_card(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], title: str) -> None:
    draw.rounded_rectangle(box, radius=12, fill=PANEL, outline=(49, 65, 88, 255), width=1)
    draw.text((box[0] + 18, box[1] + 14), title, fill=TEXT, font=font(22))


def make_icon_qa(vfx_root: Path, output: Path) -> None:
    canvas = Image.new("RGBA", (1152, 720), BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((32, 24), "任务 17 · 图标缩放与深色背景 QA", fill=TEXT, font=font(30))
    draw.text((32, 64), "同一 icon.png 在 128 / 64 / 32 px 下检查轮廓、留白和元素形状差异", fill=MUTED, font=font(17))
    skills = list(SKILL_LABELS)
    for index, skill in enumerate(skills):
        column = index % 3
        row = index // 3
        x = 28 + column * 372
        y = 108 + row * 292
        box = (x, y, x + 352, y + 268)
        draw_card(draw, box, SKILL_LABELS[skill])
        icon = rgba(vfx_root / skill / "icon.png")
        for size, center_x in ((128, x + 86), (64, x + 215), (32, x + 304)):
            scaled = icon.resize((size, size), Image.Resampling.LANCZOS)
            composite_center(canvas, scaled, (center_x, y + 146))
            draw.text((center_x - 16, y + 225), str(size), fill=MUTED, font=font(14))
    canvas.save(output)


def make_testroom_particle_qa(vfx_root: Path, base: Image.Image, output: Path) -> None:
    base = base.resize((1152, 648), Image.Resampling.LANCZOS)
    crop = base.crop((700, 300, 1110, 590))
    canvas = Image.new("RGBA", (1152, 720), BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((30, 22), "TestRoom 深色背景 · 敌人附着粒子 QA", fill=TEXT, font=font(30))
    draw.text((30, 62), "上排 100% 世界尺寸；下排 2×审查缩放。只用于视觉核验，不代表场景已接线。", fill=MUTED, font=font(17))
    panels = [
        ("燃烧 100%", "burning", 1.0),
        ("不息 100%", "unending", 1.0),
        ("燃烧 2×", "burning", 2.0),
        ("不息 2×", "unending", 2.0),
    ]
    for index, (label, skill, scale) in enumerate(panels):
        column = index % 2
        row = index // 2
        x = 34 + column * 558
        y = 104 + row * 292
        panel = crop.resize((520, 240), Image.Resampling.LANCZOS)
        canvas.alpha_composite(panel, (x, y))
        draw.rectangle((x, y, x + 520, y + 240), outline=(67, 84, 108, 255), width=2)
        draw.rounded_rectangle((x + 12, y + 12, x + 155, y + 46), 8, fill=(4, 9, 16, 220))
        draw.text((x + 22, y + 18), label, fill=TEXT, font=font(16))
        if skill == "burning":
            frame = split_sheet(vfx_root / skill / "burning_enemy_loop.png", 64, 64)[4]
        else:
            frame = split_sheet(vfx_root / skill / "unending_enemy_loop.png", 64, 64)[4]
        frame = frame.resize((round(64 * scale), round(64 * scale)), Image.Resampling.NEAREST)
        # Enemy center within the crop is approximately (200, 182).
        composite_center(canvas, frame, (x + 200, y + 182))
    canvas.save(output)


def make_range_qa(vfx_root: Path, base: Image.Image, output: Path) -> None:
    base = base.resize((1152, 648), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (1152, 1180), BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((30, 22), "任务 15 权威范围叠加 QA", fill=TEXT, font=font(30))
    draw.text((30, 62), "Fury 96/192 半径 · Beam 320×24 · Reclaim 160 半径；贴图不决定碰撞", fill=MUTED, font=font(17))

    battlefield = base.crop((38, 270, 1110, 610))

    # Fury panel.
    panel = battlefield.crop((0, 0, 520, 340))
    canvas.alpha_composite(panel, (30, 110))
    draw.rectangle((30, 110, 550, 450), outline=(67, 84, 108, 255), width=2)
    center = (290, 290)
    fury_frame = split_sheet(vfx_root / "elemental_fury" / "burst_core.png", 64, 64)[3]
    fury_frame = fury_frame.resize((160, 160), Image.Resampling.NEAREST)
    composite_center(canvas, fury_frame, center)
    for radius, color, label in ((96, WATER, "R=96"), (192, FIRE, "R=192 (2.0×)")):
        draw.ellipse(
            (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
            outline=color,
            width=2,
        )
        draw.text((center[0] + radius - 64, center[1] - 22), label, fill=color, font=font(14))
    draw.text((48, 126), "ELEMENTAL FURY", fill=TEXT, font=font(18))

    # Beam panel.
    panel = battlefield.crop((520, 0, 1072, 200)).resize((552, 340), Image.Resampling.LANCZOS)
    canvas.alpha_composite(panel, (570, 110))
    draw.rectangle((570, 110, 1122, 450), outline=(67, 84, 108, 255), width=2)
    origin = (666, 287)
    segment = rgba(vfx_root / "elemental_laser" / "beam_segment_water.png")
    for index in range(5):
        canvas.alpha_composite(segment, (origin[0] + index * 64, origin[1] - 12))
    draw.rectangle((origin[0], origin[1] - 12, origin[0] + 320, origin[1] + 12), outline=GUIDE, width=2)
    for px in (origin[0] + 120, origin[0] + 240):
        pulse = split_sheet(vfx_root / "elemental_laser" / "beam_tick_water.png", 64, 64)[2]
        composite_center(canvas, pulse, (px, origin[1]))
    draw.text((588, 126), "ELEMENTAL LASER · 320×24", fill=TEXT, font=font(18))

    # Reclaim panel.
    panel = battlefield.resize((1072, 610), Image.Resampling.LANCZOS)
    canvas.alpha_composite(panel, (40, 520))
    draw.rectangle((40, 520, 1112, 1130), outline=(67, 84, 108, 255), width=2)
    player = (310, 932)
    draw.ellipse((player[0] - 160, player[1] - 160, player[0] + 160, player[1] + 160), outline=GUIDE, width=3)
    draw.text((player[0] + 90, player[1] - 145), "QUERY R=160", fill=GUIDE, font=font(16))
    water_frames = split_sheet(vfx_root / "element_reclaim" / "reclaim_particle_water.png", 32, 32)
    fire_frames = split_sheet(vfx_root / "element_reclaim" / "reclaim_particle_fire.png", 32, 32)
    starts = [(205, 830, water_frames), (430, 875, fire_frames)]
    for start_x, start_y, frames in starts:
        draw.ellipse((start_x - 13, start_y - 13, start_x + 13, start_y + 13), outline=MUTED, width=2)
        control = ((start_x + player[0]) / 2, min(start_y, player[1]) - 85)
        points: list[tuple[int, int]] = []
        for step in range(21):
            t = step / 20.0
            omt = 1.0 - t
            x = omt * omt * start_x + 2 * omt * t * control[0] + t * t * player[0]
            y = omt * omt * start_y + 2 * omt * t * control[1] + t * t * player[1]
            points.append((round(x), round(y)))
        draw.line(points, fill=(112, 138, 172, 180), width=2)
        for step in (3, 9, 15):
            frame = frames[step % len(frames)]
            composite_center(canvas, frame, points[step])
    arrival = split_sheet(vfx_root / "element_reclaim" / "reclaim_arrival_neutral.png", 64, 64)[6]
    composite_center(canvas, arrival, player)
    draw.text((58, 538), "ELEMENT RECLAIM · matched enemy → player", fill=TEXT, font=font(18))
    canvas.save(output)


def make_final_overview(vfx_root: Path, output: Path) -> None:
    canvas = Image.new("RGBA", (1152, 900), BG)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((32, 24), "任务 17 第二阶段最终资产总览", fill=TEXT, font=font(32))
    draw.text((32, 68), "稳定 icon.png + 代表帧；候选与源稿保留在各技能目录", fill=MUTED, font=font(17))
    rows = [
        ("element_bolt", rgba(vfx_root / "element_bolt" / "projectile_water_no_jitter_spritesheet.png")),
        ("elemental_fury", split_sheet(vfx_root / "elemental_fury" / "burst_core.png", 64, 64)[3]),
        ("elemental_laser", rgba(vfx_root / "elemental_laser" / "beam_segment_water.png")),
        ("element_reclaim", split_sheet(vfx_root / "element_reclaim" / "reclaim_particle_water.png", 32, 32)[2]),
        ("burning", split_sheet(vfx_root / "burning" / "burning_enemy_loop.png", 64, 64)[4]),
        ("unending", split_sheet(vfx_root / "unending" / "unending_enemy_loop.png", 64, 64)[4]),
    ]
    for index, (skill, sample) in enumerate(rows):
        column = index % 3
        row = index // 3
        x = 30 + column * 372
        y = 110 + row * 370
        draw_card(draw, (x, y, x + 350, y + 340), SKILL_LABELS[skill])
        icon = rgba(vfx_root / skill / "icon.png").resize((160, 160), Image.Resampling.LANCZOS)
        composite_center(canvas, icon, (x + 96, y + 150))
        sample_box = fit(sample, (130, 130))
        composite_center(canvas, sample_box, (x + 266, y + 150))
        draw.text((x + 28, y + 282), "ICON", fill=MUTED, font=font(14))
        draw.text((x + 238, y + 282), "VFX", fill=MUTED, font=font(14))
    canvas.save(output)


def run_stats(vfx_root: Path) -> dict:
    rows = []
    failures: list[str] = []
    for relative, expected in EXPECTED_PNGS.items():
        path = vfx_root / relative
        if not path.exists():
            failures.append(f"missing:{relative}")
            continue
        image = Image.open(path)
        converted = image.convert("RGBA")
        size_ok = expected is None or converted.size == expected
        corners = corner_alpha(converted)
        corners_ok = all(alpha == 0 for alpha in corners)
        coverage = alpha_coverage(converted)
        pollution = key_pollution(converted) if relative.endswith("icon.png") else 0
        if not size_ok:
            failures.append(f"size:{relative}:{converted.size}!={expected}")
        if not corners_ok:
            failures.append(f"corners:{relative}:{corners}")
        if relative.endswith("icon.png") and not (0.12 <= coverage <= 0.75):
            failures.append(f"icon_coverage:{relative}:{coverage:.4f}")
        if pollution:
            failures.append(f"key_pollution:{relative}:{pollution}")
        rows.append(
            {
                "file": relative,
                "size": list(converted.size),
                "mode": image.mode,
                "coverage": round(coverage, 6),
                "corner_alpha": corners,
                "key_pollution_pixels": pollution,
                "pass": size_ok and corners_ok and pollution == 0,
            }
        )

    laser = vfx_root / "elemental_laser"
    mask_pairs = []
    for base in (
        "beam_segment_water",
        "beam_segment_fire",
        "beam_tick_water",
        "beam_tick_fire",
    ):
        color = rgba(laser / f"{base}.png")
        mask = Image.open(laser / f"{base}_mask.png").convert("L")
        aligned = color.size == mask.size and list(color.getchannel("A").getdata()) == list(mask.getdata())
        mask_pairs.append({"base": base, "size": list(color.size), "aligned": aligned})
        if not aligned:
            failures.append(f"mask_alignment:{base}")

    return {
        "final_png_count": len(rows),
        "rows": rows,
        "mask_pairs": mask_pairs,
        "black_additive_assets": 0,
        "black_additive_check": "N/A: final assets use RGBA alpha or color+mask; no black-background additive texture selected.",
        "failures": failures,
        "pass": not failures,
    }


def write_report(stats: dict, output: Path) -> None:
    icon_rows = [row for row in stats["rows"] if row["file"].endswith("icon.png")]
    min_coverage = min(row["coverage"] for row in icon_rows)
    max_coverage = max(row["coverage"] for row in icon_rows)
    text = f"""# 任务 17 第二阶段 QA 报告

状态：{"PASS" if stats["pass"] else "FAIL"}

## 自动检查

- 最终 PNG：{stats["final_png_count"]} 个。
- 六个图标：256×256 RGBA，透明四角，主体覆盖率 {min_coverage:.1%}～{max_coverage:.1%}。
- 色键边缘污染：六图标可见像素中绿色/洋红色键残留均为 0。
- 激光颜色图/遮罩：4/4 尺寸一致，遮罩像素与颜色图 alpha 完全一致。
- 黑底加法：本版未选用黑底加法纹理；最终资产均使用 RGBA alpha 或颜色图+遮罩，因此该项 N/A。
- 失败项：{len(stats["failures"])}。

## 可视化检查文件

- `stage2_icons_scale_qa.png`：128/64/32 px 图标缩放与深色背景可读性。
- `stage2_testroom_particles_qa.png`：燃烧/不息在真实 TestRoom 深色背景上的 100% 与 2×检查。
- `stage2_range_overlay_qa.png`：Fury 96/192、Beam 320×24、Reclaim 160 权威范围叠加。
- `stage2_final_overview.png`：六技能稳定图标和代表 VFX 总览。
- `testroom_runtime_base.png`：Godot 4.7.1 运行时原始截图。

所有叠加图均为 QA 合成，不代表已修改或接入 TestRoom 场景。
"""
    output.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    vfx_root = root / "assets" / "generated" / "vfx"
    qa_root = root / "docs" / "vfx" / "qa"
    qa_root.mkdir(parents=True, exist_ok=True)
    base = rgba(qa_root / "testroom_runtime_base.png")

    make_icon_qa(vfx_root, qa_root / "stage2_icons_scale_qa.png")
    make_testroom_particle_qa(vfx_root, base, qa_root / "stage2_testroom_particles_qa.png")
    make_range_qa(vfx_root, base, qa_root / "stage2_range_overlay_qa.png")
    make_final_overview(vfx_root, qa_root / "stage2_final_overview.png")
    stats = run_stats(vfx_root)
    (qa_root / "stage2_qa_stats.json").write_text(
        json.dumps(stats, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    write_report(stats, qa_root / "stage2_qa_report.md")
    print(f"FINAL_PNG={stats['final_png_count']}")
    print(f"MASK_ALIGNMENT={sum(1 for pair in stats['mask_pairs'] if pair['aligned'])}/{len(stats['mask_pairs'])}")
    print(f"FAILURES={len(stats['failures'])}")
    if stats["failures"]:
        for failure in stats["failures"]:
            print(f"FAIL:{failure}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
