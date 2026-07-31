# Task 15 first-batch delivery integration

This module implements geometry and target transactions only. It never reads
live energy, attack, or current element values.

## Production-ready scene paths

- Rage: `res://combat/delivery/element_rage_delivery.tscn`
- Beam: `res://combat/delivery/element_beam_delivery.tscn`

The checked-in scenes use the formal project layers:

- enemy hurtboxes: mask `8` (`EnemyHurtbox`)
- world blockers: mask `4` (`WorldBlocker`)

Task 16 may override the exported logical dimensions, but VFX scale must not
replace these query parameters.

## Element Rage

`ElementRageDelivery.initialize_burst()` accepts the already-locked
`AllEnergyBurstExecutionSnapshot`. Its logical radius is:

```text
effective radius = base_radius * snapshot.radius_scale
```

The default `base_radius` is `96`. Wall blocking is explicit:
`walls_block_targets = true` and `blocking_collision_mask = 4`. One trigger
submits exactly one `hit_index = 0` window to every legal enemy receiver and
then finishes.

```gdscript
var rage := preload(
    "res://combat/delivery/element_rage_delivery.tscn"
).instantiate() as ElementRageDelivery
if not rage.initialize_burst(
    execution_snapshot as AllEnergyBurstExecutionSnapshot,
    delivery_id,
    spawn_transform,
    facing_direction,
):
    rage.free()
    return
delivery_parent.add_child(rage)
```

Read-only VFX baseline: `burst_submitted(origin, radius, target_count)` fires
after all synchronous hit submissions and before delivery cleanup. The signal's
`radius` is the authoritative logical radius.

## Element Beam

`ElementBeamDelivery` has no timer. Initialize it from the accepted
`ChannelExecutionSnapshot`, add it to the tree on activation, and forward every
task-14 `ChannelTickSnapshot` in signal order:

```gdscript
beam.initialize_channel(
    channel_snapshot,
    delivery_id,
    spawn_transform,
    facing_direction,
)
delivery_parent.add_child(beam)

executor.execution_tick_generated.connect(beam.submit_tick)
executor.execution_ended.connect(func(
        _snapshot: SkillExecutionSnapshot,
        _end: SkillExecutionEndResult
) -> void:
    beam.close_hit_window()
)
```

The Beam requires consecutive `tick_index` values. Every tick clears the prior
tick's delivery ledger, queries the Beam node's current world position, and
passes that tick's exact locked payload through `HitRequest -> CombatReceiver`.
Therefore a target is hit at most once per tick and may be hit again on the next
tick. Movement/follow behavior belongs to the Host or parent transform; the
Delivery never writes character movement rules.

Default logical bounds are `beam_length = 320` and `beam_width = 24`.
Read-only VFX baseline: render from the Beam node's current world origin along
its locked direction, use these dimensions, pulse on
`tick_submitted(tick_index, target_count)`, and stop on `delivery_finished`.

Release, energy exhaustion, interruption, death, layer/tree exit must route the
execution end to `close_hit_window()`. That call finishes the Delivery and
clears its tick index, target ledger, query state, and locked references.

## Range reclaim port

Task 16 can install the concrete task-14 port without changing
`ElementReclaimExecution`:

```gdscript
var reclaim_port := RangeElementReclaimPort.new(
    player_node,
    energy_component,
    160.0,
    8,
    256,
)
executor.set_execution_services(SkillExecutionServices.new(reclaim_port))
```

The port queries only explicit `CombatHurtbox -> CombatReceiver ->
ElementCarrier` links. It builds complete before/after snapshots for every
matching carrier, validates stable identity and energy snapshots, silently
commits all carriers and the clamped energy restore, and only then publishes
carrier and energy notifications.

## Focused verification

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path <project> `
  --script res://combat/tests/run_first_batch_delivery_tests.gd
```

The runner covers Rage radius/walls/dedup/snapshot locking, Beam thresholds,
large delta, penetration, entry/exit, lifecycle and reuse, plus range-reclaim
success, clipping, mixed elements, notification order, invalid targets, and
whole-transaction rejection.
