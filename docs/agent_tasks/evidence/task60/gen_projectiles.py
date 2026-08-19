#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Task60 projectile + impact + telegraph generator. Hand-authored geometric pixel art
(no external source material; no image_gen model available this session).
All bolts are Right-facing (Vector2.RIGHT baseline), per task60 spec section 5.4.
"""
import os, hashlib, json
from PIL import Image, ImageDraw

OUT_PROJ = r"C:\Users\heliashi\Documents\元素地牢-4.7\assets\world\projectiles"
OUT_TEL  = r"C:\Users\heliashi\Documents\元素地牢-4.7\assets\world\ui_world\telegraph"
EVID_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\docs\agent_tasks\evidence\task60"
os.makedirs(OUT_PROJ, exist_ok=True)
os.makedirs(OUT_TEL, exist_ok=True)

def crisp_alpha(im, threshold=128):
    px = im.load()
    w,h = im.size
    for y in range(h):
        for x in range(w):
            r,g,b,a = px[x,y]
            px[x,y] = (r,g,b, 255 if a>=threshold else 0)
    return im

def outline(im, color):
    """Add a 1px outline of `color` around the opaque silhouette (into transparent neighbor pixels)."""
    px = im.load()
    w,h = im.size
    to_paint = []
    for y in range(h):
        for x in range(w):
            if px[x,y][3] == 0:
                neigh_opaque = False
                for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]:
                    nx,ny = x+dx,y+dy
                    if 0<=nx<w and 0<=ny<h and px[nx,ny][3]==255:
                        neigh_opaque = True
                        break
                if neigh_opaque:
                    to_paint.append((x,y))
    for (x,y) in to_paint:
        px[x,y] = (color[0],color[1],color[2],255)
    return im

# ---- Bolt: elongated crescent, pointed tip to the RIGHT, tail fins to the LEFT ----
def make_bolt(w, h, main, dark, hi, outline_color):
    S = 4  # supersample factor for a smoother large silhouette, then hard-threshold + nearest downscale
    big = Image.new("RGBA", (w*S, h*S), (0,0,0,0))
    d = ImageDraw.Draw(big)
    cy = h*S//2
    margin = 3*S
    tip_x = w*S - margin
    tail_x = margin
    # main crescent body: polygon approximating a lens tapering to a point on the right
    body = [
        (tail_x, cy),
        (tail_x + (tip_x-tail_x)*0.25, cy - h*S*0.34),
        (tip_x, cy - h*S*0.06),
        (tip_x + 1*S, cy),
        (tip_x, cy + h*S*0.06),
        (tail_x + (tip_x-tail_x)*0.25, cy + h*S*0.34),
    ]
    d.polygon(body, fill=main)
    # dark rear core
    core = [
        (tail_x, cy),
        (tail_x + (tip_x-tail_x)*0.18, cy - h*S*0.16),
        (tail_x + (tip_x-tail_x)*0.40, cy),
        (tail_x + (tip_x-tail_x)*0.18, cy + h*S*0.16),
    ]
    d.polygon(core, fill=dark)
    # small forward highlight sliver (<=10% area) near the tip, single cluster
    hi_poly = [
        (tip_x - (tip_x-tail_x)*0.14, cy - h*S*0.05),
        (tip_x - (tip_x-tail_x)*0.02, cy),
        (tip_x - (tip_x-tail_x)*0.14, cy + h*S*0.05),
    ]
    d.polygon(hi_poly, fill=hi)
    # tail fins (two short backward strokes)
    for fy in (cy - h*S*0.22, cy + h*S*0.22):
        d.line([(tail_x - 1*S, fy), (tail_x + (tip_x-tail_x)*0.22, cy)], fill=dark, width=max(1,S//2))
    small = big.resize((w,h), Image.NEAREST)
    small = crisp_alpha(small, threshold=140)
    small = outline(small, outline_color)
    return small

def sha256(path):
    hh = hashlib.sha256()
    with open(path,"rb") as f:
        hh.update(f.read())
    return hh.hexdigest()

def alpha_stats(im):
    px = im.load(); w,h = im.size
    xs=[];ys=[];partial=0;opaque=0
    for y in range(h):
        for x in range(w):
            a = px[x,y][3]
            if a>0: xs.append(x); ys.append(y)
            if 0<a<255: partial+=1
            if a==255: opaque+=1
    bbox = (min(xs),min(ys),max(xs)+1,max(ys)+1) if xs else None
    return bbox, partial, opaque/(w*h)

results = {}

BOLT_W, BOLT_H = 32, 16

specs = {
    "boss_ember_bolt_v1":  dict(main=(214,90,34,255),  dark=(120,32,18,255),  hi=(255,214,110,255), outline=(58,26,24,255)),
    "boss_tide_bolt_v1":   dict(main=(46,104,168,255), dark=(22,52,92,255),   hi=(150,222,232,255), outline=(14,20,38,255)),
    "boss_plain_bolt_v1":  dict(main=(150,150,158,255),dark=(74,74,84,255),   hi=(224,224,230,255), outline=(26,22,30,255)),
    "sentry_tide_bolt_v1": dict(main=(40,150,190,255), dark=(18,80,108,255),  hi=(150,232,236,255), outline=(10,40,54,255)),
}

for name, sp in specs.items():
    im = make_bolt(BOLT_W, BOLT_H, sp["main"], sp["dark"], sp["hi"], sp["outline"])
    path = os.path.join(OUT_PROJ, name+".png")
    im.save(path)
    bbox, partial, cov = alpha_stats(im)
    results[name+".png"] = {"size": im.size, "mode": im.mode, "sha256": sha256(path),
                              "bytes": os.path.getsize(path), "alpha_bbox": bbox,
                              "partial_alpha_px": partial, "opaque_coverage": round(cov,6),
                              "facing": "right"}

# ---- Impact: 4-frame burst, small radial spikes, neutral-bright ----
def make_impact_frame(size, radius, core_col, mid_col, spike_col, outline_col):
    S=4
    big = Image.new("RGBA",(size*S,size*S),(0,0,0,0))
    d = ImageDraw.Draw(big)
    cx=cy=size*S//2
    r = radius*S
    d.ellipse([cx-r,cy-r,cx+r,cy+r], fill=mid_col)
    d.ellipse([cx-r*0.55,cy-r*0.55,cx+r*0.55,cy+r*0.55], fill=core_col)
    import math
    for i in range(6):
        ang = i*math.pi/3
        x2 = cx + math.cos(ang)*r*1.05
        y2 = cy + math.sin(ang)*r*1.05
        d.line([(cx,cy),(x2,y2)], fill=spike_col, width=max(1,S//2))
    small = big.resize((size,size), Image.NEAREST)
    small = crisp_alpha(small, threshold=140)
    small = outline(small, outline_col)
    return small

impact_sizes = [6,8,9,7]
impact_frames = []
for i,r in enumerate(impact_sizes):
    fr = make_impact_frame(24, r, (255,238,180,255), (255,196,96,255), (214,120,40,255), (58,26,24,255))
    impact_frames.append(fr)

sheet = Image.new("RGBA", (24*4,24), (0,0,0,0))
for i,fr in enumerate(impact_frames):
    sheet.alpha_composite(fr, (i*24,0))
impact_path = os.path.join(OUT_PROJ, "bolt_impact_v1.png")
sheet.save(impact_path)
bbox, partial, cov = alpha_stats(sheet)
results["bolt_impact_v1.png"] = {"size": sheet.size, "mode": sheet.mode, "sha256": sha256(impact_path),
                                   "bytes": os.path.getsize(impact_path), "alpha_bbox": bbox,
                                   "partial_alpha_px": partial, "opaque_coverage": round(cov,6),
                                   "layout": "4 frames, 24x24 each, horizontal strip"}

with open(os.path.join(EVID_DIR, "projectile_stats.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

# ---- Telegraph: Dead-Cells-style yellow exclamation mark, 32x32 world-layer icon ----
def make_telegraph_frame(bob_offset=0):
    S = 4
    size = 32
    big = Image.new("RGBA", (size*S, size*S), (0,0,0,0))
    d = ImageDraw.Draw(big)
    cx = size*S//2
    top = 4*S + bob_offset*S
    bar_w = 5*S
    bar_h = 15*S
    gap = 3*S
    dot_r = 3*S
    yellow = (255,214,32,255)
    yellow_hi = (255,240,150,255)
    dark_outline = (46,34,10,255)
    # bar (rounded rect approximation via polygon)
    d.polygon([
        (cx-bar_w//2, top),
        (cx+bar_w//2, top),
        (cx+bar_w//2 - S, top+bar_h),
        (cx-bar_w//2 + S, top+bar_h),
    ], fill=yellow)
    # inner highlight sliver on the bar (single small cluster)
    d.polygon([
        (cx-bar_w//2 + S, top+S),
        (cx-bar_w//2 + 2*S, top+S),
        (cx-bar_w//2 + 1*S, top+bar_h-2*S),
    ], fill=yellow_hi)
    # dot
    dot_cy = top+bar_h+gap+dot_r
    d.ellipse([cx-dot_r,dot_cy-dot_r,cx+dot_r,dot_cy+dot_r], fill=yellow)
    d.ellipse([cx-dot_r*0.4,dot_cy-dot_r*0.4,cx+dot_r*0.1,dot_cy+dot_r*0.1], fill=yellow_hi)
    small = big.resize((size,size), Image.NEAREST)
    small = crisp_alpha(small, threshold=140)
    small = outline(small, dark_outline)
    return small

tel_static = make_telegraph_frame(0)
p = os.path.join(OUT_TEL, "telegraph_alert_static_v1.png")
tel_static.save(p)
bbox, partial, cov = alpha_stats(tel_static)
tel_results = {"telegraph_alert_static_v1.png": {"size": tel_static.size, "mode": tel_static.mode,
    "sha256": sha256(p), "bytes": os.path.getsize(p), "alpha_bbox": bbox,
    "partial_alpha_px": partial, "opaque_coverage": round(cov,6), "purpose": "reduced-motion single frame"}}

bob_frames = [make_telegraph_frame(off) for off in [0,-1,0]]
strip = Image.new("RGBA", (32*3,32), (0,0,0,0))
for i,fr in enumerate(bob_frames):
    strip.alpha_composite(fr, (i*32,0))
p2 = os.path.join(OUT_TEL, "telegraph_alert_v1.png")
strip.save(p2)
bbox, partial, cov = alpha_stats(strip)
tel_results["telegraph_alert_v1.png"] = {"size": strip.size, "mode": strip.mode,
    "sha256": sha256(p2), "bytes": os.path.getsize(p2), "alpha_bbox": bbox,
    "partial_alpha_px": partial, "opaque_coverage": round(cov,6),
    "layout": "3 frames, 32x32 each, horizontal strip, bounce sequence"}

with open(os.path.join(EVID_DIR, "telegraph_stats.json"), "w", encoding="utf-8") as f:
    json.dump(tel_results, f, indent=2, ensure_ascii=False)

print(json.dumps(tel_results, indent=2))
