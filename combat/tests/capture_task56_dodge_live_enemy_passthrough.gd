extends SceneTree

const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task56/screenshots"
const BODY_DISPLACEMENT_TOLERANCE := 0.35

var _failures: Array[String] = []
var _saved: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	var world := Node2D.new()
	world.name = "Task56BossCaptureWorld"
	root.add_child(world)
	current_scene = world
	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	_assert(room != null and room.configure(BOSS_ROOM), "formal Boss room configures")
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
	for _frame: int in 45:
		await physics_frame
		if player.is_on_floor():
			break
	_assert(player.is_on_floor() and boss.is_on_floor(), "player and formal Boss are grounded on the real Boss dais")
	_assert(boss.terminal_enemy and boss.is_physics_processing(), "terminal Boss physics remains active for capture")
	var boss_start := boss.global_position
	await _settle_visual()
	await _save("task56_01_boss_dodge_ready_1920x1080.png")

	Input.action_press(&"move_right")
	_assert(bool(player.call(&"_try_start_dodge")), "capture starts a real rightward dodge")
	Input.action_release(&"move_right")
	for _frame: int in 4:
		await physics_frame
	_assert(bool(player.get("_dodging")) and player.combat_receiver.dodging, "mid capture remains inside the complete i-frame window")
	_assert_eq(player.collision_layer, 0, "mid capture hides PlayerBody from the active Boss")
	_assert(boss.is_physics_processing(), "Boss physics remains active during the overlap frame")
	await _save("task56_02_boss_dodge_mid_overlap_1920x1080.png")

	for _frame: int in 30:
		if not bool(player.get("_dodging")):
			break
		await physics_frame
	await _settle_visual()
	var boss_horizontal_delta := absf(boss.global_position.x - boss_start.x)
	_assert(not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "capture reaches complete dodge cleanup")
	_assert(player.global_position.x > boss.global_position.x, "recovered player is visibly beyond the Boss center")
	_assert(boss_horizontal_delta <= BODY_DISPLACEMENT_TOLERANCE, "active Boss is not carried to the dodge endpoint (delta=%.4f)" % boss_horizontal_delta)
	_assert_eq(player.collision_layer, 1, "capture recovery restores the formal player layer")
	_assert_eq(player.collision_mask, 6, "capture recovery restores the formal player mask")
	_assert(player.sprite.modulate.is_equal_approx(Color(player.get("_base_sprite_modulate"))), "capture recovery restores the player visual")
	await _save("task56_03_boss_dodge_recovered_1920x1080.png")

	_assert_eq(_saved.size(), 3, "capture writes one three-frame formal Boss action group")
	print("TASK 56 BOSS DODGE VISUAL CAPTURE: 1 test, %d images, %d failures" % [_saved.size(), _failures.size()])
	for path: String in _saved:
		print("CAPTURED: " + path)
	quit(0 if _failures.is_empty() else 1)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_assert_eq(image.get_size(), Vector2i(1920, 1080), file_name + " keeps original viewport size")
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	_assert(image.save_png(ProjectSettings.globalize_path(path)) == OK, file_name + " saves successfully")
	_saved.append(path)


func _settle_visual() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("CAPTURE FAIL: " + message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assert(actual == expected, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])
