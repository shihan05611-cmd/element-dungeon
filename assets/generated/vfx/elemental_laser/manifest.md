# Elemental Laser final manifest

| File | Purpose | Blend | Anchor / display | Tintable | Frames / timing |
|---|---|---|---|---|---|
| `icon.png` | Skill icon | alpha | HUD 32×32 or 64×64 | no | static |
| `beam_segment_water.png` | Repeatable rounded water Beam | premultiplied alpha | left-center; repeat 5× to 320×24 | fixed water | static, brightness pulse per Tick |
| `beam_segment_fire.png` | Repeatable serrated fire Beam | premultiplied alpha | left-center; repeat 5× to 320×24 | fixed fire | static, brightness pulse per Tick |
| `beam_segment_water_mask.png` | Exact alpha mask for water segment | mask | UV-aligned 64×24 | yes | static |
| `beam_segment_fire_mask.png` | Exact alpha mask for fire segment | mask | UV-aligned 64×24 | yes | static |
| `beam_tick_water.png` | Water target pulse | light additive / alpha | target center, 64×64 | fixed water | 8 frames × 40 ms = 0.32 s |
| `beam_tick_fire.png` | Fire target pulse | light additive / alpha | target center, 64×64 | fixed fire | 8 frames × 40 ms = 0.32 s |
| `beam_tick_water_mask.png` | Exact water pulse mask | mask | UV-aligned 512×64 | yes | follows color sheet |
| `beam_tick_fire_mask.png` | Exact fire pulse mask | mask | UV-aligned 512×64 | yes | follows color sheet |

Task 15 baseline and hookup:

- Authoritative Beam is 320×24 from the Beam node's current world origin along its locked direction.
- Repeat the segment; do not stretch the width beyond 24.
- On every `tick_submitted(tick_index, target_count)` at the task-14 0.5 s cadence, pulse whole-beam brightness and optionally play the matching 64×64 pulse at every legal target.
- The beam is piercing; never stop visuals at the first target.
- Stop and clear on `delivery_finished`.

