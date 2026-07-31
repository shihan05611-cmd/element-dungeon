# Task 18 skill VFX runtime evidence

Status: `REVIEW`

## Runtime wiring

| Skill | Stable asset | Presentation scene | Authoritative event | Lifetime |
|---|---|---|---|---|
| `element_bolt` | Existing water/fire projectile sheets plus task-17 `icon.png` | Intentionally empty; reuses `res://scenes/element_projectile.tscn` and `res://resources/animations/element_projectile_frames.tres` | Existing projectile Delivery | Existing projectile cleanup and reuse contract |
| `elemental_fury` | `burst_core.png` | `res://scenes/vfx/elemental_fury_presentation.tscn` | `ElementRageDelivery.burst_submitted(origin, radius, target_count)` | One 8-frame playback; frees on completion and scene teardown |
| `elemental_laser` | Five water/fire 64×24 Beam segments and matching Tick sheets | `res://scenes/vfx/elemental_laser_presentation.tscn` | `hit_submitted`, `tick_submitted`, `delivery_finished` | Follows the Delivery world origin and locked direction; Tick only pulses visuals; finish/tree exit clears Beam and flashes |
| `element_reclaim` | Water/fire travel particles, neutral extract and arrival sheets | `res://scenes/vfx/element_reclaim_presentation.tscn` | `ReclaimVfxPort` delegates the formal port/transaction and publishes `ReclaimVfxEvent` only after `publish_committed()` | Three particles per committed target, 0.40 s travel, one arrival flash after the final particle; failure publishes nothing |
| `burning` | `burning_enemy_loop.png`, `burning_tick.png` | `res://scenes/vfx/burning_presentation.tscn` | Actual passive registration, `ElementCarrier.elements_changed`, committed `CombatReceiver.hit_resolved` with skill `burning` | Exactly one enemy-attached loop while registered and fire layers > 0; zero layers, unequip, death, tree exit, scene change clear it |
| `unending` | `unending_enemy_loop.png`, `unending_trigger.png` | `res://scenes/vfx/unending_presentation.tscn` | Actual passive registration, `ElementCarrier.elements_changed`, certified `basic_attack_committed` after the registered runtime callback | Exactly one enemy-attached loop while registered and water layers > 0; zero layers, unequip, death, tree exit, scene change clear it |

`SkillVfxCoordinator` is configured once by TestRoom with Player, the configured
RunSessionHost/Runtime, and the current enemy list. Dynamic visuals copy the
cast-time element from `CastSnapshot`; they never read live `CurrentElement`
during playback.

## Catalog state

The six obtainable skills point to their accepted task-17 icons. Fury, Laser,
Reclaim, Burning and Unending point to the scenes above. Fury and Laser retain
their task-15 `runtime_delivery_scene` values. Element Bolt deliberately keeps
`presentation_scene` empty so there is no second projectile runtime. The fixed
basic attack `element_slash` keeps both icon and presentation empty.

This is ready for task 12 to consume through the Catalog without any task-12
document, HUD, layout or feedback changes.

## Verification

- Task 18 focused: `9 tests / 124 assertions`.
- Task 15 focused: `26 tests / 163 assertions`.
- Task 16 focused: `11 tests / 209 assertions`.
- Full headless set: `17/17` runners, `211 tests / 1573 assertions`.
- Godot 4.7.1 headless editor scan: exit `0`, no task-18 script error or warning.
- Godot 4.7.1 main-scene smoke: `180` frames, exit `0`.
- Connected editor runtime: game log contains only the helper registration.
  Editor warnings are the pre-existing combat/growth baseline and do not point
  at task-18 files.

## 1152×648 runtime captures

- `fury_192_runtime.png`: maximum authoritative radius, locked water tint.
- `laser_fire_tick_runtime.png`: five-segment 320×24 piercing fire Beam and an
  authoritative Tick flash on the enemy.
- `reclaim_water_runtime.png`: committed water Reclaim with three particles
  travelling from enemy to player.
- `passives_enemy_attached_runtime.png`: registered Burning and Unending loops
  and their committed trigger accents attached to the enemy.

The captures are actual TestRoom frames. They do not modify HUD behavior,
collision, targeting, damage, layers, energy, cooldown, Channel cadence, or
movement.

## Review note

The presentation-only Reclaim decorator reads the already-frozen target plans
from the concrete task-15 transaction because the frozen combat contract has no
public presentation-target accessor. It never queries targets, validates
energy, consumes layers, or changes commit/publish ordering itself. This is the
only deliberate coupling to a concrete task-15 implementation and should be
rechecked if that transaction representation is replaced later.

