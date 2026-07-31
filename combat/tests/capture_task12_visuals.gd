extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _room: Node2D
var _hud: CombatHUD
var _overlay
var _enemy: CombatEnemy
var _player: PlayerCharacter
var _feedback: CombatFeedback
var _host: RunSessionHost
var _cast_id: int = 12000
var _delivery_id: int = 14000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_enemy = _room.get_node("Orc") as CombatEnemy
	_player = _room.get_node("Player") as PlayerCharacter
	_feedback = _room.get_node("WorldFeedbackLayer") as CombatFeedback
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_overlay = _hud.run_overlay
	_player.set_physics_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false

	root.size = Vector2i(1152, 648)
	await _settle()
	await _capture("01_combat_hud_1152x648.png")

	root.size = Vector2i(900, 540)
	await _settle()
	await _capture("02_combat_hud_scaled_900x540.png")

	root.size = Vector2i(1152, 648)
	_enemy.element_carrier.set_amounts_silent(2, 3)
	_hud.set_colorblind_mode(true)
	await _settle()
	await _capture("03_colorblind_target_layers.png")

	_hud.set_reduced_motion(true)
	_hud.call(
		"_show_feedback",
		"元素锁定 · 水滴 水 · WATER · 已生成攻击不跟随切换",
		&"lock",
		4.0
	)
	await _settle()
	await _capture("04_reduced_motion_locked_element.png")
	_hud.set_reduced_motion(false)
	_hud.set_colorblind_mode(false)

	_overlay.show_loadout()
	_overlay.try_preview_assignment(&"burning", SkillSlotIds.ACTIVE_2)
	await _settle()
	await _capture("05_active_slot_passive_preview.png")

	_overlay.try_preview_assignment(&"element_bolt", SkillSlotIds.PASSIVE_1)
	await _settle()
	await _capture("06_passive_slot_rejects_active.png")

	var four_passives := RuntimeLoadoutSnapshot.new(
		[
			RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, &"burning"),
			RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, &"unending"),
			RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, &"burning"),
			RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"unending"),
		],
		_host.runtime_loadout.snapshot().revision
	)
	_overlay.set_preview_snapshot(four_passives)
	await _settle()
	await _capture("07_zero_active_four_passive_warning.png")
	_overlay.hide_overlay()

	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	_enemy.element_carrier.set_amounts_silent(0, 2)
	_submit_hit(ElementIds.WATER, 2, 10.0)
	await _settle()
	await _capture("08_single_final_damage_reaction.png")

	var offer := RewardOffer.new(
		&"task12_visual_offer",
		&"room_visual",
		RewardType.SKILL,
		12,
		[
			RewardOption.new(
				&"task12_visual_option",
				RewardType.SKILL,
				&"elemental_fury",
				"元素之怒",
				"CURRENT_ELEMENT 主动 · 接受时锁定当前元素"
			)
		]
	)
	_overlay.show_reward(offer)
	await _settle()
	await _capture("09_reward_ui_catalog_copy.png")

	print("TASK 12 VISUAL CAPTURE COMPLETE")
	quit(0)


func _submit_hit(
	element_id: StringName,
	element_amount: int,
	offensive_damage: float
) -> CombatResult:
	_cast_id += 1
	_delivery_id += 1
	var stats := CombatStatSnapshot.new()
	var payload := RuntimeAttackPayload.from_locked_inputs(
		stats.effective_attack,
		offensive_damage / stats.effective_attack,
		0.0,
		offensive_damage,
		element_id,
		element_amount,
		PackedStringArray(["task12_visual"])
	)
	var snapshot := CastSnapshot.new(
		_cast_id,
		&"task12_visual_reaction",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	return _enemy.combat_receiver.receive_hit(HitRequest.new(
		snapshot,
		payload,
		_delivery_id,
		0,
		_enemy.global_position,
		Vector2.RIGHT
	))


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(
		"res://docs/agent_tasks/evidence/task12/%s" % file_name
	)
	var result := image.save_png(path)
	if result != OK:
		printerr("TASK 12 capture failed: %s (%d)" % [path, result])
		quit(1)
	print("CAPTURED " + path)
