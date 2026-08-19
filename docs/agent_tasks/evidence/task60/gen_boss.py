#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Task60 boss portrait generator. Programmatic pixel pipeline (no image_gen model available this session).
Source: Blood Monster_A (100x100 split, no-shadow variant), itch-purchased, user-confirmed license:
modify/derive OK, non-commercial only, no redistribution.
"""
import os, hashlib, json
from PIL import Image

SRC_DIR = r"C:\Users\heliashi\Desktop\游戏资产\Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A\Characters(100x100 split)\Blood Monster_A\Blood Monster_A"
OUT_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\assets\world\enemies\tide_ember_sovereign"
EVID_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\docs\agent_tasks\evidence\task60"

CANVAS = 200
CROP_BOX = (38, 30, 74, 60)   # fixed source-space window shared by all frames (36x30)
SCALE = 4                     # integer scale only
PASTE_XY = (28, 50)           # fixed offset in the 200x200 canvas -> shared anchor/baseline

FRAME_PICKS = {
    "idle":  ("Blood Monster_A_Idle.png", 0),
    "walk":  ("Blood Monster_A_Walk.png", 2),
    "attack":("Blood Monster_A_Attack01.png", 4),
    "hurt":  ("Blood Monster_A_Hurt.png", 0),
    "death": ("Blood Monster_A_Death.png", 2),
}

def load_frame(fn, idx):
    im = Image.open(os.path.join(SRC_DIR, fn)).convert("RGBA")
    return im.crop((idx*100, 0, idx*100+100, 100))

def place_on_canvas(frame100):
    crop = frame100.crop(CROP_BOX)
    scaled = crop.resize((crop.width*SCALE, crop.height*SCALE), Image.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0,0,0,0))
    canvas.alpha_composite(scaled, PASTE_XY)
    return canvas

# ---- Palette remap tables (RGB -> RGB), alpha untouched ----
SRC_BLACK   = (0,0,0)
SRC_MAIN    = (162,43,75)
SRC_DARK    = (110,20,56)
SRC_STRIPE  = (49,19,57)
SRC_HI_A    = (217,216,216)
SRC_HI_B    = (192,191,191)
SRC_OUTLINE2= (31,26,26)
SRC_HI_C    = (207,69,84)

PLAIN_MAP = {
    SRC_BLACK:   (26,22,30),
    SRC_OUTLINE2:(26,22,30),
    SRC_MAIN:    (162,43,75),
    SRC_DARK:    (98,18,50),
    SRC_STRIPE:  (49,19,57),
    SRC_HI_A:    (222,214,214),
    SRC_HI_B:    (196,188,188),
    SRC_HI_C:    (214,86,98),
}

EMBER_MAP = {
    SRC_BLACK:   (58,26,24),
    SRC_OUTLINE2:(58,26,24),
    SRC_MAIN:    (191,79,32),
    SRC_DARK:    (122,34,20),
    SRC_STRIPE:  (61,24,20),
    SRC_HI_A:    (247,201,96),
    SRC_HI_B:    (222,142,54),
    SRC_HI_C:    (255,168,52),
}

TIDE_MAP = {
    SRC_BLACK:   (14,20,38),
    SRC_OUTLINE2:(14,20,38),
    SRC_MAIN:    (43,95,158),
    SRC_DARK:    (24,54,96),
    SRC_STRIPE:  (20,66,74),
    SRC_HI_A:    (196,232,232),
    SRC_HI_B:    (150,204,214),
    SRC_HI_C:    (98,206,222),
}

def remap(canvas, mapping):
    px = canvas.load()
    w,h = canvas.size
    for y in range(h):
        for x in range(w):
            r,g,b,a = px[x,y]
            if a == 0:
                continue
            key = (r,g,b)
            if key in mapping:
                nr,ng,nb = mapping[key]
                px[x,y] = (nr,ng,nb,a)
    return canvas

def src_to_canvas(sx, sy):
    return (PASTE_XY[0] + (sx-CROP_BOX[0])*SCALE, PASTE_XY[1] + (sy-CROP_BOX[1])*SCALE)

def add_ember_cracks(canvas):
    """Add extra bright crack pixels inside the dark stripe/body mass - new geometry, not just recolor."""
    px = canvas.load()
    w,h = canvas.size
    crack_color = (255,200,90,255)
    # deterministic jagged line across the stripe band area (upper-mid body), source-space anchored
    src_pts = [(50,37),(52,39),(49,41),(53,43),(50,46),(54,48)]
    pts = [src_to_canvas(sx,sy) for sx,sy in src_pts]
    for (x,y) in pts:
        for dx,dy in [(0,0),(1,0),(0,1)]:
            if 0<=x+dx<w and 0<=y+dy<h:
                r,g,b,a = px[x+dx,y+dy]
                if a>0:
                    px[x+dx,y+dy] = crack_color
    return canvas

def add_tide_drips(canvas):
    """Soften outer edge alpha + add hanging drip blobs below baseline - new geometry, not just recolor."""
    px = canvas.load()
    w,h = canvas.size
    # soften: any fully-opaque pixel whose 4-neighborhood touches transparency gets 1 ring of half-alpha halo
    edge_pixels = []
    for y in range(h):
        for x in range(w):
            r,g,b,a = px[x,y]
            if a == 255:
                neigh_transparent = False
                for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx,ny = x+dx,y+dy
                    if 0<=nx<w and 0<=ny<h:
                        if px[nx,ny][3] == 0:
                            neigh_transparent = True
                if neigh_transparent:
                    edge_pixels.append((x,y,r,g,b))
    for (x,y,r,g,b) in edge_pixels:
        for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]:
            nx,ny = x+dx,y+dy
            if 0<=nx<w and 0<=ny<h and px[nx,ny][3]==0:
                px[nx,ny] = (r,g,b,110)
    # drip blobs hanging from lower edge - find bottom-most opaque row and drop 3 small blobs
    bottom_y = 0
    cols_at_bottom = []
    for x in range(w):
        col_bottom = None
        for y in range(h-1,-1,-1):
            if px[x,y][3] >= 200:
                col_bottom = y
                break
        if col_bottom is not None:
            cols_at_bottom.append((x,col_bottom))
    if cols_at_bottom:
        cols_at_bottom.sort(key=lambda t:t[1])
        drip_cols = [cols_at_bottom[len(cols_at_bottom)//4], cols_at_bottom[len(cols_at_bottom)//2], cols_at_bottom[3*len(cols_at_bottom)//4]]
        drip_color = (60,150,190,230)
        for (x,by) in drip_cols:
            for i in range(1,5):
                yy = by+i
                if yy < h:
                    px[x,yy] = drip_color
                    if i>=3 and 0<=x-1:
                        px[x-1,min(yy+1,h-1)] = (drip_color[0],drip_color[1],drip_color[2],150)
    return canvas

def add_contact_shadow(canvas, baseline_y=170):
    px = canvas.load()
    w,h = canvas.size
    subj_xs = [x for x in range(w) if any(px[x,y][3]>0 for y in range(h))]
    if not subj_xs:
        return canvas
    x0,x1 = min(subj_xs), max(subj_xs)
    width = x1-x0
    sx0 = x0 + int(width*0.15)
    sx1 = x1 - int(width*0.15)
    for y in range(baseline_y, min(baseline_y+3, h)):
        for x in range(sx0, sx1):
            r,g,b,a = px[x,y]
            shadow_a = 130 if y==baseline_y else 90
            if a==0:
                px[x,y] = (10,8,12,shadow_a)
    return canvas

def sha256(path):
    h = hashlib.sha256()
    with open(path,"rb") as f:
        h.update(f.read())
    return h.hexdigest()

def alpha_stats(im):
    px = im.load()
    w,h = im.size
    xs=[];ys=[]
    partial=0
    opaque=0
    for y in range(h):
        for x in range(w):
            a = px[x,y][3]
            if a>0:
                xs.append(x); ys.append(y)
            if 0<a<255:
                partial+=1
            if a==255:
                opaque+=1
    bbox = (min(xs),min(ys),max(xs)+1,max(ys)+1) if xs else None
    coverage = opaque / (w*h)
    return bbox, partial, coverage

results = {}
os.makedirs(OUT_DIR, exist_ok=True)

for pose in ["idle","walk","attack"]:
    fn, idx = FRAME_PICKS[pose]
    base = place_on_canvas(load_frame(fn, idx))

    plain = remap(base.copy(), PLAIN_MAP)
    plain = add_contact_shadow(plain)
    p_path = os.path.join(OUT_DIR, f"boss_plain_{pose}_v1.png")
    plain.save(p_path)

    ember = remap(base.copy(), EMBER_MAP)
    ember = add_ember_cracks(ember)
    ember = add_contact_shadow(ember)
    e_path = os.path.join(OUT_DIR, f"boss_ember_{pose}_v1.png")
    ember.save(e_path)

    tide = remap(base.copy(), TIDE_MAP)
    tide = add_tide_drips(tide)
    tide = add_contact_shadow(tide)
    t_path = os.path.join(OUT_DIR, f"boss_tide_{pose}_v1.png")
    tide.save(t_path)

    for label,path,img in [("plain",p_path,plain),("ember",e_path,ember),("tide",t_path,tide)]:
        bbox, partial, coverage = alpha_stats(img)
        results[os.path.basename(path)] = {
            "size": img.size, "mode": img.mode, "sha256": sha256(path),
            "bytes": os.path.getsize(path), "alpha_bbox": bbox,
            "partial_alpha_px": partial, "opaque_coverage": round(coverage,6),
        }

# hurt/death shared neutral (plain palette)
for pose in ["hurt","death"]:
    fn, idx = FRAME_PICKS[pose]
    base = place_on_canvas(load_frame(fn, idx))
    plain = remap(base.copy(), PLAIN_MAP)
    plain = add_contact_shadow(plain)
    path = os.path.join(OUT_DIR, f"boss_{pose}_v1.png")
    plain.save(path)
    bbox, partial, coverage = alpha_stats(plain)
    results[os.path.basename(path)] = {
        "size": plain.size, "mode": plain.mode, "sha256": sha256(path),
        "bytes": os.path.getsize(path), "alpha_bbox": bbox,
        "partial_alpha_px": partial, "opaque_coverage": round(coverage,6),
    }

with open(os.path.join(EVID_DIR, "boss_stats.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print(json.dumps(results, indent=2))
