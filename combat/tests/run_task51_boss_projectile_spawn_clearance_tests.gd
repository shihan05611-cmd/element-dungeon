extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PROJECTILE_RADIUS := 13.0
const PROJECTILE_VISIBLE_BOTTOM := 15.04
## Task 61 retires the single shared boss_arc_projectile_profile.tres in
## favor of one EnemyProjectileProfile per Boss form; the real room's Boss
## now starts in the "ember" form, whose profile fires at 320 (not the old
## placeholder's 255) with a 62px spawn offset (not 58px). Collision radius,
## masks, and ground-clearance geometry are unchanged.
const PROJECTILE_SPEED := 320.0
const PROJECTILE_SPAWN_OFFSET := 62.0
const GROUND_SUPPORT_TOP := 692.0

var _harness := TestHarness.new()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_async_test("main_ground_has_no_hidden_dais", _test_main_ground_has_no_hidden_dais)
	await _run_async_test("main_ground_left_and_right_clearance", _test_main_ground_left_and_right_clearance)
	_finish()


func _test_main_ground_has_no_hidden_dais() -> void:
	var context := await _create_boss_context()
	var room := context[&"room"] as RunRoomInstance
	var boss := context[&"boss"] as CombatEnemy
	_expect(room.get_node_or_null("BossDais") == null, "BossDais is removed from the formal Boss room")
	_expect_eq(_one_way_shape_count(room), 0, "formal Boss room contains zero hidden one-way platforms")
	_expect(boss.is_on_floor(), "Boss is settled on the main-ground physics support")
	_expect(absf(boss.global_position.y - 660.0) <= 0.25, "Boss settles at the formal main-ground root Y=660 (got %.3f)" % boss.global_position.y)
	await _destroy_context(context)


func _test_main_ground_left_and_right_clearance() -> void:
	for direction_x: float in [-1.0, 1.0]:
		var context := await _create_boss_context()
		var boss := context[&"boss"] as CombatEnemy
		_expect(boss.is_on_floor(), "Boss is settled on the only main-ground physics support")
		_expect(absf(boss.global_position.y - 660.0) <= 0.25, "Boss remains at the formal main-ground root Y=660")
		await _verify_spawn(context, direction_x, GROUND_SUPPORT_TOP, "ground")
		await _destroy_context(context)


func _create_boss_context() -> Dictionary:
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
	# Task 61's real room Boss starts in the "ember" form, whose profile
	# fires a 3-way spread (§3.7 "三连火弹散射"). This clearance test is
	# about single-shot spawn/aim/ground-clearance geometry, not spread fan
	# behavior (covered independently by task59's spread_count test and
	# task61's own ranged-telegraph test), so it pins a single-shot copy of
	# the same profile instead of asserting against a fan of 3 directions.
	var single_shot_profile: EnemyProjectileProfile = boss.ranged_projectile_profile.duplicate()
	single_shot_profile.spread_count = 1
	single_shot_profile.spread_angle_degrees = 0.0
	boss.ranged_projectile_profile = single_shot_profile

	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = Vector2(500.0, 660.0)
	world.add_child(player)
	boss.player = player
	boss.ai_enabled = false
	for _frame: int in 12:
		await physics_frame

	return {
		&"world": world,
		&"room": room,
		&"boss": boss,
		&"player": player,
	}


func _verify_spawn(context: Dictionary, direction_x: float, support_top: float, support_name: String) -> void:
	var world := context[&"world"] as Node2D
	var boss := context[&"boss"] as CombatEnemy
	var player := context[&"player"] as PlayerCharacter
	player.global_position = Vector2(boss.global_position.x + direction_x * 240.0, 660.0)
	await physics_frame

	var created: Array[Node] = []
	boss.delivery_created.connect(func(delivery: Node) -> void: created.append(delivery), CONNECT_ONE_SHOT)
	var fired_before := boss.boss_projectiles_fired
	_fire_immediate_shot(boss)
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
	_expect(is_equal_approx(projectile.speed, PROJECTILE_SPEED), "%s %s shot keeps speed 320 (Task 61 ember-form profile)" % [support_name, _direction_name(direction_x)])
	_expect(is_equal_approx(projectile.direction.x, direction_x) and is_zero_approx(projectile.direction.y), "%s %s shot preserves horizontal direction" % [support_name, _direction_name(direction_x)])
	_expect(absf(projectile.global_position.x - (boss.global_position.x + direction_x * PROJECTILE_SPAWN_OFFSET)) <= 0.01, "%s %s shot keeps horizontal spawn offset 62 (Task 61 ember-form profile)" % [support_name, _direction_name(direction_x)])

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


## Task 61 retires scripts/enemy.gd's terminal_enemy-gated
## _spawn_boss_projectile() direct-call entry point (now owned entirely by
## BossTideEmber's own _physics_process()). Reproduces the same
## deterministic "fire now, no telegraph wait" behavior directly against the
## still-generic _resolve_accurate_direction()/_apply_facing()/
## _launch_ranged_projectile() methods shared with TidalSentry.
func _fire_immediate_shot(boss: CombatEnemy) -> void:
	var profile := boss.ranged_projectile_profile
	var direction: Vector2 = boss.call("_resolve_accurate_direction", profile, boss.player.global_position)
	boss.call("_apply_facing", direction)
	boss.call("_launch_ranged_projectile", profile, direction, &"boss_arc")


func _blocker_overlaps(projectile: ProjectileDelivery) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = projectile.projectile_shape
	query.transform = projectile.global_transform
	query.collision_mask = projectile.blocking_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = projectile.query_margin
	return projectile.get_world_2d().direct_space_state.intersect_shape(query, projectile.max_contact_results)


func _one_way_shape_count(node: Node) -> int:
	var count := 1 if node is CollisionShape2D and (node as CollisionShape2D).one_way_collision else 0
	for child: Node in node.get_children():
		count += _one_way_shape_count(child)
	return count


func _destroy_context(context: Dictionary) -> void:
	var world := context[&"world"] as Node2D
	if current_scene == world:
		current_scene = null
	world.queue_free()
	await process_frame


func _direction_name(direction_x: float) -> String:
	return "right" if direction_x > 0.0 else "left"


func _run_async_test(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _finish() -> void:
	quit(_harness.report("TASK 51 BOSS PROJECTILE SPAWN CLEARANCE TESTS"))
