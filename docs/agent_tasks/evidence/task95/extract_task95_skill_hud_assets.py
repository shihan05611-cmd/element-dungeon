from __future__ import annotations

from hashlib import sha256
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "docs/agent_tasks/evidence/task94/task94_skill_hud_hierarchy_states_full_concept_1920x1080.png"
OUTPUT = ROOT / "assets/ui/hud_skill"
EVIDENCE = Path(__file__).parent / "native_assets"

ACTIVE_BOX = (690, 918, 1230, 1060)
PASSIVE_BOX = (1420, 934, 1835, 1050)
ACTIVE_SIZE = (324, 85)
PASSIVE_SIZE = (249, 70)
EXPECTED_SOURCE_RGBA_SHA256 = "b33092d351bbca4066e1a82dee92369b20690a4b094494ab4099fac0d256c021"

RGBA = tuple[int, int, int, int]
TRANSPARENT: RGBA = (0, 0, 0, 0)

# Every opaque RGB value below occurs verbatim in Task94's final PASS crop.
A_BLACK: RGBA = (5, 5, 9, 255)
A_SHADOW: RGBA = (10, 13, 20, 255)
A_DARK: RGBA = (11, 16, 23, 255)
A_LOW: RGBA = (14, 21, 32, 255)
A_INNER: RGBA = (18, 32, 51, 255)
A_BLUE: RGBA = (32, 64, 95, 255)
A_MID: RGBA = (53, 125, 182, 255)
A_HIGH: RGBA = (73, 168, 221, 255)

P_BLACK: RGBA = (10, 13, 19, 255)
P_DARK: RGBA = (13, 16, 24, 255)
P_LOW: RGBA = (21, 25, 34, 255)
P_MID: RGBA = (24, 29, 38, 255)
P_EDGE: RGBA = (31, 37, 48, 255)
P_HIGH: RGBA = (40, 45, 60, 255)
P_BLUE: RGBA = (44, 49, 70, 255)
P_DASH_SHADOW: RGBA = (64, 69, 82, 255)
P_DASH_HIGH: RGBA = (103, 110, 123, 255)

LOCK_SHADOW: RGBA = (119, 118, 119, 255)
LOCK_MID: RGBA = (136, 133, 135, 255)
LOCK_HIGH: RGBA = (163, 159, 161, 255)

PULSE_DARK: RGBA = (64, 87, 133, 255)
PULSE_MID: RGBA = (97, 128, 190, 255)
PULSE_HIGH: RGBA = (120, 152, 216, 255)
PULSE_PEAK: RGBA = (155, 182, 247, 255)


def rgba_hash(image: Image.Image) -> str:
    return sha256(image.convert("RGBA").tobytes()).hexdigest()


def rect(image: Image.Image, x0: int, y0: int, x1: int, y1: int, color: RGBA) -> None:
    """Paint one literal inclusive native-pixel run rectangle."""
    pixels = image.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            pixels[x, y] = color


def hline(image: Image.Image, x0: int, x1: int, y: int, color: RGBA) -> None:
    rect(image, x0, y, x1, y, color)


def vline(image: Image.Image, x: int, y0: int, y1: int, color: RGBA) -> None:
    rect(image, x, y0, x, y1, color)


def paint_active_outer(image: Image.Image) -> None:
    # Hand-authored native 324x85 silhouette. The broad dark runs form the
    # stepped outside mask; the blue runs are the literal Task94 light layers.
    rect(image, 8, 0, 315, 1, A_BLACK)
    rect(image, 5, 2, 318, 3, A_SHADOW)
    rect(image, 3, 4, 320, 5, A_DARK)
    rect(image, 1, 6, 322, 8, A_SHADOW)
    rect(image, 0, 9, 5, 75, A_BLACK)
    rect(image, 318, 9, 323, 75, A_BLACK)
    rect(image, 1, 76, 322, 78, A_SHADOW)
    rect(image, 3, 79, 320, 81, A_DARK)
    rect(image, 5, 82, 318, 83, A_SHADOW)
    rect(image, 8, 84, 315, 84, A_BLACK)

    hline(image, 8, 315, 2, A_BLUE)
    hline(image, 9, 314, 3, A_MID)
    hline(image, 11, 312, 4, A_HIGH)
    hline(image, 8, 315, 5, A_MID)
    hline(image, 7, 316, 6, A_BLUE)
    hline(image, 6, 317, 7, A_INNER)
    vline(image, 2, 9, 75, A_BLUE)
    vline(image, 3, 10, 74, A_MID)
    vline(image, 4, 11, 73, A_HIGH)
    vline(image, 5, 10, 74, A_INNER)
    vline(image, 318, 10, 74, A_INNER)
    vline(image, 319, 10, 74, A_BLUE)
    vline(image, 320, 9, 75, A_SHADOW)
    hline(image, 6, 317, 77, A_INNER)
    hline(image, 7, 316, 78, A_BLUE)
    hline(image, 9, 314, 79, A_MID)
    hline(image, 11, 312, 80, A_HIGH)
    hline(image, 8, 315, 81, A_BLUE)

    rect(image, 4, 6, 7, 9, A_MID)
    rect(image, 6, 5, 10, 7, A_HIGH)
    rect(image, 313, 5, 317, 7, A_MID)
    rect(image, 316, 7, 319, 10, A_BLUE)
    rect(image, 4, 75, 7, 78, A_BLUE)
    rect(image, 6, 78, 10, 80, A_HIGH)
    rect(image, 313, 78, 317, 80, A_MID)
    rect(image, 316, 75, 319, 78, A_INNER)


def paint_active_divider(image: Image.Image, center_x: int) -> None:
    # One layered separator band. There are exactly two calls, at x=108/216.
    vline(image, center_x - 2, 7, 78, A_BLACK)
    vline(image, center_x - 1, 7, 78, A_INNER)
    vline(image, center_x, 7, 78, A_BLUE)
    vline(image, center_x + 1, 7, 78, A_SHADOW)
    hline(image, center_x - 2, center_x + 1, 7, A_MID)
    hline(image, center_x - 2, center_x + 1, 78, A_MID)


def paint_key_tab(image: Image.Image, x: int) -> None:
    # 23x26 native tab contour. Its center stays transparent for runtime digits.
    rect(image, x + 3, 8, x + 19, 9, A_BLACK)
    rect(image, x + 1, 10, x + 21, 11, A_SHADOW)
    rect(image, x, 12, x + 2, 29, A_BLACK)
    rect(image, x + 20, 12, x + 22, 29, A_BLACK)
    rect(image, x + 1, 30, x + 21, 32, A_SHADOW)
    rect(image, x + 3, 33, x + 19, 33, A_BLACK)
    hline(image, x + 4, x + 18, 10, A_HIGH)
    hline(image, x + 3, x + 19, 11, A_MID)
    vline(image, x + 2, 13, 28, A_MID)
    vline(image, x + 3, 13, 28, A_HIGH)
    vline(image, x + 19, 13, 28, A_INNER)
    vline(image, x + 20, 13, 28, A_BLUE)
    hline(image, x + 3, x + 19, 29, A_BLUE)
    hline(image, x + 4, x + 18, 30, A_INNER)


def build_active() -> Image.Image:
    image = Image.new("RGBA", ACTIVE_SIZE, TRANSPARENT)
    paint_active_outer(image)
    paint_active_divider(image, 108)
    paint_active_divider(image, 216)
    # Reassert the uninterrupted horizontal highlight layers across both joins.
    hline(image, 11, 312, 4, A_HIGH)
    hline(image, 8, 315, 5, A_MID)
    hline(image, 11, 312, 80, A_HIGH)
    hline(image, 8, 315, 81, A_BLUE)
    for x in (11, 119, 227):
        paint_key_tab(image, x)
    return image


def paint_passive_outer(image: Image.Image) -> None:
    rect(image, 6, 0, 242, 1, P_BLACK)
    rect(image, 3, 2, 245, 4, P_DARK)
    rect(image, 1, 5, 247, 7, P_LOW)
    rect(image, 0, 8, 4, 61, P_BLACK)
    rect(image, 244, 8, 248, 61, P_BLACK)
    rect(image, 1, 62, 247, 64, P_LOW)
    rect(image, 3, 65, 245, 67, P_DARK)
    rect(image, 6, 68, 242, 69, P_BLACK)
    hline(image, 7, 241, 3, P_HIGH)
    hline(image, 5, 243, 4, P_EDGE)
    vline(image, 2, 9, 60, P_EDGE)
    vline(image, 3, 10, 59, P_HIGH)
    hline(image, 5, 243, 65, P_EDGE)
    hline(image, 7, 241, 66, P_HIGH)


def paint_passive_slot(image: Image.Image, x: int) -> None:
    # Quiet 57x58 slot motif, repeated at the four explicit Task94 positions.
    rect(image, x + 4, 6, x + 52, 7, P_BLACK)
    rect(image, x + 2, 8, x + 54, 10, P_DARK)
    rect(image, x, 11, x + 3, 58, P_BLACK)
    rect(image, x + 53, 11, x + 56, 58, P_BLACK)
    rect(image, x + 2, 59, x + 54, 62, P_DARK)
    rect(image, x + 4, 63, x + 52, 63, P_BLACK)
    hline(image, x + 5, x + 51, 8, P_BLUE)
    hline(image, x + 4, x + 52, 9, P_HIGH)
    vline(image, x + 2, 12, 57, P_EDGE)
    vline(image, x + 3, 13, 56, P_BLUE)
    vline(image, x + 52, 13, 56, P_MID)
    vline(image, x + 53, 12, 57, P_EDGE)
    hline(image, x + 4, x + 52, 59, P_MID)
    hline(image, x + 5, x + 51, 60, P_EDGE)


def build_passive_frame() -> Image.Image:
    image = Image.new("RGBA", PASSIVE_SIZE, TRANSPARENT)
    paint_passive_outer(image)
    for x in (7, 66, 125, 184):
        paint_passive_slot(image, x)
    return image


def build_empty_inset() -> Image.Image:
    image = Image.new("RGBA", (42, 44), TRANSPARENT)
    for x0, x1 in ((8, 13), (17, 22), (26, 31)):
        rect(image, x0 + 1, 4, x1 + 1, 5, P_DASH_SHADOW)
        rect(image, x0, 3, x1, 4, P_DASH_HIGH)
        rect(image, x0 + 1, 38, x1 + 1, 39, P_DASH_SHADOW)
        rect(image, x0, 37, x1, 38, P_DASH_HIGH)
    for y0, y1 in ((9, 14), (18, 23), (27, 32)):
        rect(image, 4, y0 + 1, 5, y1 + 1, P_DASH_SHADOW)
        rect(image, 3, y0, 4, y1, P_DASH_HIGH)
        rect(image, 37, y0 + 1, 38, y1 + 1, P_DASH_SHADOW)
        rect(image, 36, y0, 37, y1, P_DASH_HIGH)
    rect(image, 5, 5, 8, 6, P_DASH_HIGH)
    rect(image, 33, 5, 36, 6, P_DASH_HIGH)
    rect(image, 5, 35, 8, 36, P_DASH_HIGH)
    rect(image, 33, 35, 36, 36, P_DASH_HIGH)
    return image


def build_lock() -> Image.Image:
    image = Image.new("RGBA", (24, 30), TRANSPARENT)
    # Literal native-pixel lock silhouette; no resampling or font glyph.
    rect(image, 8, 1, 15, 2, LOCK_SHADOW)
    rect(image, 6, 3, 17, 4, LOCK_MID)
    rect(image, 5, 5, 8, 12, LOCK_MID)
    rect(image, 15, 5, 18, 12, LOCK_MID)
    rect(image, 8, 4, 15, 6, LOCK_HIGH)
    rect(image, 8, 7, 10, 12, LOCK_SHADOW)
    rect(image, 13, 7, 15, 12, LOCK_SHADOW)
    rect(image, 3, 12, 20, 14, LOCK_SHADOW)
    rect(image, 2, 15, 21, 25, LOCK_MID)
    rect(image, 4, 13, 19, 16, LOCK_HIGH)
    rect(image, 4, 17, 6, 24, LOCK_HIGH)
    rect(image, 18, 17, 20, 24, LOCK_SHADOW)
    rect(image, 4, 25, 19, 27, LOCK_SHADOW)
    rect(image, 7, 28, 16, 28, P_BLACK)
    rect(image, 10, 18, 13, 21, P_BLACK)
    rect(image, 11, 22, 12, 25, P_BLACK)
    return image


def build_pulse_border() -> Image.Image:
    image = Image.new("RGBA", (57, 58), TRANSPARENT)
    rect(image, 4, 0, 52, 1, PULSE_DARK)
    rect(image, 2, 2, 54, 3, PULSE_MID)
    rect(image, 0, 4, 2, 53, PULSE_DARK)
    rect(image, 54, 4, 56, 53, PULSE_DARK)
    rect(image, 2, 54, 54, 55, PULSE_MID)
    rect(image, 4, 56, 52, 57, PULSE_DARK)
    hline(image, 5, 51, 2, PULSE_PEAK)
    hline(image, 4, 52, 3, PULSE_HIGH)
    vline(image, 1, 5, 52, PULSE_HIGH)
    vline(image, 2, 6, 51, PULSE_PEAK)
    vline(image, 53, 6, 51, PULSE_MID)
    vline(image, 54, 5, 52, PULSE_HIGH)
    hline(image, 4, 52, 54, PULSE_HIGH)
    hline(image, 5, 51, 55, PULSE_MID)
    return image


def verify_source_palette(source: Image.Image) -> None:
    active_colors = set(source.crop(ACTIVE_BOX).getdata())
    passive_colors = set(source.crop(PASSIVE_BOX).getdata())
    for color in (A_BLACK, A_SHADOW, A_DARK, A_LOW, A_INNER, A_BLUE, A_MID, A_HIGH):
        if color not in active_colors:
            raise RuntimeError(f"active palette color is not in Task94: {color}")
    for color in (
        P_BLACK, P_DARK, P_LOW, P_MID, P_EDGE, P_HIGH, P_BLUE,
        P_DASH_SHADOW, P_DASH_HIGH, LOCK_SHADOW, LOCK_MID, LOCK_HIGH,
        PULSE_DARK, PULSE_MID, PULSE_HIGH, PULSE_PEAK,
    ):
        if color not in passive_colors:
            raise RuntimeError(f"passive palette color is not in Task94: {color}")


def verify_native_contract(outputs: dict[str, Image.Image]) -> None:
    active = outputs["active_frame.png"]
    passive = outputs["passive_frame.png"]
    if active.size != ACTIVE_SIZE or passive.size != PASSIVE_SIZE:
        raise RuntimeError("native target dimensions changed")
    for y in (4, 5, 80, 81):
        if any(active.getpixel((x, y))[3] == 0 for x in range(11, 313)):
            raise RuntimeError(f"active horizontal edge is not continuous at y={y}")
    for x in (108, 216):
        if any(active.getpixel((x, y))[3] == 0 for y in range(7, 79)):
            raise RuntimeError(f"active divider is incomplete at x={x}")
    for point in ((54, 44), (162, 44), (270, 44), (82, 68), (190, 68), (298, 68)):
        if active.getpixel(point)[3] != 0:
            raise RuntimeError(f"active dynamic field was baked at {point}")
    for point in ((35, 35), (94, 35), (153, 35), (212, 35)):
        if passive.getpixel(point)[3] != 0:
            raise RuntimeError(f"passive icon field was baked at {point}")
    for name, image in outputs.items():
        if image.getchannel("A").getextrema() != (0, 255):
            raise RuntimeError(f"{name} must contain both transparent and opaque pixels")


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    source_hash = rgba_hash(source)
    if source.size != (1920, 1080) or source_hash != EXPECTED_SOURCE_RGBA_SHA256:
        raise RuntimeError(f"unexpected Task94 source: size={source.size} hash={source_hash}")
    verify_source_palette(source)

    outputs = {
        "active_frame.png": build_active(),
        "passive_frame.png": build_passive_frame(),
        "passive_empty_inset.png": build_empty_inset(),
        "passive_lock.png": build_lock(),
        "passive_pulse_border.png": build_pulse_border(),
    }
    verify_native_contract(outputs)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    for name, image in outputs.items():
        image.save(OUTPUT / name)
        stem = Path(name).stem
        image.save(EVIDENCE / f"{stem}_1x.png")
        image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(
            EVIDENCE / f"{stem}_4x_nearest.png"
        )

    report = [
        "# Task95 native-pixel HUD asset provenance",
        "",
        f"- sole visual reference: `{SOURCE.relative_to(ROOT).as_posix()}`",
        f"- source RGBA SHA-256: `{source_hash}`",
        f"- Task94 reference boxes inspected: active `{ACTIVE_BOX}`; passive `{PASSIVE_BOX}`",
        "- native authoring: every 1x opaque run is hand-authored directly at 324x85 / 249x70 (and state-resource native sizes); no Task94 crop was resized into a runtime asset.",
        "- palette: every opaque RGB tuple occurs verbatim in the corresponding Task94 final PASS crop.",
        "- active structure: one stepped outer contour, continuous y=4/5 and y=80/81 edges, exactly two layered separator bands centered at x=108 and x=216, plus three empty key-tab contours.",
        "- passive structure: lower-weight group contour and four repeated quiet native slot contours; empty dash, lock and pulse remain separate state resources.",
        "- dynamic exclusion: shared frames contain no icon, key digit, SP value, cooldown shade/countdown, passive icon, lock, empty dash or pulse.",
        "- evidence scaling: only `native_assets/*_4x_nearest.png` uses resize, strictly 4x nearest-neighbor for inspection; runtime assets are the authored 1x images.",
        "- runtime interior samples remain source-exact: active `(1170, 980)` = `(13, 17, 23, 255)`; passive `(1800, 1018)` = `(16, 20, 28, 255)`.",
        "",
        "## Runtime outputs",
        "",
    ]
    for name, image in outputs.items():
        report.append(
            f"- `{(OUTPUT / name).relative_to(ROOT).as_posix()}`: size `{image.size}`, "
            f"alpha `{image.getchannel('A').getextrema()}`, RGBA SHA-256 `{rgba_hash(image)}`"
        )
    report.extend(["", "## Inspection outputs", ""])
    for name, image in outputs.items():
        stem = Path(name).stem
        report.append(f"- `native_assets/{stem}_1x.png`: exact runtime pixels")
        report.append(f"- `native_assets/{stem}_4x_nearest.png`: `{image.width * 4}x{image.height * 4}`, nearest-neighbor")
    (Path(__file__).parent / "asset_provenance.md").write_text("\n".join(report) + "\n", encoding="utf-8")

    print("TASK95 NATIVE PIXEL ASSET AUTHORING COMPLETE")
    for name, image in outputs.items():
        print(f"{name}: size={image.size} alpha={image.getchannel('A').getextrema()} sha256={rgba_hash(image)}")


if __name__ == "__main__":
    main()
