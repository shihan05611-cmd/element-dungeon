extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

## Task 15 focused test entry point:
## Godot --headless --path <project> --script
## res://combat/tests/run_first_batch_delivery_tests.gd

const HURTBOX_LAYER: int = 8
const WALL_LAYER: int = 4

var _harness := TestHarness.new()
var _world: Node2D
var _next_cast_id: int = 15000


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	var packed_world := load("res://combat/tests/scenes/delivery_physics_test.tscn") as PackedScene
	if packed_world == null:
		printerr("TASK 15 FIRST BATCH TESTS FAILED: physics test scene unavailable")
		quit(1)
		return
	_world = packed_world.instantiate() as Node2D
	root.add_child(_world)
	await physics_frame

	await _run_test("rage_minimum_radius_and_payload", _test_rage_minimum_radius_and_payload)
	await _run_test("rage_midpoint_radius", _test_rage_midpoint_radius)
	await _run_test("rage_maximum_multi_target_and_reaction", _test_rage_maximum_multi_target_and_reaction)
	await _run_test("rage_wall_rule_is_explicit", _test_rage_wall_rule_is_explicit)
	await _run_test("rage_duplicate_hurtboxes_hit_once", _test_rage_duplicate_hurtboxes_hit_once)
	await _run_test("rage_snapshot_remains_locked", _test_rage_snapshot_remains_locked)

	await _run_test("beam_channel_thresholds_049_050_100", _test_beam_channel_thresholds)
	await _run_test("beam_large_delta_penetrates_all_targets", _test_beam_large_delta_penetrates_all_targets)
	await _run_test("beam_target_enter_and_exit", _test_beam_target_enter_and_exit)
	await _run_test("beam_per_tick_dedup_and_cross_tick_rehit", _test_beam_per_tick_dedup_and_cross_tick_rehit)
	await _run_test("beam_rejects_out_of_order_ticks", _test_beam_rejects_out_of_order_ticks)
	await _run_test("beam_release_cleans_runtime_state", _test_beam_release_cleans_runtime_state)
	await _run_test("beam_insufficient_energy_cleans_runtime_state", _test_beam_insufficient_energy_cleans_runtime_state)
	await _run_test("beam_death_cancel_cleans_runtime_state", _test_beam_death_cancel_cleans_runtime_state)
	await _run_test("beam_tree_exit_cleans_runtime_state", _test_beam_tree_exit_cleans_runtime_state)
	await _run_test("beam_reuse_resets_tick_and_targets", _test_beam_reuse_resets_tick_and_targets)

	await _run_test("reclaim_no_explicit_target", _test_reclaim_no_explicit_target)
	await _run_test("reclaim_no_matching_element", _test_reclaim_no_matching_element)
	await _run_test("reclaim_full_energy_is_atomic", _test_reclaim_full_energy_is_atomic)
	await _run_test("reclaim_single_target_locked_element_and_deltas", _test_reclaim_single_target_locked_element_and_deltas)
	await _run_test("reclaim_multi_target_commits_before_notifications", _test_reclaim_multi_target_commits_before_notifications)
	await _run_test("reclaim_mixed_elements_only_consume_matches", _test_reclaim_mixed_elements_only_consume_matches)
	await _run_test("reclaim_near_full_reports_clamped_restore", _test_reclaim_near_full_reports_clamped_restore)
	await _run_test("reclaim_invalid_target_rejects_whole_transaction", _test_reclaim_invalid_target_rejects_whole_transaction)
	await _run_test("reclaim_snapshot_mismatch_rejects_whole_transaction", _test_reclaim_snapshot_mismatch_rejects_whole_transaction)
	await _run_test("reclaim_energy_mismatch_rejects_whole_transaction", _test_reclaim_energy_mismatch_rejects_whole_transaction)

	quit(_harness.report("TASK 15 FIRST BATCH TESTS"))


func _run_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)
	await _reset_world()


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_harness.expect_eq(actual, expected, message)


func _expect_float(actual: float, expected: float, message: String) -> void:
	_harness.expect_float(actual, expected, message)


func _reset_world() -> void:
	for child: Node in _world.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
	await process_frame
	await physics_frame


func _cast(
		element_id: StringName = ElementIds.WATER,
		attack_multiplier: float = 1.0,
		team_id: StringName = &"player"
) -> CastSnapshot:
	_next_cast_id += 1
	return CastSnapshot.new(
		_next_cast_id,
		&"task_15_test",
		101,
		102,
		team_id,
		element_id,
		CombatStatSnapshot.new(attack_multiplier)
	)


func _make_target(
		position: Vector2,
		water: int = 0,
		fire: int = 0,
		hurtbox_size: Vector2 = Vector2(8.0, 20.0)
) -> Dictionary:
	var host := Node2D.new()
	host.position = position
	host.name = "Target"
	var receiver := CombatReceiver.new()
	receiver.target_team_id = &"enemy"
	var damage := DamageReceiver.new()
	damage.configure_runtime(1000, 1000)
	var carrier := ElementCarrier.new()
	carrier.set_amounts_silent(water, fire)
	receiver.add_child(damage)
	receiver.add_child(carrier)
	receiver.configure_components(carrier, damage)
	host.add_child(receiver)
	var hurtbox := _add_hurtbox(host, receiver, Vector2.ZERO, hurtbox_size)
	_world.add_child(host)
	return {
		"host": host,
		"receiver": receiver,
		"damage": damage,
		"carrier": carrier,
		"hurtbox": hurtbox,
	}


func _add_hurtbox(
		host: Node2D,
		receiver: CombatReceiver,
		local_position: Vector2,
		size: Vector2
) -> CombatHurtbox:
	var hurtbox := CombatHurtbox.new()
	hurtbox.position = local_position
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.configure_receiver(receiver)
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	hurtbox.add_child(collision_shape)
	host.add_child(hurtbox)
	return hurtbox


func _make_wall(position: Vector2, size: Vector2 = Vector2(2.0, 100.0)) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = WALL_LAYER
	wall.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)
	_world.add_child(wall)
	return wall


func _burst_snapshot(
		energy: int,
		maximum: int = 100,
		element_id: StringName = ElementIds.WATER,
		attack_multiplier: float = 1.0,
		impact_position: Vector2 = Vector2.ZERO
) -> AllEnergyBurstExecutionSnapshot:
	var cast_snapshot := _cast(element_id, attack_multiplier)
	var multiplier := float(energy) * 0.08
	var amount := mini(10, floori(float(energy) / 20.0))
	var radius_steps := floori(float(energy) / float(maximum) * 10.0)
	var payload := RuntimeAttackPayload.from_locked_stats(
		cast_snapshot.stat_snapshot,
		multiplier,
		element_id,
		amount,
		PackedStringArray(["elemental_fury", "burst"])
	)
	return AllEnergyBurstExecutionSnapshot.new(
		cast_snapshot,
		energy,
		maximum,
		SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT,
		payload,
		1.0 + float(radius_steps) * 0.10,
		impact_position
	)


func _submit_rage(
		snapshot: AllEnergyBurstExecutionSnapshot,
		base_radius: float,
		walls_block: bool = true,
		origin: Vector2 = Vector2.ZERO
) -> Dictionary:
	var delivery := ElementRageDelivery.new()
	delivery.queue_free_on_finish = false
	delivery.base_radius = base_radius
	delivery.hurtbox_collision_mask = HURTBOX_LAYER
	delivery.walls_block_targets = walls_block
	delivery.blocking_collision_mask = WALL_LAYER
	delivery.trigger_on_ready = false
	var report := {"radius": 0.0, "targets": -1}
	delivery.burst_submitted.connect(func(
			_report_origin: Vector2,
			radius: float,
			target_count: int
	) -> void:
		report.radius = radius
		report.targets = target_count
	)
	_expect(
		delivery.initialize_burst(
			snapshot,
			1,
			Transform2D(0.0, origin),
			Vector2.RIGHT
		),
		"rage initializes from accepted snapshot"
	)
	_world.add_child(delivery)
	await process_frame
	await physics_frame
	_expect(delivery.trigger_burst(), "rage submits its one logical window")
	report["delivery"] = delivery
	return report


func _test_rage_minimum_radius_and_payload() -> void:
	var inside := _make_target(Vector2(59.0, 0.0), 0, 0, Vector2(1.0, 1.0))
	var outside := _make_target(Vector2(62.0, 0.0), 0, 0, Vector2(1.0, 1.0))
	await physics_frame
	var snapshot := _burst_snapshot(20)
	_expect(snapshot != null, "20 energy creates burst snapshot")
	_expect_float(snapshot.payload.damage_multiplier, 1.6, "minimum payload is 160 percent")
	_expect_eq(snapshot.payload.element_amount, 1, "minimum payload has one layer")
	var report := await _submit_rage(snapshot, 50.0)
	_expect_float(report.radius, 60.0, "minimum effective radius is base times 1.2")
	_expect_eq(inside.damage.current_health, 984, "inside target receives locked 16 damage")
	_expect_eq(inside.carrier.get_amount(ElementIds.WATER), 1, "inside target receives one water layer")
	_expect_eq(outside.damage.current_health, 1000, "outside target is excluded")


func _test_rage_midpoint_radius() -> void:
	var inside := _make_target(Vector2(74.0, 0.0), 0, 0, Vector2(1.0, 1.0))
	var outside := _make_target(Vector2(77.0, 0.0), 0, 0, Vector2(1.0, 1.0))
	await physics_frame
	var snapshot := _burst_snapshot(50)
	_expect_float(snapshot.radius_scale, 1.5, "midpoint snapshot locks 1.5 radius scale")
	_expect_float(snapshot.payload.damage_multiplier, 4.0, "midpoint locks 400 percent")
	_expect_eq(snapshot.payload.element_amount, 2, "midpoint locks two layers")
	var report := await _submit_rage(snapshot, 50.0)
	_expect_float(report.radius, 75.0, "midpoint effective radius")
	_expect_eq(inside.damage.current_health, 960, "midpoint inside target is hit")
	_expect_eq(outside.damage.current_health, 1000, "midpoint outside target is not hit")


func _test_rage_maximum_multi_target_and_reaction() -> void:
	var first := _make_target(Vector2(30.0, -10.0))
	var reacting := _make_target(Vector2(70.0, 10.0), 0, 1)
	await physics_frame
	var snapshot := _burst_snapshot(100)
	_expect_float(snapshot.radius_scale, 2.0, "maximum snapshot locks double radius")
	_expect_float(snapshot.payload.damage_multiplier, 8.0, "maximum locks 800 percent")
	_expect_eq(snapshot.payload.element_amount, 5, "maximum locks five layers")
	var report := await _submit_rage(snapshot, 50.0)
	_expect_eq(report.targets, 2, "one burst reaches every legal target")
	_expect_eq(first.damage.current_health, 920, "first target takes 80 damage")
	_expect_eq(reacting.damage.current_health, 896, "existing reaction multiplier remains in CombatReceiver")
	_expect_eq(reacting.carrier.get_amount(ElementIds.FIRE), 0, "reaction consumes opposite layer")
	_expect_eq(reacting.carrier.get_amount(ElementIds.WATER), 4, "reaction attaches remaining locked layers")


func _test_rage_wall_rule_is_explicit() -> void:
	var blocked := _make_target(Vector2(40.0, -30.0))
	var unblocked := _make_target(Vector2(40.0, 30.0))
	_make_wall(Vector2(20.0, -30.0), Vector2(2.0, 30.0))
	_make_wall(Vector2(20.0, 30.0), Vector2(2.0, 30.0))
	await physics_frame
	await _submit_rage(
		_burst_snapshot(20, 100, ElementIds.WATER, 1.0, Vector2(0.0, -30.0)),
		50.0,
		true,
		Vector2(0.0, -30.0)
	)
	await _submit_rage(
		_burst_snapshot(20, 100, ElementIds.WATER, 1.0, Vector2(0.0, 30.0)),
		50.0,
		false,
		Vector2(0.0, 30.0)
	)
	_expect_eq(blocked.damage.current_health, 1000, "enabled wall blocking suppresses target")
	_expect_eq(unblocked.damage.current_health, 984, "disabled wall blocking intentionally passes target")


func _test_rage_duplicate_hurtboxes_hit_once() -> void:
	var target := _make_target(Vector2(30.0, 0.0))
	_add_hurtbox(target.host, target.receiver, Vector2(3.0, 0.0), Vector2(8.0, 20.0))
	var submissions := {"count": 0}
	target.receiver.hit_resolved.connect(func(_result: CombatResult) -> void:
		submissions.count += 1
	)
	await physics_frame
	var report := await _submit_rage(_burst_snapshot(20), 50.0)
	_expect_eq(report.targets, 1, "duplicate overlap records one receiver")
	_expect_eq(submissions.count, 1, "duplicate hurtboxes submit one CombatReceiver hit")
	_expect_eq(target.damage.current_health, 984, "duplicate overlap damages once")


func _test_rage_snapshot_remains_locked() -> void:
	var target := _make_target(Vector2(50.0, 0.0))
	var snapshot := _burst_snapshot(100, 100, ElementIds.WATER, 1.0)
	var later_energy := EnergyComponent.new()
	later_energy.configure_runtime(200, 1)
	var later_element := CurrentElementController.new()
	later_element.configure_runtime(ElementIds.FIRE, [ElementIds.WATER, ElementIds.FIRE])
	_world.add_child(later_energy)
	_world.add_child(later_element)
	await physics_frame
	await _submit_rage(snapshot, 50.0)
	_expect_eq(later_energy.current_energy, 1, "live energy mutation is unrelated to delivery")
	_expect_eq(later_element.current_element_id, ElementIds.FIRE, "live element changed after snapshot")
	_expect_eq(target.damage.current_health, 920, "damage remains locked to accepted attack and energy")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 5, "locked water is delivered")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 0, "later fire is never read")


func _channel_skill() -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_id = &"task_15_beam"
	skill.execution_definition = ChannelExecution.new()
	return skill


func _make_execution_rig(
		current_energy: int,
		maximum_energy: int = 100,
		element_id: StringName = ElementIds.WATER,
		origin: Vector2 = Vector2.ZERO,
		reclaim: bool = false
) -> Dictionary:
	var host := Node2D.new()
	host.position = origin
	var delivery_parent := Node2D.new()
	host.add_child(delivery_parent)
	var energy := EnergyComponent.new()
	energy.configure_runtime(maximum_energy, current_energy)
	energy.set_process(false)
	host.add_child(energy)
	var element := CurrentElementController.new()
	element.configure_runtime(element_id, [ElementIds.WATER, ElementIds.FIRE])
	host.add_child(element)
	var executor := SkillExecutor.new()
	executor.configure_dependencies(energy, element, delivery_parent)
	executor.configure_cast_identity(2001 + _next_cast_id, 3001 + _next_cast_id, &"player")
	executor.set_process(false)
	var port: RangeElementReclaimPort = null
	if reclaim:
		port = RangeElementReclaimPort.new(host, energy, HURTBOX_LAYER, 256)
		executor.set_execution_services(SkillExecutionServices.new(port))
	host.add_child(executor)
	_world.add_child(host)
	executor.set_process(false)
	energy.set_process(false)
	return {
		"host": host,
		"delivery_parent": delivery_parent,
		"energy": energy,
		"element": element,
		"executor": executor,
		"port": port,
	}


func _attach_beam(
		rig: Dictionary,
		result: CastAttemptResult,
		origin: Vector2 = Vector2.ZERO
) -> ElementBeamDelivery:
	var beam := ElementBeamDelivery.new()
	beam.queue_free_on_finish = false
	beam.beam_length = 160.0
	beam.beam_width = 20.0
	beam.hurtbox_collision_mask = HURTBOX_LAYER
	_expect(
		beam.initialize_channel(
			result.execution_snapshot as ChannelExecutionSnapshot,
			1,
			Transform2D(0.0, origin),
			Vector2.RIGHT
		),
		"beam initializes from accepted Channel snapshot"
	)
	_world.add_child(beam)
	rig.executor.execution_tick_generated.connect(func(tick: ChannelTickSnapshot) -> void:
		beam.submit_tick(tick)
	)
	rig.executor.execution_ended.connect(func(
			_snapshot: SkillExecutionSnapshot,
			_end: SkillExecutionEndResult
	) -> void:
		beam.close_hit_window()
	)
	await process_frame
	await physics_frame
	return beam


func _test_beam_channel_thresholds() -> void:
	var target := _make_target(Vector2(80.0, 0.0))
	var rig := _make_execution_rig(30)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(rig, result)
	rig.executor.advance(0.49)
	_expect_eq(target.damage.current_health, 1000, "0.49 seconds produces no hit")
	_expect_eq(beam.last_tick_index, 0, "delivery owns no independent timer")
	rig.executor.advance(0.01)
	_expect_eq(target.damage.current_health, 995, "0.50 seconds submits one 50 percent tick")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 1, "first tick attaches one locked layer")
	rig.executor.advance(0.50)
	_expect_eq(target.damage.current_health, 990, "1.00 total seconds submits exactly two ticks")
	_expect_eq(beam.last_tick_index, 2, "tick identity follows task 14 runtime")


func _test_beam_large_delta_penetrates_all_targets() -> void:
	var first := _make_target(Vector2(40.0, -4.0))
	var second := _make_target(Vector2(120.0, 4.0))
	var rig := _make_execution_rig(30)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(rig, result)
	rig.executor.advance(1.5)
	_expect_eq(first.damage.current_health, 985, "large delta submits three ordered ticks to first target")
	_expect_eq(second.damage.current_health, 985, "beam penetrates through first into second")
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 3, "first target receives three layer applications")
	_expect_eq(second.carrier.get_amount(ElementIds.WATER), 3, "second target receives three layer applications")
	_expect_eq(beam.last_tick_index, 3, "large delta does not merge or drop ticks")


func _test_beam_target_enter_and_exit() -> void:
	var target := _make_target(Vector2(80.0, 40.0))
	var rig := _make_execution_rig(30)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	await _attach_beam(rig, result)
	rig.executor.advance(0.5)
	_expect_eq(target.damage.current_health, 1000, "outside target is absent from first tick")
	target.host.position.y = 0.0
	await physics_frame
	rig.executor.advance(0.5)
	_expect_eq(target.damage.current_health, 995, "entering target is hit on next legal tick")
	target.host.position.y = 40.0
	await physics_frame
	rig.executor.advance(0.5)
	_expect_eq(target.damage.current_health, 995, "exiting target is absent from later tick")


func _test_beam_per_tick_dedup_and_cross_tick_rehit() -> void:
	var target := _make_target(Vector2(80.0, 0.0))
	_add_hurtbox(target.host, target.receiver, Vector2(4.0, 0.0), Vector2(8.0, 20.0))
	var hits := {"count": 0}
	target.receiver.hit_resolved.connect(func(_result: CombatResult) -> void:
		hits.count += 1
	)
	var rig := _make_execution_rig(20)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(rig, result)
	rig.executor.advance(0.5)
	_expect_eq(hits.count, 1, "duplicate hurtboxes hit once in one tick")
	_expect_eq(beam.get_recorded_target_count(1), 1, "only current tick receiver ledger is retained")
	rig.executor.advance(0.5)
	_expect_eq(hits.count, 2, "next tick may hit the same receiver again")
	_expect_eq(beam.get_recorded_target_count(1), 0, "previous tick ledger is cleared")
	_expect_eq(beam.get_recorded_target_count(2), 1, "current tick ledger is present")


func _test_beam_rejects_out_of_order_ticks() -> void:
	var target := _make_target(Vector2(80.0, 0.0))
	var definition := ChannelExecution.new()
	var skill := _channel_skill()
	var snapshot := definition.prepare(
		SkillExecutionContext.new(
			skill,
			_cast(),
			DeliverySpawnSnapshot.new(),
			20,
			100
		),
		null
	).snapshot as ChannelExecutionSnapshot
	var beam := ElementBeamDelivery.new()
	beam.queue_free_on_finish = false
	beam.beam_length = 160.0
	beam.beam_width = 20.0
	beam.hurtbox_collision_mask = HURTBOX_LAYER
	_expect(
		beam.initialize_channel(snapshot, 1, Transform2D.IDENTITY, Vector2.RIGHT),
		"direct beam initializes"
	)
	_world.add_child(beam)
	await physics_frame
	var second := ChannelTickSnapshot.new(snapshot, 2, 15, 5, snapshot.build_tick_payload())
	var first := ChannelTickSnapshot.new(snapshot, 1, 20, 5, snapshot.build_tick_payload())
	_expect(not beam.submit_tick(second), "out-of-order tick is rejected")
	_expect_eq(target.damage.current_health, 1000, "rejected order submits no hit")
	_expect(beam.submit_tick(first), "first ordered tick is accepted")
	_expect_eq(target.damage.current_health, 995, "accepted tick uses standard receiver path")


func _test_beam_release_cleans_runtime_state() -> void:
	var target := _make_target(Vector2(80.0, 0.0))
	var rig := _make_execution_rig(20)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(rig, result)
	rig.executor.advance(0.5)
	_expect(rig.executor.request_channel_release(result.cast_snapshot.cast_id), "release is accepted")
	_expect(beam.is_finished and beam.cleanup_complete, "release closes and cleans beam")
	_expect_eq(beam.last_tick_index, 0, "release clears tick counter")
	_expect(beam.payload == null and not beam.channel_active, "release clears locked runtime references")
	rig.executor.advance(2.0)
	_expect_eq(target.damage.current_health, 995, "release produces no trailing hit")


func _test_beam_insufficient_energy_cleans_runtime_state() -> void:
	var target := _make_target(Vector2(80.0, 0.0))
	var rig := _make_execution_rig(7)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(rig, result)
	rig.executor.advance(1.0)
	_expect_eq(target.damage.current_health, 995, "only affordable tick is submitted")
	_expect_eq(rig.energy.current_energy, 2, "insufficient boundary does not overspend")
	_expect(beam.is_finished and beam.cleanup_complete, "insufficient energy end cleans beam")
	_expect_eq(beam.last_tick_index, 0, "insufficient end clears tick identity")


func _test_beam_death_cancel_cleans_runtime_state() -> void:
	var rig := _make_execution_rig(20)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(rig, result)
	_expect(
		rig.executor.cancel_current_cast(&"death", result.cast_snapshot.cast_id),
		"death cancellation is accepted"
	)
	_expect(beam.is_finished and beam.cleanup_complete, "death cancellation cleans beam")
	_expect(beam.payload == null and not beam.channel_active, "death leaves no query state")


func _test_beam_tree_exit_cleans_runtime_state() -> void:
	var definition := ChannelExecution.new()
	var skill := _channel_skill()
	var snapshot := definition.prepare(
		SkillExecutionContext.new(
			skill,
			_cast(),
			DeliverySpawnSnapshot.new(),
			20,
			100
		),
		null
	).snapshot as ChannelExecutionSnapshot
	var beam := ElementBeamDelivery.new()
	beam.queue_free_on_finish = false
	beam.hurtbox_collision_mask = HURTBOX_LAYER
	_expect(
		beam.initialize_channel(snapshot, 1, Transform2D.IDENTITY, Vector2.RIGHT),
		"tree-exit beam initializes"
	)
	_world.add_child(beam)
	await process_frame
	_world.remove_child(beam)
	_expect(beam.is_finished and beam.cleanup_complete, "tree exit finishes and cleans")
	_expect_eq(beam.finish_reason, DeliveryBase.FINISH_TREE_EXITED, "tree exit has typed reason")
	_expect(beam.payload == null and not beam.channel_active, "tree exit clears references")
	beam.free()


func _test_beam_reuse_resets_tick_and_targets() -> void:
	var first_target := _make_target(Vector2(80.0, 0.0))
	var first_rig := _make_execution_rig(20)
	await physics_frame
	var first_result: CastAttemptResult = first_rig.executor._try_cast_configured(_channel_skill())
	var beam := await _attach_beam(first_rig, first_result)
	first_rig.executor.advance(0.5)
	first_rig.executor.request_channel_release(first_result.cast_snapshot.cast_id)
	_world.remove_child(beam)
	_expect(beam.prepare_for_reuse(), "clean detached beam enters new generation")
	var second_target := _make_target(Vector2(80.0, 100.0))
	var second_rig := _make_execution_rig(20, 100, ElementIds.FIRE, Vector2(0.0, 100.0))
	await physics_frame
	var second_result: CastAttemptResult = second_rig.executor._try_cast_configured(_channel_skill())
	_expect(
		beam.initialize_channel(
			second_result.execution_snapshot as ChannelExecutionSnapshot,
			2,
			Transform2D(0.0, Vector2(0.0, 100.0)),
			Vector2.RIGHT
		),
		"reused beam accepts fresh Channel snapshot"
	)
	_world.add_child(beam)
	second_rig.executor.execution_tick_generated.connect(func(tick: ChannelTickSnapshot) -> void:
		beam.submit_tick(tick)
	)
	await process_frame
	await physics_frame
	second_rig.executor.advance(0.5)
	_expect_eq(first_target.damage.current_health, 995, "old target receives no reused-generation hit")
	_expect_eq(second_target.damage.current_health, 995, "fresh target receives first reused tick")
	_expect_eq(second_target.carrier.get_amount(ElementIds.FIRE), 1, "reused payload uses fresh locked element")
	_expect_eq(beam.last_tick_index, 1, "reused tick counter restarts at one")


func _reclaim_skill() -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_id = &"task_15_reclaim"
	skill.cooldown = 5.0
	skill.execution_definition = ElementReclaimExecution.new()
	return skill


func _reclaim_request(rig: Dictionary) -> ElementReclaimRequest:
	return ElementReclaimRequest.new(
		_cast(rig.element.current_element_id),
		rig.energy.current_energy,
		rig.energy.maximum
	)


func _test_reclaim_no_explicit_target() -> void:
	var rig := _make_execution_rig(50, 100, ElementIds.WATER, Vector2.ZERO, true)
	var arbitrary_host := Node2D.new()
	arbitrary_host.position = Vector2(20.0, 0.0)
	var arbitrary_carrier := ElementCarrier.new()
	arbitrary_carrier.set_amounts_silent(3, 0)
	arbitrary_host.add_child(arbitrary_carrier)
	_world.add_child(arbitrary_host)
	await physics_frame
	var prepared: ElementReclaimPrepareResult = rig.port.prepare(_reclaim_request(rig))
	_expect(not prepared.accepted, "carrier without CombatHurtbox is not guessed")
	_expect_eq(prepared.reject_reason, CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "no target is typed")
	_expect_eq(prepared.detail, &"no_reclaim_targets", "no explicit target detail")
	_expect_eq(rig.energy.current_energy, 50, "failed query preserves energy")
	_expect_eq(arbitrary_carrier.get_amount(ElementIds.WATER), 3, "failed query preserves layers")


func _test_reclaim_no_matching_element() -> void:
	var target := _make_target(Vector2(30.0, 0.0), 0, 4)
	var rig := _make_execution_rig(50, 100, ElementIds.WATER, Vector2.ZERO, true)
	await physics_frame
	var prepared: ElementReclaimPrepareResult = rig.port.prepare(_reclaim_request(rig))
	_expect(not prepared.accepted, "nonmatching carrier rejects")
	_expect_eq(prepared.reject_reason, CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "no match is typed")
	_expect_eq(prepared.detail, &"no_matching_element", "no match detail is distinct")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 4, "failure preserves opposite layers")
	_expect_eq(rig.energy.current_energy, 50, "failure restores no energy")


func _test_reclaim_full_energy_is_atomic() -> void:
	var target := _make_target(Vector2(30.0, 0.0), 3, 2)
	var rig := _make_execution_rig(100, 100, ElementIds.WATER, Vector2.ZERO, true)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_reclaim_skill())
	_expect(not result.accepted, "full energy reclaim rejects")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.NO_BENEFIT, "full energy typed rejection")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "full energy consumes no layers")
	_expect_eq(rig.energy.current_energy, 100, "full energy remains unchanged")
	_expect(not rig.executor.is_skill_on_cooldown(&"task_15_reclaim"), "failure starts no cooldown")


func _test_reclaim_single_target_locked_element_and_deltas() -> void:
	var target := _make_target(Vector2(30.0, 0.0), 3, 2)
	var rig := _make_execution_rig(50, 100, ElementIds.WATER, Vector2.ZERO, true)
	var element_delta := {"water": 0, "fire": 0}
	var energy_delta := {"value": 0}
	target.carrier.elements_changed.connect(func(
			_current: ElementSnapshot,
			water_delta: int,
			fire_delta: int
	) -> void:
		element_delta.water = water_delta
		element_delta.fire = fire_delta
	)
	rig.energy.energy_changed.connect(func(_current: int, _maximum: int, delta: int) -> void:
		energy_delta.value = delta
	)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_reclaim_skill())
	var snapshot := result.execution_snapshot as ElementReclaimExecutionSnapshot
	_expect(result.accepted and snapshot != null, "single target reclaim accepts")
	_expect_eq(snapshot.matched_element_amount, 3, "snapshot reports consumed layers")
	_expect_eq(snapshot.theoretical_energy_restore, 15, "snapshot reports theoretical restore")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 0, "locked water is fully consumed")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 2, "unmatched fire is preserved")
	_expect_eq(rig.energy.current_energy, 65, "energy restores five per layer")
	_expect_eq(element_delta.water, -3, "water notification delta matches snapshots")
	_expect_eq(element_delta.fire, 0, "fire notification delta remains zero")
	_expect_eq(energy_delta.value, 15, "energy notification reports actual restore")
	_expect(rig.executor.is_skill_on_cooldown(&"task_15_reclaim"), "success starts cooldown")


func _test_reclaim_multi_target_commits_before_notifications() -> void:
	var first := _make_target(Vector2(50.0, 0.0), 2, 1)
	var second := _make_target(Vector2(20.0, 0.0), 4, 2)
	var rig := _make_execution_rig(40, 100, ElementIds.WATER, Vector2.ZERO, true)
	var publication_order: Array[int] = []
	var all_final_when_first_publishes := {"value": false}
	first.carrier.elements_changed.connect(func(
			_current: ElementSnapshot,
			_water_delta: int,
			_fire_delta: int
	) -> void:
		publication_order.append(first.receiver.get_instance_id())
		all_final_when_first_publishes.value = (
			second.carrier.get_amount(ElementIds.WATER) == 0
			and rig.energy.current_energy == 70
		)
	)
	second.carrier.elements_changed.connect(func(
			_current: ElementSnapshot,
			_water_delta: int,
			_fire_delta: int
	) -> void:
		publication_order.append(second.receiver.get_instance_id())
	)
	rig.energy.energy_changed.connect(func(_current: int, _maximum: int, _delta: int) -> void:
		publication_order.append(-1)
	)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_reclaim_skill())
	_expect(result.accepted, "multi-target reclaim accepts")
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 0, "first target commits")
	_expect_eq(second.carrier.get_amount(ElementIds.WATER), 0, "second target commits")
	_expect(all_final_when_first_publishes.value, "all carriers and energy are final before first notification")
	var receiver_order := [
		first.receiver.get_instance_id(),
		second.receiver.get_instance_id(),
	]
	receiver_order.sort()
	_expect_eq(publication_order[0], receiver_order[0], "carrier notifications use stable identity order")
	_expect_eq(publication_order[1], receiver_order[1], "second carrier follows stable identity")
	_expect_eq(publication_order[2], -1, "energy publishes after all carriers")


func _test_reclaim_mixed_elements_only_consume_matches() -> void:
	var mixed := _make_target(Vector2(20.0, -10.0), 2, 3)
	var fire_only := _make_target(Vector2(30.0, 0.0), 0, 4)
	var both := _make_target(Vector2(40.0, 10.0), 1, 1)
	var rig := _make_execution_rig(20, 100, ElementIds.WATER, Vector2.ZERO, true)
	await physics_frame
	var result: CastAttemptResult = rig.executor._try_cast_configured(_reclaim_skill())
	var snapshot := result.execution_snapshot as ElementReclaimExecutionSnapshot
	_expect(result.accepted, "mixed target set accepts")
	_expect_eq(snapshot.matched_element_amount, 3, "only water layers are counted")
	_expect_eq(mixed.carrier.get_amount(ElementIds.WATER), 0, "mixed target water consumed")
	_expect_eq(mixed.carrier.get_amount(ElementIds.FIRE), 3, "mixed target fire preserved")
	_expect_eq(fire_only.carrier.get_amount(ElementIds.FIRE), 4, "fire-only target remains unchanged")
	_expect_eq(both.carrier.get_amount(ElementIds.WATER), 0, "second matching target consumed")
	_expect_eq(both.carrier.get_amount(ElementIds.FIRE), 1, "second opposite element preserved")
	_expect_eq(rig.energy.current_energy, 35, "energy uses matching layer total only")


func _test_reclaim_near_full_reports_clamped_restore() -> void:
	var target := _make_target(Vector2(30.0, 0.0), 2, 0)
	var rig := _make_execution_rig(97, 100, ElementIds.WATER, Vector2.ZERO, true)
	var energy_delta := {"value": 0}
	rig.energy.energy_changed.connect(func(_current: int, _maximum: int, delta: int) -> void:
		energy_delta.value = delta
	)
	await physics_frame
	var prepared: ElementReclaimPrepareResult = rig.port.prepare(_reclaim_request(rig))
	var transaction := prepared.transaction as RangeElementReclaimTransaction
	_expect(prepared.accepted and transaction != null, "near-full transaction prepares")
	_expect_eq(transaction.matched_element_amount, 2, "near-full consumed amount report")
	_expect_eq(transaction.theoretical_energy_restore, 10, "near-full theoretical restore report")
	_expect(transaction.validation_error().is_empty(), "near-full transaction validates")
	transaction.commit_silent()
	transaction.publish_committed()
	_expect_eq(transaction.actual_energy_restore, 3, "actual restore reports maximum clamp")
	_expect_eq(rig.energy.current_energy, 100, "energy clamps to maximum")
	_expect_eq(energy_delta.value, 3, "notification reports actual clamped delta")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 0, "all layers consume despite energy clamp")


func _test_reclaim_invalid_target_rejects_whole_transaction() -> void:
	var first := _make_target(Vector2(20.0, 0.0), 2, 0)
	var invalidated := _make_target(Vector2(40.0, 0.0), 3, 0)
	var rig := _make_execution_rig(30, 100, ElementIds.WATER, Vector2.ZERO, true)
	await physics_frame
	var prepared: ElementReclaimPrepareResult = rig.port.prepare(_reclaim_request(rig))
	var transaction := prepared.transaction as RangeElementReclaimTransaction
	_expect(prepared.accepted and transaction != null, "transaction prepares before target invalidation")
	invalidated.receiver.accepting_hits = false
	_expect_eq(transaction.validation_error(), &"reclaim_target_unavailable", "invalid target rejects transaction")
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 2, "first target is not partially consumed")
	_expect_eq(invalidated.carrier.get_amount(ElementIds.WATER), 3, "invalid target remains unchanged")
	_expect_eq(rig.energy.current_energy, 30, "invalid transaction restores no energy")


func _test_reclaim_snapshot_mismatch_rejects_whole_transaction() -> void:
	var first := _make_target(Vector2(20.0, 0.0), 2, 0)
	var changed := _make_target(Vector2(40.0, 0.0), 3, 1)
	var rig := _make_execution_rig(30, 100, ElementIds.WATER, Vector2.ZERO, true)
	await physics_frame
	var prepared: ElementReclaimPrepareResult = rig.port.prepare(_reclaim_request(rig))
	var transaction := prepared.transaction as RangeElementReclaimTransaction
	_expect(prepared.accepted and transaction != null, "transaction prepares before snapshot change")
	changed.carrier.set_amounts_silent(4, 1)
	_expect_eq(
		transaction.validation_error(),
		&"reclaim_carrier_snapshot_changed",
		"snapshot mismatch rejects transaction"
	)
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 2, "unchanged first carrier is not consumed")
	_expect_eq(changed.carrier.get_amount(ElementIds.WATER), 4, "external changed state is not overwritten")
	_expect_eq(changed.carrier.get_amount(ElementIds.FIRE), 1, "other element remains intact")
	_expect_eq(rig.energy.current_energy, 30, "snapshot mismatch restores no energy")


func _test_reclaim_energy_mismatch_rejects_whole_transaction() -> void:
	var target := _make_target(Vector2(30.0, 0.0), 3, 2)
	var rig := _make_execution_rig(30, 100, ElementIds.WATER, Vector2.ZERO, true)
	await physics_frame
	var prepared: ElementReclaimPrepareResult = rig.port.prepare(_reclaim_request(rig))
	var transaction := prepared.transaction as RangeElementReclaimTransaction
	_expect(prepared.accepted and transaction != null, "transaction prepares before energy change")
	rig.energy.set_current(31)
	_expect_eq(
		transaction.validation_error(),
		&"reclaim_energy_snapshot_changed",
		"energy snapshot mismatch rejects transaction"
	)
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "energy mismatch consumes no layers")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 2, "energy mismatch preserves other element")
	_expect_eq(rig.energy.current_energy, 31, "transaction does not overwrite external energy change")
