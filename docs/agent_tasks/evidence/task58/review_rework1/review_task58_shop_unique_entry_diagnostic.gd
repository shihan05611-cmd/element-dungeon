extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _hit_sequence := 58_920_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task58_review_unique_shop_entry"
	root.add_child(coordinator)
	current_scene = coordinator
	if not await _wait_combat(coordinator, &"combat_01_entry"):
		_fail("RunGame did not start Battle01")
		return
	await _finish_room(coordinator)
	if not await _wait_combat(coordinator, &"combat_02_swarm"):
		_fail("RunGame did not reach Battle02")
		return
	await _finish_room(coordinator)
	if not await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 360):
		_fail("RunGame did not enter the physical shop room")
		return
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	print("OVERLAY_BEFORE_L=%s" % str(overlay.visible))
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_L
	coordinator.combat_hud._unhandled_input(event)
	print("OVERLAY_AFTER_PHYSICAL_L=%s" % str(overlay.visible))
	print("ACTIVE_SHOP_ROOM_AT_L=%s" % str(coordinator.active_shop_room != null))
	if overlay.visible:
		_fail("physical L opens the closed SHOP Overlay without a crown F interaction")
		return
	print("TASK58 REVIEW UNIQUE SHOP ENTRY PASSED")
	quit(0)


func _finish_room(coordinator: RunFlowCoordinator) -> void:
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


func _fail(message: String) -> void:
	printerr("TASK58 REVIEW UNIQUE SHOP ENTRY FAILED: " + message)
	quit(1)
