# Unending VFX v1

| File | Size | Frames | Use |
|---|---:|---:|---|
| `unending_enemy_loop_v1.png` | 768×64 | 12 × 64×64 | Rounded bubbles and orbiting droplets attached to an enemy |
| `unending_trigger_v1.png` | 512×64 | 8 × 64×64 | Brief inward/rising water accent on a successful Unending trigger |
| `unending_preview_v1.gif` | 256×256 | 16 | Loop plus one trigger review preview |

Integration notes:

- Show the loop on an enemy only while Unending is equipped and that enemy has at least one water layer.
- Trigger `unending_trigger_v1.png` on a successful basic-attack heal event and keep the accent on the enemy, per the selected direction.
- Anchor at enemy body center and use normal alpha or light additive blending.
- The animation does not encode layer count and must not imply water-layer consumption or the player's current element.

