extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _coordinator: RunFlowCoordinator
var _hit_sequence := 58_900_000
var _saw_shop_snapshot := false
var _overlay_visible_at_shop_snapshot := false
var _shop_room_active_at_shop_snapshot := false


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task58_review_shop_initial_visibility"
	root.add_child(_coordinator)
	current_scene = _coordinator
	if not await _wait_combat(&"combat_01_entry"):
		return _finish(false, "RunGame did not boot Battle01")
	await _finish_normal_room()
	if not await _wait_combat(&"combat_02_swarm"):
		return _finish(false, "Battle01 did not reach Battle02")
	var callback := func(snapshot: RunSnapshot, _cause: StringName) -> void:
		if snapshot != null and snapshot.route.phase == RunPhase.SHOP:
			_saw_shop_snapshot = true
			_overlay_visible_at_shop_snapshot = _coordinator.combat_hud.run_overlay.visible
			_shop_room_active_at_shop_snapshot = _coordinator.active_shop_room != null
	_coordinator.host.session_snapshot_changed.connect(callback)
	await _finish_normal_room()
	await process_frame
	var flash_confirmed := (
		_saw_shop_snapshot
		and _overlay_visible_at_shop_snapshot
		and not _shop_room_active_at_shop_snapshot
	)
	print("SHOP_SNAPSHOT_SEEN=%s" % str(_saw_shop_snapshot))
	print("OVERLAY_VISIBLE_AT_SHOP_SNAPSHOT=%s" % str(_overlay_visible_at_shop_snapshot))
	print("SHOP_ROOM_ACTIVE_AT_SHOP_SNAPSHOT=%s" % str(_shop_room_active_at_shop_snapshot))
	print("OVERLAY_VISIBLE_AFTER_DEFERRED_ENTRY=%s" % str(_coordinator.combat_hud.run_overlay.visible))
	_finish(not flash_confirmed, "SHOP snapshot exposes the shop overlay before deferred crown-room entry hides it")


func _finish_normal_room() -> void:
	var room := _coordinator.active_room
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat(enemy)
	await process_frame
	_coordinator.player.global_position = room.chest.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	_coordinator.player.global_position = room.portal.global_position
	_coordinator.player.interact_requested.emit()


func _defeat(enemy: CombatEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.defeated:
		return
	_hit_sequence += 1
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task58_review_finisher",
		58,
		58,
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new(),
	)
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	enemy.combat_receiver.receive_hit(
		HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	)


func _wait_combat(room_id: StringName) -> bool:
	for _frame: int in 480:
		if (
			_coordinator.active_room != null
			and _coordinator.active_room.room_id == room_id
			and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
		):
			return true
		await process_frame
	return false


func _finish(passed: bool, detail: String) -> void:
	print("REVIEW SHOP INITIAL VISIBILITY: %s | %s" % ["PASS" if passed else "FAIL", detail])
	quit(0 if passed else 1)
