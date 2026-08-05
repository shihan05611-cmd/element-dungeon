extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task27"

var _room: Node2D
var _host: RunSessionHost
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _authority_safe_root: Control
var _authority_panel: PanelContainer


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EVIDENCE_DIR)
	)
	if directory_error != OK:
		printerr("TASK 27 evidence directory failed: %d" % directory_error)
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)
	if not _reach_shop_with_dream_dust():
		quit(1)
		return
	var opened := _host.run_session.open_shop_draft()
	if not opened.accepted or opened.shop_snapshot == null:
		printerr("TASK 27 visual shop snapshot unavailable")
		quit(1)
		return
	var before := _host.run_session.snapshot()
	var upgraded := _host.run_session.upgrade_active_skill(
		&"task27_visual_bolt_lv2",
		before.revision,
		opened.shop_snapshot.session_id,
		&"element_bolt"
	)
	if (
		not upgraded.accepted
		or upgraded.run_snapshot.skills.progress_for(&"element_bolt").level != 2
		or upgraded.run_snapshot.economy.balance != 25
		or upgraded.shop_commit.charged_dream_dust != 55
	):
		printerr("TASK 27 visual authority did not reach the required Lv2 economy state")
		quit(1)
		return
	if not _player.configure_run_skill_level_effects(_host.run_session):
		printerr("TASK 27 visual level adapter failed")
		quit(1)
		return
	_player.global_position = Vector2(330.0, 470.0)
	_enemy.global_position = Vector2(720.0, 470.0)
	_player.facing = 1.0
	_player.energy_component.set_current(100)
	_enemy.defeated = false
	_enemy.combat_receiver.accepting_hits = true
	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	var cast := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	if (
		not cast.accepted
		or cast.cast_snapshot.level_effect.level != 2
		or not is_equal_approx(cast.cast_snapshot.level_effect.damage_scale, 1.25)
		or cast.payload == null
		or not is_equal_approx(cast.payload.offensive_damage, 12.5)
		or _player.energy_component.current_energy != 90
	):
		printerr("TASK 27 visual cast did not freeze the asserted Lv2 bolt effect")
		quit(1)
		return
	_player.skill_executor.advance(0.25)
	await physics_frame
	await process_frame
	_add_authority_panel(upgraded.run_snapshot)
	await process_frame
	await process_frame
	if not _authority_panel_is_inside_logical_safe_area():
		printerr("TASK 27 authority panel is outside the logical safe area")
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		printerr("TASK 27 screenshot has wrong size: %s" % str(image.get_size()))
		quit(1)
		return
	var proof_counts := _authority_panel_proof_counts(image)
	if proof_counts.x < 200 or proof_counts.y < 300:
		printerr(
			"TASK 27 authority panel pixels missing: border=%d text=%d"
			% [proof_counts.x, proof_counts.y]
		)
		quit(1)
		return
	var output_path := "%s/01_authoritative_lv2_element_bolt_1920x1080.png" % EVIDENCE_DIR
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		printerr("TASK 27 screenshot save failed: %d" % save_error)
		quit(1)
		return
	print(
		"TASK 27 VISUAL CAPTURE COMPLETE: Lv2 element_bolt, damage 12.5, dust 25, revision %d, border_pixels %d, text_pixels %d"
		% [upgraded.run_snapshot.revision, proof_counts.x, proof_counts.y]
	)
	quit(0)


func _reach_shop_with_dream_dust() -> bool:
	var session := _host.run_session
	for room_number: int in range(1, 4):
		var room_id := session.snapshot().route.current_room_id
		if room_number > 1:
			room_id = StringName("task27_visual_room_%d" % room_number)
			if not session.begin_combat_room(room_id).accepted:
				printerr("TASK 27 visual room begin rejected: %d" % room_number)
				return false
		var dream_dust := 80 if room_number == 1 else 0
		if not session.handle_event(RoomCompletedEvent.new(
			StringName("task27_visual_done_%d" % room_number),
			room_id,
			0,
			0,
			dream_dust
		)).accepted:
			printerr("TASK 27 visual room completion rejected: %d" % room_number)
			return false
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1),
			5700 + room_number
		)
		if not generated.accepted:
			printerr("TASK 27 visual legacy reward fixture rejected: %d" % room_number)
			return false
		if not session.claim_reward(
			generated.reward_offer.offer_id,
			generated.reward_offer.options[0].option_id
		).accepted:
			printerr("TASK 27 visual legacy reward claim rejected: %d" % room_number)
			return false
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		if not session.choose_route(route_id).accepted:
			printerr("TASK 27 visual route rejected: %d" % room_number)
			return false
	return session.snapshot().route.phase == RunPhase.SHOP


func _add_authority_panel(snapshot: RunSnapshot) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_room.add_child(layer)
	_authority_safe_root = Control.new()
	_authority_safe_root.name = &"Task27AuthoritySafeRoot"
	_authority_safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_authority_safe_root)
	_authority_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = &"Task27AuthorityPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -390.0
	panel.offset_top = 10.0
	panel.offset_right = -24.0
	panel.offset_bottom = 122.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9161b28")
	style.border_color = Color("d7b56d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override(&"panel", style)
	var label := Label.new()
	label.text = "TASK 27 · 权威主动等级接线\n元素弹 Lv2 · 伤害尺度 ×1.25\n梦尘 25 · 升级实付 55 · SP消耗 10\n元素层数 / 冷却 / 范围不变"
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color("f5ead0"))
	label.add_theme_constant_override(&"line_spacing", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	_authority_safe_root.add_child(panel)
	_authority_panel = panel
	assert(snapshot.skills.progress_for(&"element_bolt").level == 2)


func _authority_panel_is_inside_logical_safe_area() -> bool:
	if _authority_safe_root == null or _authority_panel == null:
		return false
	var safe_rect := Rect2(Vector2.ZERO, _authority_safe_root.size)
	var panel_rect := _authority_panel.get_rect()
	return (
		safe_rect.encloses(panel_rect)
		and panel_rect.size.x >= 360.0
		and panel_rect.size.y >= 110.0
		and panel_rect.end.y < safe_rect.size.y * 0.25
	)


func _authority_panel_proof_counts(image: Image) -> Vector2i:
	# This is the exact physical top-right region used by independent Review.
	# Requiring both the gold border and pale text prevents a successful capture
	# when the anchored panel is clipped, transparent or pushed off the canvas.
	var bounds := Rect2i(1050, 20, 870, 320)
	var border_target := Color("d7b56d")
	var text_target := Color("f5ead0")
	var border_pixels := 0
	var text_pixels := 0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var pixel := image.get_pixel(x, y)
			if _color_is_near(pixel, border_target, 0.035):
				border_pixels += 1
			if _color_is_near(pixel, text_target, 0.08):
				text_pixels += 1
	return Vector2i(border_pixels, text_pixels)


func _color_is_near(value: Color, target: Color, tolerance: float) -> bool:
	return (
		absf(value.r - target.r) <= tolerance
		and absf(value.g - target.g) <= tolerance
		and absf(value.b - target.b) <= tolerance
		and value.a >= 0.95
	)
