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
var _overlay: RunOverlayInterface
var _delivery_serial: int = 24000
var _cast_serial: int = 25000


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
	_overlay = _hud.run_overlay as RunOverlayInterface
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)

	await _run_async_test("dual_anchor_resolution_matrix", _test_dual_anchor_resolution_matrix)
	_run_test("strict_three_active_four_passive_and_compatibility", _test_strict_three_active_four_passive_and_compatibility)
	_run_test("compact_authoritative_state_grammar", _test_compact_authoritative_state_grammar)
	await _run_async_test("target_authority_without_visible_text", _test_target_authority_without_visible_text)
	await _run_async_test("reward_one_two_three_equal_centered", _test_reward_one_two_three_equal_centered)
	await _run_async_test("reward_focus_confirm_guard_and_recovery", _test_reward_focus_confirm_guard_and_recovery)
	await _run_async_test("reward_long_copy_safe_footer", _test_reward_long_copy_safe_footer)
	_run_test("accessibility_modes", _test_accessibility_modes)
	_run_test("single_final_damage_contract", _test_single_final_damage_contract)
	await _run_async_test("real_reward_explicit_confirm", _test_real_reward_explicit_confirm)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 24 COMPACT HUD REWARD TESTS"))


func _test_dual_anchor_resolution_matrix() -> void:
	var resolutions: Array[Vector2i] = [
		Vector2i(1152, 648),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(1366, 768),
		Vector2i(2560, 1600),
		Vector2i(3840, 2160),
		Vector2i(3440, 1440),
		Vector2i(900, 540),
	]
	for viewport_size: Vector2i in resolutions:
		root.size = viewport_size
		await _settle_layout()
		var hud_root := _hud.get_node("Root") as Control
		var bounds := hud_root.get_global_rect()
		var status_rect := _hud.status_panel.get_global_rect()
		var belt_rect := _hud.skill_panel.get_global_rect()
		_expect(status_rect.size.is_equal_approx(CombatHUD.STATUS_SIZE), "status uses the shared HP/SP-only size at %s" % str(viewport_size))
		var passive_rect := _hud.passive_panel.get_global_rect()
		_expect(belt_rect.size.is_equal_approx(CombatHUD.SKILL_STRIP_SIZE), "active skill belt uses the shared density size at %s" % str(viewport_size))
		# Task 72: assert the design intent (passive strip subordinate to the
		# active belt) instead of the pre-task-72 hard-coded width.
		_expect(passive_rect.size.x < belt_rect.size.x, "four-passive strip stays narrower than the active belt at %s" % str(viewport_size))
		_expect(passive_rect.size.y == CombatHUD.PASSIVE_STRIP_SIZE.y, "four-passive strip uses the shared density height at %s" % str(viewport_size))
		_expect(_inside(status_rect, bounds), "status stays in safe canvas at %s" % str(viewport_size))
		_expect(_inside(belt_rect, bounds), "skill belt stays in safe canvas at %s" % str(viewport_size))
		_expect(_inside(passive_rect, bounds), "passive strip stays in safe canvas at %s" % str(viewport_size))
		_expect(not status_rect.intersects(belt_rect), "dual anchors do not overlap at %s" % str(viewport_size))
		_expect(not status_rect.intersects(passive_rect), "status and passive strip remain strictly separated at %s" % str(viewport_size))
		_expect(absf(belt_rect.get_center().x - bounds.get_center().x) <= 0.2, "skill belt remains centered at %s" % str(viewport_size))
		_expect(belt_rect.end.y <= bounds.end.y - 15.9, "skill belt keeps bottom safe margin at %s" % str(viewport_size))
	# Task 72: derive from the HUD's own constants instead of copying literals,
	# so the budget test keeps describing the real panels after a resize.
	var permanent_area := (
		CombatHUD.STATUS_SIZE.x * CombatHUD.STATUS_SIZE.y
		+ CombatHUD.SKILL_STRIP_SIZE.x * CombatHUD.SKILL_STRIP_SIZE.y
		+ CombatHUD.PASSIVE_STRIP_SIZE.x * CombatHUD.PASSIVE_STRIP_SIZE.y
	)
	_expect(permanent_area / (1152.0 * 648.0) * 100.0 < 12.5, "seven-slot HUD stays below 12.5 percent of minimum viewport")
	root.size = Vector2i(1152, 648)
	await _settle_layout()


func _test_strict_three_active_four_passive_and_compatibility() -> void:
	var row := _hud.get_node("Root/SkillPanel/Margin/Skills/SlotRow") as HBoxContainer
	var passive_row := _hud.get_node("Root/PassivePanel/Margin/SlotRow") as HBoxContainer
	_expect(row.get_child_count() == 3, "active belt contains exactly three active slots")
	_expect(passive_row.get_child_count() == 4, "independent low-weight strip contains exactly four passive slots")
	var expected_order: Array[StringName] = [
		SkillSlotIds.ACTIVE_1,
		SkillSlotIds.ACTIVE_2,
		SkillSlotIds.ACTIVE_3,
		SkillSlotIds.PASSIVE_1,
		SkillSlotIds.PASSIVE_2,
		SkillSlotIds.PASSIVE_3,
		SkillSlotIds.PASSIVE_4,
	]
	for slot_id: StringName in expected_order:
		var visible_panel := _hud.visual_slot_panel(slot_id)
		var compatibility_panel := _hud.slot_panel(slot_id)
		_expect(visible_panel != null and visible_panel.name == String(slot_id), "seven-slot projection retains %s" % String(slot_id))
		_expect(compatibility_panel != null and not compatibility_panel.is_visible_in_tree(), "task12 adapter stays resolvable but invisible: %s" % String(slot_id))
		_expect(compatibility_panel.size.x >= 150.0 and compatibility_panel.size.y >= 88.0, "task12 adapter preserves old readable bounds: %s" % String(slot_id))
		_expect(visible_panel.size.y > 0.0, "visible compact footprint has a real area: %s" % String(slot_id))
	for slot_id: StringName in SkillSlotIds.passive():
		_expect(_hud.slot_visible_fields(slot_id) == [&"icon"], "%s is icon-only" % String(slot_id))
	var status := _hud.status_panel.get_node("Margin/Status") as Control
	_expect(status.get_node_or_null("HealthRow/HealthBar/HealthValue") != null and status.get_node_or_null("EnergyRow/EnergyBar/EnergyValue") != null, "status panel retains both HP/SP value paths")
	_expect(status.get_node_or_null("TitleRow") == null and status.get_node_or_null("CurrentElement") == null, "status panel has no title or element projection")
	_expect(not _hud.help_panel.is_visible_in_tree() and not _hud.debug_panel.is_visible_in_tree(), "help and debug are not permanent HUD")


func _test_compact_authoritative_state_grammar() -> void:
	_equip_four()
	var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	var cooldown_label := active.get_node("Margin/Body/CooldownLabel") as Label
	_expect(not _hud.slot_visible_fields(SkillSlotIds.ACTIVE_1).has(&"cooldown"), "available state has no persistent copy")
	_player.energy_component.set_current(0)
	_expect(_is_grayscale(active.get_node("Margin/Body/Icon") as TextureRect), "zero energy grays out the active icon")
	_player.energy_component.set_current(_player.energy_component.maximum)
	var skill := _player.skill_controller.get_skill_for_slot(SkillSlotIds.ACTIVE_1)
	var cooldowns = _player.skill_executor.get("_cooldowns")
	cooldowns.start(skill.skill_id, 2.4)
	_hud.call("_refresh_skill_status")
	_expect(cooldown_label.visible and cooldown_label.text == "2.4", "authority cooldown shows remaining seconds")
	_expect(String(_hud.call("_format_cooldown", 12.2)) == "13", "long cooldown stays integer-short")
	cooldowns.advance(30.0)
	(_hud.get("_slot_transients") as Dictionary).clear()
	var feedback_before := _hud.feedback_text()
	var feedback_visible_before := (_hud.get_node("Root/FeedbackPanel") as Control).visible
	_hud.call("_on_cast_attempted", SkillSlotIds.ACTIVE_1, CastAttemptResult.rejected(CastAttemptResult.RejectReason.BUSY, skill.skill_id, &"", 0.0, SkillSlotIds.ACTIVE_1))
	_expect(_hud.feedback_text() == feedback_before and (_hud.get_node("Root/FeedbackPanel") as Control).visible == feedback_visible_before, "busy rejection does not project FeedbackPanel copy")
	_expect(not (_hud.get("_slot_transients") as Dictionary).has(SkillSlotIds.ACTIVE_1), "busy rejection does not create slot transient text")
	_hud.call("_refresh_skill_status")


func _test_target_authority_without_visible_text() -> void:
	var previous := _enemy.element_carrier.snapshot()
	_enemy.element_carrier.set_amounts_silent(2, 3)
	_enemy.element_carrier.notify_changed(previous)
	await process_frame
	var target_panel := _hud.get_node("Root/TargetPanel") as Control
	var water := target_panel.get_node("Margin/Box/Water") as Label
	var fire := target_panel.get_node("Margin/Box/Fire") as Label
	_expect(water.text.contains("×2") and fire.text.contains("×3"), "target authority data still updates hidden compatibility bindings")
	_expect(not target_panel.is_visible_in_tree() and not _hud.has_visible_target_attachment_text(), "formal target text panel never renders")
	_expect(not _all_visible_text(_hud.get_node("Root")).contains("水滴 WATER"), "no visible target water fallback/follow text exists")
	_expect(not _all_visible_text(_hud.get_node("Root")).contains("火焰 FIRE"), "no visible target fire fallback/follow text exists")
	_enemy.position.x = 1800.0
	await process_frame
	_expect(not target_panel.is_visible_in_tree(), "off-screen authority does not create a text fallback")
	_enemy.position.x = 820.0


func _test_reward_one_two_three_equal_centered() -> void:
	root.size = Vector2i(1152, 648)
	await _settle_layout()
	for count: int in [1, 2, 3]:
		var before_revision := _host.run_session.snapshot().revision
		_overlay.show_reward(_offer(count, false))
		await _settle_layout()
		_expect(_overlay.reward_card_count() == count, "reward binds exactly %d authoritative options" % count)
		_expect(not (_overlay.get("_close") as Button).visible, "reward stage has no fabricated close/cancel")
		var cards_row := _overlay.reward_cards_container()
		var group_rect := Rect2()
		var first_width := -1.0
		for index: int in count:
			var card := _overlay.reward_card(index)
			if index == 0:
				first_width = card.size.x
				group_rect = card.get_global_rect()
			else:
				group_rect = group_rect.merge(card.get_global_rect())
			_expect(is_equal_approx(card.size.x, first_width), "%d-option cards are equal width" % count)
			_expect(card.size.x >= 268.0 and card.size.y >= 300.0, "%d-option cards preserve readable comparison area" % count)
			_expect(card.focus_mode == Control.FOCUS_ALL, "%d-option cards are keyboard/gamepad focusable" % count)
			_expect(card.get_node_or_null("Margin/Content/Description") != null and card.get_node_or_null("Margin/Content/BuildState") != null, "reward card keeps authoritative effect and build-state fields")
		_expect(absf(group_rect.get_center().x - cards_row.get_global_rect().get_center().x) <= 1.0, "%d-option group is centered" % count)
		_expect(_host.run_session.snapshot().revision == before_revision, "%d-option initial focus never claims" % count)
		_expect(_overlay.reward_selected_index() == 0 and not _overlay.reward_confirm_button().disabled, "%d-option stage focuses without auto-claim and exposes confirm" % count)
		_overlay.hide_overlay()


func _test_reward_focus_confirm_guard_and_recovery() -> void:
	var offer := _offer(3, false)
	_overlay.show_reward(offer)
	await _settle_layout()
	var revision_before := _host.run_session.snapshot().revision
	var submit_before := _overlay.reward_submit_count()
	_overlay.reward_card(1).pressed.emit()
	_expect(_overlay.reward_selected_index() == 1, "moving focus changes only the selected candidate")
	_expect(_host.run_session.snapshot().revision == revision_before, "focus action does not call reward authority")
	_expect(not _overlay.reward_card(0).focus_neighbor_right.is_empty() and not _overlay.reward_card(1).focus_neighbor_bottom.is_empty(), "focus order is left-to-right then confirm")
	_overlay.set("_reward_submitting", true)
	_overlay.call("_claim_reward", offer.options[1].option_id)
	_expect(_overlay.reward_submit_count() == submit_before and _host.run_session.snapshot().revision == revision_before, "duplicate-submit guard blocks re-entry before authority")
	_overlay.set("_reward_submitting", false)
	_overlay.call("_confirm_reward_selection")
	await _settle_layout()
	_expect(_overlay.reward_submit_count() == submit_before + 1, "explicit confirm performs exactly one authority attempt")
	_expect(not _overlay.reward_submission_active(), "failed authority attempt exits submitting state")
	_expect(_overlay.reward_selected_index() == 1 and not _overlay.reward_card(1).disabled, "failed submit preserves selected recoverable candidate")
	_expect(not _overlay.reward_confirm_button().disabled, "failed submit re-enables independent confirm")
	_expect(root.gui_get_focus_owner() == _overlay.reward_card(1), "failed submit restores focus to the selected card")
	_overlay.hide_overlay()


func _test_reward_long_copy_safe_footer() -> void:
	root.size = Vector2i(900, 540)
	await _settle_layout()
	_overlay.show_reward(_offer(3, true))
	await _settle_layout()
	var panel_rect := (_overlay.get("_panel") as Control).get_global_rect()
	var confirm_rect := _overlay.reward_confirm_button().get_global_rect()
	_expect(confirm_rect.size.x >= 176.0 and confirm_rect.size.y >= 44.0, "900x540 confirm keeps at least a 44px logical hot area")
	for card: Button in _overlay.get("_reward_cards"):
		_expect(panel_rect.encloses(card.get_global_rect()), "long-copy card stays within overlay panel")
		_expect(not card.get_global_rect().intersects(confirm_rect), "long copy cannot cover the fixed confirmation footer")
		for label: Label in card.find_children("*", "Label", true, false):
			_expect(label.get_theme_font_size(&"font_size") >= 12, "reward body never drops below 12px")
	var description := _overlay.reward_card(0).get_node("Margin/Content/Description") as Label
	_expect(description.max_lines_visible == 4 and description.autowrap_mode != TextServer.AUTOWRAP_OFF, "80-character copy wraps and summarizes within four lines")
	_overlay.hide_overlay()
	root.size = Vector2i(1152, 648)
	await _settle_layout()


func _test_accessibility_modes() -> void:
	_hud.set_colorblind_mode(true)
	var status := _hud.status_panel.get_node("Margin/Status") as Control
	_expect(status.get_node_or_null("CurrentElement") == null and status.get_node_or_null("ElementBadge") == null, "accessibility mode does not recreate element UI in the status panel")
	_hud.set_reduced_motion(true)
	var feedback_panel := _hud.get_node("Root/FeedbackPanel") as Control
	var before_position := feedback_panel.position
	_hud.call("_show_feedback", "减少动态 · 状态语义保持", &"info", 0.1)
	_expect(_hud.reduced_motion and _feedback.reduced_motion, "reduced motion propagates to world feedback")
	_expect(feedback_panel.position.is_equal_approx(before_position), "reduced-motion feedback has no positional animation")
	_expect(_hud.feedback_text().contains("状态语义保持"), "reduced motion preserves status meaning")
	_hud.set_reduced_motion(false)
	_hud.set_colorblind_mode(false)


func _test_single_final_damage_contract() -> void:
	_reset_enemy()
	_enemy.element_carrier.set_amounts_silent(0, 2)
	var groups_before := _feedback.get_child_count()
	var result := _submit_hit(ElementIds.WATER, 2, 10.0)
	_expect(result.accepted and result.reaction_triggered, "committed two-layer reaction remains accepted")
	_expect(result.reaction_consumed == 2 and is_equal_approx(result.reaction_multiplier, 1.6), "authoritative reaction values remain unchanged")
	_expect(_feedback.get_child_count() == groups_before + 1, "one committed hit creates one feedback group")
	var group := _feedback.get_child(_feedback.get_child_count() - 1) as Control
	var final_labels := group.find_children("FinalDamage", "Label", true, false)
	_expect(final_labels.size() == 1 and (final_labels[0] as Label).text == str(result.final_damage), "exactly one final-damage number is rendered")
	var detail := group.get_node("ReactionDetail") as Label
	_expect(detail.text == "反应 ×1.6 · 消耗 2 层" and not detail.text.contains(str(result.final_damage)), "reaction annotation has no duplicate damage number")


func _test_real_reward_explicit_confirm() -> void:
	_reset_enemy()
	var lethal := _submit_hit(ElementIds.NONE, 0, 500.0)
	_expect(lethal.accepted and _enemy.defeated, "real committed combat completes the room")
	await _settle_layout()
	var snapshot := _host.run_session.snapshot()
	_expect(snapshot.pending_reward != null and snapshot.pending_reward.valid, "real RunSession installs an authoritative offer")
	_expect(_overlay.visible and _overlay.reward_card_count() == snapshot.pending_reward.options.size(), "reward_ready opens the formal comparison stage")
	var revision_before_focus := snapshot.revision
	var submit_before := _overlay.reward_submit_count()
	var selected_index := mini(1, snapshot.pending_reward.options.size() - 1)
	_overlay.reward_card(selected_index).pressed.emit()
	_expect(_host.run_session.snapshot().revision == revision_before_focus, "real offer focus still does not claim")
	_overlay.reward_confirm_button().pressed.emit()
	await _settle_layout()
	snapshot = _host.run_session.snapshot()
	_expect(snapshot.pending_reward_claimed, "independent confirm claims through the existing RunSession transaction")
	_expect(_overlay.reward_submit_count() == submit_before + 1 and not _overlay.reward_submission_active(), "real claim submits once and leaves no in-flight state")
	var claimed_revision := snapshot.revision
	_overlay.call("_claim_reward", &"already_claimed_probe")
	_expect(_host.run_session.snapshot().revision == claimed_revision and _overlay.reward_submit_count() == submit_before + 1, "post-success duplicate input cannot re-enter the transaction")
	_expect(_overlay.reward_confirm_button() == null and _overlay.reward_card_count() == 0, "success advances to authoritative route stage")


func _equip_four() -> void:
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, &"elemental_fury"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, &"elemental_laser"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, &"element_reclaim"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"burning"),
	]
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	_expect(result.accepted, "four-slot authority fixture is accepted")
	_hud.call("_refresh_skill_status")


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
		PackedStringArray(["task24"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task24_feedback_probe",
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
			StringName("task24_option_%d_%d_%s" % [count, index, "long" if long_copy else "normal"]),
			RewardType.SKILL,
			ids[index],
			display_name,
			description
		))
	return RewardOffer.new(
		StringName("task24_offer_%d_%s" % [count, "long" if long_copy else "normal"]),
		&"task24_room",
		RewardType.SKILL,
		240 + count,
		options
	)


func _settle_layout() -> void:
	await process_frame
	await process_frame


func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return (
		rect.position.x >= bounds.position.x - 0.1
		and rect.position.y >= bounds.position.y - 0.1
		and rect.end.x <= bounds.end.x + 0.1
		and rect.end.y <= bounds.end.y + 0.1
	)


func _all_visible_text(node: Node) -> String:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return ""
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _all_visible_text(child)
	return result


func _is_grayscale(icon: TextureRect) -> bool:
	var material := icon.material as ShaderMaterial
	return material != null and is_equal_approx(float(material.get_shader_parameter(&"disabled")), 1.0)


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _run_async_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
