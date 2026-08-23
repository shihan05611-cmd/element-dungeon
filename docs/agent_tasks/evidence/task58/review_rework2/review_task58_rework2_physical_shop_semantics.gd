extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _hit_sequence := 58_930_000
var _checks := 0
var _failures: Array[String] = []
var _shop_observations: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task58_review_rework2_physical_shop"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_combat(coordinator, &"combat_01_entry"), "RunGame starts Battle01")
	await _finish_room(coordinator)
	_expect(await _wait_combat(coordinator, &"combat_02_swarm"), "Battle01 reaches Battle02")
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	var commands: Array[StringName] = []
	coordinator.ui_command_result.connect(func(command: StringName, _result: RunCommandResult) -> void: commands.append(command))
	var callback := func(snapshot: RunSnapshot, cause: StringName) -> void:
		if snapshot == null or snapshot.route.phase != RunPhase.SHOP:
			return
		_shop_observations.append({
			"cause": cause,
			"visible": overlay.visible,
			"kind": overlay.formal_kind(),
			"draft": overlay.formal_shop_draft_instance_id(),
			"active_room": coordinator.active_shop_room != null,
			"revision": snapshot.revision,
		})
	coordinator.host.session_snapshot_changed.connect(callback)
	await _finish_room(coordinator, false)
	_expect(_shop_observations.size() == 1, "external listener captures initial SHOP snapshot synchronously")
	var initial: Dictionary = _shop_observations[0]
	_expect(not bool(initial["visible"]), "initial SHOP snapshot is hidden in the same signal stack")
	_expect(not bool(initial["active_room"]), "initial SHOP callback precedes deferred room entry")
	_expect(int(initial["draft"]) == 0, "initial SHOP snapshot creates no draft")
	_expect(await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 360), "physical shop room becomes active")
	var shop := coordinator.active_shop_room
	_expect(not overlay.visible and overlay.formal_kind() != &"shop", "physical shop room starts without merchant content")
	_expect(overlay.formal_shop_draft_instance_id() == 0, "room activation creates no draft")
	var authority_before := _authority_signature(coordinator.current_snapshot())

	await _press_physical_l(coordinator)
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "physical L opens existing global loadout content")
	_expect(overlay.formal_control(&"leave_shop") == null and overlay.formal_control(&"purchase:burning") == null and overlay.formal_control(&"upgrade:element_bolt") == null, "L content has no merchant controls")
	_expect(overlay.formal_shop_draft_instance_id() == 0, "physical L creates no draft")
	_expect(_authority_signature(coordinator.current_snapshot()) == authority_before and commands.is_empty(), "physical L submits no transaction")
	await _press_physical_l(coordinator)
	_expect(not overlay.visible, "second physical L closes global loadout content")

	coordinator.player.global_position = shop.wishing_crown.global_position + Vector2(500, 0)
	await _press_physical_f()
	_expect(not overlay.visible and overlay.formal_kind() != &"shop", "far physical F opens no merchant")
	_expect(overlay.formal_shop_draft_instance_id() == 0 and commands.is_empty(), "far F creates no draft or command")
	coordinator.player.global_position = shop.wishing_crown.global_position
	await _press_physical_f()
	_expect(overlay.visible and overlay.formal_kind() == &"shop", "near crown physical F opens merchant content")
	_expect(_authority_signature(coordinator.current_snapshot()) == authority_before, "crown F mutates no authority")
	var draft_id := overlay.formal_shop_draft_instance_id()
	_expect(draft_id != 0, "crown F creates one draft")
	await _press_physical_f()
	_expect(overlay.formal_shop_draft_instance_id() == draft_id, "repeated crown F reuses the draft")
	_expect(commands.is_empty(), "repeated crown F submits no command")

	var purchase_skill_id := &""
	for offer: ShopOfferSnapshot in coordinator.current_snapshot().shop.offers:
		if not coordinator.current_snapshot().skills.owns(offer.skill_id) and offer.purchase_price <= coordinator.current_snapshot().economy.balance:
			purchase_skill_id = offer.skill_id
			break
	_expect(not purchase_skill_id.is_empty(), "one affordable unowned offer exists")
	var purchase_button := overlay.formal_control(StringName("purchase:%s" % String(purchase_skill_id))) as Button
	_expect(purchase_button != null and not purchase_button.disabled, "merchant exposes purchase control")
	var before_purchase_observations := _shop_observations.size()
	if purchase_button != null:
		purchase_button.pressed.emit()
	await process_frame
	_expect(_shop_observations.size() == before_purchase_observations + 1, "purchase emits one SHOP snapshot")
	var purchase_observation: Dictionary = _shop_observations[-1]
	_expect(StringName(purchase_observation["cause"]) == &"shop_skill_purchased", "purchase callback has typed cause")
	_expect(bool(purchase_observation["visible"]) and StringName(purchase_observation["kind"]) == &"shop", "purchase snapshot keeps merchant visible")
	_expect(bool(purchase_observation["active_room"]) and int(purchase_observation["draft"]) == draft_id, "purchase snapshot keeps room and same draft")
	_expect(commands == [&"purchase_skill"], "purchase records exactly one command")

	var upgrade_button := overlay.formal_control(&"upgrade:element_bolt") as Button
	_expect(upgrade_button != null and not upgrade_button.disabled, "merchant exposes affordable active upgrade")
	var before_upgrade_observations := _shop_observations.size()
	if upgrade_button != null:
		upgrade_button.pressed.emit()
	await process_frame
	_expect(_shop_observations.size() == before_upgrade_observations + 1, "upgrade emits one SHOP snapshot")
	var upgrade_observation: Dictionary = _shop_observations[-1]
	_expect(StringName(upgrade_observation["cause"]) == &"active_skill_upgraded", "upgrade callback has typed cause")
	_expect(bool(upgrade_observation["visible"]) and StringName(upgrade_observation["kind"]) == &"shop", "upgrade snapshot keeps merchant visible")
	_expect(bool(upgrade_observation["active_room"]) and int(upgrade_observation["draft"]) == draft_id, "upgrade snapshot keeps room and same draft")
	_expect(commands == [&"purchase_skill", &"upgrade_skill"], "purchase and upgrade each submit once")

	var close_button := overlay.formal_control(&"close_shop_panel") as Button
	_expect(close_button != null and not close_button.disabled, "merchant exposes close control")
	if close_button != null:
		close_button.pressed.emit()
	await process_frame
	_expect(not overlay.visible, "close returns to physical crown world")
	var after_transactions := _authority_signature(coordinator.current_snapshot())
	await _press_physical_l(coordinator)
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "post-close L opens only global loadout")
	_expect(overlay.formal_control(&"leave_shop") == null and overlay.formal_control(&"upgrade:element_bolt") == null, "post-close L has no merchant controls")
	_expect(overlay.formal_shop_draft_instance_id() == draft_id, "post-close L creates no replacement draft")
	_expect(_authority_signature(coordinator.current_snapshot()) == after_transactions and commands == [&"purchase_skill", &"upgrade_skill"], "post-close L adds no transaction")
	await _press_physical_l(coordinator)
	_expect(not overlay.visible, "second post-close L returns to world")
	await _press_physical_f()
	_expect(overlay.visible and overlay.formal_kind() == &"shop" and overlay.formal_shop_draft_instance_id() == draft_id, "crown F reopens the same merchant draft")

	print("INITIAL=" + JSON.stringify(initial))
	print("PURCHASE=" + JSON.stringify(purchase_observation))
	print("UPGRADE=" + JSON.stringify(upgrade_observation))
	if coordinator.host.session_snapshot_changed.is_connected(callback):
		coordinator.host.session_snapshot_changed.disconnect(callback)
	coordinator.queue_free()
	await process_frame
	current_scene = null
	if _failures.is_empty():
		print("TASK58 REWORK2 REVIEW PHYSICAL SHOP SEMANTICS PASSED: %d checks" % _checks)
		quit(0)
	else:
		printerr("TASK58 REWORK2 REVIEW PHYSICAL SHOP SEMANTICS FAILED: %d failures / %d checks" % [_failures.size(), _checks])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _finish_room(coordinator: RunFlowCoordinator, wait_after_portal: bool = true) -> void:
	var room := coordinator.active_room
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat(enemy)
	await process_frame
	coordinator.player.global_position = room.chest.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center())
	coordinator.player.interact_requested.emit()
	if wait_after_portal:
		await process_frame


func _defeat(enemy: CombatEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.defeated:
		return
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task58_review_finisher", 58, 58, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _press_physical_l(coordinator: RunFlowCoordinator) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_L
	coordinator.combat_hud._unhandled_input(event)
	await process_frame


func _press_physical_f() -> void:
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _wait_combat(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.active_room != null and coordinator.active_room.room_id == room_id and coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 360)


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [snapshot.revision, snapshot.route.phase, snapshot.route.current_room_id, snapshot.economy.balance, snapshot.economy.total_spent_on_purchases, snapshot.economy.total_spent_on_upgrades, snapshot.shop.session_id if snapshot.shop != null else &""]


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
