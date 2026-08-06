# Task 17 stage 2 final asset manifest

Status: final asset package ready for integration review.

## Stable roots

| Skill | Icon | Stable VFX |
|---|---|---|
| Element Bolt | `assets/generated/vfx/element_bolt/icon.png` | Existing `projectile_water_no_jitter_spritesheet.png`, `projectile_fire_no_jitter_spritesheet.png` |
| Elemental Fury | `assets/generated/vfx/elemental_fury/icon.png` | `burst_core.png` |
| Elemental Laser | `assets/generated/vfx/elemental_laser/icon.png` | `beam_segment_{water,fire}.png`, matching masks, `beam_tick_{water,fire}.png`, matching masks |
| Element Reclaim | `assets/generated/vfx/element_reclaim/icon.png` | `reclaim_particle_{water,fire}.png`, `reclaim_extract_neutral.png`, `reclaim_arrival_neutral.png` |
| Burning | `assets/generated/vfx/burning/icon.png` | `burning_enemy_loop.png`, `burning_tick.png` |
| Unending | `assets/generated/vfx/unending/icon.png` | `unending_enemy_loop.png`, `unending_trigger.png` |

Each skill directory contains stable `prompt.md` and `manifest.md`.

## Frozen visual contracts

- Fury: base radius 96, maximum scale 2.0; one presentation animation, one logical hit window.
- Laser: 320×24, piercing; a visual pulse may occur on every authoritative 0.5 s Tick.
- Reclaim: query radius 160; particles originate at every successfully consumed enemy and arrive at the player; no success VFX for failed transactions.
- Burning: enemy-attached only when Burning is owned/equipped and the target has fire layers; no layer consumption implication.
- Unending: enemy-attached only when Unending is owned/equipped and the target has water layers; no layer consumption implication.
- Water/fire differ by both silhouette and color.

## QA evidence

- `docs/vfx/qa/stage2_qa_report.md`
- `docs/vfx/qa/stage2_qa_stats.json`
- `docs/vfx/qa/stage2_icons_scale_qa.png`
- `docs/vfx/qa/stage2_testroom_particles_qa.png`
- `docs/vfx/qa/stage2_range_overlay_qa.png`
- `docs/vfx/qa/stage2_final_overview.png`
- `docs/vfx/qa/testroom_runtime_base.png`

Automated result: 25 final PNG files checked, 4/4 laser color/mask pairs exactly aligned, 0 failures.

## Integration boundary

Task 17 did not modify Catalog, SkillDefinition, combat, growth, Player, Enemy, Host, HUD, Delivery, collision, or existing scene wiring. A later integration pass may point formal presentation fields at these stable assets using each skill's manifest parameters.

## Task 32 formal stat-passive icon additions

| Skill | Icon | World VFX |
|---|---|---|
| Passive Vitality / 坚韧体魄 | `assets/generated/vfx/passive_vitality/icon.png` | None; permanent `+20` maximum-health projection, `presentation_scene = null` |
| Passive Energy / 元素储备 | `assets/generated/vfx/passive_energy/icon.png` | None; permanent `+10` maximum-SP projection, `presentation_scene = null` |

Both Task32 icons are 256×256 RGBA alpha assets generated with the built-in `image_gen` workflow, removed from a flat chroma-key background with the official imagegen helper, and checked at original size plus 64×64 and 32×32. Their exact prompts, source hashes, final hashes, alpha statistics and usage boundaries are recorded in each skill directory's `prompt.md` and `manifest.md`. Task32 adds no animation sheet, particle, presentation scene, runtime delivery, world trigger or VFX script.
