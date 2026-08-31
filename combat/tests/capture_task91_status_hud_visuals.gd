extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task91/screenshots"

var _room: Node2D
var _hud: CombatHUD
var _player: PlayerCharacter


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_player = _room.get_node("Player") as PlayerCharacter
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		printerr("TASK 91 cannot create evidence directory")
		quit(1)
		return

	await _capture("01_water_full_same_camera.png")
	var fire := _player.request_element(ElementIds.FIRE)
	if not fire.accepted:
		printerr("TASK 91 fire switch failed")
		quit(1)
		return
	await _capture("02_fire_full_same_camera.png")
	var water := _player.request_element(ElementIds.WATER)
	_player.energy_component.set_current(34)
	var receiver := _player.damage_receiver
	var original := receiver.current_health
	if not water.accepted or not receiver.replace_health_silent(20):
		printerr("TASK 91 non-full fixture failed")
		quit(1)
		return
	receiver.notify_health_changed(20 - original)
	await _capture("03_water_low_hp_sp_same_camera.png")
	print("TASK 91 STATUS HUD VISUALS COMPLETE")
	quit(0)


func _capture(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	if image == null or image.is_empty() or image.save_png(path) != OK:
		printerr("TASK 91 cannot save " + path)
		quit(1)
