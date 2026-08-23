extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _hit_sequence := 58_910_000
var _failures: Array[String] = []
var _snapshot_observations: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task58_review_rework1_shop"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_combat(coordinator, &"combat_01_entry"), "formal RunGame starts Battle01")
	await _finish_normal_room(coordinator)
	_expect(await _wait_combat(coordinator, &"combat_02_swarm"), "Battle01 reaches Battle02")

	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	var first_shop := {"seen": false, "overlay": true, "active_room": true, "cause": &""}
	var callback := func(snapshot: RunSnapshot, cause: StringName) -> void:
		if snapshot == null or snapshot.route.phase != RunPhase.SHOP:
			return
		var observation := {
			"cause": cause,
			"overlay": overlay.visible,
			"active_room": coordinator.active_shop_room != null,
			"revision": snapshot.revision,
		}
		_snapshot_observations.append(observation)
		if not bool(first_shop["seen"]):
			first_shop["seen"] = true
			first_shop["overlay"] = overlay.visible
			first_shop["active_room"] = coordinator.active_shop_room != null
			first_shop["cause"] = cause
	coordinator.host.session_snapshot_changed.connect(callback)

	# Deliberately return from the portal interaction without awaiting a process
	# frame. The external callback above is the third real RunGame listener and
	# records the state at the end of the same authority signal stack.
	await _finish_normal_room(coordinator, false)
	_expect(bool(first_shop["seen"]), "external listener sees the initial SHOP snapshot synchronously")
	_expect(not bool(first_shop["overlay"]), "Overlay is false inside the external initial SHOP callback")
	_expect(not bool(first_shop["active_room"]), "active_shop_room is null inside the external initial SHOP callback")
	_expect(not overlay.visible and coordinator.active_shop_room == null, "signal stack returns before deferred entry and remains hidden")
	print("INITIAL_SHOP_CAUSE=%s" % String(first_shop["cause"]))
	print("INITIAL_SHOP_OVERLAY=%s" % str(first_shop["overlay"]))
	print("INITIAL_SHOP_ACTIVE_ROOM=%s" % str(first_shop["active_room"]))

	_expect(await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 360), "deferred shop room becomes active")
	var shop := coordinator.active_shop_room
	_expect(not overlay.visible, "shop room begins with Overlay hidden")
	coordinator.player.global_position = shop.wishing_crown.global_position + Vector2(500, 0)
	coordinator.player.interact_requested.emit()
	_expect(not overlay.visible, "interaction away from the crown does not open Overlay")
	var signature_before := _authority_signature(coordinator.current_snapshot())
	coordinator.player.global_position = shop.wishing_crown.global_position
	coordinator.player.interact_requested.emit()
	_expect(overlay.visible and overlay.formal_kind() == &"shop", "nearby crown F is the opening entry")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), signature_before, "crown opening mutates no authority")

	var before_purchase_count := _snapshot_observations.size()
	var purchase := coordinator.purchase_first_affordable_skill()
	_expect(purchase.accepted, "existing shop room accepts an authoritative purchase")
	_expect(_snapshot_observations.size() == before_purchase_count + 1, "purchase emits one synchronous SHOP snapshot")
	var purchase_observation: Dictionary = _snapshot_observations[-1]
	_expect(bool(purchase_observation["active_room"]), "purchase snapshot observes the existing shop room")
	_expect(bool(purchase_observation["overlay"]), "purchase snapshot does not hide the open Overlay")
	_expect(overlay.visible, "Overlay remains visible after purchase returns")
	print("PURCHASE_CAUSE=%s" % String(purchase_observation["cause"]))
	print("PURCHASE_OVERLAY=%s" % str(purchase_observation["overlay"]))
	print("PURCHASE_ACTIVE_ROOM=%s" % str(purchase_observation["active_room"]))

	var before_upgrade_count := _snapshot_observations.size()
	var before_upgrade := coordinator.current_snapshot()
	var upgrade := coordinator.upgrade_shop_skill(&"element_bolt", before_upgrade.revision, before_upgrade.shop.session_id)
	_expect(upgrade.accepted, "existing shop room accepts the initial active skill upgrade")
	_expect(_snapshot_observations.size() == before_upgrade_count + 1, "upgrade emits one synchronous SHOP snapshot")
	var upgrade_observation: Dictionary = _snapshot_observations[-1]
	_expect(bool(upgrade_observation["active_room"]), "upgrade snapshot observes the existing shop room")
	_expect(bool(upgrade_observation["overlay"]), "upgrade snapshot does not hide the open Overlay")
	_expect(overlay.visible, "Overlay remains visible after upgrade returns")
	print("UPGRADE_CAUSE=%s" % String(upgrade_observation["cause"]))
	print("UPGRADE_OVERLAY=%s" % str(upgrade_observation["overlay"]))
	print("UPGRADE_ACTIVE_ROOM=%s" % str(upgrade_observation["active_room"]))

	if coordinator.host.session_snapshot_changed.is_connected(callback):
		coordinator.host.session_snapshot_changed.disconnect(callback)
	coordinator.queue_free()
	await process_frame
	current_scene = null
	if _failures.is_empty():
		print("TASK58 REWORK1 REVIEW SHOP DIAGNOSTIC PASSED: 3 synchronous snapshots, %d checks" % 21)
		quit(0)
	else:
		printerr("TASK58 REWORK1 REVIEW SHOP DIAGNOSTIC FAILED: %d failures" % _failures.size())
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


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
	if enemy == null or not is_instance_valid(enemy) or enemy.defeated:
		return
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task58_review_finisher", 58, 58, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


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
	return [snapshot.revision, snapshot.route.phase, snapshot.economy.balance, snapshot.shop.session_id if snapshot.shop != null else &""]


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])
