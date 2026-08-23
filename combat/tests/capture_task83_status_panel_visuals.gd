extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task83/screenshots"

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
	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		printerr("TASK 83 cannot create evidence directory")
		quit(1)
		return
	if not _status_is_hp_sp_only() or not await _save_viewport("01_water_hp_sp.png"):
		quit(1)
		return
	var fire := _player.request_element(ElementIds.FIRE)
	if not fire.accepted or not _status_is_hp_sp_only() or not await _save_viewport("02_fire_hp_sp.png"):
		quit(1)
		return
	var health := _player.damage_receiver
	var original := health.current_health
	if not health.replace_health_silent(20):
		quit(1)
		return
	health.notify_health_changed(20 - original)
	if not _hud.low_health.visible or not await _save_viewport("03_fire_low_hp.png"):
		quit(1)
		return
	print("TASK 83 STATUS PANEL VISUALS COMPLETE")
	quit(0)


func _status_is_hp_sp_only() -> bool:
	var status := _hud.get_node_or_null("Root/StatusPanel/Margin/Status") as Control
	return status != null \
		and status.get_node_or_null("HealthRow/HealthBar/HealthValue") != null \
		and status.get_node_or_null("EnergyRow/EnergyBar/EnergyValue") != null \
		and status.get_node_or_null("TitleRow") == null \
		and status.get_node_or_null("CurrentElement") == null


func _save_viewport(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))) == OK
