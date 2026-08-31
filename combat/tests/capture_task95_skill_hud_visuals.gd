extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task95/screenshots"

var _room: Node2D
var _hud: CombatHUD
var _player: PlayerCharacter
var _host: RunSessionHost


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
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_host.set_process(false)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		_fail("cannot create screenshot directory")
		return
	if not _replace_visual_loadout():
		return
	_player.energy_component.set_current(_player.energy_component.maximum)
	_hud.call("_refresh_skill_status")
	_hud.call("_hide_feedback")

	if not await _capture("01_normal_with_empty_1920x1080.png", Vector2i(1920, 1080)):
		return
	var reclaim := _player.skill_controller.get_skill_for_slot(SkillSlotIds.ACTIVE_1)
	var cooldowns = _player.skill_executor.get("_cooldowns")
	cooldowns.start(reclaim.skill_id, reclaim.cooldown)
	cooldowns.advance(2.0)
	_hud.call("_refresh_skill_status")
	if not await _capture("02_cooldown_3s_and_empty_1920x1080.png", Vector2i(1920, 1080)):
		return
	cooldowns.advance(20.0)
	_hud.call("_refresh_skill_status")
	_hud.call("_set_slot_transient", SkillSlotIds.PASSIVE_1, "触发", &"passive")
	_hud.call("_refresh_slot", SkillSlotIds.PASSIVE_1)
	for _frame: int in 45:
		var pulse := _hud.get_node("Root/PassivePanel/Margin/SlotRow/passive_1/Margin/Body/PulseBorder") as TextureRect
		if pulse.modulate.a >= 0.68:
			break
		await process_frame
	if not await _capture("03_passive_trigger_1920x1080.png", Vector2i(1920, 1080)):
		return

	_hud.set_skill_hud_visible(false)
	if not await _capture("04_h_hidden_1920x1080.png", Vector2i(1920, 1080)):
		return
	_hud._unhandled_input(_h_key_event())
	(_hud.get("_slot_transients") as Dictionary).clear()
	_hud.call("_refresh_skill_status")
	if not await _capture("05_h_restored_1920x1080.png", Vector2i(1920, 1080)):
		return
	if not await _capture("06_layout_1152x648.png", Vector2i(1152, 648)):
		return
	if not await _capture("07_layout_2560x1440.png", Vector2i(2560, 1440)):
		return
	print("TASK 95 SKILL HUD VISUALS COMPLETE: 7 true-window captures")
	quit(0)


func _replace_visual_loadout() -> bool:
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, &"element_reclaim"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, &"ignition"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, &""),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"burning"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, &""),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3, &""),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4, &""),
	]
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	if not result.accepted:
		_fail("mixed visual loadout was rejected")
		return false
	return true


func _capture(file_name: String, viewport_size: Vector2i) -> bool:
	root.size = viewport_size
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	if image == null or image.is_empty() or image.get_size() != viewport_size or image.save_png(path) != OK:
		_fail("cannot save exact-size true-window capture: %s actual=%s" % [path, image.get_size() if image != null else Vector2i.ZERO])
		return false
	return true


func _h_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_H
	return event


func _fail(message: String) -> void:
	printerr("TASK 95 " + message)
	quit(1)
