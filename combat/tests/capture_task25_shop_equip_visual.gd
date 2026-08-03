extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task25"

var _room: Node2D
var _host: RunSessionHost
var _overlay: RunOverlayInterface


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EVIDENCE_DIR)
	)
	if directory_error != OK:
		printerr("TASK 25 evidence directory failed: %d" % directory_error)
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_overlay = (_room.get_node("CombatHUD") as CombatHUD).run_overlay as RunOverlayInterface
	var player := _room.get_node("Player") as PlayerCharacter
	var enemy := _room.get_node("Orc") as CombatEnemy
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	_host.set_process(false)
	if not _reach_shop():
		quit(1)
		return
	_overlay.show_loadout()
	await _settle()
	var before := _host.run_session.snapshot()
	_overlay.call("_select_skill", &"element_bolt")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_overlay.call("_on_slot_input", click, SkillSlotIds.ACTIVE_2)
	await _settle()
	var after := _host.run_session.snapshot()
	var status := _overlay.get("_status") as Label
	var subtitle := _overlay.get("_subtitle") as Label
	var confirm := _overlay.get("_confirm") as Button
	if (
		after.revision != before.revision + 1
		or after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2) != &"element_bolt"
		or not after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1).is_empty()
		or not status.text.contains("即时生效")
		or not subtitle.text.contains("技能装配即时生效")
		or confirm.text != "确认属性并离开"
	):
		printerr("TASK 25 visual authority fixture did not reach the required immediate state")
		quit(1)
		return
	var image := root.get_texture().get_image()
	var output_path := "%s/01_shop_immediate_equip_1920x1080.png" % EVIDENCE_DIR
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		printerr("TASK 25 screenshot save failed: %d" % save_error)
		quit(1)
		return
	print("TASK 25 VISUAL CAPTURE COMPLETE: 1 screenshot, immediate revision %d -> %d" % [
		before.revision,
		after.revision,
	])
	quit(0)


func _reach_shop() -> bool:
	var session := _host.run_session
	for room_number: int in range(1, 4):
		var room_id := session.snapshot().route.current_room_id
		if room_number > 1:
			room_id = StringName("task25_visual_room_%d" % room_number)
			if not session.begin_combat_room(room_id).accepted:
				printerr("TASK 25 visual room begin rejected: %d" % room_number)
				return false
		if not session.handle_event(RoomCompletedEvent.new(
			StringName("task25_visual_done_%d" % room_number), room_id, 100
		)).accepted:
			printerr("TASK 25 visual room completion rejected: %d" % room_number)
			return false
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1),
			2600 + room_number
		)
		if not generated.accepted:
			printerr("TASK 25 visual reward generation rejected: %d" % room_number)
			return false
		var option := generated.reward_offer.options[0]
		if not session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted:
			printerr("TASK 25 visual reward claim rejected: %d" % room_number)
			return false
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		if not session.choose_route(route_id).accepted:
			printerr("TASK 25 visual route rejected: %d" % room_number)
			return false
	return true


func _settle() -> void:
	await process_frame
	await process_frame
