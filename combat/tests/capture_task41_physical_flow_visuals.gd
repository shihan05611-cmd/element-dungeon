extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _coordinator: RunFlowCoordinator
var _hit_sequence: int = 41_500_000
var _capture_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


## Evidence capture must keep collecting screenshots instead of aborting on a
## transient mismatch. Behavioral assertions belong in the harness runners.
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task41_visual_authority"
	root.add_child(_coordinator)
	current_scene = _coordinator
	await _wait_combat(&"combat_01_entry")
	var room := _coordinator.active_room
	await _capture("task41_01_first_room_two_enemies_1920x1080.png", Vector2i(1920, 1080))
	_defeat_batch(room.initial_enemies)
	await process_frame
	await _wait_frames(60)
	await _capture("task41_02_single_wave_clear_1920x1080.png", Vector2i(1920, 1080))
	_interact_at(room.chest)
	await process_frame
	await _capture("task41_03_open_chest_unlocked_portal_1920x1080.png", Vector2i(1920, 1080))
	_interact_at(room.portal)
	await _wait_combat(&"combat_02_swarm")
	await _capture("task41_04_direct_second_combat_1920x1080.png", Vector2i(1920, 1080))
	await _finish_normal_room()
	await _wait_phase(RunPhase.SHOP)
	await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 180)
	root.size = Vector2i(1366, 768)
	var overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	await _capture("task41_05_single_shop_1366x768.png", Vector2i(1366, 768))
	var close_button := overlay.formal_control(&"close_shop_panel") as Button
	if close_button != null:
		close_button.pressed.emit()
	await process_frame
	var shop_room := _coordinator.active_shop_room
	Input.action_press(&"move_right")
	for _frame: int in 360:
		await physics_frame
		if shop_room.exit_portal.can_interact(_coordinator.player.global_position):
			break
	Input.action_release(&"move_right")
	await _capture("task41_06_shop_exit_f_prompt_1366x768.png", Vector2i(1366, 768))
	await _press_interact_input()
	await _wait_combat(&"combat_04_validation")
	await _finish_normal_room()
	await _wait_combat(&"combat_06_final_boss")
	root.size = Vector2i(2560, 1440)
	room = _coordinator.active_room
	var boss := room.enemies[0] as BossTideEmber
	boss.ai_enabled = false
	await _wait_frames(90)
	await _capture("task41_07_boss_purple_outline_2560x1440.png", Vector2i(2560, 1440))
	boss.player = _coordinator.player
	_coordinator.player.global_position = boss.global_position + Vector2(-320.0, 0.0)
	var boss_direction: Vector2 = boss.call("_resolve_accurate_direction", boss.ranged_projectile_profile, boss.player.global_position)
	boss.call("_apply_facing", boss_direction)
	boss.call("_launch_ranged_projectile", boss.ranged_projectile_profile, boss_direction, &"boss_arc")
	await process_frame
	await _capture("task41_08_boss_low_projectile_jump_path_2560x1440.png", Vector2i(2560, 1440))
	_defeat_batch(room.enemies)
	await process_frame
	await _capture("task41_09_settlement_chest_2560x1440.png", Vector2i(2560, 1440))
	_interact_at(room.chest)
	await _wait_phase(RunPhase.RUN_COMPLETE)
	await _capture("task41_10_results_2560x1440.png", Vector2i(2560, 1440))
	print("TASK41 VISUAL CAPTURE COMPLETED: %d screenshots" % _capture_count)
	quit(0)


func _finish_normal_room() -> void:
	var room := _coordinator.active_room
	_defeat_batch(room.initial_enemies)
	await process_frame
	_defeat_batch(room.reinforcement_enemies)
	await process_frame
	_interact_at(room.chest)
	await process_frame
	_interact_at(room.portal)
	await process_frame


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task41_capture", 41, 41, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
		enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _interact_at(target: RunWorldInteractable) -> void:
	_coordinator.player.global_position = target.global_position
	_coordinator.player.interact_requested.emit()


func _wait_combat(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator.active_room != null and _coordinator.active_room.room_id == room_id and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 360)


func _wait_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator.host.run_session != null and _coordinator.current_snapshot().route.phase == phase
	, 360)


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _wait_frames(frames: int) -> void:
	for _frame: int in frames:
		await process_frame


func _press_interact_input() -> void:
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


func _capture(file_name: String, expected_size: Vector2i) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty() and image.get_size() == expected_size:
		image.save_png("res://docs/agent_tasks/evidence/task41/screenshots/%s" % file_name)
		_capture_count += 1
