extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

## Dependency-free headless Agent C test entry point:
## Godot --headless --path <project> --script res://combat/tests/run_delivery_tests.gd

const HURTBOX_LAYER: int = 1
const WALL_LAYER: int = 2

var _harness := TestHarness.new()
var _world: Node2D


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	var packed_world := load("res://combat/tests/scenes/delivery_physics_test.tscn") as PackedScene
	if packed_world == null:
		printerr("DELIVERY TESTS FAILED: test scene could not be loaded")
		quit(1)
		return
	_world = packed_world.instantiate() as Node2D
	root.add_child(_world)
	await physics_frame

	await _run_test("initialization_is_tree_safe_and_immutable", _test_initialization_is_tree_safe_and_immutable)
	await _run_test("melee_continuous_overlap_hits_once", _test_melee_continuous_overlap_hits_once)
	await _run_test("melee_hits_each_overlapping_target", _test_melee_hits_each_overlapping_target)
	await _run_test("melee_different_hit_indices_hit_again", _test_melee_different_hit_indices_hit_again)
	await _run_test("two_delivery_ids_are_independent", _test_two_delivery_ids_are_independent)
	await _run_test("two_casts_same_frame_are_independent", _test_two_casts_same_frame_are_independent)
	await _run_test("multiple_hurtboxes_share_receiver_dedup", _test_multiple_hurtboxes_share_receiver_dedup)
	await _run_test("melee_left_and_right_use_current_direction", _test_melee_left_and_right_use_current_direction)
	await _run_test("high_speed_projectile_hits_thin_hurtbox", _test_high_speed_projectile_hits_thin_hurtbox)
	await _run_test("wall_before_target_blocks", _test_wall_before_target_blocks)
	await _run_test("target_before_wall_hits_target", _test_target_before_wall_hits_target)
	await _run_test("wall_wins_equal_distance_tie", _test_wall_wins_equal_distance_tie)
	await _run_test("large_delta_sweep_is_reproducible", _test_large_delta_sweep_is_reproducible)
	await _run_test("projectile_keeps_cast_snapshot_after_source_changes", _test_projectile_keeps_cast_snapshot_after_source_changes)
	await _run_test("queued_receiver_is_ignored_safely", _test_queued_receiver_is_ignored_safely)
	await _run_test("finish_clears_delivery_cache", _test_finish_clears_delivery_cache)

	quit(_harness.report("DELIVERY TESTS"))


func _run_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)
	await _reset_world()


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_harness.expect_eq(actual, expected, message)


func _cast(cast_id: int, element_id: StringName = ElementIds.WATER) -> CastSnapshot:
	return CastSnapshot.new(
		cast_id,
		&"agent_c_test",
		101,
		102,
		&"player",
		element_id,
		CombatStatSnapshot.new()
	)


func _payload(element_id: StringName = ElementIds.WATER, damage: float = 10.0) -> RuntimeAttackPayload:
	return RuntimeAttackPayload.new(damage, damage, element_id, 1)


func _make_target(
		position: Vector2,
		hurtbox_size: Vector2 = Vector2(10.0, 24.0),
		with_carrier: bool = false
) -> Dictionary:
	var host := Node2D.new()
	host.position = position
	host.name = "Target"
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


func _make_wall(position: Vector2, size: Vector2 = Vector2(2.0, 80.0)) -> StaticBody2D:
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


func _make_melee(
		cast_id: int,
		delivery_id: int,
		origin: Vector2,
		facing: Vector2,
		hit_index: int = 0
) -> MeleeDelivery:
	var melee := MeleeDelivery.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36.0, 32.0)
	melee.hit_shape = shape
	melee.hurtbox_collision_mask = HURTBOX_LAYER
	melee.query_offset = Vector2(24.0, 0.0)
	melee.active_on_ready = true
	melee.initial_hit_index = hit_index
	_expect(
		melee.initialize_delivery(
			_cast(cast_id),
			_payload(),
			delivery_id,
			Transform2D(0.0, origin),
			facing
		),
		"melee initialization succeeds"
	)
	_world.add_child(melee)
	return melee


func _make_projectile(
		cast_id: int,
		delivery_id: int,
		origin: Vector2 = Vector2.ZERO,
		facing: Vector2 = Vector2.RIGHT,
		element_id: StringName = ElementIds.WATER
) -> ProjectileDelivery:
	var projectile := ProjectileDelivery.new()
	var shape := CircleShape2D.new()
	shape.radius = 2.0
	projectile.projectile_shape = shape
	projectile.speed = 12000.0
	projectile.max_distance = 500.0
	projectile.hurtbox_collision_mask = HURTBOX_LAYER
	projectile.blocking_collision_mask = WALL_LAYER
	projectile.wall_tie_distance = 0.1
	_expect(
		projectile.initialize_delivery(
			_cast(cast_id, element_id),
			_payload(element_id),
			delivery_id,
			Transform2D(0.0, origin),
			facing
		),
		"projectile initialization succeeds"
	)
	_world.add_child(projectile)
	return projectile


func _sync_physics(frames: int = 1) -> void:
	for _index in range(frames):
		await physics_frame


func _reset_world() -> void:
	for child in _world.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
	await process_frame
	await physics_frame


func _test_initialization_is_tree_safe_and_immutable() -> void:
	var melee := MeleeDelivery.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10.0, 10.0)
	melee.hit_shape = shape
	var first_cast := _cast(1)
	var first_payload := _payload()
	_expect(
		melee.initialize_delivery(
			first_cast,
			first_payload,
			7,
			Transform2D(0.0, Vector2(12.0, 34.0)),
			Vector2.RIGHT
		),
		"tree-free initialization is accepted"
	)
	_expect(
		not melee.initialize_delivery(
			_cast(2, ElementIds.FIRE),
			_payload(ElementIds.FIRE),
			8,
			Transform2D.IDENTITY,
			Vector2.LEFT
		),
		"second initialization is rejected"
	)
	_expect(melee.cast_snapshot == first_cast, "cast snapshot cannot be replaced")
	_expect(melee.payload == first_payload, "payload cannot be replaced")
	_expect_eq(melee.delivery_id, 7, "delivery id remains locked")
	_world.add_child(melee)
	await process_frame
	_expect(melee.global_position.is_equal_approx(Vector2(12.0, 34.0)), "cached world transform applies in ready")


func _test_melee_continuous_overlap_hits_once() -> void:
	var target := _make_target(Vector2(24.0, 0.0))
	await _sync_physics()
	var melee := _make_melee(10, 1, Vector2.ZERO, Vector2.RIGHT)
	await _sync_physics(4)
	_expect_eq(target.damage.current_health, 990, "continuous overlap damages once")
	_expect_eq(melee.get_recorded_target_count(0), 1, "one receiver is retained for active window")


func _test_melee_hits_each_overlapping_target() -> void:
	var first := _make_target(Vector2(24.0, -8.0))
	var second := _make_target(Vector2(28.0, 8.0))
	await _sync_physics()
	_make_melee(20, 1, Vector2.ZERO, Vector2.RIGHT)
	await _sync_physics(2)
	_expect_eq(first.damage.current_health, 990, "first target receives full hit")
	_expect_eq(second.damage.current_health, 990, "second target receives full hit")


func _test_melee_different_hit_indices_hit_again() -> void:
	var target := _make_target(Vector2(24.0, 0.0))
	await _sync_physics()
	var melee := _make_melee(30, 1, Vector2.ZERO, Vector2.RIGHT, 0)
	await _sync_physics(2)
	melee.close_hit_window()
	_expect(melee.open_hit_window(1), "second explicit hit index opens")
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 980, "different hit index is an independent hit")


func _test_two_delivery_ids_are_independent() -> void:
	var target := _make_target(Vector2(24.0, 0.0))
	await _sync_physics()
	_make_melee(40, 1, Vector2.ZERO, Vector2.RIGHT)
	_make_melee(40, 2, Vector2.ZERO, Vector2.RIGHT)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 980, "same cast deliveries can each hit")


func _test_two_casts_same_frame_are_independent() -> void:
	var target := _make_target(Vector2(24.0, 0.0))
	await _sync_physics()
	_make_melee(50, 1, Vector2.ZERO, Vector2.RIGHT)
	_make_melee(51, 1, Vector2.ZERO, Vector2.RIGHT)
	await _sync_physics()
	_expect_eq(target.damage.current_health, 980, "same-frame casts do not share dedup")


func _test_multiple_hurtboxes_share_receiver_dedup() -> void:
	var target := _make_target(Vector2(24.0, 0.0), Vector2(8.0, 20.0))
	_add_hurtbox(target.host, target.receiver, Vector2(6.0, 0.0), Vector2(8.0, 20.0))
	await _sync_physics()
	var submission_count := {"value": 0}
	var melee := _make_melee(60, 1, Vector2.ZERO, Vector2.RIGHT)
	melee.hit_submitted.connect(func(_result: CombatResult, _receiver: CombatReceiver, _hurtbox: CombatHurtbox) -> void:
		submission_count.value += 1
	)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 990, "shared receiver is damaged once")
	_expect_eq(submission_count.value, 1, "shared receiver receives one submission")
	_expect_eq(melee.get_recorded_target_count(0), 1, "dedup key is receiver instance id")


func _test_melee_left_and_right_use_current_direction() -> void:
	var right_target := _make_target(Vector2(24.0, -40.0))
	var left_target := _make_target(Vector2(-24.0, 40.0))
	await _sync_physics()
	_make_melee(70, 1, Vector2(0.0, -40.0), Vector2.RIGHT)
	_make_melee(71, 1, Vector2(0.0, 40.0), Vector2.LEFT)
	await _sync_physics(2)
	_expect_eq(right_target.damage.current_health, 990, "right-facing query uses right offset")
	_expect_eq(left_target.damage.current_health, 990, "left-facing query uses fresh left offset")


func _test_high_speed_projectile_hits_thin_hurtbox() -> void:
	var target := _make_target(Vector2(100.0, 0.0), Vector2(2.0, 30.0))
	var observed := {"result": null}
	target.receiver.hit_resolved.connect(func(result: CombatResult) -> void:
		observed.result = result
	)
	await _sync_physics()
	_make_projectile(80, 1)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 990, "sweep catches two-pixel hurtbox")
	var result: CombatResult = observed.result
	_expect(result != null and result.accepted, "projectile submits accepted hit")
	if result != null:
		_expect(result.hit_position.distance_to(Vector2(100.0, 0.0)) < 20.0, "result carries world hit position")
		_expect(result.hit_direction.is_equal_approx(Vector2.RIGHT), "result carries locked direction")


func _test_wall_before_target_blocks() -> void:
	var target := _make_target(Vector2(100.0, 0.0), Vector2(4.0, 30.0))
	_make_wall(Vector2(50.0, 0.0))
	await _sync_physics()
	var reason := {"value": &""}
	var projectile := _make_projectile(90, 1)
	projectile.delivery_finished.connect(func(value: StringName) -> void:
		reason.value = value
	)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 1000, "wall prevents through-wall hit")
	_expect_eq(reason.value, DeliveryBase.FINISH_BLOCKED, "projectile ends as blocked")


func _test_target_before_wall_hits_target() -> void:
	var target := _make_target(Vector2(50.0, 0.0), Vector2(4.0, 30.0))
	_make_wall(Vector2(100.0, 0.0))
	await _sync_physics()
	var reason := {"value": &""}
	var projectile := _make_projectile(100, 1)
	projectile.delivery_finished.connect(func(value: StringName) -> void:
		reason.value = value
	)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 990, "target in front of wall is hit")
	_expect_eq(reason.value, DeliveryBase.FINISH_HIT, "projectile ends on target hit")


func _test_wall_wins_equal_distance_tie() -> void:
	var target := _make_target(Vector2(60.0, 0.0), Vector2(4.0, 30.0))
	_make_wall(Vector2(60.0, 0.0), Vector2(4.0, 60.0))
	await _sync_physics()
	var reason := {"value": &""}
	var projectile := _make_projectile(110, 1)
	projectile.delivery_finished.connect(func(value: StringName) -> void:
		reason.value = value
	)
	await _sync_physics(2)
	_expect_eq(target.damage.current_health, 1000, "equal-distance wall suppresses target")
	_expect_eq(reason.value, DeliveryBase.FINISH_BLOCKED, "tie resolves to blocker")


func _test_large_delta_sweep_is_reproducible() -> void:
	var target := _make_target(Vector2(180.0, 0.0), Vector2(2.0, 30.0))
	await _sync_physics()
	var projectile := _make_projectile(120, 1)
	projectile.advance(0.25)
	_expect_eq(target.damage.current_health, 990, "quarter-second step still sweeps thin target")
	_expect(projectile.is_finished, "large step reaches one deterministic terminal result")


func _test_projectile_keeps_cast_snapshot_after_source_changes() -> void:
	var target := _make_target(Vector2(100.0, 0.0), Vector2(4.0, 30.0), true)
	var caster := Node.new()
	_world.add_child(caster)
	await _sync_physics()
	var projectile := _make_projectile(130, 1, Vector2.ZERO, Vector2.RIGHT, ElementIds.WATER)
	var locked_payload := projectile.payload
	var later_form := ElementIds.FIRE
	caster.queue_free()
	await _sync_physics(2)
	_expect_eq(later_form, ElementIds.FIRE, "test source changed to fire")
	_expect_eq(locked_payload.element_id, ElementIds.WATER, "in-flight payload remains water")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 1, "water attaches after caster is released")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 0, "later form is never queried")


func _test_queued_receiver_is_ignored_safely() -> void:
	var target := _make_target(Vector2(80.0, 0.0), Vector2(4.0, 30.0))
	target.receiver.queue_free()
	await process_frame
	await _sync_physics()
	var reason := {"value": &""}
	var projectile := _make_projectile(140, 1)
	projectile.delivery_finished.connect(func(value: StringName) -> void:
		reason.value = value
	)
	projectile.advance(1.0)
	_expect_eq(reason.value, DeliveryBase.FINISH_MAX_DISTANCE, "invalid receiver is skipped without late callback")


func _test_finish_clears_delivery_cache() -> void:
	var target := _make_target(Vector2(24.0, 0.0))
	await _sync_physics()
	var observed_count := {"value": -1}
	var melee := _make_melee(150, 1, Vector2.ZERO, Vector2.RIGHT)
	await _sync_physics(2)
	_expect_eq(melee.get_recorded_target_count(0), 1, "active window owns one cache entry")
	melee.delivery_finished.connect(func(_reason: StringName) -> void:
		observed_count.value = melee.get_recorded_target_count(0)
	)
	melee.cancel()
	_expect_eq(observed_count.value, 0, "cache is empty before finish notification")


