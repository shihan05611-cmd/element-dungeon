extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _harness := TestHarness.new()
var _hit_sequence := 84_000_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _harness.run_test("shop_tabs_and_slot_projection", _test_shop_tabs_and_slot_projection)
	quit(_harness.report("TASK 84 SHOP TAB LAYOUT TESTS"))


func _test_shop_tabs_and_slot_projection() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task84_shop_tabs"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_combat(coordinator, &"combat_01_entry"), "run starts")
	await _finish_normal_room(coordinator)
	_expect(await _wait_combat(coordinator, &"combat_02_swarm"), "first room advances")
	await _finish_normal_room(coordinator, false)
	_expect(await _wait_until(func() -> bool: return coordinator.current_snapshot().route.phase == RunPhase.SHOP and coordinator.active_shop_room != null, 360), "shop opens")
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	coordinator.player.global_position = coordinator.active_shop_room.wishing_crown.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	for viewport: Vector2i in [Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport
		await process_frame
		var panel := overlay.get("_panel") as Control
		_expect(panel != null and Rect2(Vector2.ZERO, Vector2(viewport)).encloses(panel.get_global_rect()), "shop fits %s" % str(viewport))
	root.size = Vector2i(1920, 1080)
	var before := _signature(coordinator.current_snapshot())
	_expect(overlay.formal_control(&"shop_tab:purchase") != null and overlay.formal_control(&"shop_tab:upgrade") != null, "both local tabs exist")
	_expect(overlay.formal_control(&"upgrade:element_bolt") == null, "purchase page excludes owned active")
	var upgrade_tab := overlay.formal_control(&"shop_tab:upgrade") as Button
	if upgrade_tab != null:
		upgrade_tab.pressed.emit()
	await process_frame
	_expect(_signature(coordinator.current_snapshot()) == before, "tab switch has no authority mutation")
	_expect(overlay.formal_control(&"upgrade:element_bolt") != null and overlay.formal_control(&"purchase:burning") == null, "upgrade filters to owned active cards")
	_expect(not _tree_text(overlay.formal_area()).contains("累计实付") and not _tree_text(overlay.formal_area()).contains("预计返还"), "upgrade cards remove permanent refund copy")
	var active_row := overlay.formal_area().find_child("ShopActiveSlots", true, false)
	var passive_row := overlay.formal_area().find_child("ShopPassiveSlots", true, false)
	_expect(active_row != null and passive_row != null, "shop owns separate active and passive rows")
	_expect(_tree_text(active_row).contains("A1") and not _tree_text(active_row).contains("空槽"), "active empty slots use label-only blank faces")
	_expect(_tree_text(passive_row).contains("P1") and not _tree_text(passive_row).contains("空槽"), "passive empty slots use label-only blank faces")
	var purchase_tab := overlay.formal_control(&"shop_tab:purchase") as Button
	if purchase_tab != null:
		purchase_tab.pressed.emit()
	await process_frame
	var purchase := overlay.formal_control(&"purchase:burning") as Button
	_expect(purchase != null, "purchase page retains unowned card")
	if purchase != null:
		purchase.pressed.emit()
	await process_frame
	_expect(overlay.formal_control(&"purchase:burning") == null, "purchase refresh preserves tab and removes owned card")
	coordinator.queue_free()
	await process_frame


func _finish_normal_room(coordinator: RunFlowCoordinator, wait_after_portal: bool = true) -> void:
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
	if enemy == null or enemy.defeated:
		return
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task84_finisher", 84, 84, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	enemy.combat_receiver.receive_hit(HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _wait_combat(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool: return coordinator.active_room != null and coordinator.active_room.room_id == room_id and coordinator.current_snapshot().route.phase == RunPhase.COMBAT, 360)


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())


func _signature(snapshot: RunSnapshot) -> Array:
	return [snapshot.revision, snapshot.economy.balance, snapshot.skills.owned_skill_ids]


func _tree_text(node: Node) -> String:
	var value := (node as Label).text if node is Label else (node as Button).text if node is Button else ""
	for child in node.get_children(): value += _tree_text(child)
	return value


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)
