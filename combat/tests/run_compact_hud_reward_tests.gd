extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _hud: CombatHUD
var _feedback: CombatFeedback
var _host: RunSessionHost
var _overlay
var _delivery_serial: int = 20000
var _cast_serial: int = 21000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_feedback = _room.get_node("WorldFeedbackLayer") as CombatFeedback
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_overlay = _hud.run_overlay
	_player.set_physics_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)

	await _run_async_test("dual_anchor_layout", _test_dual_anchor_layout)
	_run_test("occupancy_budget", _test_occupancy_budget)
	_run_test("strict_three_active_four_passive_semantics", _test_strict_three_active_four_passive_semantics)
	_run_test("compact_state_grammar", _test_compact_state_grammar)
	await _run_async_test("hidden_target_authority_projection", _test_hidden_target_authority_projection)
	_run_test("accessibility_modes", _test_accessibility_modes)
	_run_test("single_final_damage_contract", _test_single_final_damage_contract)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 20 COMPACT HUD REWARD TESTS"))


func _test_dual_anchor_layout() -> void:
	for viewport_size: Vector2i in [Vector2i(1152, 648), Vector2i(900, 540)]:
		root.size = viewport_size
		await process_frame
		var status_rect := _hud.status_panel.get_global_rect()
		var belt_rect := _hud.skill_panel.get_global_rect()
		var passive_rect := _hud.passive_panel.get_global_rect()
		_expect(status_rect.size.is_equal_approx(Vector2(264, 76)), "status capsule size at %s" % str(viewport_size))
		_expect(belt_rect.size.is_equal_approx(Vector2(532, 72)), "active skill belt size at %s" % str(viewport_size))
		# Task 72: assert the design intent (passive strip reads as subordinate to
		# the active belt) rather than a hard-coded width. The old `>= 496.0`
		# pinned the pre-task-72 layout and would have to be rewritten on every
		# resize; the ratio survives further shrinking of the passive slots.
		_expect(passive_rect.size.x < belt_rect.size.x, "passive strip stays narrower than the active belt at %s" % str(viewport_size))
		_expect(passive_rect.size.y >= 40.0, "passive strip keeps a legible height at %s" % str(viewport_size))
		_expect(_inside(_physical_rect(_hud.status_panel), viewport_size), "status capsule remains in viewport at %s" % str(viewport_size))
		_expect(_inside(_physical_rect(_hud.skill_panel), viewport_size), "skill belt remains in viewport at %s" % str(viewport_size))
		_expect(_inside(_physical_rect(_hud.passive_panel), viewport_size), "passive strip remains in viewport at %s" % str(viewport_size))
		_expect(not status_rect.intersects(belt_rect), "dual anchors never overlap at %s" % str(viewport_size))
		_expect(not status_rect.intersects(passive_rect), "status and passive anchors never overlap at %s" % str(viewport_size))
		for slot_id: StringName in SkillSlotIds.all():
			var rect := _hud.visual_slot_panel(slot_id).get_global_rect()
			_expect(rect.size.x >= 44.0 and rect.size.y >= 44.0, "slot focus footprint >=44 at %s / %s" % [str(viewport_size), String(slot_id)])
	root.size = Vector2i(1152, 648)
	await process_frame


func _test_occupancy_budget() -> void:
	var canvas_area := 1152.0 * 648.0
	# Task 72: derive from the HUD's own constants instead of copying literals.
	# The old hard-coded 496*54 kept "passing" after the layout changed while no
	# longer describing any real panel -- a budget test measuring stale numbers.
	var permanent_area := (
		CombatHUD.STATUS_SIZE.x * CombatHUD.STATUS_SIZE.y
		+ CombatHUD.SKILL_STRIP_SIZE.x * CombatHUD.SKILL_STRIP_SIZE.y
		+ CombatHUD.PASSIVE_STRIP_SIZE.x * CombatHUD.PASSIVE_STRIP_SIZE.y
	)
	var peak_area := permanent_area + 360.0 * 36.0
	_expect(permanent_area / canvas_area <= 0.125, "seven-slot permanent HUD budget <=12.5%")
	_expect(peak_area / canvas_area <= 0.145, "feedback peak <=14.5%")


func _test_strict_three_active_four_passive_semantics() -> void:
	for slot_id: StringName in SkillSlotIds.all():
		_expect(_hud.slot_panel(slot_id) != null, "shared slot exists: %s" % String(slot_id))
	_expect((_hud.get_node("Root/SkillPanel/Margin/Skills/SlotRow") as HBoxContainer).get_child_count() == 4, "active belt contains CurrentElement plus A1-A3")
	_expect((_hud.get_node("Root/PassivePanel/Margin/SlotRow") as HBoxContainer).get_child_count() == 4, "independent passive strip contains P1-P4")
	for slot_id: StringName in SkillSlotIds.passive():
		var passive := _hud.visual_slot_panel(slot_id)
		_expect(not (passive.get_node("Margin/Body/Key") as Control).visible, "%s has no false keycap" % String(slot_id))
		_expect(not (passive.get_node("Margin/Body/Cost") as Control).visible, "%s has no false SP cost" % String(slot_id))
	var pivot_shape := (_hud.get_node("Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementShape") as Label).text
	var pivot_text := (_hud.get_node("Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementText") as Label).text
	_expect(not pivot_shape.is_empty() and pivot_text.contains("水"), "CurrentElement pivot combines shape and short text")


func _test_compact_state_grammar() -> void:
	var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	var state := active.get_node("Margin/Body/State") as Label
	_expect(state.text.is_empty() and not state.visible, "ready state stays visually quiet")
	_player.energy_component.set_current(0)
	_expect(state.text == "能量", "zero energy uses short resource word")
	_hud.call("_on_cast_attempted", SkillSlotIds.ACTIVE_1, CastAttemptResult.rejected(CastAttemptResult.RejectReason.COOLDOWN_ACTIVE, &"element_bolt", &"", 2.4, SkillSlotIds.ACTIVE_1))
	_expect(state.text == "失败", "cooldown rejection uses compact failure state")
	_expect(String(_hud.call("_format_cooldown", 12.2)) == "13", "cooldown >=10 uses integer seconds")
	_hud.call("_on_cast_attempted", SkillSlotIds.ACTIVE_1, CastAttemptResult.rejected(CastAttemptResult.RejectReason.BUSY, &"element_bolt", &"", 0.0, SkillSlotIds.ACTIVE_1))
	_expect(state.text == "失败", "busy rejection stays distinct from false success")
	_expect(_hud.feedback_text().contains("动作结束后重试"), "busy failure keeps recovery guidance in feedback")
	_player.energy_component.set_current(_player.energy_component.maximum)
	_hud.call("_expire_slot_transients")


func _test_hidden_target_authority_projection() -> void:
	var previous := _enemy.element_carrier.snapshot()
	_enemy.element_carrier.set_amounts_silent(2, 3)
	_enemy.element_carrier.notify_changed(previous)
	await process_frame
	var target_panel := _hud.get_node("Root/TargetPanel") as Control
	_expect(_all_text(target_panel).contains("×2") and _all_text(target_panel).contains("×3"), "hidden compatibility binding still consumes authority layers")
	_expect(not target_panel.is_visible_in_tree() and not _hud.has_visible_target_attachment_text(), "formal HUD exposes no target attachment text")
	_enemy.position.x = 1800.0
	await process_frame
	_expect(not target_panel.is_visible_in_tree(), "off-screen authority creates no text fallback")
	_enemy.position.x = 820.0


func _test_reward_one_two_three_layout() -> void:
	root.size = Vector2i(1152, 648)
	for count: int in [1, 2, 3]:
		_overlay.show_reward(_offer(count, false))
		await process_frame
		_expect(_overlay.reward_card_count() == count, "reward binds actual %d options" % count)
		var cards_row := _overlay.get("_reward_cards_row") as HBoxContainer
		var group_rect := Rect2()
		for index: int in count:
			var card := cards_row.get_child(index) as Button
			_expect(card.size.is_equal_approx(Vector2(328, 344)), "%d-option card uses 328x344" % count)
			group_rect = card.get_global_rect() if index == 0 else group_rect.merge(card.get_global_rect())
		_expect(absf(group_rect.get_center().x - 576.0) <= 1.5, "%d-option group is centered" % count)
		_expect((_overlay.get("_close") as Button).visible == false, "reward has no fabricated cancel control")
		_overlay.hide_overlay()
	root.size = Vector2i(900, 540)
	_overlay.show_reward(_offer(3, false))
	await process_frame
	for card: Button in _overlay.get("_reward_cards"):
		_expect(card.size.is_equal_approx(Vector2(268, 320)), "900x540 card uses 268x320")
	_overlay.hide_overlay()
	root.size = Vector2i(1152, 648)
	await process_frame


func _test_reward_focus_and_explicit_confirm() -> void:
	var offer := _offer(3, false)
	_overlay.show_reward(offer)
	await process_frame
	var before_revision := _host.run_session.snapshot().revision
	var cards: Array[Button] = _overlay.get("_reward_cards")
	cards[1].pressed.emit()
	_expect(_overlay.reward_selected_index() == 1, "first card action only changes focused candidate")
	_expect(_host.run_session.snapshot().revision == before_revision, "focus navigation does not submit reward")
	var confirm: Button = _overlay.reward_confirm_button()
	_expect(confirm != null and confirm.text.contains("2"), "independent confirm reflects focused candidate")
	_expect(not cards[0].focus_neighbor_right.is_empty() and not cards[1].focus_neighbor_bottom.is_empty(), "focus order is left-to-right then confirm")
	_overlay.set("_reward_submitting", true)
	_overlay.call("_claim_reward", offer.options[1].option_id)
	_expect(_host.run_session.snapshot().revision == before_revision, "duplicate submit guard blocks re-entry")
	_overlay.set("_reward_submitting", false)
	_overlay.hide_overlay()
	var single := _offer(1, false)
	_overlay.show_reward(single)
	await process_frame
	_expect(_overlay.reward_selected_index() == 0 and _overlay.reward_confirm_button().visible, "single option still requires explicit focus and confirm")
	_overlay.hide_overlay()


func _test_reward_long_copy_bounds() -> void:
	_overlay.show_reward(_offer(3, true))
	await process_frame
	var panel_rect := (_overlay.get("_panel") as Control).get_global_rect()
	for card: Button in _overlay.get("_reward_cards"):
		_expect(panel_rect.encloses(card.get_global_rect()), "80-character reward card stays within comparison panel")
		for label: Label in card.find_children("*", "Label", true, false):
			_expect(label.get_theme_font_size(&"font_size") >= 12, "reward body never drops below 12px")
	_overlay.hide_overlay()


func _test_accessibility_modes() -> void:
	var normal_water := _hud.call("_element_color", ElementIds.WATER) as Color
	_hud.set_colorblind_mode(true)
	var assisted_water := _hud.call("_element_color", ElementIds.WATER) as Color
	_expect(normal_water != assisted_water, "colorblind palette changes without removing text")
	_expect(_all_text(_hud.get_node("Root/TargetPanel")).contains("水滴") and _all_text(_hud.get_node("Root/TargetPanel")).contains("火焰"), "color is not the only element signal")
	_hud.set_reduced_motion(true)
	_hud.call("_show_feedback", "元素锁定 · 水滴◇ WATER", &"lock", 0.1)
	_expect(_hud.reduced_motion and _feedback.reduced_motion, "reduced motion propagates to world feedback")
	_expect(_hud.feedback_text().contains("元素锁定"), "reduced motion preserves semantic timing")
	_hud.set_reduced_motion(false)
	_hud.set_colorblind_mode(false)


func _test_single_final_damage_contract() -> void:
	_reset_enemy()
	_enemy.element_carrier.set_amounts_silent(0, 2)
	var groups_before := _feedback.get_child_count()
	var result := _submit_hit(ElementIds.WATER, 2, 10.0)
	_expect(result.accepted and result.reaction_triggered, "committed two-layer reaction remains accepted")
	_expect(result.reaction_consumed == 2 and is_equal_approx(result.reaction_multiplier, 1.6), "formal two-layer reaction values are unchanged")
	_expect(_feedback.get_child_count() == groups_before + 1, "one committed hit creates one feedback group")
	var group := _feedback.get_child(_feedback.get_child_count() - 1) as Control
	var final_labels := group.find_children("FinalDamage", "Label", true, false)
	_expect(final_labels.size() == 1 and (final_labels[0] as Label).text == str(result.final_damage), "exactly one final-damage number is rendered")
	var detail := group.get_node("ReactionDetail") as Label
	_expect(detail.text == "反应 ×1.6 · 消耗 2 层" and not detail.text.contains(str(result.final_damage)), "annotation keeps multiplier and actual consumption without a duplicate number")


func _submit_hit(element_id: StringName, element_amount: int, offensive_damage: float) -> CombatResult:
	_delivery_serial += 1
	_cast_serial += 1
	var stats := CombatStatSnapshot.new(1.0, 0.0)
	var payload := RuntimeAttackPayload.from_locked_inputs(
		stats.effective_attack,
		offensive_damage / stats.effective_attack,
		0.0,
		offensive_damage,
		element_id,
		element_amount,
		PackedStringArray(["task20"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task20_feedback_probe",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	var request := HitRequest.new(snapshot, payload, _delivery_serial, 0, _enemy.global_position, Vector2.RIGHT)
	return _enemy.combat_receiver.receive_hit(request)


func _reset_enemy() -> void:
	_enemy.defeated = false
	_enemy.hurt_time = 0.0
	_enemy.attack_time = 0.0
	_enemy.combat_receiver.accepting_hits = true
	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	_enemy.element_carrier.clear_all(false)


func _offer(count: int, long_copy: bool) -> RewardOffer:
	var ids: Array[StringName] = [&"elemental_fury", &"elemental_laser", &"burning"]
	var names := ["元素之怒", "Elemental Laser With A Deliberately Long Authoritative Display Name", "燃烧"]
	var options: Array[RewardOption] = []
	for index: int in count:
		var description := "权威效果说明：本候选只投影正式内容字段。"
		if long_copy:
			description = "这是用于八十个中文字符压力验证的权威测试说明，内容会自动换行并在固定卡片操作安全区之前收束，不会横向越界、挤掉独立确认路径，也不会借此生成任何新规则、评分、稀有度、重随或取消能力。"
		options.append(RewardOption.new(StringName("task20_option_%d_%d" % [count, index]), RewardType.SKILL, ids[index], names[index], description))
	return RewardOffer.new(StringName("task20_offer_%d" % count), &"task20_room", RewardType.SKILL, 20 + count, options)


func _physical_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var raw_size := Vector2(root.size)
	var hud_root := _hud.get_node("Root") as Control
	var render_scale := Vector2(
		minf(1.0, raw_size.x / maxf(hud_root.size.x, 1.0)),
		minf(1.0, raw_size.y / maxf(hud_root.size.y, 1.0))
	)
	return Rect2(rect.position * render_scale, rect.size * render_scale)


func _inside(rect: Rect2, viewport_size: Vector2) -> bool:
	return rect.position.x >= -0.1 and rect.position.y >= -0.1 and rect.end.x <= viewport_size.x + 0.1 and rect.end.y <= viewport_size.y + 0.1


func _all_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _all_text(child)
	return result


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _run_async_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
