extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")

var _harness := TestHarness.new()
var _hit_sequence: int = 700000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task29_real_flow"
	_expect(coordinator != null, "run_game root is RunFlowCoordinator")
	if coordinator == null:
		_finish()
		return
	get_root().add_child(coordinator)
	var booted := await _wait_until(func() -> bool:
		return (
			coordinator.host != null
			and coordinator.host.run_session != null
			and coordinator.active_room != null
			and coordinator.host.run_session.snapshot().route.phase == RunPhase.COMBAT
		)
	, 360)
	_expect(booted, "formal RunGame boots into combat one")
	if not booted:
		_expect(coordinator.last_error.is_empty(), "bootstrap has no integration error: %s" % String(coordinator.last_error))
		coordinator.queue_free()
		_finish()
		return

	var host_id := coordinator.host.get_instance_id()
	var session_id := coordinator.host.run_session.get_instance_id()
	var player_id := coordinator.player.get_instance_id()
	var panel_id := coordinator.smoke_panel.get_instance_id()
	var loadout_id := coordinator.host.runtime_loadout.get_instance_id()
	var passive_adapter_id := coordinator.host.passive_adapter.get_instance_id()
	var shop_sessions: Array[StringName] = []
	var scene_paths: Array[String] = [coordinator.active_room.scene_path]
	var room_instances: Array[int] = [coordinator.active_room.get_instance_id()]

	_expect_eq(coordinator.host.run_session.snapshot().route.current_room_id, &"combat_01_entry", "new main scene starts at combat one")
	_expect_eq(coordinator.room_container.get_child_count(), 1, "one active RunRoomInstance after bootstrap")
	_expect(coordinator.player.get_parent() == coordinator, "player is persistent sibling of RoomContainer")
	_expect(coordinator.host.get_parent() == coordinator, "host is persistent sibling of RoomContainer")
	_expect(coordinator.smoke_panel.get_parent() == coordinator, "smoke HUD is persistent sibling of RoomContainer")

	await _finish_current_room(coordinator)
	_expect(await _wait_for_room(coordinator, &"combat_02_swarm"), "combat one loads the fixed second combat")
	_record_room(coordinator, scene_paths, room_instances)
	_expect_eq(coordinator.active_room.template_id, &"arena_tidal_battle_02", "fixed second combat uses Battle Room 02")

	await _finish_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.SHOP), "combat two reaches the single physical shop")
	_assert_persistent_ids(coordinator, host_id, session_id, player_id, panel_id, loadout_id, passive_adapter_id)
	var middle_shop := coordinator.host.run_session.snapshot()
	shop_sessions.append(middle_shop.shop.session_id)
	var purchase_two := coordinator.purchase_first_affordable_skill()
	_expect(purchase_two.accepted, "single shop completes an authoritative purchase")
	_expect(await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 360), "single physical shop room becomes active")
	coordinator.player.global_position = coordinator.active_shop_room.exit_portal.global_position
	coordinator.player.interact_requested.emit()
	_expect(await _wait_for_room(coordinator, &"combat_04_validation"), "middle shop loads combat four")
	_record_room(coordinator, scene_paths, room_instances)
	_expect_eq(coordinator.active_room.template_id, &"arena_tidal_battle_01", "third combat reuses Battle Room 01")

	await _finish_current_room(coordinator)
	_expect(await _wait_for_room(coordinator, &"combat_06_final_boss"), "third combat loads boss arena directly")
	_record_room(coordinator, scene_paths, room_instances)
	_expect_eq(coordinator.active_room.template_id, &"arena_tidal_boss", "boss uses dedicated full-room PackedScene")
	var before_boss := coordinator.host.run_session.snapshot()
	var boss_balance := before_boss.economy.balance
	await _finish_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.RUN_COMPLETE), "boss settlement chest reaches result")

	var final := coordinator.host.run_session.snapshot()
	_assert_persistent_ids(coordinator, host_id, session_id, player_id, panel_id, loadout_id, passive_adapter_id)
	_expect(final.result != null and final.result.is_complete(), "complete result snapshot exists")
	_expect_eq(final.route.completed_combat_rooms, 4, "real scene run completes exactly four combat rooms")
	_expect_eq(final.route.shop_visits, 1, "real scene run visits exactly one shop")
	_expect_eq(final.route.route_choices, 0, "real scene run chooses no routes")
	_expect_eq(final.route.selected_route_option_ids, [], "route-free run freezes no option ids")
	_expect_eq(shop_sessions.size(), 1, "one shop session observed")
	_expect_eq(_unique_string_name_count(shop_sessions), 1, "single shop session id is unique")
	_expect(final.economy.total_spent_on_purchases > 0, "real run consumes dream dust in shops")
	_expect_eq(final.economy.balance, boss_balance, "boss kill and room completion award zero dream dust")
	_expect(final.shop == null, "boss result has no terminal shop")
	_expect(final.pending_reward == null, "boss result has no free reward")
	_expect_eq(scene_paths.size(), 4, "four scene activations recorded by runner")
	_expect_eq(room_instances.size(), 4, "four room instance activations recorded by runner")
	_expect_eq(_unique_int_count(room_instances), 4, "every combat uses a different RunRoomInstance")
	_expect_eq(_unique_string_count(scene_paths), 3, "run observes Battle01, Battle02, and Boss PackedScene templates")
	_expect_eq(coordinator.room_container.get_child_count(), 1, "only one active RunRoomInstance remains at result")
	_expect_eq(coordinator.activated_scene_paths, final.route.activated_scene_paths, "coordinator history matches authority history")
	_expect_eq(coordinator.activated_room_instance_ids, final.route.activated_room_instance_ids, "instance history matches authority history")
	coordinator.queue_free()
	await process_frame
	_finish()


func _finish_current_room(coordinator: RunFlowCoordinator) -> void:
	var room := coordinator.active_room
	_expect(room != null and room.configured, "active room is a configured RunRoomInstance")
	if room == null:
		return
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat_enemy(coordinator, enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat_enemy(coordinator, enemy)
	await process_frame
	_expect(room.room_is_cleared, "all configured enemies clear before a physical interaction")
	coordinator.player.global_position = room.chest.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	if room.room_definition.final_boss:
		return
	_expect(room.chest.consumed and not room.portal.locked, "typed chest result unlocks the physical portal")
	coordinator.player.global_position = room.portal.global_position
	coordinator.player.interact_requested.emit()
	await process_frame


func _defeat_enemy(coordinator: RunFlowCoordinator, enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task29_real_room_finisher",
		coordinator.player.get_instance_id(),
		coordinator.player.get_instance_id(),
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(9999.0, 9999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(
		cast,
		payload,
		_hit_sequence,
		0,
		enemy.global_position,
		Vector2.RIGHT
	)
	var result := enemy.combat_receiver.receive_hit(request)
	_expect(result.accepted and enemy.defeated, "enemy defeated through real CombatReceiver transaction")


func _record_room(
		coordinator: RunFlowCoordinator,
		scene_paths: Array[String],
		instance_ids: Array[int]
) -> void:
	scene_paths.append(coordinator.active_room.scene_path)
	instance_ids.append(coordinator.active_room.get_instance_id())
	_expect_eq(coordinator.room_container.get_child_count(), 1, "RoomContainer owns exactly one active room")


func _assert_persistent_ids(
		coordinator: RunFlowCoordinator,
		host_id: int,
		session_id: int,
		player_id: int,
		panel_id: int,
		loadout_id: int,
		passive_adapter_id: int
) -> void:
	_expect_eq(coordinator.host.get_instance_id(), host_id, "RunSessionHost persists across rooms")
	_expect_eq(coordinator.host.run_session.get_instance_id(), session_id, "RunSession persists across rooms")
	_expect_eq(coordinator.player.get_instance_id(), player_id, "Player persists across rooms")
	_expect_eq(coordinator.smoke_panel.get_instance_id(), panel_id, "HUD/smoke panel persists across rooms")
	_expect_eq(coordinator.host.runtime_loadout.get_instance_id(), loadout_id, "seven-slot Runtime persists across rooms")
	_expect_eq(coordinator.host.passive_adapter.get_instance_id(), passive_adapter_id, "passive Runtime adapter persists across rooms")


func _wait_for_phase(coordinator: RunFlowCoordinator, phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return (
			coordinator.host.run_session != null
			and coordinator.host.run_session.snapshot().route.phase == phase
		)
	, 360)


func _wait_for_room(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			coordinator.active_room != null
			and coordinator.active_room.room_id == room_id
			and coordinator.host.run_session.snapshot().route.phase == RunPhase.COMBAT
		)
	, 360)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _unique_int_count(values: Array[int]) -> int:
	var unique: Array[int] = []
	for value: int in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_string_count(values: Array[String]) -> int:
	var unique: Array[String] = []
	for value: String in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_string_name_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _finish() -> void:
	quit(_harness.report("REAL ROOM FLOW TEST", 1))


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)
