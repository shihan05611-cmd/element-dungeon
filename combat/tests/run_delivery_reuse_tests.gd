extends SceneTree

## Agent C round-two tests: locked element/skill presentation, delayed and
## multi-hit attacks, and safe optional pool reuse.

const HURTBOX_LAYER: int = 1
const WALL_LAYER: int = 2
const ELEMENT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/element_projectile.tscn")

var _failures: Array[String] = []
var _assertions: int = 0
var _tests: int = 0
var _world: Node2D


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	_world = Node2D.new()
	_world.name = "DeliveryReuseTestWorld"
	root.add_child(_world)
	await physics_frame

	await _run_test("reuse_requires_finished_detached_cleanup", _test_reuse_requires_finished_detached_cleanup)
	await _run_test("pooled_water_then_fire_has_no_runtime_leak", _test_pooled_water_then_fire_has_no_runtime_leak)
	await _run_test("melee_and_delayed_reset_initial_hit_index", _test_melee_and_delayed_reset_initial_hit_index)
	await _run_test("common_projectile_ignores_current_element_and_skill_mutation", _test_common_projectile_ignores_current_element_and_skill_mutation)
	await _run_test("exclusive_auto_switch_spawns_locked_fire_projectile", _test_exclusive_auto_switch_spawns_locked_fire_projectile)
	await _run_test("delayed_area_keeps_queued_water_snapshot", _test_delayed_area_keeps_queued_water_snapshot)
	await _run_test("multi_hit_indices_share_one_locked_snapshot", _test_multi_hit_indices_share_one_locked_snapshot)
	await _run_test("wall_and_max_distance_clean_runtime_references", _test_wall_and_max_distance_clean_runtime_references)
	await _run_test("tree_exit_cleans_and_allows_reset", _test_tree_exit_cleans_and_allows_reset)
	await _run_test("element_projectile_presentation_resets_between_uses", _test_element_projectile_presentation_resets_between_uses)

	if _failures.is_empty():
		print("DELIVERY REUSE TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr(
			"DELIVERY REUSE TESTS FAILED: %d failures / %d tests, %d assertions"
			% [_failures.size(), _tests, _assertions]
		)
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await test_callable.call()
	if _failures.size() == before:
		print("PASS " + test_name)
	else:
		for index in range(before, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]
	await _reset_world()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _cast(
		cast_id: int,
		element_id: StringName,
		skill_id: StringName = &"agent_c_round_two"
) -> CastSnapshot:
	return CastSnapshot.new(
		cast_id,
		skill_id,
		4001,
		4002,
		&"player",
		element_id,
		CombatStatSnapshot.new()
	)


func _payload(
		element_id: StringName,
		tags: PackedStringArray = PackedStringArray(),
		damage: float = 10.0
) -> RuntimeAttackPayload:
	return RuntimeAttackPayload.new(damage, damage, element_id, 1, tags)


func _make_target(
		position: Vector2,
		hurtbox_size: Vector2 = Vector2(6.0, 28.0),
		with_carrier: bool = false,
		collision_layer: int = HURTBOX_LAYER
) -> Dictionary:
	var host := Node2D.new()
	host.position = position
	var receiver := CombatReceiver.new()
	receiver.target_team_id = &"enemy"
	var damage := DamageReceiver.new()
	damage.configure_runtime(1000, 1000)
	receiver.add_child(damage)
	var carrier: ElementCarrier = null
	if with_carrier:
		carrier = ElementCarrier.new()
		receiver.add_child(carrier)
	receiver.configure_components(carrier, damage)
	host.add_child(receiver)
	var hurtbox := CombatHurtbox.new()
	hurtbox.collision_layer = collision_layer
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.configure_receiver(receiver)
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = hurtbox_size
	collision_shape.shape = rectangle
	hurtbox.add_child(collision_shape)
	host.add_child(hurtbox)
	_world.add_child(host)
	return {
		"host": host,
		"receiver": receiver,
		"damage": damage,
		"carrier": carrier,
		"hurtbox": hurtbox,
	}


func _make_wall(position: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = WALL_LAYER
	wall.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2.0, 60.0)
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)
	_world.add_child(wall)
	return wall


func _configured_projectile() -> ProjectileDelivery:
	var projectile := ProjectileDelivery.new()
	var shape := CircleShape2D.new()
	shape.radius = 2.0
	projectile.projectile_shape = shape
	projectile.speed = 12000.0
	projectile.max_distance = 500.0
	projectile.hurtbox_collision_mask = HURTBOX_LAYER
	projectile.blocking_collision_mask = WALL_LAYER
	projectile.queue_free_on_finish = false
	return projectile


func _configured_melee() -> MeleeDelivery:
	var melee := MeleeDelivery.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48.0, 36.0)
	melee.hit_shape = shape
	melee.hurtbox_collision_mask = HURTBOX_LAYER
	melee.query_offset = Vector2(24.0, 0.0)
	melee.active_on_ready = true
	melee.queue_free_on_finish = false
	return melee


func _sync_physics(frames: int = 1) -> void:
	for _index in range(frames):
		await physics_frame


func _reset_world() -> void:
	for child in _world.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
	await process_frame
	await physics_frame


func _test_reuse_requires_finished_detached_cleanup() -> void:
	var projectile := _configured_projectile()
	var water_cast := _cast(1001, ElementIds.WATER)
	var water_payload := _payload(ElementIds.WATER)
	_expect(
		projectile.initialize_delivery(
			water_cast,
			water_payload,
			1,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"first initialization succeeds"
	)
	_expect(not projectile.prepare_for_reuse(), "fresh unfinished object cannot reset")
	_expect(
		not projectile.initialize_delivery(
			_cast(1002, ElementIds.FIRE),
			_payload(ElementIds.FIRE),
			2,
			Transform2D.IDENTITY,
			Vector2.LEFT
		),
		"second initialize without reset is rejected"
	)
	_expect(projectile.cast_snapshot == water_cast, "rejected initialize preserves first cast")
	_world.add_child(projectile)
	projectile.cancel()
	_expect(projectile.is_finished and projectile.cleanup_complete, "cancel finishes and cleans")
	_expect(projectile.cast_snapshot == null and projectile.payload == null, "cancel releases locked references")
	_expect_eq(projectile.delivery_id, 0, "cancel clears delivery id")
	_expect_eq(projectile.direction, Vector2.ZERO, "cancel clears direction")
	_expect(not projectile.prepare_for_reuse(), "finished object must leave tree before reset")
	_world.remove_child(projectile)
	_expect(projectile.prepare_for_reuse(), "finished detached object can reset")
	_expect(not projectile.is_initialized and not projectile.is_finished, "reset returns fresh lifecycle state")
	_expect_eq(projectile.reuse_generation, 1, "successful reset advances generation")
	projectile.free()


func _test_pooled_water_then_fire_has_no_runtime_leak() -> void:
	var target := _make_target(Vector2(100.0, 0.0))
	var results: Array[CombatResult] = []
	target.receiver.hit_resolved.connect(func(result: CombatResult) -> void:
		results.append(result)
	)
	await _sync_physics()

	var projectile := _configured_projectile()
	projectile.hit_index = 3
	var first_signal_count := {"value": 0}
	projectile.hit_submitted.connect(func(
			_result: CombatResult,
			_receiver: CombatReceiver,
			_hurtbox: CombatHurtbox
	) -> void:
		first_signal_count.value += 1
	)
	_expect(
		projectile.initialize_delivery(
			_cast(1101, ElementIds.WATER, &"pooled_water_skill"),
			_payload(ElementIds.WATER, PackedStringArray(["water_trail"])),
			11,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"water use initializes"
	)
	_world.add_child(projectile)
	await _sync_physics(2)
	_expect(projectile.is_finished and projectile.cleanup_complete, "water hit finishes reusable object")
	_expect_eq(first_signal_count.value, 1, "first signal fires once")
	_expect_eq(projectile.get_recorded_target_count(3), 0, "first target cache is cleared")
	_expect_eq(projectile.distance_travelled, 0.0, "first distance is cleared")
	_expect_eq(projectile.hit_index, 0, "old runtime hit index is cleared")
	_expect(projectile.cast_snapshot == null and projectile.payload == null, "old water references are released")
	_world.remove_child(projectile)
	_expect(projectile.prepare_for_reuse(), "water use prepares for fire reuse")

	var second_signal_count := {"value": 0}
	projectile.hit_submitted.connect(func(
			_result: CombatResult,
			_receiver: CombatReceiver,
			_hurtbox: CombatHurtbox
	) -> void:
		second_signal_count.value += 1
	)
	_expect(
		projectile.initialize_delivery(
			_cast(1102, ElementIds.FIRE, &"pooled_fire_skill"),
			_payload(ElementIds.FIRE, PackedStringArray(["fire_trail"])),
			12,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"fire reuse initializes"
	)
	_world.add_child(projectile)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 980, "same target is hit once per generation")
	_expect_eq(results.size(), 2, "both generations submit")
	if results.size() == 2:
		_expect_eq(results[0].source_element_id, ElementIds.WATER, "first result is water")
		_expect_eq(results[0].skill_id, &"pooled_water_skill", "first result keeps water skill id")
		_expect_eq(results[0].hit_index, 3, "first result keeps configured index")
		_expect_eq(results[1].source_element_id, ElementIds.FIRE, "second result is fire")
		_expect_eq(results[1].skill_id, &"pooled_fire_skill", "second result does not inherit old skill id")
		_expect_eq(results[1].hit_index, 0, "second result does not inherit old index")
		_expect_eq(results[1].cast_id, 1102, "second result uses new cast")
		_expect_eq(results[1].delivery_id, 12, "second result uses new delivery id")
	_expect_eq(first_signal_count.value, 1, "old signal connection does not survive reset")
	_expect_eq(second_signal_count.value, 1, "new generation signal fires once")
	_world.remove_child(projectile)
	projectile.free()


func _test_melee_and_delayed_reset_initial_hit_index() -> void:
	var melee_target := _make_target(Vector2(24.0, 0.0))
	var melee_results: Array[CombatResult] = []
	melee_target.receiver.hit_resolved.connect(func(result: CombatResult) -> void:
		melee_results.append(result)
	)
	await _sync_physics()

	var melee := _configured_melee()
	melee.initial_hit_index = 5
	_expect(
		melee.initialize_delivery(
			_cast(1151, ElementIds.WATER),
			_payload(ElementIds.WATER),
			15,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"first pooled melee initializes"
	)
	_world.add_child(melee)
	await _sync_physics()
	melee.cancel()
	_expect_eq(melee.initial_hit_index, 0, "melee cleanup clears previous initial index")
	_world.remove_child(melee)
	_expect(melee.prepare_for_reuse(), "melee prepares after first generation")
	_expect(
		melee.initialize_delivery(
			_cast(1152, ElementIds.FIRE),
			_payload(ElementIds.FIRE),
			16,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"second pooled melee initializes"
	)
	_world.add_child(melee)
	await _sync_physics()
	_expect_eq(melee_results.size(), 2, "pooled melee hits in both generations")
	if melee_results.size() == 2:
		_expect_eq(melee_results[0].hit_index, 5, "first melee generation uses configured index")
		_expect_eq(melee_results[1].hit_index, 0, "second melee generation does not inherit index")
	melee.cancel()
	_world.remove_child(melee)
	melee.free()

	var delayed_target := _make_target(Vector2(0.0, 100.0))
	var delayed_results: Array[CombatResult] = []
	delayed_target.receiver.hit_resolved.connect(func(result: CombatResult) -> void:
		delayed_results.append(result)
	)
	await _sync_physics()
	var delayed := DelayedAreaDelivery.new()
	var delayed_shape := CircleShape2D.new()
	delayed_shape.radius = 30.0
	delayed.hit_shape = delayed_shape
	delayed.hurtbox_collision_mask = HURTBOX_LAYER
	delayed.trigger_delay = 0.0
	delayed.active_duration = 0.01
	delayed.initial_hit_index = 7
	delayed.queue_free_on_finish = false
	_expect(
		delayed.initialize_delivery(
			_cast(1153, ElementIds.WATER),
			_payload(ElementIds.WATER),
			17,
			Transform2D(0.0, Vector2(0.0, 100.0)),
			Vector2.RIGHT
		),
		"first delayed generation initializes"
	)
	_world.add_child(delayed)
	await _sync_physics(2)
	_expect(delayed.is_finished, "first delayed generation completes")
	_expect_eq(delayed.initial_hit_index, 0, "delayed cleanup clears inherited initial index")
	_world.remove_child(delayed)
	_expect(delayed.prepare_for_reuse(), "delayed area prepares after first generation")
	_expect(
		delayed.initialize_delivery(
			_cast(1154, ElementIds.FIRE),
			_payload(ElementIds.FIRE),
			18,
			Transform2D(0.0, Vector2(0.0, 100.0)),
			Vector2.RIGHT
		),
		"second delayed generation initializes"
	)
	_world.add_child(delayed)
	await _sync_physics(2)
	_expect_eq(delayed_results.size(), 2, "delayed area hits in both generations")
	if delayed_results.size() == 2:
		_expect_eq(delayed_results[0].hit_index, 7, "first delayed generation uses configured index")
		_expect_eq(delayed_results[1].hit_index, 0, "second delayed generation does not inherit index")
	_world.remove_child(delayed)
	delayed.free()


func _test_common_projectile_ignores_current_element_and_skill_mutation() -> void:
	var current := CurrentElementController.new()
	current.configure_runtime(ElementIds.WATER)
	_world.add_child(current)
	var target := _make_target(Vector2(100.0, 0.0))
	var observed := {"result": null}
	target.receiver.hit_resolved.connect(func(result: CombatResult) -> void:
		observed.result = result
	)
	await _sync_physics()

	var definition := AttackPayloadDefinition.new()
	definition.damage_multiplier = 1.0
	definition.element_mode = AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
	definition.element_amount = 1
	definition.presentation_tags = PackedStringArray(["locked_water_fx"])
	var skill := SkillDefinition.new()
	skill.skill_id = &"shared_skill_key"
	skill.element_policy = SkillDefinition.ElementPolicy.CURRENT_ELEMENT
	var execution := InstantDeliveryExecution.new()
	execution.delivery_scene = load("res://combat/delivery/projectile_delivery.tscn")
	execution.payload = definition
	skill.execution_definition = execution
	var cast := _cast(1201, current.current_element_id, skill.skill_id)
	var runtime := definition.build_runtime(cast)
	var projectile := _configured_projectile()
	_expect(
		projectile.initialize_delivery(cast, runtime, 21, Transform2D.IDENTITY, Vector2.RIGHT),
		"common water projectile initializes"
	)
	_world.add_child(projectile)
	current.request_element(ElementIds.FIRE)
	skill.skill_id = &"replacement_skill"
	definition.element_mode = AttackPayloadDefinition.ElementMode.FIXED_ELEMENT
	definition.fixed_element_id = ElementIds.FIRE
	definition.presentation_tags = PackedStringArray(["replacement_fx"])
	await _sync_physics(2)
	var result: CombatResult = observed.result
	_expect(result != null and result.accepted, "locked common projectile hits")
	if result != null:
		_expect_eq(result.source_element_id, ElementIds.WATER, "CurrentElement switch does not recolor hit")
		_expect_eq(result.skill_id, &"shared_skill_key", "skill replacement does not change skill id")
		_expect(result.presentation_tags.has("locked_water_fx"), "locked effect tag reaches result")
		_expect(not result.presentation_tags.has("replacement_fx"), "later Resource tag is ignored")
	_expect_eq(current.current_element_id, ElementIds.FIRE, "authoritative CurrentElement did switch")


func _test_exclusive_auto_switch_spawns_locked_fire_projectile() -> void:
	var delivery_parent := Node2D.new()
	_world.add_child(delivery_parent)
	var host := Node2D.new()
	var energy := EnergyComponent.new()
	energy.configure_runtime(100, 100)
	host.add_child(energy)
	var current := CurrentElementController.new()
	current.configure_runtime(ElementIds.WATER)
	host.add_child(current)
	var executor := SkillExecutor.new()
	executor.configure_dependencies(energy, current, delivery_parent)
	executor.configure_cast_identity(5001, 5002, &"player")
	executor.set_spawn_snapshot_provider(func(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
		return DeliverySpawnSnapshot.new(Transform2D(0.0, Vector2(0.0, 200.0)), Vector2.RIGHT)
	)
	host.add_child(executor)
	executor.set_process(false)
	_world.add_child(host)

	var definition := AttackPayloadDefinition.new()
	definition.damage_multiplier = 0.5
	definition.element_mode = AttackPayloadDefinition.ElementMode.FIXED_ELEMENT
	definition.fixed_element_id = ElementIds.FIRE
	definition.element_amount = 2
	definition.presentation_tags = PackedStringArray(["exclusive_fire_fx"])
	var skill := SkillDefinition.new()
	skill.skill_id = &"exclusive_fire_skill"
	skill.element_policy = SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
	skill.required_element_id = ElementIds.FIRE
	skill.startup_time = 0.01
	skill.recovery_time = 0.1
	var execution := InstantDeliveryExecution.new()
	execution.active_time = 0.2
	execution.delivery_scene = ELEMENT_PROJECTILE_SCENE
	execution.payload = definition
	skill.execution_definition = execution

	var observation := {"valid": false}
	executor.delivery_spawned.connect(func(
			cast_id: int,
			delivery_id: int,
			delivery: Node
	) -> void:
		var projectile := delivery as ElementProjectile
		observation.valid = (
			projectile != null
			and projectile.cast_snapshot.cast_id == cast_id
			and projectile.delivery_id == delivery_id
			and projectile.cast_snapshot.skill_id == &"exclusive_fire_skill"
			and projectile.payload.element_id == ElementIds.FIRE
			and projectile.locked_element_color == projectile.fire_color
			and projectile.locked_presentation_tags.has("exclusive_fire_fx")
			and current.current_element_id == ElementIds.FIRE
		)
	)
	await process_frame
	var attempt := executor._try_cast_configured(skill)
	_expect(attempt.accepted, "exclusive cast transaction succeeds")
	_expect_eq(current.current_element_id, ElementIds.FIRE, "exclusive cast auto-switches before spawn")
	executor.advance(0.02)
	_expect(observation.valid, "spawned projectile uses accepted exclusive fire snapshot")


func _test_delayed_area_keeps_queued_water_snapshot() -> void:
	var current := CurrentElementController.new()
	current.configure_runtime(ElementIds.WATER)
	_world.add_child(current)
	var first := _make_target(Vector2(-20.0, 0.0))
	var second := _make_target(Vector2(20.0, 0.0))
	var results: Array[CombatResult] = []
	first.receiver.hit_resolved.connect(func(result: CombatResult) -> void: results.append(result))
	second.receiver.hit_resolved.connect(func(result: CombatResult) -> void: results.append(result))
	await _sync_physics()

	var delayed := DelayedAreaDelivery.new()
	var shape := CircleShape2D.new()
	shape.radius = 48.0
	delayed.hit_shape = shape
	delayed.hurtbox_collision_mask = HURTBOX_LAYER
	delayed.trigger_delay = 0.05
	delayed.active_duration = 0.05
	delayed.queue_free_on_finish = false
	var cast := _cast(1301, current.current_element_id, &"delayed_water_area")
	_expect(
		delayed.initialize_delivery(
			cast,
			_payload(ElementIds.WATER, PackedStringArray(["delayed_water_fx"])),
			31,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"delayed water area initializes"
	)
	_world.add_child(delayed)
	current.request_element(ElementIds.FIRE)
	await _sync_physics(8)
	_expect_eq(results.size(), 2, "delayed AOE hits every target once")
	for result in results:
		_expect_eq(result.source_element_id, ElementIds.WATER, "delayed hit stays water")
		_expect_eq(result.cast_id, 1301, "delayed hit keeps queued cast")
		_expect_eq(result.hit_index, 0, "delayed hit keeps configured segment")
	_expect_eq(current.current_element_id, ElementIds.FIRE, "element changed while attack was queued")
	_expect(delayed.is_finished and delayed.payload == null, "delayed completion releases snapshot references")


func _test_multi_hit_indices_share_one_locked_snapshot() -> void:
	var current := CurrentElementController.new()
	current.configure_runtime(ElementIds.WATER)
	_world.add_child(current)
	var target := _make_target(Vector2(24.0, 0.0))
	var results: Array[CombatResult] = []
	target.receiver.hit_resolved.connect(func(result: CombatResult) -> void: results.append(result))
	await _sync_physics()

	var melee := _configured_melee()
	_expect(
		melee.initialize_delivery(
			_cast(1401, ElementIds.WATER, &"three_hit_water"),
			_payload(ElementIds.WATER),
			41,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"multi-hit melee initializes"
	)
	_world.add_child(melee)
	await _sync_physics()
	current.request_element(ElementIds.FIRE)
	for next_index in [1, 2]:
		melee.close_hit_window()
		_expect(melee.open_hit_window(next_index), "next explicit segment opens")
		await _sync_physics()
	_expect_eq(results.size(), 3, "three explicit indices each hit")
	for index in range(results.size()):
		_expect_eq(results[index].hit_index, index, "segment index is preserved")
		_expect_eq(results[index].source_element_id, ElementIds.WATER, "segment uses locked water payload")
		_expect_eq(results[index].cast_id, 1401, "segment uses one cast snapshot")
	_expect_eq(current.current_element_id, ElementIds.FIRE, "element switch does not change later segments")


func _test_wall_and_max_distance_clean_runtime_references() -> void:
	_make_wall(Vector2(50.0, 0.0))
	await _sync_physics()
	var blocked := _configured_projectile()
	_expect(
		blocked.initialize_delivery(
			_cast(1501, ElementIds.WATER),
			_payload(ElementIds.WATER),
			51,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"blocked projectile initializes"
	)
	_world.add_child(blocked)
	blocked.advance(0.1)
	_expect_eq(blocked.finish_reason, DeliveryBase.FINISH_BLOCKED, "wall path finishes blocked")
	_expect(blocked.cleanup_complete and blocked.payload == null, "wall path clears payload")

	var ranged_out := _configured_projectile()
	ranged_out.max_distance = 10.0
	_expect(
		ranged_out.initialize_delivery(
			_cast(1502, ElementIds.FIRE),
			_payload(ElementIds.FIRE),
			52,
			Transform2D(0.0, Vector2(0.0, 100.0)),
			Vector2.RIGHT
		),
		"range projectile initializes"
	)
	_world.add_child(ranged_out)
	ranged_out.advance(1.0)
	_expect_eq(ranged_out.finish_reason, DeliveryBase.FINISH_MAX_DISTANCE, "range path finishes at max")
	_expect(ranged_out.cleanup_complete and ranged_out.cast_snapshot == null, "range path clears cast")


func _test_tree_exit_cleans_and_allows_reset() -> void:
	var target := _make_target(Vector2(24.0, 0.0))
	await _sync_physics()
	var melee := _configured_melee()
	var reasons: Array[StringName] = []
	melee.delivery_finished.connect(func(reason: StringName) -> void: reasons.append(reason))
	_expect(
		melee.initialize_delivery(
			_cast(1601, ElementIds.WATER),
			_payload(ElementIds.WATER),
			61,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"tree-exit melee initializes"
	)
	_world.add_child(melee)
	await _sync_physics()
	_expect_eq(melee.get_recorded_target_count(0), 1, "active delivery owns target cache")
	_world.remove_child(melee)
	_expect(melee.is_finished and melee.cleanup_complete, "tree exit finalizes lifecycle")
	_expect_eq(melee.finish_reason, DeliveryBase.FINISH_TREE_EXITED, "tree exit has structured reason")
	_expect_eq(reasons, [DeliveryBase.FINISH_TREE_EXITED], "tree-exit notification emits once")
	_expect(melee.cast_snapshot == null and melee.payload == null, "tree exit releases references")
	_expect_eq(melee.get_recorded_target_count(0), 0, "tree exit clears target cache")
	_expect(melee.prepare_for_reuse(), "clean tree-exited delivery can reset")
	melee.free()


func _test_element_projectile_presentation_resets_between_uses() -> void:
	var projectile := ElementProjectile.new()
	var shape := CircleShape2D.new()
	shape.radius = 2.0
	projectile.projectile_shape = shape
	projectile.speed = 100.0
	projectile.max_distance = 100.0
	projectile.hurtbox_collision_mask = 0
	projectile.blocking_collision_mask = 0
	projectile.queue_free_on_finish = false
	_expect(
		projectile.initialize_delivery(
			_cast(1701, ElementIds.WATER),
			_payload(ElementIds.WATER, PackedStringArray(["water_glow", "splash"])),
			71,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"water presentation initializes"
	)
	_world.add_child(projectile)
	_expect_eq(projectile.locked_element_color, projectile.water_color, "water color comes from locked payload")
	_expect(projectile.locked_presentation_tags.has("water_glow"), "water effect tags are locked")
	projectile.cancel()
	_expect_eq(projectile.locked_element_color, Color.WHITE, "finish clears old color")
	_expect(projectile.locked_presentation_tags.is_empty(), "finish clears old effect tags")
	_world.remove_child(projectile)
	_expect(projectile.prepare_for_reuse(), "presentation projectile resets")
	_expect(
		projectile.initialize_delivery(
			_cast(1702, ElementIds.FIRE),
			_payload(ElementIds.FIRE, PackedStringArray(["ember"])),
			72,
			Transform2D.IDENTITY,
			Vector2.RIGHT
		),
		"fire presentation reuse initializes"
	)
	_world.add_child(projectile)
	_expect_eq(projectile.locked_element_color, projectile.fire_color, "fire reuse has new locked color")
	_expect_eq(projectile.locked_presentation_tags, PackedStringArray(["ember"]), "fire reuse has only new tags")
	_world.remove_child(projectile)
	projectile.free()



