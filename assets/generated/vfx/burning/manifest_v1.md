# Burning VFX v1

| File | Size | Frames | Use |
|---|---:|---:|---|
| `burning_enemy_loop_v1.png` | 768×64 | 12 × 64×64 | Sparse fire tongues and rising sparks attached to an enemy |
| `burning_tick_v1.png` | 512×64 | 8 × 64×64 | Short outward spark accent for the one-second damage tick |
| `burning_preview_v1.gif` | 256×256 | 16 | Loop plus one tick review preview |

Integration notes:

- Show the loop on an enemy only while Burning is equipped and that enemy has at least one fire layer.
- Anchor at enemy body center; keep the sprite in the enemy's visual layer and do not create ground fire.
- Trigger `burning_tick_v1.png` on the confirmed Burning one-second tick.
- The loop does not encode layer count and must not imply fire-layer consumption.
- Use normal alpha or light additive blending; keep the enemy silhouette readable.

