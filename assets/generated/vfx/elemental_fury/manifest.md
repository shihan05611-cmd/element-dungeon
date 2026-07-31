# Elemental Fury final manifest

| File | Purpose | Blend | Anchor / display | Tintable | Frames / timing |
|---|---|---|---|---|---|
| `icon.png` | Skill icon | alpha | HUD 32×32 or 64×64 | no | static |
| `burst_core.png` | User-selected main burst animation | light additive or premultiplied alpha | center `(0.5,0.5)`; suggested visual diameter `radius × 1.5` | yes, use locked cast element | 8 × 64×64; suggested 60 ms/frame, 0.48 s total |

Task 15 baseline and hookup:

- Authoritative base radius 96; maximum radius scale 2.0 gives radius 192.
- Start frame 0 at cast commit; align the decisive frame to `burst_submitted(origin, radius, target_count)`.
- One animation playback must not create extra hit windows.
- Scale from the signal radius; the texture never determines collision.

Source selection:

- `source_candidates/burst_core_neutral_candidate.png` was approved by the user and promoted pixel-for-pixel.
- `shock_ring_neutral_candidate` and `dissipate_neutral_candidate` remain review candidates and are not final dependencies.

