# Elemental Laser VFX v1

| File | Size | Frames | Use |
|---|---:|---:|---|
| `beam_segment_water_v1.png` | 64×24 | 1 | Seamless rounded water beam segment |
| `beam_segment_fire_v1.png` | 64×24 | 1 | Seamless jagged fire beam segment |
| `beam_tick_water_v1.png` | 512×64 | 8 × 64×64 | Water target-crossing pulse |
| `beam_tick_fire_v1.png` | 512×64 | 8 × 64×64 | Fire target-crossing pulse |
| `beam_preview_v1.gif` | 768×192 | 12 | Water/fire review preview |

Integration notes:

- Repeat each 64×24 segment five times to match the default authoritative 320×24 Beam bounds.
- The segment origin is the Beam node's current world origin and it extends along the locked direction.
- Use alpha or premultiplied-alpha blending; no separate glow texture is required for this intentionally simple version.
- On each `tick_submitted`, briefly raise beam brightness and optionally play the matching target pulse.
- Stop and clear all visuals on `delivery_finished`.

