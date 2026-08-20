#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Task70 melee/summon telegraph icon generator.

Reproduces the generation method documented in
assets/world/ui_world/telegraph/manifest_v1.md for telegraph_alert_v1 (Task60):
"原创几何像素绘制（Python + Pillow，4x 超采样绘制后阈值化 alpha + 整数最近邻降采样）"
-- original geometric pixel art, drawn at integer supersample, alpha-thresholded,
then integer-factor downsampled. No external art assets, no image_gen tool used.

Canvas / animation contract copied from the existing telegraph_alert_v1.png (verified
by direct pixel inspection of the shipped file, not re-derived):
  - logical canvas 32x32 per frame, 3-frame horizontal strip (96x32) for the bounce
    sequence, plus a single 32x32 static frame for reduced-motion.
  - bounce = frame1 is the WHOLE frame0 raster content shifted up by exactly 1px
    (frame2 == frame0). No other per-frame difference. This is copied verbatim from
    telegraph_alert_v1.png (measured: frame0 bbox (12,3,20,29), frame1 bbox
    (12,2,20,28), frame2 == frame0).
  - stroke: 1px hard outline (no anti-aliasing, partial_alpha_px == 0 in the shipped
    alert icon) traced along the outer boundary of the opaque silhouette (outline is
    INSET, part of the shape's own boundary layer, not an extra ring drawn outside
    the silhouette bbox).
  - one small (10-14px) interior highlight cluster, placed asymmetrically near a
    visually prominent part of the shape (matches alert: cluster near the top-left
    of the bar and a single px near the dot center).

telegraph_alert_v1.png itself is NOT touched by this script (read-only reference for
geometry/colors, used only to state the contract above; regenerating it is out of
scope and forbidden by the task).
"""
import os, hashlib, json, math
from PIL import Image, ImageDraw

OUT_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\assets\world\ui_world\telegraph"
EVID_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\docs\agent_tasks\evidence\task70"

CANVAS = 32
SS = 8  # supersample factor (>= the 4x used for Task60; downsampled the same way)
BIG = CANVAS * SS

# ---- background swatches, sampled directly from
# docs/agent_tasks/evidence/task60/08_telegraph_4background_readability.png
# (dark / water / fire / purple), reused verbatim for the new 4-background QA ----
BG_DARK   = (24, 20, 28)
BG_WATER  = (20, 60, 100)
BG_FIRE   = (90, 36, 20)
BG_PURPLE = (60, 20, 90)

ICONS = {
    "melee": {
        "outline": (42, 10, 12),
        "main":    (230, 32, 42),
        "highlight": (255, 168, 150),
    },
    "summon": {
        "outline": (26, 10, 42),
        "main":    (150, 32, 214),
        "highlight": (224, 168, 255),
    },
}


def render_melee_mask():
    """Two triangular wedges converging to a pinch point -- inward-collapsing blade
    shape ("about to land on you"). Silhouette is a single bowtie/hourglass blob,
    topologically distinct from the alert's two separate blobs (bar + dot) and from
    the summon ring's hollow-with-spikes blob."""
    im = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(im)
    def P(x, y):
        return (x * SS, y * SS)
    top = [P(10, 3), P(22, 3), P(16, 15)]
    bot = [P(16, 17), P(22, 29), P(10, 29)]
    d.polygon(top, fill=255)
    d.polygon(bot, fill=255)
    return im


def render_summon_mask():
    """Ring (annulus) with 6 radiating star points -- "something is about to appear
    on the field". Silhouette has a hole in the middle (transparent center), which
    no other telegraph icon has -- strongest possible desaturated-silhouette
    differentiator from both alert (2 solid blobs) and melee (1 pinched solid blob)."""
    im = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(im)
    cx, cy = 16 * SS, 16 * SS
    r_out = 10 * SS
    r_in = 6 * SS
    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=255)
    n_points = 6
    spike_len = 4 * SS
    spike_half_w = 1.7 * SS
    for i in range(n_points):
        ang = math.radians(i * 360 / n_points - 90)
        bx = cx + r_out * math.cos(ang)
        by = cy + r_out * math.sin(ang)
        tx = cx + (r_out + spike_len) * math.cos(ang)
        ty = cy + (r_out + spike_len) * math.sin(ang)
        perp = ang + math.pi / 2
        p1 = (bx + spike_half_w * math.cos(perp), by + spike_half_w * math.sin(perp))
        p2 = (bx - spike_half_w * math.cos(perp), by - spike_half_w * math.sin(perp))
        d.polygon([p1, p2, (tx, ty)], fill=255)
    d.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=0)
    return im


RENDERERS = {"melee": render_melee_mask, "summon": render_summon_mask}

# small interior highlight cluster, in 32x32 logical coords, per icon
HIGHLIGHT_PX = {
    "melee": [(12, 5), (13, 5), (12, 6), (13, 6), (14, 6)],
    "summon": [(20, 8), (21, 8), (22, 9), (21, 10), (20, 9)],
}


def downsample_threshold(mask_big):
    small = mask_big.resize((CANVAS, CANVAS), Image.BOX)
    px = small.load()
    for y in range(CANVAS):
        for x in range(CANVAS):
            px[x, y] = 255 if px[x, y] >= 128 else 0
    return small


def colorize(mask, outline_c, main_c, hi_c, hi_px):
    px = mask.load()
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    opx = out.load()
    hi_set = set(hi_px)
    for y in range(CANVAS):
        for x in range(CANVAS):
            if px[x, y] == 0:
                continue
            is_edge = False
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < CANVAS and 0 <= ny < CANVAS) or mask.getpixel((nx, ny)) == 0:
                    is_edge = True
                    break
            if is_edge:
                opx[x, y] = (*outline_c, 255)
            elif (x, y) in hi_set:
                opx[x, y] = (*hi_c, 255)
            else:
                opx[x, y] = (*main_c, 255)
    return out


def shift_up_1px(frame):
    """Reproduce the alert icon's bounce mechanism exactly: whole-frame content
    shifted up by 1px, top row clipped, bottom row becomes empty."""
    shifted = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shifted.paste(frame.crop((0, 1, CANVAS, CANVAS)), (0, 0))
    return shifted


def alpha_bbox_coverage(im):
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    partial = 0
    opaque = 0
    for y in range(h):
        for x in range(w):
            a = px[x, y][3]
            if a > 0:
                xs.append(x); ys.append(y)
            if 0 < a < 255:
                partial += 1
            if a == 255:
                opaque += 1
    bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1) if xs else None
    return bbox, partial, opaque, opaque / (w * h)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


results = {}
frames_cache = {}

for name, colors in ICONS.items():
    mask_big = RENDERERS[name]()
    mask = downsample_threshold(mask_big)
    frame0 = colorize(mask, colors["outline"], colors["main"], colors["highlight"], HIGHLIGHT_PX[name])
    frame1 = shift_up_1px(frame0)
    frame2 = frame0.copy()
    frames_cache[name] = [frame0, frame1, frame2]

    strip = Image.new("RGBA", (CANVAS * 3, CANVAS), (0, 0, 0, 0))
    for i, fr in enumerate([frame0, frame1, frame2]):
        strip.alpha_composite(fr, (i * CANVAS, 0))
    strip_path = os.path.join(OUT_DIR, f"telegraph_{name}_v1.png")
    strip.save(strip_path)

    static_path = os.path.join(OUT_DIR, f"telegraph_{name}_static_v1.png")
    frame0.save(static_path)

    for label, path, im in [("strip", strip_path, strip), ("static", static_path, frame0)]:
        bbox, partial, opaque, coverage = alpha_bbox_coverage(im)
        results[os.path.basename(path)] = {
            "size": im.size,
            "mode": im.mode,
            "sha256": sha256(path),
            "bytes": os.path.getsize(path),
            "alpha_bbox": bbox,
            "partial_alpha_px": partial,
            "opaque_px": opaque,
            "opaque_coverage": round(coverage, 6),
        }

with open(os.path.join(EVID_DIR, "telegraph_v1_stats.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(json.dumps(results, indent=2, ensure_ascii=False))

# ---- 4-background readability QA (dark/water/fire/purple), matching Task60 method ----
bgs = [("dark", BG_DARK), ("water", BG_WATER), ("fire", BG_FIRE), ("purple", BG_PURPLE)]
cell = CANVAS + 8
qa = Image.new("RGB", (cell * 4, cell * 2 + 4), (255, 255, 255))
for row, name in enumerate(["melee", "summon"]):
    frame0 = frames_cache[name][0]
    for col, (bgname, bgcol) in enumerate(bgs):
        panel = Image.new("RGB", (cell, cell), bgcol)
        panel.paste(frame0, (4, 4), frame0)
        qa.paste(panel, (col * cell, row * (cell + 4)))
qa.save(os.path.join(EVID_DIR, "telegraph_melee_summon_4background_readability.png"))

# ---- native 1x + 2x nearest QA ----
qa2 = Image.new("RGBA", ((CANVAS + CANVAS * 2 + 12) * 2, CANVAS * 2 + 8), (40, 40, 40, 255))
xoff = 4
for name in ["melee", "summon"]:
    frame0 = frames_cache[name][0]
    qa2.alpha_composite(frame0, (xoff, 4))
    frame2x = frame0.resize((CANVAS * 2, CANVAS * 2), Image.NEAREST)
    qa2.alpha_composite(frame2x, (xoff + CANVAS + 8, 4))
    xoff += CANVAS + 8 + CANVAS * 2 + 12
qa2.save(os.path.join(EVID_DIR, "telegraph_melee_summon_native1x_2x_nearest_qa.png"))

# ---- decolorized (grayscale) silhouette comparison: alert + melee + summon ----
alert_path = os.path.join(OUT_DIR, "telegraph_alert_static_v1.png")
alert_im = Image.open(alert_path).convert("RGBA")
triplet_names = ["alert", "melee", "summon"]
triplet_imgs = {"alert": alert_im, "melee": frames_cache["melee"][0], "summon": frames_cache["summon"][0]}

def desaturate(im):
    gray = Image.new("RGBA", im.size, (0, 0, 0, 0))
    px = im.load()
    gpx = gray.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            l = int(round(0.299 * r + 0.587 * g + 0.114 * b))
            gpx[x, y] = (l, l, l, a)
    return gray

cell_w = CANVAS * 4 + 16
panel_h = CANVAS * 4 * 2 + 16 + 16  # color + gap + gray + top/bottom margin
comp = Image.new("RGB", (cell_w * 3, panel_h), (200, 200, 200))
for i, nm in enumerate(triplet_names):
    color_im = triplet_imgs[nm]
    gray_im = desaturate(color_im)
    # stack color above grayscale, each scaled 4x nearest
    color4 = color_im.resize((CANVAS * 4, CANVAS * 4), Image.NEAREST)
    gray4 = gray_im.resize((CANVAS * 4, CANVAS * 4), Image.NEAREST)
    comp.paste(color4.convert("RGB"), (i * cell_w + 8, 8), color4)
    comp.paste(gray4.convert("RGB"), (i * cell_w + 8, CANVAS * 4 + 24), gray4)
comp.save(os.path.join(EVID_DIR, "telegraph_desaturated_silhouette_comparison.png"))

print("done")
