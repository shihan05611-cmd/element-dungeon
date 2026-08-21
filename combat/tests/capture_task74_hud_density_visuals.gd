extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task74/screenshots"

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
		printerr("TASK 74 cannot create evidence directory")
		quit(1)
		return

	var normal := root.get_texture().get_image()
	if not _save_png(normal, "01_hud_1920x1080.png"):
		quit(1)
		return
	var loadout_crop := normal.get_region(Rect2i(640, 780, 640, 270))
	loadout_crop.resize(1280, 540, Image.INTERPOLATE_NEAREST)
	if not _save_png(loadout_crop, "02_loadout_4x.png"):
		quit(1)
		return

	var exclusive_preview := SkillDefinition.new()
	exclusive_preview.skill_id = &"element_bolt"
	exclusive_preview.element_policy = SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
	exclusive_preview.required_element_id = ElementIds.FIRE
	_hud.call("_refresh_slot_view", (_hud.get("_slot_views") as Dictionary)[SkillSlotIds.ACTIVE_1], SkillSlotIds.ACTIVE_1, exclusive_preview, true)
	await process_frame
	await RenderingServer.frame_post_draw
	var mismatch := root.get_texture().get_image().get_region(Rect2i(720, 930, 520, 145))
	mismatch.resize(1560, 435, Image.INTERPOLATE_NEAREST)
	if not _save_png(mismatch, "03_element_mismatch_grayscale_3x.png"):
		quit(1)
		return
	print("TASK 74 HUD VISUALS COMPLETE")
	quit(0)


func _save_png(image: Image, file_name: String) -> bool:
	if image == null or image.is_empty():
		return false
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	return image.save_png(path) == OK
