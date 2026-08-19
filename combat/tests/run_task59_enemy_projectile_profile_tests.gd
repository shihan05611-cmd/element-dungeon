extends SceneTree

## Task 59: EnemyProjectileProfile data layer, arbitrary-direction aiming and
## the yellow "!" telegraph. Covers every branch required by
## docs/agent_tasks/pending/59_enemy_projectile_profile_aiming_and_telegraph.md §7.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/run/boss_arc_projectile.tscn")
const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const TestHarness := preload("res://combat/tests/test_harness.gd")

var _harness := TestHarness.new()
var _hit_seq: int = 5_900_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_test("validation_error_branches", _test_validation_error_branches)
	await _run_test("equivalence_horizontal_zero_telegraph", _test_equivalence_horizontal_zero_telegraph)
	await _run_test("diagonal_direction_and_angle_limit", _test_diagonal_direction_and_angle_limit)
	await _run_test("zero_vector_falls_back_to_facing", _test_zero_vector_falls_back_to_facing)
	await _run_test("diagonal_spawn_clears_world_blocker", _test_diagonal_spawn_clears_world_blocker)
	await _run_test("telegraph_timing_lock_and_stillness", _test_telegraph_timing_lock_and_stillness)
	await _run_test("death_during_telegraph_cancels", _test_death_during_telegraph_cancels)
	await _run_test("cancel_telegraph_on_hurt_both_branches", _test_cancel_telegraph_on_hurt_both_branches)
	await _run_test("spread_count_symmetric_independent", _test_spread_count_symmetric_independent)
	await _run_test("sprite_rotation_matches_direction", _test_sprite_rotation_matches_direction)
	_finish()


# ---------------------------------------------------------------------------
# 1. validation_error() branches
# ---------------------------------------------------------------------------
func _test_validation_error_branches() -> void:
	_expect_eq(_make_valid_profile().validation_error(), &"", "a fully valid profile has no error")

	var p := _make_valid_profile()
	p.projectile_scene = null
	_expect_eq(p.validation_error(), &"missing_projectile_scene", "missing projectile scene")

	p = _make_valid_profile()
	p.speed = 0.0
	_expect_eq(p.validation_error(), &"invalid_speed", "non-positive speed")

	p = _make_valid_profile()
	p.speed = NAN
	_expect_eq(p.validation_error(), &"invalid_speed", "NaN speed")

	p = _make_valid_profile()
	p.max_distance = 0.0
	_expect_eq(p.validation_error(), &"invalid_max_distance", "non-positive max distance")

	p = _make_valid_profile()
	p.damage = -1.0
	_expect_eq(p.validation_error(), &"invalid_damage", "negative damage")

	p = _make_valid_profile()
	p.element_id = &"lava"
	_expect_eq(p.validation_error(), &"invalid_element_id", "unknown element id")

	p = _make_valid_profile()
	p.element_amount = -1
	_expect_eq(p.validation_error(), &"invalid_element_amount", "negative element amount")

	p = _make_valid_profile()
	p.element_amount = 11
	_expect_eq(p.validation_error(), &"invalid_element_amount", "element amount above 10")

	p = _make_valid_profile()
	p.element_id = ElementIds.NONE
	p.element_amount = 3
	_expect_eq(p.validation_error(), &"none_element_has_amount", "none element carrying a nonzero amount")

	p = _make_valid_profile()
	p.hurtbox_collision_mask = -1
	_expect_eq(p.validation_error(), &"invalid_hurtbox_collision_mask", "negative hurtbox mask")

	p = _make_valid_profile()
	p.blocking_collision_mask = -1
	_expect_eq(p.validation_error(), &"invalid_blocking_collision_mask", "negative blocking mask")

	p = _make_valid_profile()
	p.telegraph_duration = -0.1
	_expect_eq(p.validation_error(), &"invalid_telegraph_duration", "negative telegraph duration")

	p = _make_valid_profile()
	p.aim_mode = 99 as EnemyProjectileProfile.AimMode
	_expect_eq(p.validation_error(), &"invalid_aim_mode", "out-of-enum aim mode")

	p = _make_valid_profile()
	p.aim_angle_limit_degrees = 0.0
	_expect_eq(p.validation_error(), &"invalid_aim_angle_limit", "zero aim angle limit")

	p = _make_valid_profile()
	p.aim_angle_limit_degrees = 91.0
	_expect_eq(p.validation_error(), &"invalid_aim_angle_limit", "aim angle limit above 90")

	p = _make_valid_profile()
	p.spread_count = 0
	_expect_eq(p.validation_error(), &"invalid_spread_count", "spread count below 1")

	p = _make_valid_profile()
	p.spread_count = 3
	p.spread_angle_degrees = -1.0
	_expect_eq(p.validation_error(), &"invalid_spread_angle", "negative spread angle with spread_count > 1")

	p = _make_valid_profile()
	p.spawn_offset_distance = -1.0
	_expect_eq(p.validation_error(), &"invalid_spawn_offset_distance", "negative spawn offset distance")

	p = _make_valid_profile()
	p.texture_forward_offset_degrees = NAN
	_expect_eq(p.validation_error(), &"invalid_texture_forward_offset", "NaN texture forward offset")

	p = _make_valid_profile()
	p.attack_interval = 0.0
	_expect_eq(p.validation_error(), &"invalid_attack_interval", "non-positive attack interval")


# ---------------------------------------------------------------------------
# 2. Equivalence: HORIZONTAL_ONLY + zero telegraph reproduces pre-Task59
#    behavior (spawn transform, mask, speed, and final hit outcome).
# ---------------------------------------------------------------------------
func _test_equivalence_horizontal_zero_telegraph() -> void:
	for direction_x: float in [-1.0, 1.0]:
		var world := Node2D.new()
		root.add_child(world)
		current_scene = world

		var boss := ENEMY_SCENE.instantiate() as CombatEnemy
		boss.terminal_enemy = true
		boss.ai_enabled = false
		var equivalence_profile := _make_valid_profile()
		equivalence_profile.aim_mode = EnemyProjectileProfile.AimMode.HORIZONTAL_ONLY
		equivalence_profile.telegraph_duration = 0.0
		boss.ranged_projectile_profile = equivalence_profile
		world.add_child(boss)

		var player := PLAYER_SCENE.instantiate() as PlayerCharacter
		world.add_child(player)
		await process_frame

		boss.global_position = Vector2(500.0, 500.0)
		player.global_position = Vector2(500.0 + direction_x * 300.0, 500.0)
		boss.player = player
		boss.set_physics_process(false)
		player.set_physics_process(false)

		var created: Array[Node] = []
		boss.delivery_created.connect(func(node: Node) -> void: created.append(node), CONNECT_ONE_SHOT)
		_fire_immediate_shot(boss, equivalence_profile)
		_expect_eq(created.size(), 1, "equivalence shot creates exactly one delivery (%s)" % _dir_name(direction_x))
		if created.is_empty():
			await _destroy_context({&"world": world})
			continue

		var projectile := created[0] as ProjectileDelivery
		_expect(is_equal_approx(projectile.speed, 255.0), "equivalence shot keeps the legacy speed 255 (%s)" % _dir_name(direction_x))
		_expect_eq(projectile.hurtbox_collision_mask, 16, "equivalence shot keeps the legacy hurtbox mask 16 (%s)" % _dir_name(direction_x))
		_expect_eq(projectile.blocking_collision_mask, 4, "equivalence shot keeps the legacy blocking mask 4 (%s)" % _dir_name(direction_x))
		_expect(
			is_equal_approx(projectile.direction.x, direction_x) and is_zero_approx(projectile.direction.y),
			"equivalence shot direction is exactly horizontal (%s)" % _dir_name(direction_x)
		)
		_expect(
			absf(projectile.global_position.x - (boss.global_position.x + direction_x * 58.0)) <= 0.01,
			"equivalence shot keeps the legacy spawn offset 58 (%s)" % _dir_name(direction_x)
		)
		_expect(
			absf(projectile.global_position.y - boss.global_position.y) <= 0.01,
			"equivalence shot keeps the legacy spawn Y with no vertical offset (%s)" % _dir_name(direction_x)
		)

		var outcome := {&"finished": false, &"reason": StringName()}
		projectile.delivery_finished.connect(func(reason: StringName) -> void:
			outcome[&"finished"] = true
			outcome[&"reason"] = reason
		)
		for _frame: int in 300:
			if bool(outcome[&"finished"]):
				break
			await physics_frame
		_expect(
			bool(outcome[&"finished"]) and outcome[&"reason"] == DeliveryBase.FINISH_HIT,
			"equivalence shot reaches the aligned player exactly as before Task59 (%s)" % _dir_name(direction_x)
		)

		world.queue_free()
		await process_frame


# ---------------------------------------------------------------------------
# 3. Diagonal aiming: direction correct, normalized, and angle-limited.
# ---------------------------------------------------------------------------
func _test_diagonal_direction_and_angle_limit() -> void:
	var profile := _make_valid_profile()
	profile.aim_mode = EnemyProjectileProfile.AimMode.AIM_AT_PLAYER
	profile.aim_angle_limit_degrees = 60.0

	var moderate := profile.resolve_direction(Vector2.ZERO, Vector2(100.0, -50.0), 1.0)
	_expect(is_equal_approx(moderate.length(), 1.0), "moderate diagonal direction is normalized")
	_expect(moderate.x > 0.0 and moderate.y < 0.0, "moderate diagonal direction points toward the upper-right player")
	_expect(moderate.is_equal_approx(Vector2(100.0, -50.0).normalized()), "moderate diagonal direction matches the unclamped aim exactly")

	var steep := profile.resolve_direction(Vector2.ZERO, Vector2(10.0, -100.0), 1.0)
	var angle_from_horizontal := atan2(absf(steep.y), absf(steep.x))
	_expect(angle_from_horizontal <= deg_to_rad(60.0) + 0.001, "steep diagonal direction is clamped to the 60 degree aim limit")
	_expect(steep.x > 0.0, "clamped steep direction keeps the correct horizontal side")
	_expect(is_equal_approx(steep.length(), 1.0), "clamped steep direction stays normalized")

	var down_left := profile.resolve_direction(Vector2.ZERO, Vector2(-80.0, 40.0), 1.0)
	_expect(down_left.x < 0.0 and down_left.y > 0.0, "diagonal direction points toward the lower-left player")

	var near_vertical := profile.resolve_direction(Vector2.ZERO, Vector2(0.001, -500.0), -1.0)
	var near_vertical_angle := atan2(absf(near_vertical.y), absf(near_vertical.x))
	_expect(near_vertical_angle <= deg_to_rad(60.0) + 0.001, "near-vertical aim is still clamped away from unreadable vertical shots")


# ---------------------------------------------------------------------------
# 4. Zero vector (player exactly overlapping the spawn origin) falls back to
#    the horizontal facing direction.
# ---------------------------------------------------------------------------
func _test_zero_vector_falls_back_to_facing() -> void:
	var profile := _make_valid_profile()
	profile.aim_mode = EnemyProjectileProfile.AimMode.AIM_AT_PLAYER
	var same_point := Vector2(200.0, 300.0)

	_expect_eq(profile.resolve_direction(same_point, same_point, 1.0), Vector2.RIGHT, "exact overlap falls back to rightward facing")
	_expect_eq(profile.resolve_direction(same_point, same_point, -1.0), Vector2.LEFT, "exact overlap falls back to leftward facing")
	_expect_eq(profile.resolve_direction(same_point, same_point, 0.0), Vector2.RIGHT, "exact overlap with zero facing defaults rightward")


# ---------------------------------------------------------------------------
# 5. Diagonal spawn point does not embed in the formal Boss room's
#    WorldBlocker geometry (Task 51 precedent).
# ---------------------------------------------------------------------------
func _test_diagonal_spawn_clears_world_blocker() -> void:
	for direction_x: float in [-1.0, 1.0]:
		var context := await _create_boss_context()
		var boss := context[&"boss"] as CombatEnemy
		var player := context[&"player"] as PlayerCharacter

		var diagonal_profile := _make_valid_profile()
		diagonal_profile.aim_mode = EnemyProjectileProfile.AimMode.AIM_AT_PLAYER
		boss.ranged_projectile_profile = diagonal_profile
		player.global_position = Vector2(boss.global_position.x + direction_x * 220.0, boss.global_position.y - 90.0)
		await physics_frame

		var created: Array[Node] = []
		boss.delivery_created.connect(func(node: Node) -> void: created.append(node), CONNECT_ONE_SHOT)
		_fire_immediate_shot(boss, diagonal_profile)
		_expect_eq(created.size(), 1, "diagonal shot creates exactly one delivery (%s)" % _dir_name(direction_x))
		if not created.is_empty():
			var projectile := created[0] as ProjectileDelivery
			projectile.queue_free_on_finish = false
			_expect(not is_zero_approx(projectile.direction.y), "diagonal shot direction has a real vertical component (%s)" % _dir_name(direction_x))
			var overlaps := _blocker_overlaps(projectile)
			_expect_eq(overlaps.size(), 0, "diagonal spawn point starts with zero WorldBlocker overlaps (%s)" % _dir_name(direction_x))
			projectile.free()
		await _destroy_context(context)


# ---------------------------------------------------------------------------
# 6. Telegraph timing: no shot during the wait, exactly one shot afterward,
#    direction locked at telegraph start, enemy stands still throughout.
# ---------------------------------------------------------------------------
func _test_telegraph_timing_lock_and_stillness() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	# Absorb the physics-tick catch-up burst that follows first-time scene
	# instantiation before relying on single-tick timing below.
	for _frame: int in 10:
		await physics_frame

	boss.global_position = Vector2(500.0, 500.0)
	player.global_position = Vector2(800.0, 500.0)
	boss.player = player
	boss.set("_boss_projectile_cooldown", 0.0)
	var profile: EnemyProjectileProfile = boss.ranged_projectile_profile
	_expect(profile != null and profile.telegraph_duration > 0.0, "the shipped Boss profile telegraphs before firing")

	var created: Array[Node] = []
	boss.delivery_created.connect(func(node: Node) -> void: created.append(node))
	await _drive_ranged_cycle(boss, profile)
	await _drive_ranged_cycle(boss, profile)
	_expect(bool(boss.get("_telegraph_active")), "cooldown reaching zero begins a telegraph instead of firing instantly")
	_expect_eq(created.size(), 0, "no delivery is created the instant the telegraph begins")
	_expect(is_zero_approx(boss.velocity.x), "boss stands still the instant the telegraph begins")
	var locked_direction: Vector2 = boss.get("_telegraph_locked_direction")
	_expect(
		is_equal_approx(locked_direction.x, 1.0) and is_zero_approx(locked_direction.y),
		"telegraph locks in the direction toward the player at the moment it begins"
	)

	# Move the player far away in the opposite direction; the locked shot must not retarget.
	player.global_position = Vector2(100.0, 900.0)

	var remaining: float = boss.get("_telegraph_time_remaining")
	var frames := int(ceil(remaining * 60.0)) + 12
	for _frame: int in frames:
		if not bool(boss.get("_telegraph_active")):
			break
		_expect(is_zero_approx(boss.velocity.x), "boss remains still for the whole telegraph window")
		await _drive_ranged_cycle(boss, profile)

	_expect_eq(created.size(), 1, "telegraph fires exactly once after it completes")
	if not created.is_empty():
		var projectile := created[0] as ProjectileDelivery
		_expect(
			is_equal_approx(projectile.direction.x, 1.0) and is_zero_approx(projectile.direction.y),
			"the fired shot keeps the direction locked at telegraph start, ignoring the player's new position"
		)
	world.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 7. Death during the telegraph window cancels it; no post-mortem shot.
# ---------------------------------------------------------------------------
func _test_death_during_telegraph_cancels() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	for _frame: int in 10:
		await physics_frame

	boss.global_position = Vector2(500.0, 500.0)
	player.global_position = Vector2(800.0, 500.0)
	boss.player = player
	boss.set("_boss_projectile_cooldown", 0.0)
	var profile: EnemyProjectileProfile = boss.ranged_projectile_profile

	var created: Array[Node] = []
	boss.delivery_created.connect(func(node: Node) -> void: created.append(node))
	await _drive_ranged_cycle(boss, profile)
	await _drive_ranged_cycle(boss, profile)
	_expect(bool(boss.get("_telegraph_active")), "telegraph begins before the lethal hit")

	var cast := CastSnapshot.new(_next_hit_id(), &"task59_lethal", 91, 91, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	boss.combat_receiver.receive_hit(HitRequest.new(cast, payload, _next_hit_id(), 0, boss.global_position, Vector2.RIGHT))
	_expect(boss.defeated, "the lethal hit defeats the boss mid-telegraph")
	_expect(not bool(boss.get("_telegraph_active")), "death immediately cancels the active telegraph")

	for _frame: int in 60:
		await _drive_ranged_cycle(boss, profile)
	_expect_eq(created.size(), 0, "a boss that dies mid-telegraph never fires the pending shot")
	world.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 8. cancel_telegraph_on_hurt: both branches asserted.
# ---------------------------------------------------------------------------
func _test_cancel_telegraph_on_hurt_both_branches() -> void:
	for cancel_on_hurt: bool in [true, false]:
		var world := Node2D.new()
		root.add_child(world)
		current_scene = world
		var boss := ENEMY_SCENE.instantiate() as CombatEnemy
		boss.terminal_enemy = true
		boss.ai_enabled = false
		var profile := _make_valid_profile()
		profile.telegraph_duration = 0.3
		profile.cancel_telegraph_on_hurt = cancel_on_hurt
		boss.ranged_projectile_profile = profile
		world.add_child(boss)
		var player := PLAYER_SCENE.instantiate() as PlayerCharacter
		world.add_child(player)
		for _frame: int in 10:
			await physics_frame

		boss.damage_receiver.configure_runtime(300, 300, 0.0)
		boss.global_position = Vector2(500.0, 500.0)
		player.global_position = Vector2(800.0, 500.0)
		boss.player = player
		boss.set("_boss_projectile_cooldown", 0.0)

		var created: Array[Node] = []
		boss.delivery_created.connect(func(node: Node) -> void: created.append(node))
		await _drive_ranged_cycle(boss, profile)
		await _drive_ranged_cycle(boss, profile)
		_expect(bool(boss.get("_telegraph_active")), "telegraph begins (cancel_telegraph_on_hurt=%s)" % cancel_on_hurt)

		var cast := CastSnapshot.new(_next_hit_id(), &"task59_nonlethal", 92, 92, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var payload := RuntimeAttackPayload.new(5.0, 5.0, ElementIds.NONE, 0)
		boss.combat_receiver.receive_hit(HitRequest.new(cast, payload, _next_hit_id(), 0, boss.global_position, Vector2.RIGHT))
		_expect(not boss.defeated, "the non-lethal hit does not defeat the boss (cancel_telegraph_on_hurt=%s)" % cancel_on_hurt)

		if cancel_on_hurt:
			_expect(not bool(boss.get("_telegraph_active")), "cancel_telegraph_on_hurt=true cancels the active telegraph on hit")
		else:
			_expect(bool(boss.get("_telegraph_active")), "cancel_telegraph_on_hurt=false keeps the telegraph running through a hit")

		for _frame: int in 40:
			await _drive_ranged_cycle(boss, profile)
		if cancel_on_hurt:
			_expect_eq(created.size(), 0, "a cancelled telegraph never fires (cancel_telegraph_on_hurt=true)")
		else:
			_expect_eq(created.size(), 1, "an uncancelled telegraph still fires on schedule (cancel_telegraph_on_hurt=false)")

		world.queue_free()
		await process_frame


# ---------------------------------------------------------------------------
# 9. spread_count > 1: symmetric angle distribution, independently resolved.
# ---------------------------------------------------------------------------
func _test_spread_count_symmetric_independent() -> void:
	var profile := _make_valid_profile()
	profile.spread_count = 3
	profile.spread_angle_degrees = 30.0
	var directions := profile.spread_directions(Vector2.RIGHT)
	_expect_eq(directions.size(), 3, "spread_count 3 yields three directions")
	if directions.size() == 3:
		_expect(absf(directions[1].angle()) < 0.001, "the middle spread shot matches the base direction")
		_expect(absf(directions[0].angle() + directions[2].angle()) < 0.001, "spread is symmetric around the base direction")
		_expect(absf(absf(directions[0].angle()) - deg_to_rad(15.0)) < 0.001, "outer spread shots sit at half the spread angle")

	var single := _make_valid_profile()
	single.spread_count = 1
	var single_directions := single.spread_directions(Vector2(0.0, -1.0))
	_expect_eq(single_directions.size(), 1, "spread_count 1 yields exactly the base direction")
	if not single_directions.is_empty():
		_expect(single_directions[0].is_equal_approx(Vector2(0.0, -1.0)), "spread_count 1 applies no rotation")

	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	boss.ranged_projectile_profile = profile
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	await process_frame

	boss.global_position = Vector2(500.0, 500.0)
	player.global_position = Vector2(800.0, 500.0)
	boss.player = player
	boss.set_physics_process(false)
	player.set_physics_process(false)

	var created: Array[Node] = []
	boss.delivery_created.connect(func(node: Node) -> void: created.append(node))
	_fire_immediate_shot(boss, profile)
	_expect_eq(created.size(), 3, "spread_count 3 launches three independent deliveries in one shot")
	_expect_eq(boss.boss_projectiles_fired, 1, "a multi-pellet spread still counts as a single attack cycle")
	var seen_ids: Dictionary = {}
	for node: Node in created:
		seen_ids[node.get_instance_id()] = true
	_expect_eq(seen_ids.size(), 3, "each spread pellet is a distinct delivery instance")

	var outcome := {&"finished": 0, &"reasons": [] as Array[StringName]}
	for node: Node in created:
		(node as ProjectileDelivery).delivery_finished.connect(func(reason: StringName) -> void:
			outcome[&"finished"] = int(outcome[&"finished"]) + 1
			(outcome[&"reasons"] as Array).append(reason)
		)
	for _frame: int in 300:
		if int(outcome[&"finished"]) >= 3:
			break
		await physics_frame
	_expect_eq(int(outcome[&"finished"]), 3, "all three independent spread pellets resolve to their own finish")
	_expect((outcome[&"reasons"] as Array).has(DeliveryBase.FINISH_HIT), "the centered spread pellet still reaches the aligned player")
	world.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 10. Sprite rotation matches direction.angle() plus the texture basis
#     correction (the current left-facing placeholder texture).
# ---------------------------------------------------------------------------
func _test_sprite_rotation_matches_direction() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	await process_frame

	boss.global_position = Vector2(500.0, 500.0)
	player.global_position = Vector2(700.0, 380.0)
	boss.player = player
	var profile := _make_valid_profile()
	profile.aim_mode = EnemyProjectileProfile.AimMode.AIM_AT_PLAYER
	profile.texture_forward_offset_degrees = 180.0
	boss.ranged_projectile_profile = profile

	var created: Array[Node] = []
	boss.delivery_created.connect(func(node: Node) -> void: created.append(node), CONNECT_ONE_SHOT)
	_fire_immediate_shot(boss, profile)
	_expect_eq(created.size(), 1, "rotation test fires exactly one delivery")
	if not created.is_empty():
		var projectile := created[0] as ProjectileDelivery
		var expected_rotation := projectile.direction.angle() + PI
		_expect(
			absf(wrapf(projectile.rotation - expected_rotation, -PI, PI)) < 0.01,
			"delivery root rotation matches direction.angle() plus the left-facing texture basis correction"
		)
		var sprite := projectile.get_node_or_null("Sprite2D") as Sprite2D
		_expect(
			sprite != null and absf(wrapf(sprite.global_rotation - expected_rotation, -PI, PI)) < 0.01,
			"the visible sprite inherits the same corrected rotation"
		)
	world.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# Shared fixtures / helpers
# ---------------------------------------------------------------------------
func _make_valid_profile() -> EnemyProjectileProfile:
	var p := EnemyProjectileProfile.new()
	p.projectile_scene = PROJECTILE_SCENE
	p.speed = 255.0
	p.max_distance = 980.0
	p.damage = 8.0
	p.element_id = ElementIds.NONE
	p.element_amount = 0
	p.hurtbox_collision_mask = 16
	p.blocking_collision_mask = 4
	p.telegraph_duration = 0.0
	p.aim_mode = EnemyProjectileProfile.AimMode.HORIZONTAL_ONLY
	p.aim_angle_limit_degrees = 60.0
	p.spread_count = 1
	p.spread_angle_degrees = 0.0
	p.spawn_offset_distance = 58.0
	p.texture_forward_offset_degrees = 180.0
	p.attack_interval = 1.9
	p.cancel_telegraph_on_hurt = true
	p.presentation_tags = PackedStringArray(["task59_test"])
	return p


func _create_boss_context() -> Dictionary:
	var world := Node2D.new()
	world.name = "Task59BossWorld"
	root.add_child(world)
	current_scene = world

	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	_expect(room != null and room.configure(BOSS_ROOM), "formal Boss room configures for task59 fixtures")
	room.activate()
	var boss := room.enemies[0] as CombatEnemy
	boss.set("_boss_projectile_cooldown", 9999.0)

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


func _destroy_context(context: Dictionary) -> void:
	var world := context[&"world"] as Node2D
	if current_scene == world:
		current_scene = null
	world.queue_free()
	await process_frame


func _blocker_overlaps(projectile: ProjectileDelivery) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = projectile.projectile_shape
	query.transform = projectile.global_transform
	query.collision_mask = projectile.blocking_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = projectile.query_margin
	return projectile.get_world_2d().direct_space_state.intersect_shape(query, projectile.max_contact_results)


func _dir_name(direction_x: float) -> String:
	return "right" if direction_x > 0.0 else "left"


## Task 61 retires the old terminal_enemy-gated _spawn_boss_projectile()
## direct-call entry point from scripts/enemy.gd (its production role is now
## fully owned by BossTideEmber's own _physics_process()). This test suite
## still needs a deterministic, no-telegraph-wait "fire now" primitive for
## generic CombatEnemy fixtures, so it reproduces the exact same three-line
## body directly against the still-present, still-generic
## _resolve_accurate_direction()/_apply_facing()/_launch_ranged_projectile()
## methods (shared with TidalSentry, unaffected by the retirement).
## Task 61 removes the generic "if terminal_enemy: _advance_ranged_attack_cycle(...)"
## trigger from CombatEnemy._physics_process() (terminal_enemy is now purely
## a data flag, read only by growth/flow reward logic, never gating
## behavior). BossTideEmber and TidalSentry each call the still-present,
## still-generic _advance_ranged_attack_cycle() directly from their own
## _physics_process() override; a bare CombatEnemy fixture (as used
## throughout this file) has nothing left to call it automatically, so
## telegraph-timing tests must drive it explicitly, once per simulated
## physics tick, alongside a real await physics_frame elsewhere in the same
## loop for gravity/movement/projectile simulation to keep progressing.
func _drive_ranged_cycle(boss: CombatEnemy, profile: EnemyProjectileProfile) -> void:
	if not boss.defeated:
		boss.call("_advance_ranged_attack_cycle", 1.0 / 60.0, profile, &"boss_arc")
	await physics_frame


func _fire_immediate_shot(boss: CombatEnemy, profile: EnemyProjectileProfile) -> void:
	var direction: Vector2 = boss.call("_resolve_accurate_direction", profile, boss.player.global_position)
	boss.call("_apply_facing", direction)
	boss.call("_launch_ranged_projectile", profile, direction, &"boss_arc")


func _next_hit_id() -> int:
	_hit_seq += 1
	return _hit_seq


func _run_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _finish() -> void:
	quit(_harness.report("TASK 59 ENEMY PROJECTILE PROFILE TESTS"))
