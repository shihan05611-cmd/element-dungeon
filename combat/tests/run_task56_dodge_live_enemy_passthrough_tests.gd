extends SceneTree

const TEST_ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BODY_DISPLACEMENT_TOLERANCE := 0.35

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	await _run_async("active_normal_enemy_passthrough", _test_active_normal_enemy_passthrough)
	await _run_async("active_formal_boss_passthrough", _test_active_formal_boss_passthrough)
	await _run_async("world_blocker_and_collision_state_lifecycle", _test_world_blocker_and_collision_state_lifecycle)
	await _run_async("death_and_exit_restore_collision_state", _test_death_and_exit_restore_collision_state)
	_finish()


func _test_active_normal_enemy_passthrough() -> void:
	var rig := await _make_test_room()
	var room := rig[&"room"] as Node2D
	var player := rig[&"player"] as PlayerCharacter
	var enemy := rig[&"enemy"] as CombatEnemy
	player.global_position.x = 500.0
	enemy.global_position.x = player.global_position.x + 35.0
	player.velocity = Vector2.ZERO
	enemy.velocity = Vector2.ZERO
	enemy.ai_enabled = false
	enemy.set_physics_process(true)
	player.set_physics_process(true)
	var player_start := player.global_position
	var enemy_start := enemy.global_position
	var expected_distance := float(player.call(&"_dodge_body_world_width")) * PlayerCharacter.DODGE_DISTANCE_IN_BODY_WIDTHS

	Input.action_press(&"move_right")
	_expect(bool(player.call(&"_try_start_dodge")), "active normal-enemy fixture starts a rightward dodge")
	Input.action_release(&"move_right")
	_expect(enemy.is_physics_processing() and not enemy.ai_enabled, "normal enemy keeps _physics_process/move_and_slide active with autonomous intent disabled")
	_expect_eq(player.collision_layer, 0, "dodge hides the formal PlayerBody layer from the active enemy")
	_expect_eq(player.collision_mask, 4, "dodge keeps only the formal WorldBlocker mask from the formal mask")
	await _wait_for_dodge_end(player)

	_expect(not bool(player.get("_dodging")), "normal-enemy dodge completes")
	_expect(absf(player.global_position.x - player_start.x - expected_distance) <= expected_distance * 0.02, "active normal enemy does not truncate the five-body-width dodge")
	_expect(player.global_position.x > enemy.global_position.x, "player finishes beyond the active normal enemy center")
	var enemy_horizontal_delta := absf(enemy.global_position.x - enemy_start.x)
	_expect(enemy_horizontal_delta <= BODY_DISPLACEMENT_TOLERANCE, "active normal enemy is not carried horizontally by dodge collision recovery (delta=%.4f)" % enemy_horizontal_delta)
	_expect_eq(player.collision_layer, 1, "normal completion restores the exact formal player collision layer")
	_expect_eq(player.collision_mask, 6, "normal completion restores the exact formal player collision mask")

	player.global_position = enemy.global_position + Vector2(-45.0, 0.0)
	player.velocity = Vector2.ZERO
	var collision := player.move_and_collide(Vector2(50.0, 0.0))
	_expect(collision != null and collision.get_collider() == enemy, "post-dodge player/enemy body collision is restored")
	_expect(player.global_position.x < enemy.global_position.x, "restored body collision prevents post-dodge ghosting through the enemy")
	await _dispose(room)


func _test_active_formal_boss_passthrough() -> void:
	var world := Node2D.new()
	world.name = "Task56BossWorld"
	root.add_child(world)
	current_scene = world
	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	_expect(room != null and room.configure(BOSS_ROOM), "formal Boss room configures through RunRoomInstance")
	room.activate()
	var boss := room.enemies[0] as CombatEnemy
	boss.ai_enabled = false
	boss.velocity = Vector2.ZERO
	boss.set("_boss_projectile_cooldown", 9999.0)
	boss.set_physics_process(true)

	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = boss.global_position + Vector2(-90.0, 0.0)
	world.add_child(player)
	boss.player = player
	await _settle_floor(player)
	var player_start := player.global_position
	var boss_start := boss.global_position
	var expected_distance := float(player.call(&"_dodge_body_world_width")) * PlayerCharacter.DODGE_DISTANCE_IN_BODY_WIDTHS

	Input.action_press(&"move_right")
	_expect(bool(player.call(&"_try_start_dodge")), "formal Boss fixture starts a rightward dodge")
	Input.action_release(&"move_right")
	_expect(boss.terminal_enemy and boss.is_physics_processing(), "formal terminal Boss keeps _physics_process/move_and_slide active")
	_expect_eq(player.collision_layer, 0, "dodge hides PlayerBody from the active formal Boss")
	await _wait_for_dodge_end(player)

	_expect(player.global_position.x > boss.global_position.x, "player finishes beyond the formal Boss center")
	_expect(absf(player.global_position.x - player_start.x - expected_distance) <= expected_distance * 0.02, "formal Boss does not truncate the five-body-width dodge")
	var boss_horizontal_delta := absf(boss.global_position.x - boss_start.x)
	_expect(boss_horizontal_delta <= BODY_DISPLACEMENT_TOLERANCE, "formal Boss is not carried horizontally by dodge collision recovery (delta=%.4f)" % boss_horizontal_delta)
	_expect_eq(player.collision_layer, 1, "Boss pass-through completion restores the formal player layer")
	_expect_eq(player.collision_mask, 6, "Boss pass-through completion restores the formal player mask")
	await _dispose(world)


func _test_world_blocker_and_collision_state_lifecycle() -> void:
	var rig := await _make_test_room()
	var room := rig[&"room"] as Node2D
	var player := rig[&"player"] as PlayerCharacter
	var enemy := rig[&"enemy"] as CombatEnemy
	enemy.global_position = Vector2(700.0, player.global_position.y)
	player.set_physics_process(false)
	player.global_position = Vector2(1035.0, player.global_position.y)
	player.velocity = Vector2.ZERO
	player.collision_layer = 9
	player.collision_mask = 7
	var start := player.global_position
	var expected_distance := float(player.call(&"_dodge_body_world_width")) * PlayerCharacter.DODGE_DISTANCE_IN_BODY_WIDTHS

	Input.action_press(&"move_right")
	_expect(bool(player.call(&"_try_start_dodge")), "wall fixture starts with custom collision state")
	Input.action_release(&"move_right")
	_expect_eq(player.collision_layer, 8, "dodge clears only PlayerBody while retaining unrelated custom layer bits")
	_expect_eq(player.collision_mask, 5, "dodge clears EnemyBody and retains unrelated/custom mask bits plus WorldBlocker")
	for _step: int in 12:
		if not bool(player.get("_dodging")):
			break
		player.call(&"_advance_dodge", 0.03)
	var travelled := player.global_position.x - start.x
	_expect(travelled >= 0.0 and travelled < expected_distance * 0.75, "real world wall truncates dodge before the open-ground target")
	_expect(not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "wall interruption clears dodge and i-frame state")
	_expect_eq(player.collision_layer, 9, "wall interruption restores the exact custom collision layer")
	_expect_eq(player.collision_mask, 7, "wall interruption restores the exact custom collision mask")
	await _dispose(room)


func _test_death_and_exit_restore_collision_state() -> void:
	var death_rig := await _make_test_room()
	var death_room := death_rig[&"room"] as Node2D
	var player := death_rig[&"player"] as PlayerCharacter
	player.set_physics_process(false)
	player.collision_layer = 9
	player.collision_mask = 7
	_expect(bool(player.call(&"_try_start_dodge")), "death fixture starts with custom collision state")
	player.call(&"_on_death_candidate", CombatResult.new())
	_expect(player.defeated and not bool(player.get("_dodging")), "death interrupts the dodge")
	_expect_eq(player.collision_layer, 9, "death restores the exact custom collision layer")
	_expect_eq(player.collision_mask, 7, "death restores the exact custom collision mask")
	await _dispose(death_room)

	var exit_rig := await _make_test_room()
	var exit_room := exit_rig[&"room"] as Node2D
	var exiting := exit_rig[&"player"] as PlayerCharacter
	exiting.set_physics_process(false)
	exiting.collision_layer = 9
	exiting.collision_mask = 7
	_expect(bool(exiting.call(&"_try_start_dodge")), "exit fixture starts with custom collision state")
	exit_room.remove_child(exiting)
	_expect(not bool(exiting.get("_dodging")), "tree exit interrupts the dodge")
	_expect_eq(exiting.collision_layer, 9, "tree exit restores the exact custom collision layer")
	_expect_eq(exiting.collision_mask, 7, "tree exit restores the exact custom collision mask")
	exiting.free()
	await _dispose(exit_room)


func _make_test_room() -> Dictionary:
	var room := TEST_ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	enemy.ai_enabled = false
	enemy.set_physics_process(true)
	await _settle_floor(player)
	return {&"room": room, &"player": player, &"enemy": enemy}


func _settle_floor(player: PlayerCharacter) -> void:
	player.set_physics_process(true)
	for _frame: int in 45:
		await physics_frame
		if player.is_on_floor():
			return
	_expect(false, "player settles on a real WorldBlocker floor")


func _wait_for_dodge_end(player: PlayerCharacter) -> void:
	for _frame: int in 30:
		await physics_frame
		if not bool(player.get("_dodging")):
			return
	_expect(false, "dodge completes within 30 physics frames")


func _dispose(node: Node) -> void:
	for tween: Tween in get_processed_tweens():
		tween.kill()
	if current_scene == node:
		current_scene = null
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _run_async(name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callable.call()
	if _failures.size() == before:
		print("PASS: " + name)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if _failures.is_empty():
		print("TASK 56 LIVE ENEMY DODGE PASSTHROUGH TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 56 LIVE ENEMY DODGE PASSTHROUGH TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
