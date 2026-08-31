from __future__ import annotations

from hashlib import sha256
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
TARGET = ROOT.parent / "task91" / "screenshots" / "01_water_full_same_camera.png"
RAW = ROOT / "task94_imagegen_raw.png"
NORMALIZED = ROOT / "task94_imagegen_raw_normalized_1920x1080.png"
FINAL = ROOT / "task94_skill_hud_hierarchy_states_full_concept_1920x1080.png"
ACTIVE_CLOSEUP = ROOT / "task94_active_hud_closeup_4x_nearest.png"
PASSIVE_CLOSEUP = ROOT / "task94_passive_4x1_closeup_4x_nearest.png"
RULES = ROOT / "task94_state_rules_1920x1080.png"

ACTIVE_BOX = (690, 918, 1230, 1060)
PASSIVE_BOX = (1420, 934, 1835, 1050)
CLEANUP_BOX = (800, 864, 1120, 934)
ALLOWED_BOXES = (CLEANUP_BOX, ACTIVE_BOX, PASSIVE_BOX)


def rgba_hash(image: Image.Image) -> str:
    return sha256(image.convert("RGBA").tobytes()).hexdigest()


def masked_copy(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA").copy()
    draw = ImageDraw.Draw(result)
    for x0, y0, x1, y1 in ALLOWED_BOXES:
        draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill=(0, 0, 0, 0))
    return result


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        Path(r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc"),
        Path(r"C:\Windows\Fonts\simhei.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


target = Image.open(TARGET).convert("RGBA")
previous = Image.open(FINAL).convert("RGBA")
raw = Image.open(RAW).convert("RGBA")
raw.resize((1920, 1080), Image.Resampling.NEAREST).save(NORMALIZED)

final = target.copy()
final.paste(target.crop((1280, 864, 1600, 934)), CLEANUP_BOX[:2])

# Preserve the previously accepted passive 4x1 area pixel-for-pixel.
final.paste(previous.crop(PASSIVE_BOX), PASSIVE_BOX[:2])

# User-selected final combination: three independently closed stepped frames with
# clean content fields and no inset rectangle.
active_native = raw.crop((600, 800, 1072, 926))
active = active_native.resize((540, 142), Image.Resampling.NEAREST)
active_mask = Image.new("L", active.size, 0)
ImageDraw.Draw(active_mask).polygon(
    [(2, 10), (10, 2), (530, 2), (538, 10), (538, 132), (530, 140), (10, 140), (2, 132)],
    fill=255,
)
final.paste(active, ACTIVE_BOX[:2], active_mask)

# Remove the residual frame-within-frame lines that the generative edit left behind.
# Keep the independent outer frames and key tabs; touch only the inset rectangle bands.
active_draw = ImageDraw.Draw(final)
for inner_left, inner_right in ((708, 858), (885, 1035), (1063, 1212)):
    clean = final.getpixel((inner_left + 85, 947))
    active_draw.rectangle((inner_left + 35, 933, inner_right + 4, 943), fill=clean)
    active_draw.rectangle((inner_left - 4, 1035, inner_right + 4, 1046), fill=clean)
    active_draw.rectangle((inner_left - 4, 970, inner_left + 8, 1036), fill=clean)
    active_draw.rectangle((inner_right - 8, 941, inner_right + 4, 1036), fill=clean)
final.save(FINAL)

active_final = final.crop(ACTIVE_BOX)
passive_final = final.crop(PASSIVE_BOX)
active_final.resize((2160, 568), Image.Resampling.NEAREST).save(ACTIVE_CLOSEUP)
passive_final.resize((1660, 464), Image.Resampling.NEAREST).save(PASSIVE_CLOSEUP)

board = Image.new("RGBA", (1920, 1080), (7, 12, 23, 255))
draw = ImageDraw.Draw(board)
cyan = (78, 190, 242, 255)
muted = (125, 149, 181, 255)
white = (234, 242, 250, 255)
panel = (14, 24, 41, 255)
draw.rounded_rectangle((36, 28, 1884, 1052), radius=18, fill=panel, outline=(35, 72, 108, 255), width=3)
draw.text((76, 58), "TASK 94  技能 HUD 状态规则", font=font(46, True), fill=white)
draw.text((78, 116), "仅概念、尚未实装｜用户选定：主动三独立闭合框、无框中框｜被动：右下 4×1", font=font(24), fill=muted)

active_2x = active_final.resize((1080, 284), Image.Resampling.NEAREST)
board.alpha_composite(active_2x, (70, 180))
draw.text((1190, 190), "主动区（用户选定样式）", font=font(30, True), fill=cyan)
active_lines = [
    "• 三个相邻但各自闭合的厚框",
    "• 每槽内容区无内层矩形描边",
    "• 槽间保留紧密的成对阶梯接缝",
    "• 键位片左上；SP 固定右下",
    "• 冷却读秒居中；第三槽图标为空",
]
for i, line in enumerate(active_lines):
    draw.text((1190, 242 + i * 43), line, font=font(23), fill=white)
draw.line((730, 555, 730, 505), fill=cyan, width=4)
draw.polygon([(720, 521), (730, 505), (740, 521)], fill=cyan)
draw.text((560, 562), "冷却覆盖层由底部向上推进", font=font(23), fill=cyan)

draw.text((76, 640), "被动区（像素保持 4×1）", font=font(30, True), fill=cyan)
slot_boxes = [
    (1432, 944, 1526, 1040),
    (1530, 944, 1624, 1040),
    (1628, 944, 1722, 1040),
    (1726, 944, 1820, 1040),
]
slot_labels = ["空槽：内凹虚线", "未解锁：小锁", "响应态：细亮边脉冲", "已装备：安静图标"]
for i, (box, label) in enumerate(zip(slot_boxes, slot_labels)):
    sample = final.crop(box).resize((235, 240), Image.Resampling.NEAREST)
    x = 78 + i * 328
    board.alpha_composite(sample, (x, 692))
    draw.text((x, 945), label, font=font(21), fill=white)

draw.text((1510, 682), "右下固定锚点", font=font(28, True), fill=cyan)
draw.line((1510, 740, 1805, 740), fill=muted, width=3)
draw.line((1805, 740, 1805, 1000), fill=muted, width=3)
draw.rectangle((1745, 940, 1805, 1000), outline=cyan, width=4)
draw.line((1745, 970, 1585, 970), fill=cyan, width=4)
draw.polygon([(1585, 970), (1603, 959), (1603, 981)], fill=cyan)
draw.text((1510, 1008), "4×1 仅向左生长；安全边距不变", font=font(21), fill=white)
board.save(RULES)

masked_target = masked_copy(target)
masked_final = masked_copy(final)
print(f"target_size={target.size}")
print(f"raw_size={raw.size}")
print(f"final_size={final.size}")
print(f"target_rgba_sha256={rgba_hash(target)}")
print(f"final_rgba_sha256={rgba_hash(final)}")
print(f"masked_target_sha256={rgba_hash(masked_target)}")
print(f"masked_final_sha256={rgba_hash(masked_final)}")
print(f"masked_diff_bbox={ImageChops.difference(masked_target, masked_final).getbbox()}")
print(f"passive_closeup_sha256={rgba_hash(passive_final.resize((1660, 464), Image.Resampling.NEAREST))}")
print(f"allowed_boxes={ALLOWED_BOXES}")
