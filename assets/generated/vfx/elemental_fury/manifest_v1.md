# Elemental Fury VFX v1

## Selected asset

| File | Size | Frames | Use |
|---|---:|---:|---|
| `burst_core_neutral_v1.png` | 512×64 | 8 × 64×64 | User-selected burst core; tint from the cast's locked element |
| `burst_core_neutral_v1_preview.gif` | 256×256 | 8 | Enlarged review preview only |

Integration notes:

- Center anchor: `(0.5, 0.5)`.
- Scale the visual from the authoritative rage radius supplied by `burst_submitted(origin, radius, target_count)`.
- Default logical radius is 96 and the maximum energy scale is 2.0.
- The eight-frame animation is presentation only; it must not add another hit window.
- The 80 ms GIF timing is a review timing, not a combat rule.

