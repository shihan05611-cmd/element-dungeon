extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")

var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _hud: CombatHUD
var _feedback: CombatFeedback
var _host: RunSessionHost
var _overlay
var _delivery_serial: int = 9000
var _cast_serial: int = 7000


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
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)

	_run_test("formal_four_slot_hud_and_icons", _test_formal_four_slot_hud_and_icons)
	await _run_async_test("responsive_fixed_layout", _test_responsive_fixed_layout)
	_run_test("element_text_shape_and_colorblind", _test_element_text_shape_and_colorblind)
	_run_test("three_policy_and_future_element_preview", _test_three_policy_and_future_element_preview)
	_run_test("structured_failure_feedback", _test_structured_failure_feedback)
	_run_test("manual_lock_and_auto_feedback", _test_manual_lock_and_auto_feedback)
	_run_test("active_slot_rejects_passive", _test_active_slot_rejects_passive)
	_run_test("passive_slot_rejects_active", _test_passive_slot_rejects_active)
	_run_test("zero_active_four_passive_warning", _test_zero_active_four_passive_warning)
	_run_test("single_final_number_two_layer_reaction", _test_single_final_number_two_layer_reaction)
	_run_test("actual_consumption_one_layer", _test_actual_consumption_one_layer)
	_run_test("reduced_motion_preserves_semantics", _test_reduced_motion_preserves_semantics)
	await _run_async_test("reward_to_shop_ui_wiring", _test_reward_to_shop_ui_wiring)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 12 HUD LOADOUT FEEDBACK TESTS"))


func _test_formal_four_slot_hud_and_icons() -> void:
	_expect(_hud != null and _overlay != null, "formal HUD and run overlay exist")
	var panels: Array[PanelContainer] = []
	for slot_id: StringName in [SkillSlotIds.ACTIVE_1, SkillSlotIds.ACTIVE_2, SkillSlotIds.ACTIVE_3, SkillSlotIds.PASSIVE_1]:
		var panel := _hud.slot_panel(slot_id)
		panels.append(panel)
		_expect(panel != null, "slot panel exists: %s" % String(slot_id))
		_expect(panel.size.x >= 150.0 and panel.size.y >= 88.0, "slot has stable readable bounds: %s" % String(slot_id))
	_expect(panels.size() == 4, "exactly four shared slot panels are exposed")
	var active_one := _hud.slot_panel(SkillSlotIds.ACTIVE_1)
	var icon := active_one.get_node("Margin/Box/Content/Icon") as TextureRect
	_expect(icon.texture != null and icon.texture.resource_path == CATALOG.content_for(&"element_bolt").icon.resource_path, "HUD consumes catalog element bolt icon")
	_expect((active_one.get_node("Margin/Box/Top/Key") as Control).visible, "equipped active skill shows keycap")
	_expect(not (_hud.slot_panel(SkillSlotIds.PASSIVE_1).get_node("Margin/Box/Top/Key") as Control).visible, "PASSIVE_1 never shows a cast keycap")
	_expect(_hud.get_node_or_null("Root/StatusPanel/Margin/Status/TitleRow") == null and _hud.get_node_or_null("Root/StatusPanel/Margin/Status/CurrentElement") == null, "status panel removes legacy title and element nodes")
	_expect((_hud.get_node("Root/TargetPanel/Margin/Box/Water") as Label).text.contains("水滴") and (_hud.get_node("Root/TargetPanel/Margin/Box/Fire") as Label).text.contains("火焰"), "target layers use shape and text")


func _test_responsive_fixed_layout() -> void:
	for viewport_size: Vector2i in [Vector2i(1152, 648), Vector2i(900, 540), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		var root_control := _hud.get_node("Root") as Control
		var status_rect := _hud.status_panel.get_global_rect()
		var skill_rect := _hud.skill_panel.get_global_rect()
		var help_rect := _hud.help_panel.get_global_rect()
		var target_rect := (_hud.get_node("Root/TargetPanel") as Control).get_global_rect()
		_expect(_inside(status_rect, root_control.size), "status inside %s" % str(viewport_size))
		_expect(_inside(skill_rect, root_control.size), "four slots inside %s" % str(viewport_size))
		_expect(_inside(help_rect, root_control.size), "help inside %s" % str(viewport_size))
		_expect(_inside(target_rect, root_control.size), "target layers inside %s" % str(viewport_size))
		_expect(not status_rect.intersects(skill_rect), "status and slots do not overlap at %s" % str(viewport_size))
		var previous_end := -INF
		for slot_id: StringName in [SkillSlotIds.ACTIVE_1, SkillSlotIds.ACTIVE_2, SkillSlotIds.ACTIVE_3, SkillSlotIds.PASSIVE_1]:
			var rect := _hud.slot_panel(slot_id).get_global_rect()
			_expect(rect.position.x >= previous_end, "slot order does not overlap at %s" % str(viewport_size))
			previous_end = rect.end.x
	root.size = Vector2i(1152, 648)
	await process_frame


func _test_element_text_shape_and_colorblind() -> void:
	var water_label := (_hud.get_node("Root/TargetPanel/Margin/Box/Water") as Label).text
	var fire_label := (_hud.get_node("Root/TargetPanel/Margin/Box/Fire") as Label).text
	var normal_water := _hud.call("_element_color", ElementIds.WATER) as Color
	_hud.set_colorblind_mode(true)
	var assisted_water := _hud.call("_element_color", ElementIds.WATER) as Color
	_expect(normal_water != assisted_water, "colorblind mode changes semantic palette")
	_expect(water_label.contains("WATER") and water_label.contains("水滴"), "water remains identified without color")
	_expect(fire_label.contains("FIRE") and fire_label.contains("火焰"), "fire remains identified without color")
	_expect(_hud.colorblind_mode and _overlay.colorblind_mode, "colorblind mode propagates to loadout UI")
	_hud.set_colorblind_mode(false)


func _test_three_policy_and_future_element_preview() -> void:
	_overlay.show_loadout()
	var current_skill := CATALOG.gameplay_for(&"element_bolt")
	var exclusive_skill := CATALOG.gameplay_for(&"burning")
	var neutral_skill := CATALOG.fixed_basic_attack_definition()
	var current_text := String(_overlay.call("_policy_text", current_skill))
	var exclusive_text := String(_overlay.call("_policy_text", exclusive_skill))
	var neutral_text := String(_overlay.call("_policy_text", neutral_skill))
	_expect(current_skill.element_policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT and not current_text.is_empty(), "CURRENT_ELEMENT policy has a visible explanation")
	_expect(exclusive_skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT and not exclusive_text.is_empty(), "EXCLUSIVE_ELEMENT policy has a visible explanation")
	_expect(neutral_skill.element_policy == SkillDefinition.ElementPolicy.NEUTRAL and not neutral_text.is_empty(), "NEUTRAL policy has a visible explanation")
	_expect(not String(_overlay.call("_element_text", &"earth")).is_empty(), "third element has a generic accessible label")
	_expect(not String(_overlay.call("_element_text", &"wind")).is_empty(), "fourth element has a generic accessible label")
	_expect((_overlay.get("_slot_row") as HBoxContainer).get_child_count() == 7, "future element previews preserve the strict three-active/four-passive zones")
	_overlay.hide_overlay()


func _test_structured_failure_feedback() -> void:
	_hud.call("_show_reject_feedback", CastAttemptResult.rejected(CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, &"element_bolt", &"", 0.0, SkillSlotIds.ACTIVE_1))
	var energy_text := _hud.feedback_text()
	_hud.call("_show_reject_feedback", CastAttemptResult.rejected(CastAttemptResult.RejectReason.COOLDOWN_ACTIVE, &"element_reclaim", &"", 2.4, SkillSlotIds.ACTIVE_1))
	var cooldown_text := _hud.feedback_text()
	_hud.call("_show_reject_feedback", CastAttemptResult.rejected(CastAttemptResult.RejectReason.BUSY, &"element_bolt", &"", 0.0, SkillSlotIds.ACTIVE_1))
	var busy_text := _hud.feedback_text()
	_expect(not energy_text.is_empty(), "energy rejection has feedback")
	_expect(cooldown_text.contains("2.4"), "cooldown rejection includes the remaining time")
	_expect(not busy_text.is_empty(), "busy rejection has feedback")
	_expect(energy_text != cooldown_text and cooldown_text != busy_text and energy_text != busy_text, "energy cooldown and busy cannot be confused")


func _test_manual_lock_and_auto_feedback() -> void:
	_player.skill_executor.advance(2.0)
	var manual := _player.request_element(ElementIds.FIRE)
	_expect(manual.accepted and manual.changed, "manual switch commits")
	_expect(not _hud.feedback_text().is_empty(), "manual switch has feedback")
	var current_policy := (_hud.slot_panel(SkillSlotIds.ACTIVE_1).get_node("Margin/Box/Content/Text/Policy") as Label).text
	_expect(not current_policy.is_empty(), "manual switch immediately updates the dynamic badge")
	_player.energy_component.set_current(100)
	var accepted := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(accepted.accepted, "current-element cast accepted")
	_expect(_hud.feedback_text().contains("FIRE"), "accepted common skill identifies its locked element")
	var exclusive := SkillDefinition.new()
	exclusive.skill_id = &"qa_exclusive"
	exclusive.element_policy = SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
	exclusive.required_element_id = ElementIds.WATER
	var exclusive_snapshot := _cast_snapshot(ElementIds.WATER, &"qa_exclusive")
	var auto_text := _hud.cast_acceptance_feedback(exclusive, "模拟专属", SkillSlotIds.ACTIVE_2, exclusive_snapshot, true)
	_expect(auto_text.contains("ACTIVE_2") and auto_text.contains("WATER"), "exclusive accepted feedback identifies its slot and element")
	var failed := CastAttemptResult.rejected(CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, &"qa_exclusive", &"")
	_hud.call("_on_cast_attempted", SkillSlotIds.ACTIVE_2, failed)
	_expect(not _hud.feedback_text().is_empty() and _hud.feedback_text() != auto_text, "failed exclusive cast replaces the success feedback")
	_player.skill_executor.advance(2.0)


func _test_active_slot_rejects_passive() -> void:
	_overlay.show_loadout()
	var before: RuntimeLoadoutSnapshot = _overlay.current_preview()
	var detail: StringName = _overlay.try_preview_assignment(&"burning", SkillSlotIds.ACTIVE_2)
	var after: RuntimeLoadoutSnapshot = _overlay.current_preview()
	_expect(detail == &"passive_skill_in_active_slot", "ACTIVE slot rejects PASSIVE through runtime validation")
	_expect(after.same_mapping(before), "rejected passive drop does not mutate preview")
	_expect(after.entries.size() == 7, "strict preview keeps the complete seven-slot snapshot")
	_expect(after.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty(), "rejected active slot stays empty")


func _test_passive_slot_rejects_active() -> void:
	var before: StringName = _overlay.current_preview().get_skill_id(SkillSlotIds.PASSIVE_1)
	var detail: StringName = _overlay.try_preview_assignment(&"element_bolt", SkillSlotIds.PASSIVE_1)
	var after: StringName = _overlay.current_preview().get_skill_id(SkillSlotIds.PASSIVE_1)
	_expect(detail == &"active_skill_in_passive_slot", "PASSIVE_1 rejects ACTIVE through runtime validation")
	_expect(before == after, "rejected drop does not mutate preview")
	_expect(not String((_overlay.get("_status") as Label).text).is_empty(), "rejection gives a visible reason")


func _test_zero_active_four_passive_warning() -> void:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"burning"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, &"unending"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4),
	]
	_overlay.set_preview_snapshot(RuntimeLoadoutSnapshot.new(entries, _host.runtime_loadout.snapshot().revision))
	_expect(_overlay.zero_active_warning_visible(), "zero-active warning is visible")
	_expect(not (_overlay.get("_warning") as Label).text.is_empty(), "zero-active warning explains the consequence")
	_expect(not (_overlay.get("_confirm") as Button).disabled or not (_overlay.get("_confirm") as Button).text.is_empty(), "warning itself does not erase confirmation semantics")
	for slot_id: StringName in SkillSlotIds.all():
		var slot_key := "按键 %s" % ("1" if slot_id == SkillSlotIds.ACTIVE_1 else "2" if slot_id == SkillSlotIds.ACTIVE_2 else "3" if slot_id == SkillSlotIds.ACTIVE_3 else "—")
		_expect(not _all_text(_overlay.slot_card(slot_id)).contains(slot_key), "four-passive preview has no cast key: %s" % String(slot_id))
	_expect(_overlay.current_preview().entries.size() == 7, "legacy HUD preview retains the full seven-slot authority")
	_expect(
		_overlay.current_preview().get_skill_id(SkillSlotIds.PASSIVE_1) == &"burning"
		and _overlay.current_preview().get_skill_id(SkillSlotIds.PASSIVE_2) == &"unending",
		"strict passive mappings survive without prebuilding the task30 HUD"
	)
	_overlay.set_preview_snapshot(_host.runtime_loadout.snapshot())
	_overlay.hide_overlay()


func _test_single_final_number_two_layer_reaction() -> void:
	_reset_enemy()
	_enemy.element_carrier.set_amounts_silent(0, 2)
	var before := _feedback.get_child_count()
	var result := _submit_hit(ElementIds.WATER, 2, 10.0)
	_expect(result.accepted and result.reaction_triggered, "two-layer reaction commits")
	_expect(result.reaction_consumed == 2 and is_equal_approx(result.reaction_multiplier, 1.6), "two layers produce actual 1.6 multiplier")
	_expect(_feedback.get_child_count() == before + 1, "one feedback group is spawned")
	var group := _feedback.get_child(_feedback.get_child_count() - 1) as Control
	var final_label := group.get_node("FinalDamage") as Label
	var detail := group.get_node("ReactionDetail") as Label
	_expect(final_label.text == str(result.final_damage), "only one final damage number is displayed")
	_expect(detail.text == "反应 ×1.6 · 消耗 2 层", "reaction annotation contains multiplier and consumed layers")
	_expect(group.find_children("FinalDamage", "Label", true, false).size() == 1, "feedback has one final-damage label")
	_expect(not _feedback.semantic_damage_summary(result).is_empty(), "semantic summary is available for the resolved hit")


func _test_actual_consumption_one_layer() -> void:
	_reset_enemy()
	_enemy.element_carrier.set_amounts_silent(1, 0)
	var result := _submit_hit(ElementIds.FIRE, 4, 10.0)
	_expect(result.accepted and result.reaction_consumed == 1, "many incoming fire layers consume only one available water layer")
	_expect(is_equal_approx(result.reaction_multiplier, 1.3), "multiplier uses actual one-layer consumption")
	var lines := _feedback.presentation_text(result)
	_expect(lines.size() == 2 and lines[1] == "反应 ×1.3 · 消耗 1 层", "feedback reports actual one layer")
	_expect(not lines[1].contains(str(result.final_damage)), "reaction annotation does not fabricate a second damage number")


func _test_reduced_motion_preserves_semantics() -> void:
	_hud.set_reduced_motion(true)
	_expect(_hud.reduced_motion and _feedback.reduced_motion, "reduced motion propagates to combat feedback")
	_hud.call("_show_feedback", "元素锁定 · 水滴 水 · WATER", &"lock", 0.1)
	_expect(_hud.feedback_text().contains("WATER"), "reduced motion preserves the accessible element label")
	var result := _submit_hit(ElementIds.NONE, 0, 5.0)
	var lines := _feedback.presentation_text(result)
	_expect(lines.size() == 1 and lines[0] == str(result.final_damage), "reduced motion preserves final damage text")
	_hud.set_reduced_motion(false)


func _test_reward_to_shop_ui_wiring() -> void:
	_reset_enemy()
	var result := _submit_hit(ElementIds.NONE, 0, 500.0)
	_expect(result.accepted and _enemy.defeated, "room-ending committed hit defeats target")
	await process_frame
	var snapshot := _host.run_session.snapshot()
	_expect(snapshot.pending_reward != null and snapshot.pending_reward.valid, "host generated authoritative reward offer")
	_expect(_overlay.visible and (_overlay.get("_reward_area") as Control).visible, "reward_ready opens reward UI")
	var option := snapshot.pending_reward.options[0]
	_overlay.call("_claim_reward", option.option_id)
	await process_frame
	snapshot = _host.run_session.snapshot()
	_expect(snapshot.pending_reward_claimed, "reward UI claims through RunSession")
	# The authoritative director offers a shop every third completed room.
	# Advance two more real room/reward cycles rather than inventing a shop phase in UI.
	for room_number: int in [2, 3]:
		var next_route := snapshot.route.next_options[0]
		_overlay.call("_choose_route", next_route.option_id)
		await process_frame
		var begin := _host.begin_next_room(StringName("room_%d" % room_number), [_enemy])
		_expect(begin.accepted, "host begins authoritative room %d" % room_number)
		_reset_enemy()
		var room_hit := _submit_hit(ElementIds.NONE, 0, 500.0)
		_expect(room_hit.accepted and _enemy.defeated, "room %d completes through committed combat" % room_number)
		await process_frame
		snapshot = _host.run_session.snapshot()
		_expect(snapshot.pending_reward != null and not snapshot.pending_reward_claimed, "room %d installs reward" % room_number)
		_overlay.call("_claim_reward", snapshot.pending_reward.options[0].option_id)
		await process_frame
		snapshot = _host.run_session.snapshot()
		_expect(snapshot.pending_reward_claimed, "room %d reward claimed through UI" % room_number)
	var shop_option: RouteOption
	for route_option: RouteOption in snapshot.route.next_options:
		if route_option.kind == RouteOption.Kind.SHOP:
			shop_option = route_option
			break
	_expect(shop_option != null, "authoritative third-room route offers shop")
	if shop_option != null:
		_overlay.call("_choose_route", shop_option.option_id)
		await process_frame
		_expect(_host.run_session.snapshot().route.phase == RunPhase.SHOP, "route UI enters authoritative shop phase")
		_expect((_overlay.get("_shop_draft") as ShopDraft) != null, "shop UI opens authoritative ShopDraft")
		_expect(not (_overlay.get("_confirm") as Button).disabled, "shop confirm is enabled only with live draft")
		_overlay.call("_confirm_shop")
		await process_frame
		_expect(not _overlay.visible, "successful shop confirmation closes overlay")


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
		PackedStringArray(["task12"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task12_feedback_probe",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	var request := HitRequest.new(snapshot, payload, _delivery_serial, 0, _enemy.global_position, Vector2.RIGHT)
	return _enemy.combat_receiver.receive_hit(request)


func _cast_snapshot(element_id: StringName, skill_id: StringName) -> CastSnapshot:
	_cast_serial += 1
	return CastSnapshot.new(
		_cast_serial,
		skill_id,
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		CombatStatSnapshot.new()
	)


func _reset_enemy() -> void:
	_enemy.defeated = false
	_enemy.hurt_time = 0.0
	_enemy.attack_time = 0.0
	_enemy.combat_receiver.accepting_hits = true
	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	_enemy.element_carrier.clear_all(false)


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
