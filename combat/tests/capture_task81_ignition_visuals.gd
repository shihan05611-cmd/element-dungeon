extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task81/screenshots"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	player.global_position = Vector2(470, 470)
	enemy.global_position = Vector2(720, 470)
	enemy.element_carrier.set_amounts_silent(2, 5)
	await physics_frame
	var ignition := player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(ignition.accepted, "ignition cast accepted")
	await create_timer(0.18).timeout
	_save("01_fire_reclaim_gathering.png")
	var state := player.get_node("IgnitionState") as IgnitionState
	state.clear(&"visual_compare_normal")
	player.skill_executor.advance(8.01)
	var normal_attack := player.try_basic_attack()
	_expect(normal_attack.accepted, "normal fire basic attack accepts")
	await create_timer(0.08).timeout
	_save("02_normal_fire_attack.png")
	player.skill_executor.advance(1.0)
	enemy.element_carrier.set_amounts_silent(0, 5)
	await physics_frame
	var renewed_ignition := player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(renewed_ignition.accepted, "renewed ignition cast accepted")
	player.skill_executor.advance(0.01)
	var attack := player.try_basic_attack()
	_expect(attack.accepted and attack.payload.element_id == ElementIds.FIRE and attack.payload.element_amount == 1, "ignition basic attack locks fire")
	await create_timer(0.08).timeout
	_save("03_ignition_fire_attack.png")
	state.clear(&"visual_capture_expired")
	player.skill_executor.advance(1.0)
	player._play_locomotion_animation()
	await process_frame
	_save("04_expired_recovery.png")
	room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 81 VISUAL CAPTURE PASSED")
		quit(0)
	for failure in _failures:
		printerr("TASK 81 VISUAL CAPTURE FAILED: " + failure)
	quit(1)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))
	_expect(error == OK, "saved " + file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
