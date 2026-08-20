#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Task70 A.2.3 window recheck for Blood Monster_A_Attack02.png.

Read-only against the source directory. Does NOT write anything under
assets/world/enemies/tide_ember_sovereign/ -- this script only recomputes the
per-frame alpha bbox of the candidate cast source sheet and compares it against
the CROP_BOX fixed by Task60/Task68 (gen_boss_v2.py), reproducing the exact
recheck that produced BLOCKED (see manifest_v2.md section 9).

Outputs (evidence only, under docs/agent_tasks/evidence/task70/):
  - bbox_report_attack02.json
  - attack02_frame_annotation_cropbox_overlay.png
"""
import os, json, hashlib
from PIL import Image, ImageDraw

SRC_DIR = r"C:\Users\heliashi\Desktop\游戏资产\Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A\Characters(100x100 split)\Blood Monster_A\Blood Monster_A"
EVID_DIR = r"C:\Users\heliashi\Documents\元素地牢-4.7\docs\agent_tasks\evidence\task70"
FN = "Blood Monster_A_Attack02.png"
CROP_BOX = (38, 30, 74, 60)  # verbatim from gen_boss_v2.py -- NOT re-tuned here
SCALE = 4

fn = os.path.join(SRC_DIR, FN)
with open(fn, "rb") as f:
    data = f.read()
src_sha256 = hashlib.sha256(data).hexdigest()

im = Image.open(fn).convert("RGBA")
assert im.height == 100 and im.width % 100 == 0
n = im.width // 100

report = {}
for i in range(n):
    frame = im.crop((i * 100, 0, i * 100 + 100, 100))
    px = frame.load()
    xs, ys = [], []
    opaque = partial = 0
    overflow_opaque = []
    for y in range(100):
        for x in range(100):
            a = px[x, y][3]
            if a > 0:
                xs.append(x); ys.append(y)
            if 0 < a < 255:
                partial += 1
            if a == 255:
                opaque += 1
                cx0, cy0, cx1, cy1 = CROP_BOX
                if not (cx0 <= x < cx1 and cy0 <= y < cy1):
                    overflow_opaque.append((x, y, px[x, y][:3]))
    bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1) if xs else None
    cx0, cy0, cx1, cy1 = CROP_BOX
    oob = not (bbox[0] >= cx0 and bbox[1] >= cy0 and bbox[2] <= cx1 and bbox[3] <= cy1)
    entry = {
        "bbox": bbox,
        "out_of_crop_box": oob,
        "opaque_px_total": opaque,
        "partial_alpha_px_total": partial,
        "opaque_px_outside_crop_box": len(overflow_opaque),
    }
    if oob:
        entry["overflow_px"] = {
            "left": max(0, cx0 - bbox[0]),
            "top": max(0, cy0 - bbox[1]),
            "right": max(0, bbox[2] - cx1),
            "bottom": max(0, bbox[3] - cy1),
        }
        entry["overflow_sample_colors"] = overflow_opaque[:10]
    report[f"frame_{i}"] = entry

report["_crop_box"] = CROP_BOX
report["_source_file"] = FN
report["_source_sha256"] = src_sha256
report["_note"] = ("frame 5 overflows CROP_BOX on the right by up to 7px with solid "
                    "opaque effect pixels (partial_alpha_px_total==0 for that frame, "
                    "i.e. not anti-alias fringe) -- see overflow_sample_colors and "
                    "opaque_px_outside_crop_box.")

with open(os.path.join(EVID_DIR, "bbox_report_attack02.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

# annotated contact sheet for independent visual review: each source frame at 4x
# nearest scale with the CROP_BOX rectangle drawn in red
cell = 100 * SCALE
sheet = Image.new("RGBA", (cell * n, cell), (40, 40, 40, 255))
for i in range(n):
    frame = im.crop((i * 100, 0, i * 100 + 100, 100)).resize((cell, cell), Image.NEAREST)
    sheet.alpha_composite(frame, (i * cell, 0))
d = ImageDraw.Draw(sheet)
for i in range(n):
    x0 = i * cell + CROP_BOX[0] * SCALE
    y0 = CROP_BOX[1] * SCALE
    x1 = i * cell + CROP_BOX[2] * SCALE
    y1 = CROP_BOX[3] * SCALE
    d.rectangle([x0, y0, x1, y1], outline=(255, 0, 0, 255), width=2)
sheet.save(os.path.join(EVID_DIR, "attack02_frame_annotation_cropbox_overlay.png"))

print(json.dumps(report, indent=2, ensure_ascii=False))
print("source sha256:", src_sha256)
