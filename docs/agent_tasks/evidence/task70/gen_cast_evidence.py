#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Task70 A: post-production evidence for the cast sheets.
Read-only against assets/ (only opens already-saved boss_*_v1/v2.png). Writes only
under docs/agent_tasks/evidence/task70/.

1. Launch-frame determination: per-frame count of the two source colors that are
   EXCLUSIVE to Attack02 frames 5/6 -- (244,237,234) and (183,165,155) -- confirmed
   absent from frames 0-4 and 7, and absent from the standard 8-color body/highlight
   palette shared with idle/walk/attack01 (verified separately). This is the
   "effect pixel appearance/decay rhythm" judged directly on the rendered cast
   sheet (post palette-remap; the two colors are not keys in any of the three
   palette maps, so they pass through unchanged and remain visually identifiable
   in plain/ember/tide alike).
2. Cross-action anchor overlay: cast frame 0 (rest pose) overlaid with idle/walk/
   attack frame 0 (all boss_plain_*_v2.png, already committed) to check the torso /
   contact-shadow baseline is unchanged across actions under the expanded window.
3. Internal 8-frame anchor overlay of boss_plain_cast_v1.png (same method as
   Task68's anchor_overlay_plain_attack.png).
"""
import os
from PIL import Image, ImageDraw

ASSET_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\assets\world\enemies\tide_ember_sovereign"
EVID_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\docs\agent_tasks\evidence\task70"
CANVAS = 200

EFFECT_COLORS = {(244, 237, 234), (183, 165, 155)}

def effect_pixel_count(frame_rgba):
    px = frame_rgba.load()
    w, h = frame_rgba.size
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and (r, g, b) in EFFECT_COLORS:
                n += 1
    return n

# ---- 1. launch frame annotation (use plain form; effect colors pass through all 3 identically) ----
cast = Image.open(os.path.join(ASSET_DIR, "boss_plain_cast_v1.png")).convert("RGBA")
n_frames = cast.width // CANVAS
counts = []
for i in range(n_frames):
    frame = cast.crop((i * CANVAS, 0, i * CANVAS + CANVAS, CANVAS))
    counts.append(effect_pixel_count(frame))

SCALE_UP = 2
sheet_w = CANVAS * SCALE_UP * n_frames
sheet_h = CANVAS * SCALE_UP + 40
ann = Image.new("RGB", (sheet_w, sheet_h), (245, 245, 245))
d = ImageDraw.Draw(ann)
launch_idx = counts.index(max(counts))
for i in range(n_frames):
    frame = cast.crop((i * CANVAS, 0, i * CANVAS + CANVAS, CANVAS)).resize(
        (CANVAS * SCALE_UP, CANVAS * SCALE_UP), Image.NEAREST)
    x0 = i * CANVAS * SCALE_UP
    bg = Image.new("RGB", frame.size, (255, 255, 255))
    bg.paste(frame, (0, 0), frame)
    ann.paste(bg, (x0, 0))
    label = f"f{i}  effect_px={counts[i]}"
    if i == launch_idx:
        label += "  <-- LAUNCH"
        d.rectangle([x0, 0, x0 + CANVAS * SCALE_UP - 1, CANVAS * SCALE_UP - 1], outline=(220, 30, 30), width=4)
    d.text((x0 + 6, CANVAS * SCALE_UP + 6), label, fill=(0, 0, 0))
ann.save(os.path.join(EVID_DIR, "cast_launch_frame_annotation.png"))
print("effect pixel counts per frame:", counts)
print("launch frame index (0-based):", launch_idx)

# ---- 2. cross-action anchor overlay (rest pose torso/shadow baseline) ----
def first_frame(fname):
    im = Image.open(os.path.join(ASSET_DIR, fname)).convert("RGBA")
    return im.crop((0, 0, CANVAS, CANVAS))

idle0 = first_frame("boss_plain_idle_v2.png")
walk0 = first_frame("boss_plain_walk_v2.png")
attack0 = first_frame("boss_plain_attack_v2.png")
cast0 = first_frame("boss_plain_cast_v1.png")

def tint(im, rgb, alpha):
    px = im.load()
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    opx = out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                opx[x, y] = (*rgb, alpha)
    return out

overlay = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 255))
overlay.alpha_composite(tint(idle0, (220, 30, 30), 90))     # red = idle
overlay.alpha_composite(tint(walk0, (30, 160, 30), 90))     # green = walk
overlay.alpha_composite(tint(attack0, (30, 90, 220), 90))   # blue = attack
overlay.alpha_composite(tint(cast0, (200, 160, 20), 90))    # amber = cast
overlay_big = overlay.resize((CANVAS * 3, CANVAS * 3), Image.NEAREST)
d2 = ImageDraw.Draw(overlay_big)
d2.text((6, 6), "red=idle f0  green=walk f0  blue=attack f0  amber=cast f0 (all rest pose, expanded window)", fill=(0, 0, 0))
overlay_big.save(os.path.join(EVID_DIR, "cross_action_anchor_overlay_cast_vs_idle_walk_attack.png"))

# ---- 3. internal 8-frame overlay of cast (same method as Task68 anchor_overlay_plain_attack) ----
internal = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 255))
alpha_step = max(30, 255 // n_frames)
for i in range(n_frames):
    frame = cast.crop((i * CANVAS, 0, i * CANVAS + CANVAS, CANVAS))
    internal.alpha_composite(tint(frame, (200, 30, 30), alpha_step))
internal_big = internal.resize((CANVAS * 3, CANVAS * 3), Image.NEAREST)
internal_big.save(os.path.join(EVID_DIR, "anchor_overlay_plain_cast_internal_8frame.png"))

print("done")
