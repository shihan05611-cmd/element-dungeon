extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task82/screenshots"

var _room: Node2D
var _hud: CombatHUD


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
	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		printerr("TASK 82 cannot create evidence directory")
		quit(1)
		return
	if not await _save_viewport("01_skill_hud_visible.png"):
		quit(1)
		return
	_hud.set_skill_hud_visible(false)
	await process_frame
	if not await _save_viewport("02_skill_hud_hidden.png"):
		quit(1)
		return
	print("TASK 82 HUD VISUALS COMPLETE")
	quit(0)


func _save_viewport(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))) == OK
