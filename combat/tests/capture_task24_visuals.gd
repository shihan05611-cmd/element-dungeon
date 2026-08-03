extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task24"

var _room: Node2D
var _hud: CombatHUD
var _overlay: RunOverlayInterface
var _enemy: CombatEnemy
var _player: PlayerCharacter
var _host: RunSessionHost
var _coordinator: SkillVfxCoordinator


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR))
	if directory_error != OK:
		printerr("TASK 24 evidence directory failed: %d" % directory_error)
		quit(1)
		return
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_enemy = _room.get_node("Orc") as CombatEnemy
	_player = _room.get_node("Player") as PlayerCharacter
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_coordinator = _room.get_node("SkillVfxCoordinator") as SkillVfxCoordinator
	_overlay = _hud.run_overlay as RunOverlayInterface
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)
	_enemy.element_carrier.set_amounts_silent(2, 3)

	await _capture_at(Vector2i(1920, 1080), "01_hud_1920x1080.png")
	await _capture_at(Vector2i(2560, 1440), "02_hud_2560x1440.png")
	await _capture_at(Vector2i(2560, 1600), "03_hud_2560x1600.png")
	await _capture_at(Vector2i(3840, 2160), "04_hud_3840x2160.png")
	await _capture_at(Vector2i(3440, 1440), "05_hud_3440x1440.png")
	await _capture_at(Vector2i(900, 540), "06_hud_900x540_stress.png")

	root.size = Vector2i(1920, 1080)
	_equip_four()
	_player.energy_component.set_current(0)
	var transients: Dictionary = _hud.get("_slot_transients")
	var until := Time.get_ticks_msec() + 5000
	transients[SkillSlotIds.ACTIVE_1] = {"text": "冷却", "tone": &"cooldown", "until": until}
	transients[SkillSlotIds.ACTIVE_2] = {"text": "能量", "tone": &"energy", "until": until}
	transients[SkillSlotIds.ACTIVE_3] = {"text": "失败", "tone": &"error", "until": until}
	transients[SkillSlotIds.PASSIVE_1] = {"text": "触发", "tone": &"passive", "until": until}
	_hud.call("_refresh_skill_status")
	var active_one: Dictionary = (_hud.get("_slot_views") as Dictionary)[SkillSlotIds.ACTIVE_1]
	var cooldown_mask := active_one["cooldown_mask"] as ColorRect
	var cooldown_label := active_one["cooldown_label"] as Label
	cooldown_mask.visible = true
	cooldown_mask.position.y = 24
	cooldown_mask.size = Vector2(36, 18)
	cooldown_label.visible = true
	cooldown_label.text = "2.4"
	_hud.call("_show_feedback", "当前忙碌 · 动作结束后重试", &"busy", 5.0)
	await _settle()
	await _capture("07_states_cooldown_energy_failure_passive.png")
	_player.energy_component.set_current(_player.energy_component.maximum)
	transients.clear()
	_hud.call("_refresh_skill_status")

	_overlay.show_reward(_offer(3, false))
	await _settle()
	await _capture("08_reward_three.png")
	_overlay.hide_overlay()

	_overlay.show_reward(_offer(2, false))
	await _settle()
	_overlay.reward_card(1).grab_focus()
	await _settle()
	await _capture("09_reward_two_centered.png")
	_overlay.hide_overlay()

	_overlay.show_reward(_offer(1, false))
	await _settle()
	await _capture("10_reward_one_explicit_confirm.png")
	_overlay.hide_overlay()

	root.size = Vector2i(900, 540)
	_overlay.show_reward(_offer(3, true))
	await _settle()
	await _capture("11_reward_long_copy_900x540.png")
	_overlay.hide_overlay()

	root.size = Vector2i(1920, 1080)
	_hud.set_colorblind_mode(true)
	await _settle()
	await _capture("12_colorblind_shape_text.png")
	_hud.set_colorblind_mode(false)

	_hud.set_reduced_motion(true)
	_hud.call("_show_feedback", "减少动态 · 形状、文字与状态语义保持", &"info", 5.0)
	await _settle()
	await _capture("13_reduced_motion.png")
	_hud.set_reduced_motion(false)

	await _stage_task18_vfx()
	await _settle()
	await _capture("14_fury_laser_reclaim_unobscured.png")

	print("TASK 24 VISUAL CAPTURE COMPLETE: 14 screenshots")
	quit(0)


func _capture_at(viewport_size: Vector2i, file_name: String) -> void:
	root.size = viewport_size
	await _settle()
	await _capture(file_name)


func _stage_task18_vfx() -> void:
	_overlay.hide_overlay()
	_enemy.position = Vector2(520.0, 320.0)
	_enemy.element_carrier.set_amounts_silent(2, 2)
	_equip_one(&"elemental_fury")
	_set_element(ElementIds.FIRE)
	_player.energy_component.set_current(100)
	var fury_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	if not fury_attempt.accepted:
		printerr("TASK 24 Fury fixture rejected: " + String(fury_attempt.reason_name()))
	_player.skill_executor.advance(0.0)
	_player.skill_executor.advance(2.0)
	_equip_one(&"elemental_laser")
	_set_element(ElementIds.WATER)
	_player.energy_component.set_current(100)
	var laser_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	if not laser_attempt.accepted:
		printerr("TASK 24 Laser fixture rejected: " + String(laser_attempt.reason_name()))
	_player.skill_executor.advance(0.0)
	_player.skill_executor.advance(0.50)
	var reclaim_event := ReclaimVfxEvent.new(
		24001,
		ElementIds.FIRE,
		[Vector2(640.0, 360.0), _enemy.global_position]
	)
	_coordinator.call("_on_reclaim_vfx_committed", reclaim_event)


func _equip_four() -> void:
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, &"elemental_fury"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, &"elemental_laser"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, &"element_reclaim"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"burning"),
	]
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	if not result.accepted:
		printerr("TASK 24 four-skill fixture rejected: " + String(result.detail))


func _equip_one(skill_id: StringName) -> void:
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(slot_id, skill_id if slot_id == SkillSlotIds.ACTIVE_1 else &""))
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	if not result.accepted:
		printerr("TASK 24 skill fixture rejected: " + String(result.detail))


func _set_element(element_id: StringName) -> void:
	if _player.current_element_controller.current_element_id == element_id:
		return
	var result := _player.request_element(element_id)
	if result == null or not result.accepted:
		printerr("TASK 24 element fixture rejected: " + String(element_id))


func _offer(count: int, long_copy: bool) -> RewardOffer:
	var ids: Array[StringName] = [&"elemental_fury", &"elemental_laser", &"burning"]
	var names: Array[String] = ["元素之怒", "Elemental Laser", "燃烧"]
	var options: Array[RewardOption] = []
	for index: int in count:
		var description := "正式权威说明：技能行为、元素策略与当前构筑关系。"
		if long_copy:
			description = "这是用于八十个中文字符压力验证的权威测试说明，内容会自动换行并在固定卡片操作安全区之前收束，不会横向越界、挤掉独立确认路径，也不会借此生成任何新规则、评分、稀有度、重随或取消能力。"
		var display_name := names[index]
		if long_copy and index == 1:
			display_name = "Elemental Laser With A Deliberately Long Authoritative Display Name"
		options.append(RewardOption.new(
			StringName("task24_visual_option_%d_%d" % [count, index]),
			RewardType.SKILL,
			ids[index],
			display_name,
			description
		))
	return RewardOffer.new(
		StringName("task24_visual_offer_%d_%s" % [count, "long" if long_copy else "normal"]),
		&"task24_visual_room",
		RewardType.SKILL,
		240 + count,
		options
	)


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s" % [EVIDENCE_DIR, file_name])
	var result := image.save_png(path)
	if result != OK:
		printerr("TASK 24 capture failed: %s (%d)" % [path, result])
		quit(1)
	print("CAPTURED " + path)
