# Unending final manifest

| File | Purpose | Blend | Anchor / display | Tintable | Frames / timing |
|---|---|---|---|---|---|
| `icon.png` | Passive icon | alpha | HUD 32×32 or 64×64 | no | static |
| `unending_enemy_loop.png` | Persistent enemy-attached bubbles and droplets | alpha / light additive | pivot `(0.5,0.84)` at enemy feet/body lower edge; 64×64 | fixed water | 12 frames × 80 ms = 0.96 s loop |
| `unending_trigger.png` | Successful recovery accent on the enemy | light additive / alpha | same pivot; 64×64 | fixed water | 8 frames × 45 ms = 0.36 s |

Trigger contract:

- Show the loop only while the player owns/equips Unending and the target has at least one water layer.
- Play `unending_trigger.png` on the successful basic-attack heal event and keep it on the enemy.
- Do not encode water-layer count, consume-layer semantics, a heart/cross, or the player's current element.

The licensed ripple/splash candidates remain under `source_candidates/` and are not stable final dependencies.

