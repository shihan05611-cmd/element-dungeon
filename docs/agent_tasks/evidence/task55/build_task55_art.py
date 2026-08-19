from __future__ import annotations

import csv
import hashlib
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
ROOM_DIR = ROOT / "assets/world/rooms/tidal_dungeon/platform_room_v1"
EVIDENCE = ROOT / "docs/agent_tasks/evidence/task55"
SOURCE_DIR = EVIDENCE / "sources"
QA_DIR = EVIDENCE / "qa"
REPORT_DIR = EVIDENCE / "reports"

WALL = ROOM_DIR / "background_wall_v1.png"
BACK = ROOM_DIR / "back_decor_v1.png"
FRONT = ROOM_DIR / "front_decor_v1.png"
GROUND = ROOM_DIR / "ground_floor_v1.png"
SHORT = ROOM_DIR / "platform_short_v1.png"
MEDIUM = ROOM_DIR / "platform_medium_v1.png"
LONG = ROOM_DIR / "platform_long_v1.png"

EXPECTED_PROTECTED = {
    ROOT / "docs/agent_tasks/completed/53_tidal_tiles_interactables_and_ranged_enemy_art.md": "6165C1E84F7160F07AC75D8ECAE533144A8550DFD6DF0F6C4553ADC2B12CD1AE",
    ROOT / "docs/agent_tasks/completed/49_five_stage_demo_flow_and_first_room_reward.md": "9D292B11D85CEBAB3913B08122DC536EA80CD4103F616FD6B551DB0927A7BB62",
    ROOT / "docs/agent_tasks/completed/52_player_dodge_distance_five_body_widths.md": "BC4B57BE63048B4DCE5D939719078FF13DC4F4187E054932A744F7880DD993FE",
    ROOT / "assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png": "2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519",
    ROOT / "assets/world/interactables/run_reward_chest/chest_closed_v2.png": "2714DAC5A5EC44B7C092A7D2F3574FB0E71A6529090138051DE1FA154C400D97",
    ROOT / "assets/world/interactables/run_route_portal/portal_active_v2.png": "0EDDAA9C484FEDB119C31DA6E081141549FCD4297E7823151C4A2BD330A7C2EA",
    ROOT / "assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png": "10C931DD8823F5DA24AA6A6EFC13D00944A0EB57F07BF7AAEE6EC531786F65F1",
}

BG_PALETTE = [
    (3, 10, 23), (4, 15, 31), (6, 22, 39), (8, 29, 49),
    (10, 37, 59), (13, 46, 69), (17, 56, 80), (22, 66, 90),
    (25, 31, 65), (31, 38, 77),
]
DECOR_PALETTE = BG_PALETTE + [(28, 76, 96), (38, 91, 110), (41, 35, 86), (55, 44, 105)]
PLATFORM_PALETTE = [
    (4, 12, 27), (6, 20, 39), (10, 34, 55), (15, 49, 72),
    (22, 64, 86), (31, 78, 99), (42, 91, 110), (49, 104, 122),
    (20, 17, 55), (32, 24, 75), (47, 34, 96), (62, 47, 116),
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def crop_to_ratio(image: Image.Image, width: int, height: int) -> Image.Image:
    image = image.convert("RGBA")
    desired = width / height
    current = image.width / image.height
    if current > desired:
        new_w = round(image.height * desired)
        x0 = (image.width - new_w) // 2
        return image.crop((x0, 0, x0 + new_w, image.height))
    new_h = round(image.width / desired)
    y0 = (image.height - new_h) // 2
    return image.crop((0, y0, image.width, y0 + new_h))


def palette_map(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    image = image.convert("RGBA")
    mapped = []
    for r, g, b, a in image.getdata():
        if a < 96:
            mapped.append((0, 0, 0, 0))
            continue
        nearest = min(palette, key=lambda p: (r - p[0]) ** 2 + (g - p[1]) ** 2 + (b - p[2]) ** 2)
        mapped.append((*nearest, 255))
    image.putdata(mapped)
    return image


def full_layer(source_name: str, transparent: bool, palette: list[tuple[int, int, int]]) -> Image.Image:
    source = Image.open(SOURCE_DIR / source_name).convert("RGBA")
    source = crop_to_ratio(source, 768, 416).resize((768, 416), Image.Resampling.NEAREST)
    if not transparent:
        source.putalpha(255)
    return palette_map(source, palette)


def flattened_platform(source_name: str, width: int, height: int, ground: bool = False) -> Image.Image:
    source = Image.open(SOURCE_DIR / source_name).convert("RGBA")
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        raise AssertionError(f"No visible source pixels: {source_name}")
    if ground:
        cropped = source.crop(bbox)
    else:
        px = alpha.load()
        tops = []
        start = bbox[0] + (bbox[2] - bbox[0]) // 4
        end = bbox[0] + (bbox[2] - bbox[0]) * 3 // 4
        for x in range(start, end):
            ys = [y for y in range(bbox[1], bbox[3]) if px[x, y] >= 96]
            if ys:
                tops.append(min(ys))
        surface_y = sorted(tops)[len(tops) // 2]
        cropped = source.crop((bbox[0], surface_y, bbox[2], bbox[3]))
    resized = cropped.resize((width, height), Image.Resampling.NEAREST)
    resized = palette_map(resized, PLATFORM_PALETTE)
    d = ImageDraw.Draw(resized)
    d.line((0, 0, width - 1, 0), fill=(49, 104, 122, 255), width=1)
    d.line((0, 1, width - 1, 1), fill=(31, 78, 99, 255), width=1)
    return resized


def alpha_metrics(image: Image.Image) -> tuple[float, int, tuple[int, int, int, int] | None]:
    alpha = image.getchannel("A")
    hist = alpha.histogram()
    nonzero = image.width * image.height - hist[0]
    partial = sum(hist[1:255])
    return nonzero / (image.width * image.height), partial, alpha.getbbox()


def image_metrics(path: Path) -> dict[str, str]:
    image = Image.open(path).convert("RGBA")
    coverage, partial, bbox = alpha_metrics(image)
    visible = [(r, g, b) for r, g, b, a in image.getdata() if a]
    luminances = [(r * 2126 + g * 7152 + b * 722) // 10000 for r, g, b in visible]
    return {
        "path": path.relative_to(ROOT).as_posix(), "width": str(image.width), "height": str(image.height),
        "mode": "RGBA", "bytes": str(path.stat().st_size), "sha256": sha256(path),
        "alpha_coverage": f"{coverage:.6f}", "partial_alpha_pixels": str(partial), "alpha_bbox": str(bbox),
        "max_luminance": str(max(luminances) if luminances else 0),
        "pixels_luminance_gt_120": str(sum(value > 120 for value in luminances)),
    }


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def checker(size: tuple[int, int], cell: int = 16) -> Image.Image:
    out = Image.new("RGBA", size, (15, 22, 35, 255))
    d = ImageDraw.Draw(out)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(25, 35, 49, 255))
    return out


def composite_layers(wall: Image.Image, back: Image.Image, front: Image.Image) -> Image.Image:
    out = wall.copy()
    out.alpha_composite(back)
    out.alpha_composite(front)
    return out


def paste_bottom_center(canvas: Image.Image, sprite: Image.Image, center_x: int, baseline: int) -> None:
    bbox = sprite.getchannel("A").getbbox()
    if not bbox:
        return
    x = center_x - (bbox[0] + bbox[2]) // 2
    y = baseline - bbox[3] + 1
    canvas.alpha_composite(sprite, (x, y))


def gameplay_2x(wall: Image.Image, back: Image.Image, front: Image.Image, platforms: dict[str, Image.Image]) -> tuple[Image.Image, Image.Image]:
    base = wall.copy()
    base.alpha_composite(back)
    base2 = base.resize((1536, 832), Image.Resampling.NEAREST)
    gameplay = Image.new("RGBA", (1536, 832), (0, 0, 0, 0))
    ground2 = platforms["ground"].resize((1536, 128), Image.Resampling.NEAREST)
    gameplay.alpha_composite(ground2, (0, 704))
    placements = ((platforms["short"], 180, 488), (platforms["medium"], 540, 344), (platforms["long"], 760, 510))
    for image, x, y in placements:
        image2 = image.resize((image.width * 2, image.height * 2), Image.Resampling.NEAREST)
        gameplay.alpha_composite(image2, (x, y))

    player = Image.open(ROOT / "assets/characters/cat/cat_idle.png").convert("RGBA").crop((0, 0, 80, 64)).resize((160, 128), Image.Resampling.NEAREST)
    orc = Image.open(ROOT / "assets/characters/orc_idle.png").convert("RGBA").crop((0, 0, 100, 100)).resize((300, 300), Image.Resampling.NEAREST)
    sentry = Image.open(ROOT / "assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png").convert("RGBA").resize((300, 300), Image.Resampling.NEAREST)
    chest = Image.open(ROOT / "assets/world/interactables/run_reward_chest/chest_closed_v2.png").convert("RGBA")
    portal = Image.open(ROOT / "assets/world/interactables/run_route_portal/portal_active_v2.png").convert("RGBA")
    baseline = 704
    paste_bottom_center(gameplay, player, 410, baseline)
    paste_bottom_center(gameplay, orc, 610, baseline)
    paste_bottom_center(gameplay, sentry, 820, baseline)
    paste_bottom_center(gameplay, chest, 1080, baseline)
    paste_bottom_center(gameplay, portal, 1280, baseline)
    final = base2.copy()
    final.alpha_composite(gameplay)
    final.alpha_composite(front.resize((1536, 832), Image.Resampling.NEAREST))
    return final, gameplay


def make_layer_qa(wall: Image.Image, back: Image.Image, front: Image.Image, gameplay: Image.Image) -> list[Path]:
    wall_path = QA_DIR / "background_wall_original_768x416.png"
    back_path = QA_DIR / "back_decor_original_768x416_on_checker.png"
    front_path = QA_DIR / "front_decor_original_768x416_on_checker.png"
    overlay_path = QA_DIR / "three_layer_overlay_768x416.png"
    wall.save(wall_path, optimize=True)
    back_preview = checker((768, 416)); back_preview.alpha_composite(back); back_preview.save(back_path, optimize=True)
    front_preview = checker((768, 416)); front_preview.alpha_composite(front); front_preview.save(front_path, optimize=True)
    composite_layers(wall, back, front).save(overlay_path, optimize=True)

    contact = Image.new("RGBA", (1536, 288), (5, 11, 23, 255))
    d = ImageDraw.Draw(contact)
    font = ImageFont.load_default()
    panels = [
        ("WALL", wall), ("BACK DECOR", back_preview),
        ("GAMEPLAY SILHOUETTES", gameplay.resize((768, 416), Image.Resampling.NEAREST)),
        ("FRONT DECOR", front_preview),
    ]
    for i, (title, image) in enumerate(panels):
        x = i * 384
        d.text((x + 10, 10), title, fill=(185, 214, 225, 255), font=font)
        thumb = image.resize((384, 208), Image.Resampling.NEAREST)
        contact.alpha_composite(thumb, (x, 40))
    d.text((10, 266), "TASK55 LAYER SEPARATION QA | every column can be disabled/replaced independently | NOT A GAME SCREENSHOT", fill=(116, 184, 202, 255), font=font)
    contact_path = QA_DIR / "layer_separation_4column.png"
    contact.save(contact_path, optimize=True)
    return [wall_path, back_path, front_path, overlay_path, contact_path]


def make_platform_qa(platforms: dict[str, Image.Image]) -> list[Path]:
    outputs = []
    for name, image in platforms.items():
        path = QA_DIR / f"{name}_2x_nearest.png"
        image.resize((image.width * 2, image.height * 2), Image.Resampling.NEAREST).save(path, optimize=True)
        outputs.append(path)
    canvas = checker((1024, 440), 16)
    d = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    y = 24
    for name in ("ground", "short", "medium", "long"):
        image = platforms[name]
        d.text((14, y), f"{name} | source {image.width}x{image.height} | standable top y=0", fill=(205, 225, 231, 255), font=font)
        canvas.alpha_composite(image, (14, y + 18))
        d.line((14, y + 17, 14 + image.width - 1, y + 17), fill=(92, 240, 179, 255), width=1)
        y += image.height + 54
    path = QA_DIR / "platform_topline_and_scale_qa.png"
    canvas.save(path, optimize=True)
    outputs.append(path)
    return outputs


def connected_highlight_metrics(image: Image.Image, threshold: int = 110) -> tuple[int, int]:
    px = image.convert("RGBA").load()
    w, h = image.size
    points = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            lum = (r * 2126 + g * 7152 + b * 722) // 10000
            if a and lum > threshold:
                points.add((x, y))
    largest = 0
    while points:
        start = points.pop()
        q = deque([start])
        size = 0
        while q:
            x, y = q.popleft(); size += 1
            for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if p in points:
                    points.remove(p); q.append(p)
        largest = max(largest, size)
    total = sum(
        1 for r, g, b, a in image.convert("RGBA").getdata()
        if a and (r * 2126 + g * 7152 + b * 722) // 10000 > threshold
    )
    return total, largest


def scan_runtime_references() -> list[str]:
    needles = [
        "assets/world/rooms/tidal_dungeon/platform_room_v1",
        "background_wall_v1.png", "back_decor_v1.png", "front_decor_v1.png",
        "ground_floor_v1.png", "platform_short_v1.png", "platform_medium_v1.png", "platform_long_v1.png",
    ]
    hits = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.name == "project.godot" or path.suffix.lower() not in {".gd", ".tscn", ".tres"}:
            continue
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith("docs/") or rel.startswith(".godot/") or "global_instakill" in rel:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="replace")
        for line_no, line in enumerate(text.splitlines(), 1):
            if any(needle in line for needle in needles):
                hits.append(f"{rel}:{line_no}:{line.strip()}")
    return hits


def main() -> None:
    for directory in (ROOM_DIR, QA_DIR, REPORT_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    for path, expected in EXPECTED_PROTECTED.items():
        if sha256(path) != expected:
            raise AssertionError(f"Protected input changed before Task55 build: {path}")

    wall = full_layer("background_wall_source.png", False, BG_PALETTE)
    back = full_layer("back_decor_alpha.png", True, DECOR_PALETTE)
    front = full_layer("front_decor_alpha.png", True, DECOR_PALETTE)
    platforms = {
        "ground": flattened_platform("ground_floor_alpha.png", 768, 64, True),
        "short": flattened_platform("platform_short_alpha.png", 160, 32),
        "medium": flattened_platform("platform_medium_alpha.png", 224, 32),
        "long": flattened_platform("platform_long_alpha.png", 320, 32),
    }
    for image, path in ((wall, WALL), (back, BACK), (front, FRONT), (platforms["ground"], GROUND), (platforms["short"], SHORT), (platforms["medium"], MEDIUM), (platforms["long"], LONG)):
        image.save(path, optimize=True)

    composite2, gameplay = gameplay_2x(wall, back, front, platforms)
    composite_draw = ImageDraw.Draw(composite2)
    composite_draw.rectangle((8, 8, 430, 30), fill=(3, 10, 23, 255))
    composite_draw.text((14, 13), "TASK55 LAYERED ART QA | 2x NEAREST | NOT A GAME SCREENSHOT", fill=(137, 198, 211, 255), font=ImageFont.load_default())
    composite_path = QA_DIR / "platform_room_composite_1536x832_2x_nearest.png"
    composite2.save(composite_path, optimize=True)
    qa_paths = make_layer_qa(wall, back, front, gameplay) + make_platform_qa(platforms) + [composite_path]

    runtime_paths = [WALL, BACK, FRONT, GROUND, SHORT, MEDIUM, LONG]
    metrics = [image_metrics(path) for path in runtime_paths]
    write_csv(REPORT_DIR / "asset_metrics.csv", metrics)
    write_csv(REPORT_DIR / "qa_metrics.csv", [image_metrics(path) for path in qa_paths])

    layer_rows = []
    for path in (WALL, BACK, FRONT):
        image = Image.open(path).convert("RGBA")
        coverage, partial, bbox = alpha_metrics(image)
        layer_rows.append({
            "path": path.relative_to(ROOT).as_posix(), "canvas": f"{image.width}x{image.height}",
            "origin": "0,0", "alpha_coverage": f"{coverage:.6f}", "partial_alpha_pixels": str(partial),
            "alpha_bbox": str(bbox), "raw_pixel_sha256": hashlib.sha256(image.tobytes()).hexdigest().upper(),
        })
    write_csv(REPORT_DIR / "layer_origin_and_distinctness.csv", layer_rows)

    highlight_rows = []
    for path in (WALL, BACK, FRONT):
        image = Image.open(path).convert("RGBA")
        total, largest = connected_highlight_metrics(image)
        highlight_rows.append({
            "path": path.relative_to(ROOT).as_posix(), "threshold_luminance": "110",
            "bright_pixels": str(total), "largest_4_connected_bright_cluster": str(largest),
            "automated_interpretation": "PASS: no obvious bright core/glow candidate" if total == 0 else "REVIEW REQUIRED",
        })
    write_csv(REPORT_DIR / "no_baked_light_brightness_scan.csv", highlight_rows)

    platform_rows = []
    platform_source_names = {
        "ground": "ground_floor_chromakey.png", "short": "platform_short_chromakey.png",
        "medium": "platform_medium_chromakey.png", "long": "platform_long_chromakey.png",
    }
    for name, path in (("ground", GROUND), ("short", SHORT), ("medium", MEDIUM), ("long", LONG)):
        image = Image.open(path).convert("RGBA")
        alpha = image.getchannel("A")
        top_by_x = []
        for x in range(image.width):
            ys = [y for y in range(image.height) if alpha.getpixel((x, y))]
            if ys:
                top_by_x.append(min(ys))
        platform_rows.append({
            "name": name, "path": path.relative_to(ROOT).as_posix(), "canvas": f"{image.width}x{image.height}",
            "visible_columns": str(len(top_by_x)), "top_y_min": str(min(top_by_x)), "top_y_max": str(max(top_by_x)),
            "topline_difference": str(max(top_by_x) - min(top_by_x)), "visible_bbox": str(alpha.getbbox()),
            "source_sha256": sha256(SOURCE_DIR / platform_source_names[name]),
        })
    write_csv(REPORT_DIR / "platform_topline_scan.csv", platform_rows)

    protected_rows = []
    for path, expected in EXPECTED_PROTECTED.items():
        actual = sha256(path)
        protected_rows.append({"path": path.relative_to(ROOT).as_posix(), "expected_sha256": expected, "actual_sha256": actual, "match": str(actual == expected).lower()})
    write_csv(REPORT_DIR / "protected_hashes.csv", protected_rows)

    runtime_hits = scan_runtime_references()
    (REPORT_DIR / "runtime_reference_scan.txt").write_text(
        "Scope: project runtime *.gd/*.tscn/*.tres; docs/.godot/project.godot/global_instakill excluded by protection rule.\n"
        + f"Task55 new asset reference hits: {len(runtime_hits)}\n"
        + ("\n".join(runtime_hits) if runtime_hits else "PASS: 0 references; no engineering connection performed.\n"), encoding="utf-8"
    )
    sidecars = list(ROOM_DIR.rglob("*.import")) + list(EVIDENCE.rglob("*.import"))
    (REPORT_DIR / "import_sidecar_scan.txt").write_text(
        f"Task55 output .import files: {len(sidecars)}\n" + ("\n".join(str(path.relative_to(ROOT)) for path in sidecars) if sidecars else "PASS: none.\n"), encoding="utf-8"
    )

    layer_hashes = {row["raw_pixel_sha256"] for row in layer_rows}
    exact_sizes = [(768, 416), (768, 416), (768, 416), (768, 64), (160, 32), (224, 32), (320, 32)]
    gates = [
        ("runtime_png_exact_sizes", all((int(row["width"]), int(row["height"])) == size for row, size in zip(metrics, exact_sizes)), "7/7 exact source canvases"),
        ("runtime_png_rgba", all(row["mode"] == "RGBA" for row in metrics), "7/7 RGBA"),
        ("layer_same_canvas_origin", all(row["canvas"] == "768x416" and row["origin"] == "0,0" for row in layer_rows), "wall/back/front share exact canvas and origin"),
        ("wall_opaque", float(layer_rows[0]["alpha_coverage"]) == 1.0, "background wall is full opaque plane"),
        ("decor_true_transparency", 0 < float(layer_rows[1]["alpha_coverage"]) < 0.45 and 0 < float(layer_rows[2]["alpha_coverage"]) < 0.18, "back/front are sparse transparent overlays"),
        ("layers_pixel_distinct", len(layer_hashes) == 3, "three layers have different raw RGBA content"),
        ("no_partial_alpha_runtime", all(int(row["partial_alpha_pixels"]) == 0 for row in metrics), "hard 0/255 alpha at target size"),
        ("automated_no_baked_light", all(int(row["bright_pixels"]) == 0 and int(row["largest_4_connected_bright_cluster"]) == 0 for row in highlight_rows), "no luminance>110 core or halo candidate; manual review still required"),
        ("front_decor_sparse", float(layer_rows[2]["alpha_coverage"]) <= 0.12, "front coverage <=12%"),
        ("platform_topline", all(int(row["topline_difference"]) <= 1 and int(row["top_y_min"]) == 0 for row in platform_rows), "all standable tops align at local y=0 within 1px"),
        ("platform_full_width", all(int(row["visible_columns"]) == int(row["canvas"].split("x")[0]) for row in platform_rows), "top/collision span covers each declared width"),
        ("platform_independent_sources", len({row["source_sha256"] for row in platform_rows}) == 4, "ground/short/medium/long trace to four distinct source images"),
        ("nearest_2x_composite", composite2.size == (1536, 832), "exact 2x room canvas"),
        ("runtime_reference_zero", len(runtime_hits) == 0, "0 engineering references"),
        ("import_sidecars_zero", len(sidecars) == 0, "0 Task55 .import files"),
        ("protected_hashes", all(row["match"] == "true" for row in protected_rows), "Task53/49/52 and accepted art inputs unchanged"),
    ]
    write_csv(REPORT_DIR / "automated_gate_results.csv", [{"gate": name, "pass": str(passed).lower(), "evidence": evidence} for name, passed, evidence in gates])
    if not all(passed for _, passed, _ in gates):
        raise AssertionError([name for name, passed, _ in gates if not passed])

    (REPORT_DIR / "qa_summary.md").write_text("\n".join([
        "# Task55 deterministic art QA summary", "",
        f"- Automated gates: `{sum(p for _, p, _ in gates)}/{len(gates)} PASS`.",
        "- Runtime PNGs: `7/7` exact RGBA canvases; all target alpha is hard 0/255.",
        f"- Layer alpha coverage: wall `{layer_rows[0]['alpha_coverage']}`, back `{layer_rows[1]['alpha_coverage']}`, front `{layer_rows[2]['alpha_coverage']}`.",
        "- Wall/back/front: `768×416`, origin `(0,0)`; runtime QA composition `1536×832` via exact 2× Nearest.",
        "- Automated bright-core scan found zero luminance>110 pixels in all three room layers. This is auxiliary evidence only; manual original-size no-light review remains mandatory.",
        "- Platform top-line difference: 0 source pixels for ground, short, medium and long; declared standable top is local `y=0`.",
        f"- Runtime references: `{len(runtime_hits)}`; Task55 `.import`: `{len(sidecars)}`.",
        "- Protected Task53/49/52 files and accepted Task53 art inputs match pre-build SHA-256.",
        "- No Godot/editor execution and no Git write operation were performed.", "",
    ]), encoding="utf-8")


if __name__ == "__main__":
    main()
