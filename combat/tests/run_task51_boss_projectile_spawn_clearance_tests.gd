extends SceneTree

const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PROJECTILE_RADIUS := 13.0
const PROJECTILE_VISIBLE_BOTTOM := 15.04
const PROJECTILE_SPEED := 255.0
const DAIS_SUPPORT_TOP := 452.0
const GROUND_SUPPORT_TOP := 540.0

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_async_test("dais_left_and_right_clearance", _test_dais_left_and_right_clearance)
	await _run_async_test("walked_ground_left_and_right_clearance", _test_walked_ground_left_and_right_clearance)
	_finish()


func _test_dais_left_and_right_clearance() -> void:
	for direction_x: float in [-1.0, 1.0]:
		var context := await _create_boss_context(false)
		var boss := context[&"boss"] as CombatEnemy
		_expect(boss.is_on_floor(), "dais boss is settled on a physics support")
		_expect(is_equal_approx(boss.global_position.y, 420.0), "dais boss retains the formal root Y=420")
		await _verify_spawn(context, direction_x, DAIS_SUPPORT_TOP, "dais")
		await _destroy_context(context)


func _test_walked_ground_left_and_right_clearance() -> void:
	for direction_x: float in [-1.0, 1.0]:
		var context := await _create_boss_context(true)
		var boss := context[&"boss"] as CombatEnemy
		_expect(bool(context[&"walked_off_dais"]), "boss reaches main ground through real AI physics movement")
		_expect(boss.is_on_floor(), "walked boss is settled on the main-ground physics support")
		_expect(absf(boss.global_position.y - 508.0) <= 0.25, "walked boss settles at the formal main-ground root Y=508 (got %.3f)" % boss.global_position.y)
		_expect(boss.global_position.x < 690.0, "walked boss exits the dais footprint before the ground shot")
		await _verify_spawn(context, direction_x, GROUND_SUPPORT_TOP, "ground")
		await _destroy_context(context)


func _create_boss_context(walk_to_ground: bool) -> Dictionary:
	var world := Node2D.new()
	world.name = "Task51World"
	root.add_child(world)
	current_scene = world

	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	_expect(room != null and room.configure(BOSS_ROOM), "formal Boss room configures")
	room.activate()
	var boss := room.enemies[0] as CombatEnemy
	boss.set("_boss_projectile_cooldown", 9999.0)

	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = Vector2(500.0, 508.0)
	world.add_child(player)
	boss.player = player
	var walked_off_dais := false
	if walk_to_ground:
		boss.ai_enabled = true
		boss.patrol_target_x = 500.0
		for _frame: int in 360:
			await physics_frame
			if boss.is_on_floor() and boss.global_position.y > 500.0 and boss.global_position.x < 690.0:
				walked_off_dais = true
				break
		boss.ai_enabled = false
		boss.velocity = Vector2.ZERO
		await physics_frame
	else:
		boss.ai_enabled = false
		for _frame: int in 4:
			await physics_frame

	return {
		&"world": world,
		&"room": room,
		&"boss": boss,
		&"player": player,
		&"walked_off_dais": walked_off_dais,
	}


func _verify_spawn(context: Dictionary, direction_x: float, support_top: float, support_name: String) -> void:
	var world := context[&"world"] as Node2D
	var boss := context[&"boss"] as CombatEnemy
	var player := context[&"player"] as PlayerCharacter
	player.global_position = Vector2(boss.global_position.x + direction_x * 240.0, 508.0)
	await physics_frame

	var created: Array[Node] = []
	boss.delivery_created.connect(func(delivery: Node) -> void: created.append(delivery), CONNECT_ONE_SHOT)
	var fired_before := boss.boss_projectiles_fired
	boss.call("_spawn_boss_projectile")
	_expect_eq(created.size(), 1, "%s %s shot creates exactly one delivery" % [support_name, _direction_name(direction_x)])
	_expect_eq(boss.boss_projectiles_fired, fired_before + 1, "%s %s shot increments the counter once" % [support_name, _direction_name(direction_x)])
	if created.is_empty():
		return
	var projectile := created[0] as ProjectileDelivery
	projectile.queue_free_on_finish = false
	var shape := projectile.projectile_shape as CircleShape2D
	_expect(shape != null and is_equal_approx(shape.radius, PROJECTILE_RADIUS), "%s %s shot keeps radius 13" % [support_name, _direction_name(direction_x)])
	_expect_eq(projectile.blocking_collision_mask, 4, "%s %s shot keeps blocker mask 4" % [support_name, _direction_name(direction_x)])
	_expect_eq(projectile.hurtbox_collision_mask, 16, "%s %s shot keeps hurtbox mask 16" % [support_name, _direction_name(direction_x)])
	_expect(is_equal_approx(projectile.speed, PROJECTILE_SPEED), "%s %s shot keeps speed 255" % [support_name, _direction_name(direction_x)])
	_expect(is_equal_approx(projectile.direction.x, direction_x) and is_zero_approx(projectile.direction.y), "%s %s shot preserves horizontal direction" % [support_name, _direction_name(direction_x)])
	_expect(absf(projectile.global_position.x - (boss.global_position.x + direction_x * 58.0)) <= 0.01, "%s %s shot keeps horizontal spawn offset 58" % [support_name, _direction_name(direction_x)])

	var center_before := projectile.global_position
	var blocker_hits := _blocker_overlaps(projectile)
	_expect_eq(blocker_hits.size(), 0, "%s %s shot starts with zero layer-4 overlaps" % [support_name, _direction_name(direction_x)])
	_expect(center_before.y + PROJECTILE_RADIUS < support_top, "%s %s authority circle clears support top" % [support_name, _direction_name(direction_x)])
	_expect(center_before.y + PROJECTILE_VISIBLE_BOTTOM < support_top, "%s %s visible alpha bottom clears support top" % [support_name, _direction_name(direction_x)])

	var events := {&"blocked_count": 0, &"finish_count": 0, &"finish_reason": StringName()}
	projectile.blocker_contact.connect(func(_position: Vector2) -> void: events[&"blocked_count"] += 1)
	projectile.delivery_finished.connect(func(reason: StringName) -> void:
		events[&"finish_count"] += 1
		events[&"finish_reason"] = reason
	)
	await physics_frame
	var center_after := projectile.global_position
	var expected_step := PROJECTILE_SPEED / float(Engine.physics_ticks_per_second)
	_expect(is_instance_valid(projectile) and not projectile.is_finished, "%s %s shot survives its first physics frame" % [support_name, _direction_name(direction_x)])
	_expect_eq(events[&"blocked_count"], 0, "%s %s shot has no first-frame blocker contact" % [support_name, _direction_name(direction_x)])
	_expect(absf((center_after.x - center_before.x) - direction_x * expected_step) <= 0.08, "%s %s shot moves by speed * physics delta" % [support_name, _direction_name(direction_x)])
	_expect(absf(center_after.y - center_before.y) <= 0.001, "%s %s shot has no Y drift" % [support_name, _direction_name(direction_x)])
	_expect(projectile.distance_travelled > 0.0, "%s %s shot records positive first-frame distance" % [support_name, _direction_name(direction_x)])

	for _frame: int in 360:
		if projectile.is_finished:
			break
		await physics_frame
	_expect(projectile.is_finished, "%s %s shot eventually reaches a player or wall" % [support_name, _direction_name(direction_x)])
	_expect(events[&"finish_reason"] == DeliveryBase.FINISH_HIT or events[&"finish_reason"] == DeliveryBase.FINISH_BLOCKED, "%s %s shot ends through the normal hit/block lifecycle" % [support_name, _direction_name(direction_x)])
	_expect_eq(events[&"finish_count"], 1, "%s %s shot finishes exactly once" % [support_name, _direction_name(direction_x)])
	projectile.free()


func _blocker_overlaps(projectile: ProjectileDelivery) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = projectile.projectile_shape
	query.transform = projectile.global_transform
	query.collision_mask = projectile.blocking_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = projectile.query_margin
	return projectile.get_world_2d().direct_space_state.intersect_shape(query, projectile.max_contact_results)


func _destroy_context(context: Dictionary) -> void:
	var world := context[&"world"] as Node2D
	if current_scene == world:
		current_scene = null
	world.queue_free()
	await process_frame


func _direction_name(direction_x: float) -> String:
	return "right" if direction_x > 0.0 else "left"


func _run_async_test(name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callable.call()
	if before == _failures.size():
		print("PASS task51_" + name)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 51 BOSS PROJECTILE SPAWN CLEARANCE TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 51 BOSS PROJECTILE SPAWN CLEARANCE TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
