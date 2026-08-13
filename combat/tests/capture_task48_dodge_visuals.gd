extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task48/screenshots"

var _failures: Array[String] = []
var _saved: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	enemy.ai_enabled = false
	enemy.set_physics_process(false)
	for _frame: int in 30:
		await physics_frame
		if player.is_on_floor():
			break
	_assert(player.is_on_floor(), "capture player is grounded")
	player.global_position.x = 500.0
	enemy.global_position = Vector2(535.0, player.global_position.y)
	await _settle_visual()
	await _save("task48_01_dodge_ready_1920x1080.png")
	Input.action_press(&"move_right")
	_assert(bool(player.call(&"_try_start_dodge")), "capture starts a real dodge")
	Input.action_release(&"move_right")
	for _frame: int in 3:
		await physics_frame
	_assert(bool(player.get("_dodging")) and player.combat_receiver.dodging, "mid-action capture is inside the full i-frame window")
	_assert(not player.get_collision_mask_value(2) and player.get_collision_mask_value(3), "mid-action capture has enemy pass-through and world collision")
	_assert(player.sprite.modulate.a < 0.9, "mid-action presentation is visibly translucent")
	await _save("task48_02_dodge_mid_enemy_overlap_1920x1080.png")
	for _frame: int in 20:
		if not bool(player.get("_dodging")):
			break
		await physics_frame
	await _settle_visual()
	_assert(not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "end capture follows complete cleanup")
	_assert_eq(player.collision_mask, 6, "end capture restores the formal mask")
	_assert(player.sprite.modulate.is_equal_approx(Color(player.get("_base_sprite_modulate"))), "end capture restores the element visual")
	await _save("task48_03_dodge_recovered_1920x1080.png")
	_assert_eq(_saved.size(), 3, "capture writes one three-frame 1920x1080 action group")
	print("TASK 48 DODGE VISUAL CAPTURE: 1 test, %d images, %d failures" % [_saved.size(), _failures.size()])
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
