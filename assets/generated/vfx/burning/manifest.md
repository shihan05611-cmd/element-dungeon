# Burning final manifest

| File | Purpose | Blend | Anchor / display | Tintable | Frames / timing |
|---|---|---|---|---|---|
| `icon.png` | Passive icon | alpha | HUD 32×32 or 64×64 | no | static |
| `burning_enemy_loop.png` | Persistent enemy-attached fire tongues and sparks | alpha / light additive | pivot `(0.5,0.84)` at enemy feet/body lower edge; 64×64 | fixed fire | 12 frames × 80 ms = 0.96 s loop |
| `burning_tick.png` | Confirmed one-second damage Tick accent | light additive / alpha | same pivot; 64×64 | fixed fire | 8 frames × 45 ms = 0.36 s |

Trigger contract:

- Show the loop only while the player owns/equips Burning and the target has at least one fire layer.
- Play `burning_tick.png` only on the confirmed one-second Burning Tick.
- Do not vary frame count by layers and do not imply fire-layer consumption.
- Keep the enemy silhouette readable; no ground-fire node is required.

The licensed `source_candidates/fire_marker_color_candidate` is retained but not selected as the stable final loop.

