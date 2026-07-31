from __future__ import annotations

from pathlib import Path


RESOURCE_PATH = Path("resources/animations/player_frames.tres")

TEXTURES = (
    ("10_water_attack", "uid://ch28ak6wa4tjn", "cat_water_attack.png", 8),
    ("11_water_idle", "uid://ctliub5lx2had", "cat_water_idle.png", 8),
    ("12_water_walk", "uid://44huip50sow7", "cat_water_walk.png", 12),
    ("13_water_jump", "uid://t7qvt2w2ek7u", "cat_water_jump.png", 3),
)

ANIMATIONS = (
    ("water_attack", 8, False, 20.0),
    ("water_idle", 8, True, 8.0),
    ("water_jump", 3, False, 6.0),
    ("water_walk", 12, True, 12.0),
)


def atlas_resources() -> str:
    blocks: list[str] = []
    for ext_id, _uid, _file_name, frame_count in TEXTURES:
        animation_name = ext_id.split("_", 1)[1]
        for index in range(frame_count):
            blocks.append(
                f'[sub_resource type="AtlasTexture" id="{animation_name}_{index}"]\n'
                f'atlas = ExtResource("{ext_id}")\n'
                f"region = Rect2({index * 80}, 0, 80, 64)\n"
            )
    return "\n".join(blocks) + "\n"


def animation_object(
    name: str, frame_count: int, loop: bool, speed: float
) -> str:
    frames = []
    for index in range(frame_count):
        frames.append(
            '{\n'
            '"duration": 1.0,\n'
            f'"texture": SubResource("{name}_{index}")\n'
            "}"
        )
    return (
        '"frames": ['
        + ", ".join(frames)
        + "],\n"
        + f'"loop": {1 if loop else 0},\n'
        + f'"name": &"{name}",\n'
        + f'"speed": {speed:.1f}\n'
    )


def main() -> None:
    text = RESOURCE_PATH.read_text(encoding="utf-8")
    if 'path="res://assets/characters/cat/cat_water_idle.png"' in text:
        raise RuntimeError("Water animations are already integrated")

    ext_anchor = (
        '[ext_resource type="Texture2D" uid="uid://cg68rpijrb6kq" '
        'path="res://assets/characters/cat/cat_fire_jump.png" id="9_fire_jump"]\n'
    )
    ext_lines = "".join(
        f'[ext_resource type="Texture2D" uid="{uid}" '
        f'path="res://assets/characters/cat/{file_name}" id="{ext_id}"]\n'
        for ext_id, uid, file_name, _count in TEXTURES
    )
    if text.count(ext_anchor) != 1:
        raise RuntimeError("Could not find unique external-resource anchor")
    text = text.replace(ext_anchor, ext_anchor + ext_lines, 1)

    subresource_anchor = '[sub_resource type="AtlasTexture" id="hurt_0"]\n'
    if text.count(subresource_anchor) != 1:
        raise RuntimeError("Could not find unique subresource anchor")
    text = text.replace(
        subresource_anchor,
        atlas_resources() + subresource_anchor,
        1,
    )

    animation_anchor = (
        '"frames": [{\n'
        '"duration": 1.0,\n'
        '"texture": SubResource("hurt_0")\n'
    )
    if text.count(animation_anchor) != 1:
        raise RuntimeError("Could not find unique animation anchor")
    water_objects = "".join(
        animation_object(name, count, loop, speed) + "}, {\n"
        for name, count, loop, speed in ANIMATIONS
    )
    text = text.replace(
        animation_anchor,
        water_objects + animation_anchor,
        1,
    )
    RESOURCE_PATH.write_text(text, encoding="utf-8", newline="\n")
    print("integrated_water_animations=4")
    print("water_frames=31")


if __name__ == "__main__":
    main()
