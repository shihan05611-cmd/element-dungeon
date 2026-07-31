# Element Bolt final manifest

Status: final visual reuse; existing runtime wiring is intentionally unchanged.

| File | Purpose | Blend | Anchor / display | Tintable | Frames / timing |
|---|---|---|---|---|---|
| `icon.png` | Skill icon | alpha | HUD 32×32 or 64×64 | no | static |
| `projectile_water_no_jitter_spritesheet.png` | Existing water projectile body and trail | alpha | four 384×160 frames; current scene offset `(-80,0)`, scale `0.2` → 76.8×32 display | no | 4 frames at 12.5 fps |
| `projectile_fire_no_jitter_spritesheet.png` | Existing fire projectile body and trail | alpha | same as water | no | 4 frames at 12.5 fps |

Read-only integration:

- SpriteFrames: `res://resources/animations/element_projectile_frames.tres`.
- Scene: `res://scenes/element_projectile.tscn`.
- Logical projectile radius remains 6; VFX scale does not change it.
- Licensed candidate sheets and Aseprite previews remain under `source_candidates/`, but were not substituted into the current scene.

Source:

- The two no-jitter projectile sheets are pre-existing project assets already wired before task 17 stage 2.
- The new icon source and alpha intermediates are under `_sources/`.

