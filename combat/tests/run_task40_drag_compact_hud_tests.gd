extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const DRAG_KIND := &"formal_shop_loadout"

var _harness := TestHarness.new()
var _hit_sequence: int = 4000000
var _coordinator: RunFlowCoordinator
var _hud: CombatHUD
var _overlay: RunOverlayInterface


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(2560, 1440)
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task40_drag_flow"
	_expect(_coordinator != null, "RunGame instantiates for Task40")
	if _coordinator == null:
		_finish()
		return
	root.add_child(_coordinator)
	current_scene = _coordinator
	_expect(await _wait_for_combat(&"combat_01_entry"), "formal run starts in combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface

	_run_test("compact_hud_state_contract", _test_compact_hud_state_contract)
	await _run_async_test("expanded_resolution_programmatic_matrix", _test_expanded_resolution_programmatic_matrix)
	await _run_async_test("formal_drag_click_and_authority_recovery", _test_formal_drag_click_and_authority_recovery)
	await _run_async_test("formal_slot_swap_single_commit", _test_formal_slot_swap_single_commit)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _test_compact_hud_state_contract() -> void:
	var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	var cooldown_mask := active.get_node("Margin/Body/CooldownMask") as ColorRect
	var cooldown_label := active.get_node("Margin/Body/CooldownLabel") as Label
	_expect(not _hud.slot_visible_fields(SkillSlotIds.ACTIVE_1).has(&"cooldown"), "normal castable state has no persistent ready copy")
	_expect(_hud.get_node_or_null("Root/SkillPanel/BusyOverlay/BusyStrip") == null, "purple BusyStrip is not created")
	_expect(_hud.skill_panel.size.is_equal_approx(CombatHUD.SKILL_STRIP_SIZE), "active belt uses the shared density size")
	_expect(_hud.passive_panel.size.is_equal_approx(CombatHUD.PASSIVE_STRIP_SIZE), "passive belt uses the shared density size")
	_expect(_hud.status_panel.size.is_equal_approx(CombatHUD.STATUS_SIZE), "HP/SP capsule uses the shared density size")

	_coordinator.player.energy_component.set_current(0)
	_expect(_is_grayscale(active.get_node("Margin/Body/Icon") as TextureRect), "SP shortage is visible on the icon")
	_coordinator.player.energy_component.set_current(_coordinator.player.energy_component.maximum)
	var skill := _coordinator.player.skill_controller.get_skill_for_slot(SkillSlotIds.ACTIVE_1)
	var cooldowns = _coordinator.player.skill_executor.get("_cooldowns")
	cooldowns.start(skill.skill_id, 2.4)
	_hud.call("_refresh_skill_status")
	_expect(cooldown_mask.visible and cooldown_label.visible and cooldown_label.text == "2.4", "cooldown mask and seconds remain intact")
	cooldowns.advance(30.0)
	_hud.call("_on_cast_attempted", SkillSlotIds.ACTIVE_1, CastAttemptResult.rejected(
		CastAttemptResult.RejectReason.BUSY,
		skill.skill_id,
		&"",
		0.0,
		SkillSlotIds.ACTIVE_1
	))
	_expect(not _hud.feedback_text().is_empty(), "busy rejection keeps recovery feedback without a permanent strip")
	(_hud.get("_slot_transients") as Dictionary).clear()
	_hud.call("_refresh_skill_status")
	_expect(not _hud.slot_visible_fields(SkillSlotIds.ACTIVE_1).has(&"cooldown"), "ready state returns to visually quiet after transient feedback")


func _test_expanded_resolution_programmatic_matrix() -> void:
	var expected_status := CombatHUD.STATUS_SIZE
	var expected_active := CombatHUD.SKILL_STRIP_SIZE
	var expected_passive := CombatHUD.PASSIVE_STRIP_SIZE
	var resolutions: Array[Vector2i] = [
		Vector2i(2560, 1600),
		Vector2i(3840, 2160),
		Vector2i(3440, 1440),
	]
	for viewport_size: Vector2i in resolutions:
		root.size = viewport_size
		await _settle_layout()
		var hud_root := _hud.get_node("Root") as Control
		var bounds := hud_root.get_global_rect()
		var status_rect := _hud.status_panel.get_global_rect()
		var active_rect := _hud.skill_panel.get_global_rect()
		var passive_rect := _hud.passive_panel.get_global_rect()
		_expect(_inside(status_rect, bounds), "status remains in safe bounds at %s" % str(viewport_size))
		_expect(_inside(active_rect, bounds), "active belt remains in safe bounds at %s" % str(viewport_size))
		_expect(_inside(passive_rect, bounds), "passive belt remains in safe bounds at %s" % str(viewport_size))
		_expect(status_rect.size.is_equal_approx(expected_status), "status is not horizontally stretched at %s" % str(viewport_size))
		_expect(active_rect.size.is_equal_approx(expected_active), "active belt is not horizontally stretched at %s" % str(viewport_size))
		_expect(
			passive_rect.size.is_equal_approx(expected_passive),
			"passive belt is not horizontally stretched at %s (actual=%s)" % [str(viewport_size), str(passive_rect.size)]
		)
		_expect(absf(active_rect.get_center().x - bounds.get_center().x) <= 0.2, "central active belt stays centered at %s" % str(viewport_size))
		_expect(not status_rect.intersects(active_rect) and not passive_rect.intersects(active_rect), "core HUD zones remain separated at %s" % str(viewport_size))
		var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
		var icon := active.get_node("Margin/Body/Icon") as TextureRect
		var key_label := active.get_node("Margin/Body/Key/Text") as Label
		_expect(icon.texture != null and icon.size.x >= 32.0 and icon.size.y >= 32.0, "active icon remains readable at %s" % str(viewport_size))
		_expect(key_label.get_theme_font_size(&"font_size") >= 11 and not key_label.text.is_empty(), "keycap remains readable at %s" % str(viewport_size))
	root.size = Vector2i(2560, 1440)
	await _settle_layout()


func _test_formal_drag_click_and_authority_recovery() -> void:
	await _finish_current_room()
	_expect(await _wait_for_combat(&"combat_02_swarm"), "combat one reaches fixed combat two")
	await _finish_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "combat two opens the single physical shop")
	_expect(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 360), "physical shop room becomes active")
	_coordinator.player.global_position = _coordinator.active_shop_room.wishing_crown.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	_expect(_overlay.formal_kind() == &"shop" and _overlay.visible, "formal shop is visible")

	var purchase_burning := _button(&"purchase:burning")
	_expect(purchase_burning != null and not purchase_burning.disabled, "first shop can buy a passive for illegal-direction coverage")
	purchase_burning.pressed.emit()
	await process_frame
	_expect(_coordinator.current_snapshot().skills.owns(&"burning"), "burning ownership is authoritative")
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.PASSIVE_1), &"burning", "new shop passive auto-equips into literal first empty P1")

	var preview := _overlay.call("_formal_drag_preview", _coordinator.host.content_catalog.content_for(&"burning")) as Control
	_expect(preview != null and _all_text(preview).contains("燃烧") and _all_text(preview).contains("PASSIVE 被动"), "drag preview contains short name and type")
	_expect(_first_texture(preview) != null, "drag preview contains the authoritative icon")
	preview.queue_free()

	var before_cancel := _coordinator.current_snapshot()
	var cancelled_payload := _payload(&"element_bolt", &"")
	_expect(bool(_overlay.call("_formal_slot_can_drop", Vector2.ZERO, cancelled_payload, SkillSlotIds.ACTIVE_2)), "owned-card payload is accepted by a formal slot drop target")
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, before_cancel.revision, "cancelled drag changes no revision")
	_expect(_coordinator.current_snapshot().loadout.same_mapping(before_cancel.loadout), "cancelled drag changes no seven-slot mapping")
	var stale_before := _coordinator.current_snapshot()
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_bolt", SkillSlotIds.ACTIVE_3), SkillSlotIds.ACTIVE_2)
	await process_frame
	var stale_after := _coordinator.current_snapshot()
	_expect_eq(stale_after.revision, stale_before.revision, "stale slot source changes no revision")
	_expect(stale_after.loadout.same_mapping(stale_before.loadout), "stale slot source changes no seven-slot mapping")
	_expect(_visible_text(_overlay).contains("拖拽来源已变化"), "stale slot source shows a recoverable short reason")

	var passive_before := _coordinator.current_snapshot()
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"burning", SkillSlotIds.PASSIVE_1), SkillSlotIds.PASSIVE_3)
	await process_frame
	var passive_after := _coordinator.current_snapshot()
	_expect_eq(passive_after.loadout.get_skill_id(SkillSlotIds.PASSIVE_3), &"burning", "auto-equipped passive slot drags from P1 into P3")
	_expect(passive_after.loadout.get_skill_id(SkillSlotIds.PASSIVE_1).is_empty(), "passive drag clears its automatic source P1")
	_expect_eq(passive_after.revision, passive_before.revision + 1, "one passive drop advances revision once")

	var passive_illegal_before := passive_after
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"burning", SkillSlotIds.PASSIVE_3), SkillSlotIds.ACTIVE_2)
	await process_frame
	var passive_illegal_after := _coordinator.current_snapshot()
	_expect_eq(passive_illegal_after.revision, passive_illegal_before.revision, "passive-to-active rejection changes no revision")
	_expect(passive_illegal_after.loadout.same_mapping(passive_illegal_before.loadout), "passive-to-active rejection changes no mapping")
	_expect(_visible_text(_overlay).contains("被动技能不能放入 ACTIVE"), "passive-to-active authority reason is visible")

	var active_before := passive_illegal_after
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_bolt", SkillSlotIds.ACTIVE_1), SkillSlotIds.ACTIVE_3)
	await process_frame
	var active_after := _coordinator.current_snapshot()
	_expect_eq(active_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_3), &"element_bolt", "owned active slot swaps into occupied A3")
	_expect(not active_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1).is_empty(), "active slot swap moves the target skill back to A1")
	_expect_eq(active_after.revision, active_before.revision + 1, "one active drop advances revision once")

	var active_illegal_before := active_after
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_bolt", SkillSlotIds.ACTIVE_3), SkillSlotIds.PASSIVE_2)
	await process_frame
	var active_illegal_after := _coordinator.current_snapshot()
	_expect_eq(active_illegal_after.revision, active_illegal_before.revision, "active-to-passive rejection changes no revision")
	_expect(active_illegal_after.loadout.same_mapping(active_illegal_before.loadout), "active-to-passive rejection changes no mapping")
	_expect(_visible_text(_overlay).contains("主动技能不能放入 PASSIVE"), "active-to-passive authority reason is visible")

	var unowned_before := active_illegal_after
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"passive_vitality", &""), SkillSlotIds.ACTIVE_1)
	await process_frame
	var unowned_after := _coordinator.current_snapshot()
	_expect_eq(unowned_after.revision, unowned_before.revision, "unowned drag rejection changes no revision")
	_expect(unowned_after.loadout.same_mapping(unowned_before.loadout), "unowned drag rejection restores authority mapping")
	var working := _overlay.get("_working_loadout") as RuntimeLoadoutSnapshot
	_expect(working != null and working.same_mapping(unowned_after.loadout), "authority rejection restores the formal working snapshot")

	var click_before := unowned_after
	_button(&"select:element_bolt").pressed.emit()
	await process_frame
	_button(&"slot:active_1").pressed.emit()
	await process_frame
	var click_after := _coordinator.current_snapshot()
	_expect_eq(click_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1), &"element_bolt", "original click-to-slot path remains effective")
	_expect_eq(click_after.revision, click_before.revision + 1, "click path still advances authority once")

	var leave := _button(&"leave_shop")
	_expect(leave != null and leave.disabled, "formal shop cannot bypass the world exit portal")


func _test_formal_slot_swap_single_commit() -> void:
	var chest_owned := _coordinator.current_snapshot()
	var granted := chest_owned.loadout.get_skill_id(SkillSlotIds.ACTIVE_2)
	_expect(not granted.is_empty() and chest_owned.skills.owns(granted), "guaranteed first chest owns an active skill in literal A2")
	_expect(_button(StringName("purchase:%s" % String(granted))) == null, "chest-owned active has no redundant purchase control")
	await process_frame
	var no_purchase := _coordinator.current_snapshot()
	_expect_eq(no_purchase.economy.balance, chest_owned.economy.balance, "chest-owned reclaim causes no shop wallet charge")
	_expect_eq(no_purchase.economy.total_spent_on_purchases, chest_owned.economy.total_spent_on_purchases, "chest-owned reclaim causes no purchase ledger change")
	_expect_eq(no_purchase.revision, chest_owned.revision, "chest-owned reclaim causes no purchase revision")
	_expect(no_purchase.skills.owns(granted), "guaranteed active chest ownership remains authoritative")

	var equip_before := _coordinator.current_snapshot()
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(granted, &""), SkillSlotIds.ACTIVE_3)
	await process_frame
	var equip_after := _coordinator.current_snapshot()
	_expect_eq(equip_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_3), granted, "owned auto-equipped active card drops from A2 into A3")
	_expect(equip_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty(), "active card drag clears automatic A2")
	_expect_eq(equip_after.revision, equip_before.revision + 1, "card drop commits exactly once")

	var swap_before := equip_after
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(granted, SkillSlotIds.ACTIVE_3), SkillSlotIds.ACTIVE_1)
	await process_frame
	var swap_after := _coordinator.current_snapshot()
	_expect_eq(swap_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_3), &"element_bolt", "slot swap moves the target skill back to the source")
	_expect_eq(swap_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1), granted, "slot swap moves the dragged skill into the target")
	_expect_eq(swap_after.revision, swap_before.revision + 1, "one slot-to-slot drop creates one authority revision")
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(swap_after.loadout), "RuntimeLoadout and RunSnapshot remain aligned after swap")
	_expect(_visible_text(_overlay).contains("槽位已互换"), "slot swap has concise success feedback")


func _payload(skill_id: StringName, source_slot_id: StringName) -> Dictionary:
	return {
		"kind": DRAG_KIND,
		"skill_id": skill_id,
		"source_slot_id": source_slot_id,
	}


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button


func _finish_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "active room is configured")
	if room == null:
		return
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat_enemy(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat_enemy(enemy)
	await process_frame
	_expect(room.room_is_cleared, "configured waves clear before Task40 proceeds")
	_coordinator.player.global_position = room.chest.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	_coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center())
	_coordinator.player.interact_requested.emit()
	await process_frame


func _defeat_enemy(enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task40_finisher",
		_coordinator.player.get_instance_id(),
		_coordinator.player.get_instance_id(),
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	var result := enemy.combat_receiver.receive_hit(request)
	_expect(result.accepted and enemy.defeated, "room enemy is defeated through CombatReceiver")


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


func _settle_layout() -> void:
	await process_frame
	await process_frame


func _is_grayscale(icon: TextureRect) -> bool:
	var material := icon.material as ShaderMaterial
	return material != null and is_equal_approx(float(material.get_shader_parameter(&"disabled")), 1.0)


func _visible_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_text(node, lines, true)
	return "\n".join(PackedStringArray(lines))


func _all_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_text(node, lines, false)
	return "\n".join(PackedStringArray(lines))


func _collect_text(node: Node, lines: Array[String], visible_only: bool) -> void:
	if visible_only and node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_text(child, lines, visible_only)


func _first_texture(node: Node) -> Texture2D:
	if node is TextureRect and (node as TextureRect).texture != null:
		return (node as TextureRect).texture
	for child: Node in node.get_children():
		var found := _first_texture(child)
		if found != null:
			return found
	return null


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
	quit(_harness.report("TASK 40 DRAG COMPACT HUD TESTS"))
