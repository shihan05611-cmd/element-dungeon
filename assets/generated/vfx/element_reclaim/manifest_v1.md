# Element Reclaim VFX v1

| File | Size | Frames | Use |
|---|---:|---:|---|
| `reclaim_particle_water_v1.png` | 256×32 | 8 × 32×32 | Rounded water droplet travelling from an affected enemy to the player |
| `reclaim_particle_fire_v1.png` | 256×32 | 8 × 32×32 | Pointed rotating fire shard travelling from an affected enemy to the player |
| `reclaim_extract_neutral_v1.png` | 512×64 | 8 × 64×64 | Tintable extraction mark at each matched enemy |
| `reclaim_arrival_neutral_v1.png` | 512×64 | 8 × 64×64 | Tintable convergence flash on the player |
| `reclaim_motion_preview_v1.gif` | 768×352 | 18 | Two-row enemy-to-player motion demonstration |

Integration notes:

- Play only after a successful reclaim transaction. Full energy, no matching layers, or failed atomic validation produces no success VFX.
- Spawn the extraction mark and 2–4 matching particles at every consumed enemy.
- Move particles along a curved path from the enemy visual center to the player's body center; the path is runtime geometry and is not baked into the particle sheet.
- Suggested visual travel duration is 0.30–0.48 s based on distance, with 20–35 ms particle staggering.
- Play `reclaim_arrival_neutral_v1.png` once after the last particle arrives.
- The authoritative query radius remains 160; these textures do not define it.

