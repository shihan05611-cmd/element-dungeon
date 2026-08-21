extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")

var _harness := TestHarness.new()
var _hit_sequence: int = 3000000
var _coordinator: RunFlowCoordinator
var _hud: CombatHUD
var _overlay: RunOverlayInterface


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1366, 768)
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = _pre_shop_dust_run_id()
	_expect(_coordinator != null, "RunGame instantiates as RunFlowCoordinator")
	if _coordinator == null:
		_finish()
		return
	root.add_child(_coordinator)
	current_scene = _coordinator
	_expect(await _wait_for_combat(&"combat_01_entry"), "formal RunGame boots into combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface

	_run_test("formal_scene_and_seven_slot_hud", _test_formal_scene_and_seven_slot_hud)
	_run_test("combat_semantics_and_accessibility", _test_combat_semantics_and_accessibility)
	await _run_async_test("combat_one_advances_without_route_ui", _test_route_focus_stale_recovery_and_confirm)
	await _run_async_test("single_shop_authority_and_recovery", _test_early_shop_authority_and_recovery)
	await _run_async_test("middle_shop_levels_max_and_second_passive", _test_middle_shop_levels_max_and_second_passive)
	await _run_async_test("combat_three_advances_directly_to_boss", _test_second_route_visible_confirm)
	await _run_async_test("preboss_shop_and_complete_result", _test_preboss_shop_and_complete_result)
	await _run_async_test("new_run_creates_new_authority", _test_new_run_creates_new_authority)
	await _run_async_test("failed_result_is_distinct", _test_failed_result_is_distinct)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _test_formal_scene_and_seven_slot_hud() -> void:
	_expect(_coordinator.get_node_or_null("RunFlowSmokePanel") == null, "formal RunGame has no smoke-panel dependency")
	_expect(_coordinator.get_node_or_null("CombatHUD") == _hud, "formal CombatHUD is a persistent scene sibling")
	_expect(_coordinator.smoke_panel == _hud, "Task29 persistence alias resolves to formal HUD only")
	var active_row := _hud.get_node("Root/SkillPanel/Margin/Skills/SlotRow") as HBoxContainer
	var passive_row := _hud.get_node("Root/PassivePanel/Margin/SlotRow") as HBoxContainer
	_expect_eq(active_row.get_child_count(), 3, "active belt contains A1-A3")
	_expect_eq(passive_row.get_child_count(), 4, "independent passive belt contains P1-P4")
	for slot_id: StringName in SkillSlotIds.all():
		var slot := _hud.visual_slot_panel(slot_id)
		var fields := _hud.slot_visible_fields(slot_id)
		_expect(slot != null and slot.is_visible_in_tree(), "formal HUD exposes %s" % String(slot_id))
		if SkillSlotIds.is_passive(slot_id):
			_expect(fields.has(&"icon") and not fields.has(&"key") and not fields.has(&"cost") and not fields.has(&"cooldown"), "%s projects only its icon while idle" % String(slot_id))
		else:
			_expect(fields.has(&"icon") and not fields.has(&"cooldown"), "%s projects an icon without availability copy" % String(slot_id))
			if _coordinator.player.skill_controller.get_skill_for_slot(slot_id) != null:
				_expect(fields.has(&"key") and fields.has(&"cost"), "%s projects key and SP cost when equipped" % String(slot_id))
	_expect(not _hud.has_visible_target_attachment_text(), "formal HUD has no target attachment text panel")


func _test_combat_semantics_and_accessibility() -> void:
	var hp_copy := _hud.health_value.text
	var sp_copy := _hud.energy_value.text
	var element_shape := (_hud.element_pivot_panel().get_node("Body/ElementShape") as Label).text
	var element_copy := (_hud.element_pivot_panel().get_node("Body/ElementText") as Label).text
	_expect(hp_copy.contains("/"), "HP exposes current and maximum")
	_expect(sp_copy.contains("/"), "SP exposes current and maximum")
	_expect(not element_shape.is_empty() and not element_copy.is_empty(), "CurrentElement uses shape plus short text")
	var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	_expect(_hud.slot_visible_fields(SkillSlotIds.ACTIVE_1).has(&"cost"), "A1 exposes its SP cost")
	_expect(not _hud.slot_visible_fields(SkillSlotIds.ACTIVE_1).has(&"cooldown"), "A1 does not show cooldown copy while ready")
	_hud.set_colorblind_mode(true)
	_hud.set_reduced_motion(true)
	_expect(_hud.colorblind_mode and _hud.reduced_motion, "colorblind and reduced-motion modes are independently enabled")
	_expect(not (_hud.element_pivot_panel().get_node("Body/ElementShape") as Label).text.is_empty(), "colorblind mode preserves element shape")
	_hud.set_colorblind_mode(false)
	_hud.set_reduced_motion(false)
	_expect(not _visible_text(_hud).is_empty(), "combat HUD keeps visible semantic copy")
	_expect(_inside(_hud.status_panel.get_global_rect(), Rect2(Vector2.ZERO, Vector2(root.size))), "status panel stays inside 1366x768")
	_expect(_inside(_hud.skill_panel.get_global_rect(), Rect2(Vector2.ZERO, Vector2(root.size))), "active belt stays inside 1366x768")
	_expect(_inside(_hud.passive_panel.get_global_rect(), Rect2(Vector2.ZERO, Vector2(root.size))), "passive belt stays inside 1366x768")


func _test_early_shop_authority_and_recovery() -> void:
	await _finish_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "combat two opens the single shop")
	_expect(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 360), "physical shop room becomes active")
	_coordinator.player.global_position = _coordinator.active_shop_room.wishing_crown.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	_expect(_overlay.visible and _overlay.formal_kind() == &"shop", "formal shop opens automatically")
	_expect(_inside(_overlay.get("_panel").get_global_rect(), Rect2(Vector2.ZERO, Vector2(root.size))), "shop panel stays inside 1366x768")
	var before := _coordinator.current_snapshot()
	_expect(before.economy.balance >= 220, "single shop projects two-room authoritative base balance")
	_expect(not _visible_text(_overlay).is_empty(), "shop presents visible economy and loadout information")

	var upgrade := _button(&"upgrade:element_bolt")
	_expect(upgrade != null and not upgrade.disabled, "owned active exposes independent upgrade")
	upgrade.pressed.emit()
	await process_frame
	var upgraded := _coordinator.current_snapshot()
	_expect_eq(upgraded.skills.progress_for(&"element_bolt").level, 2, "visible upgrade commits authoritative Lv2")
	_expect_eq(upgraded.economy.balance, before.economy.balance - 55, "visible upgrade charges authoritative price")

	var second_upgrade_revision := upgraded.revision
	_button(&"upgrade:element_bolt").pressed.emit()
	await process_frame
	var maximum := _coordinator.current_snapshot()
	_expect_eq(maximum.revision, second_upgrade_revision + 1, "second exact upgrade advances revision once")
	_expect_eq(maximum.skills.progress_for(&"element_bolt").level, 3, "single-shop budget reaches frozen maximum level")
	var max_reject := _coordinator.upgrade_shop_skill(&"element_bolt", maximum.revision, maximum.shop.session_id)
	_expect(not max_reject.accepted and max_reject.reject_reason == RunCommandResult.RejectReason.MAX_LEVEL_REACHED, "authority rejects a false fourth level")

	var reset_request := _button(&"reset:element_bolt")
	var reset_focus_revision := maximum.revision
	var reset_focus_balance := maximum.economy.balance
	reset_request.pressed.emit()
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, reset_focus_revision, "reset focus does not submit")
	_expect_eq(_coordinator.current_snapshot().economy.balance, reset_focus_balance, "reset focus does not refund")
	_expect(_button(&"reset_confirm:element_bolt") != null and _button(&"reset_cancel:element_bolt") != null, "reset exposes independent confirm and cancel")
	_expect(not _visible_text(_overlay).is_empty(), "reset confirmation presents an estimate")
	_button(&"reset_confirm:element_bolt").pressed.emit()
	await process_frame
	var reset := _coordinator.current_snapshot()
	_expect_eq(reset.skills.progress_for(&"element_bolt").level, 1, "confirmed reset returns active to Lv1")
	_expect_eq(reset.economy.balance, reset_focus_balance + 105, "confirmed reset refunds exact authoritative floor")

	var purchase := _button(&"purchase:passive_vitality")
	_expect(purchase != null and not purchase.disabled, "fixed passive offer has visible purchase control")
	purchase.pressed.emit()
	await process_frame
	var purchased := _coordinator.current_snapshot()
	_expect(purchased.skills.owns(&"passive_vitality"), "visible purchase commits ownership")
	_expect_eq(purchased.economy.balance, reset.economy.balance - 75, "visible purchase charges exact price")

	_button(&"select:passive_vitality").pressed.emit()
	await process_frame
	var loadout_revision := _coordinator.current_snapshot().revision
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.PASSIVE_1), &"passive_vitality", "purchase already auto-equips the first passive into P1")
	_button(&"slot:passive_1").pressed.emit()
	await process_frame
	var equipped := _coordinator.current_snapshot()
	_expect_eq(equipped.loadout.get_skill_id(SkillSlotIds.PASSIVE_1), &"passive_vitality", "visible P1 action commits RuntimeLoadout immediately")
	_expect_eq(equipped.revision, loadout_revision, "reselecting the already auto-equipped P1 mapping is idempotent")
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(equipped.loadout), "runtime and RunSnapshot mappings align immediately")
	_expect(_button(&"leave_shop").disabled and not _button(&"leave_shop").text.is_empty(), "shop UI keeps a disabled physical-exit affordance")


func _test_route_focus_stale_recovery_and_confirm() -> void:
	await _finish_current_room()
	_expect(await _wait_for_combat(&"combat_02_swarm"), "combat one portal loads the fixed second combat")
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.route_choices, 0, "direct transition records no route choice")
	_expect_eq(snapshot.route.next_options.size(), 0, "direct transition exposes no route options")
	_expect(_overlay.formal_kind() != &"route", "route panel never opens in the demo flow")


func _test_middle_shop_levels_max_and_second_passive() -> void:
	_expect(await _wait_for_phase(RunPhase.SHOP), "single shop remains open for level and passive controls")
	_button(&"upgrade:element_bolt").pressed.emit()
	await process_frame
	_button(&"upgrade:element_bolt").pressed.emit()
	await process_frame
	var maximum := _coordinator.current_snapshot()
	_expect_eq(maximum.skills.progress_for(&"element_bolt").level, 3, "two visible upgrades reach Lv3")
	var max_button := _button(&"upgrade:element_bolt")
	_expect(max_button != null and max_button.disabled, "max-level UI blocks a false fourth upgrade")
	var max_reject := _coordinator.upgrade_shop_skill(&"element_bolt", maximum.revision, maximum.shop.session_id)
	_expect(not max_reject.accepted and max_reject.reject_reason == RunCommandResult.RejectReason.MAX_LEVEL_REACHED, "authority rejects max-level request")
	_expect_eq(_coordinator.current_snapshot().revision, maximum.revision, "max-level rejection keeps all authority state")
	var unending_purchase := _button(&"purchase:unending")
	_expect(unending_purchase != null, "middle shop keeps unowned fixed passive offer")
	unending_purchase.pressed.emit()
	await process_frame
	_button(&"select:unending").pressed.emit()
	await process_frame
	_button(&"slot:passive_2").pressed.emit()
	await process_frame
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.PASSIVE_2), &"unending", "P2 immediate equip is authoritative")
	_expect_eq(_coordinator.current_snapshot().loadout.entries.size(), 7, "shop preserves exact seven-slot mapping")
	_expect(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 360), "physical shop room is active")
	_coordinator.player.global_position = _coordinator.active_shop_room.exit_portal.global_position
	_coordinator.player.interact_requested.emit()
	_expect(await _wait_for_combat(&"combat_04_validation"), "physical shop exit loads combat four")


func _test_second_route_visible_confirm() -> void:
	await _finish_current_room()
	_expect(await _wait_for_combat(&"combat_06_final_boss"), "combat three loads Boss directly")
	_expect_eq(_coordinator.current_snapshot().route.route_choices, 0, "pre-Boss transition records no route choice")
	_expect(_overlay.formal_kind() != &"route", "no second route UI appears")


func _test_preboss_shop_and_complete_result() -> void:
	_expect(await _wait_for_combat(&"combat_06_final_boss"), "Boss remains active for settlement verification")
	var host_id := _coordinator.host.get_instance_id()
	var session_id := _coordinator.host.run_session.get_instance_id()
	var player_id := _coordinator.player.get_instance_id()
	var hud_id := _hud.get_instance_id()
	var runtime_id := _coordinator.host.runtime_loadout.get_instance_id()
	var boss_balance := _coordinator.current_snapshot().economy.balance
	await _finish_current_room()
	_expect(await _wait_for_phase(RunPhase.RUN_COMPLETE), "boss settlement chest opens complete result")
	var final := _coordinator.current_snapshot()
	_expect(final.result != null and final.result.is_complete(), "result is frozen complete")
	_expect_eq(final.result.completed_combat_rooms, 4, "result shows four of four combats")
	_expect_eq(final.result.shop_visits, 1, "result freezes one shop visit")
	_expect_eq(final.result.route_choices, 0, "result freezes zero route confirmations")
	_expect_eq(final.economy.balance, boss_balance, "boss awards zero dream dust")
	_expect(final.shop == null and final.pending_reward == null, "boss result has no fourth shop or free reward")
	_expect(_overlay.formal_kind() == &"result" and _overlay.visible, "formal result replaces shop/route UI")
	_expect(not _visible_text(_overlay).is_empty(), "complete result presents its summary")
	_expect(_button(&"new_run") != null and not _button(&"new_run").disabled, "result exposes enabled new-run action")
	_expect(_button(&"return_entry") != null and _button(&"return_entry").disabled, "undefined title entry is explicit and safely disabled")
	_expect_eq(_coordinator.host.get_instance_id(), host_id, "Host persists through full run")
	_expect_eq(_coordinator.host.run_session.get_instance_id(), session_id, "RunSession persists through full run")
	_expect_eq(_coordinator.player.get_instance_id(), player_id, "Player persists through full run")
	_expect_eq(_hud.get_instance_id(), hud_id, "formal HUD persists through full run")
	_expect_eq(_coordinator.host.runtime_loadout.get_instance_id(), runtime_id, "RuntimeLoadout persists through full run")


func _test_new_run_creates_new_authority() -> void:
	var previous_coordinator_id := _coordinator.get_instance_id()
	var previous_session_id := _coordinator.host.run_session.get_instance_id()
	var previous_run_id := _coordinator.current_snapshot().route.run_id
	_button(&"new_run").pressed.emit()
	await process_frame
	await process_frame
	var replacement := current_scene as RunFlowCoordinator
	_expect(replacement != null and replacement.get_instance_id() != previous_coordinator_id, "new-run action reloads a new RunGame")
	if replacement == null:
		return
	_coordinator = replacement
	_expect(await _wait_for_combat(&"combat_01_entry"), "new RunGame boots into fresh combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface
	_expect(_coordinator.host.run_session.get_instance_id() != previous_session_id, "new run creates a new RunSession")
	_expect(_coordinator.current_snapshot().route.run_id != previous_run_id, "new run has a distinct run id")
	_expect_eq(_coordinator.current_snapshot().route.completed_combat_rooms, 0, "new run resets formal progress by authority")


func _test_failed_result_is_distinct() -> void:
	var before := _coordinator.current_snapshot()
	_hit_sequence += 1
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task30_player_defeat",
		_coordinator.active_enemies[0].get_instance_id(),
		_coordinator.active_enemies[0].get_instance_id(),
		&"enemy",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(cast, payload, _hit_sequence, 0, _coordinator.player.global_position, Vector2.LEFT)
	var hit := _coordinator.player.combat_receiver.receive_hit(request)
	_expect(hit.accepted, "real CombatReceiver accepts lethal player hit")
	_expect(await _wait_for_phase(RunPhase.RUN_FAILED), "player defeat opens failure result")
	var failed := _coordinator.current_snapshot()
	_expect(failed.result != null and not failed.result.is_complete(), "failure result is frozen and distinct")
	_expect_eq(failed.result.completed_combat_rooms, before.route.completed_combat_rooms, "failure grants no room completion")
	_expect_eq(failed.economy.total_earned, before.economy.total_earned, "failure grants no dream dust")
	_expect(not _visible_text(_overlay).is_empty(), "failure result presents a distinct summary")
	_expect(_button(&"new_run") != null and not _button(&"new_run").disabled, "failure result retains keyboard-focusable recovery")


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button


func _pre_shop_dust_run_id() -> StringName:
	for index: int in 256:
		var run_id := StringName("task30_ui_flow_%03d" % index)
		var session := RunSession.new(
			CATALOG.reward_definitions(), CATALOG.relic_definitions,
			CATALOG.initial_owned_skill_ids(), [ElementIds.WATER, ElementIds.FIRE],
			null, null, RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
		)
		if not session.start_formal_run(&"start", 0).accepted:
			continue
		var first := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_first", session.snapshot().revision, first.room_id, 30_000 + index * 2, first.room_scene.resource_path).accepted:
			continue
		if not session.claim_formal_room_chest(&"claim_first", session.snapshot().revision, first.room_id).accepted:
			continue
		if not session.handle_event(RoomCompletedEvent.new(&"complete_first", first.room_id, 0, 0, first.completion_dream_dust, false)).accepted:
			continue
		var second := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_second", session.snapshot().revision, second.room_id, 30_001 + index * 2, second.room_scene.resource_path).accepted:
			continue
		var claim := session.claim_formal_room_chest(&"claim_second", session.snapshot().revision, second.room_id)
		if claim.accepted and claim.chest_reward.kind == RunChestRewardSnapshot.Kind.DREAM_DUST:
			return run_id
	_expect(false, "a deterministic second-room dust cohort exists for the UI economy path")
	return &"task30_ui_flow_fallback"


func _finish_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "visible run has configured active room")
	if room == null:
		return
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat_enemy(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat_enemy(enemy)
	await process_frame
	_expect(room.room_is_cleared, "all configured enemies clear before world interaction")
	_coordinator.player.global_position = room.chest.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	if room.room_definition.final_boss:
		return
	_coordinator.player.global_position = room.portal.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame


func _defeat_enemy(enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task30_ui_finisher",
		_coordinator.player.get_instance_id(),
		_coordinator.player.get_instance_id(),
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	var result := enemy.combat_receiver.receive_hit(request)
	_expect(result.accepted and enemy.defeated, "room enemy defeated through real CombatReceiver")


func _wait_for_combat(node_or_option_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		if _coordinator == null or _coordinator.host == null or _coordinator.host.run_session == null:
			return false
		var snapshot := _coordinator.current_snapshot()
		return (
			snapshot.route.phase == RunPhase.COMBAT
			and _coordinator.active_room != null
			and (
				_coordinator.active_room.room_id == node_or_option_id
				or snapshot.route.selected_option_id == node_or_option_id
			)
		)
	, 480)


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == phase
		)
	, 480)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _visible_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_visible_text(node, lines)
	return "\n".join(PackedStringArray(lines))


func _collect_visible_text(node: Node, lines: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_visible_text(child, lines)


func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return (
		rect.position.x >= bounds.position.x - 0.2
		and rect.position.y >= bounds.position.y - 0.2
		and rect.end.x <= bounds.end.x + 0.2
		and rect.end.y <= bounds.end.y + 0.2
	)


func _run_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _finish() -> void:
	quit(_harness.report("TASK 30 RUN UI TESTS"))
