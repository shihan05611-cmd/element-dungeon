#!/usr/bin/env python3
"""Build nearest-neighbour GIF review reels for Task 78."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
BOSS = ROOT / "assets/world/enemies/tide_ember_sovereign"
VFX = ROOT / "assets/generated/vfx/burning"
OUT = ROOT / "docs/agent_tasks/evidence/task78/gifs"
FONT_PATH = ROOT / "assets/ui/fonts/fusion_pixel_12px/fusion-pixel-12px-proportional-zh_hans.otf"

ACTIONS = {
    "IDLE": ("idle", 6, 140),
    "WALK": ("walk", 8, 110),
    "ATTACK": ("attack", 8, 100),
    "CAST": ("cast", 8, 100),
    "HURT": ("hurt", 4, 130),
    "DEATH": ("death", 4, 170),
}


def sheet_path(form: str, action: str) -> Path:
    if form == "plain":
        names = {
            "idle": "boss_plain_idle_v2.png",
            "walk": "boss_plain_walk_v2.png",
            "attack": "boss_plain_attack_v2.png",
            "cast": "boss_plain_cast_v1.png",
            "hurt": "boss_hurt_v2.png",
            "death": "boss_death_v2.png",
        }
        return BOSS / names[action]
    version = "v2" if action in ("idle", "walk", "attack") else "v1"
    return BOSS / f"boss_{form}_{action}_{version}.png"


def frame(form: str, action: str, index: int) -> Image.Image:
    sheet = Image.open(sheet_path(form, action)).convert("RGBA")
    return sheet.crop((index * 200, 0, (index + 1) * 200, 200))


def text(draw: ImageDraw.ImageDraw, position: tuple[int, int], copy: str, size: int, fill: str) -> None:
    draw.text(position, copy, font=ImageFont.truetype(str(FONT_PATH), size), fill=fill)


def build_comparison() -> None:
    forms = (("plain", "PLAIN", "#eadce4"), ("tide", "TIDE", "#83ddff"), ("ember", "EMBER", "#ff9953"))
    frames = []
    durations = []
    for action_label, (action, count, duration) in ACTIONS.items():
        for index in range(count):
            canvas = Image.new("RGBA", (1200, 500), "#0d111cff")
            draw = ImageDraw.Draw(canvas)
            text(draw, (38, 24), f"TASK 78  /  {action_label}", 28, "#f6f0dd")
            for column, (form, form_label, color) in enumerate(forms):
                sprite = frame(form, action, index).resize((400, 400), Image.Resampling.NEAREST)
                canvas.alpha_composite(sprite, (column * 400, 76))
                text(draw, (column * 400 + 154, 440), form_label, 21, color)
            frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE, colors=128))
            durations.append(duration + (280 if index == count - 1 else 0))
    frames[0].save(
        OUT / "boss_three_forms_all_actions_comparison.gif",
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )


def build_form_reel(form: str, label: str, color: str) -> None:
    frames = []
    durations = []
    for action_label, (action, count, duration) in ACTIONS.items():
        for index in range(count):
            canvas = Image.new("RGBA", (600, 680), "#0d111cff")
            draw = ImageDraw.Draw(canvas)
            text(draw, (30, 22), f"{label}  /  {action_label}", 28, color)
            sprite = frame(form, action, index).resize((600, 600), Image.Resampling.NEAREST)
            canvas.alpha_composite(sprite, (0, 72))
            frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE, colors=128))
            durations.append(duration + (280 if index == count - 1 else 0))
    frames[0].save(
        OUT / f"boss_{form}_all_actions.gif",
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )


def build_burning() -> None:
    sheet = Image.open(VFX / "burning_enemy_loop.png").convert("RGBA")
    frames = []
    for index in range(12):
        sprite = sheet.crop((index * 64, 0, (index + 1) * 64, 64)).resize((384, 384), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (384, 440), "#0d111cff")
        canvas.alpha_composite(sprite, (0, 48))
        draw = ImageDraw.Draw(canvas)
        text(draw, (18, 12), "BURNING / RISING SPARKS", 18, "#ffd467")
        frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE, colors=64))
    frames[0].save(
        OUT / "burning_rising_sparks_loop.gif",
        save_all=True,
        append_images=frames[1:],
        duration=80,
        loop=0,
        disposal=2,
        optimize=False,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_comparison()
    build_form_reel("plain", "PLAIN", "#eadce4")
    build_form_reel("tide", "TIDE", "#83ddff")
    build_form_reel("ember", "EMBER", "#ff9953")
    build_burning()
    for path in sorted(OUT.glob("*.gif")):
        print(f"{path.name}: {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
