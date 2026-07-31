# Element Reclaim final manifest

| File | Purpose | Blend | Anchor / display | Tintable | Frames / timing |
|---|---|---|---|---|---|
| `icon.png` | Skill icon | alpha | HUD 32×32 or 64×64 | no | static |
| `reclaim_particle_water.png` | Rounded water particle travelling enemy → player | alpha / light additive | center, 32×32 | fixed water | 8 frames × 40 ms, loop during travel |
| `reclaim_particle_fire.png` | Pointed rotating fire shard travelling enemy → player | alpha / light additive | center, 32×32 | fixed fire | 8 frames × 40 ms, loop during travel |
| `reclaim_extract_neutral.png` | Extraction mark at each matched enemy | alpha / light additive | enemy body center, 64×64 | yes, locked element | 8 frames × 45 ms |
| `reclaim_arrival_neutral.png` | Convergence flash at player | light additive | player body center, 64×64 | yes, locked element | 8 frames × 45 ms |

Task 15 baseline and hookup:

- Authoritative query radius is 160.
- Only play after a successful atomic reclaim transaction. Full energy, no matching layer, invalidated target, or failed transaction produces no success effect.
- For each consumed enemy, spawn extraction plus 2–4 matching particles.
- Compute the curve at runtime from enemy visual center to player body center. Suggested visual travel is 0.30–0.48 s with 20–35 ms staggering.
- Play arrival once after the last particle reaches the player.
- The texture path and travel duration do not change the query radius or transaction order.

Selection:

- Licensed vortex/ring/orbit candidates remain under `source_candidates/` and are not final.
- Python particles were selected because their trajectory can be driven from arbitrary enemy positions.

