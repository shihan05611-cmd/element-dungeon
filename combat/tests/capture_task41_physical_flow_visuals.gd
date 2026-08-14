extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")

var _coordinator: RunFlowCoordinator
var _hit_sequence: int = 41_500_000
var _capture_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task41_visual_authority"
	root.add_child(_coordinator)
	current_scene = _coordinator
	assert(await _wait_combat(&"combat_01_entry"))
	var room := _coordinator.active_room
	assert(room.initial_enemies.size() == 2 and room.reinforcement_enemies.is_empty())
	await _capture("task41_01_first_room_two_enemies_1920x1080.png", Vector2i(1920, 1080))
	_defeat_batch(room.initial_enemies)
	await process_frame
	assert(room.room_is_cleared and room.chest.visible and room.portal.locked)
	await _wait_frames(60)
	await _capture("task41_02_single_wave_clear_1920x1080.png", Vector2i(1920, 1080))
	_interact_at(room.chest)
	await process_frame
	assert(room.chest.consumed and room.portal.enabled and not room.portal.locked)
	await _capture("task41_03_open_chest_unlocked_portal_1920x1080.png", Vector2i(1920, 1080))
	_interact_at(room.portal)
	assert(await _wait_combat(&"combat_02_swarm"))
	assert(_coordinator.current_snapshot().route.completed_combat_rooms == 1)
	await _capture("task41_04_direct_second_combat_1920x1080.png", Vector2i(1920, 1080))
	await _finish_normal_room()
	assert(await _wait_phase(RunPhase.SHOP))
	assert(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 180))
	root.size = Vector2i(1366, 768)
	assert(_coordinator.active_room == null and _coordinator.active_shop_room.exit_portal != null)
	var overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	var shop_before := _authority_signature(_coordinator.current_snapshot())
	var draft_id := overlay.formal_shop_draft_instance_id()
	var close_button := overlay.formal_control(&"close_shop_panel") as Button
	assert(close_button != null and close_button.visible and not close_button.disabled and close_button.focus_mode == Control.FOCUS_ALL)
	assert(close_button.text.contains("返回世界") and close_button.text.contains("L"))
	var leave_button := overlay.formal_control(&"leave_shop") as Button
	assert(leave_button != null and leave_button.disabled)
	await _capture("task41_05_single_shop_1366x768.png", Vector2i(1366, 768))
	var panel_sha := FileAccess.get_sha256("res://docs/agent_tasks/evidence/task41/screenshots/task41_05_single_shop_1366x768.png")
	close_button.pressed.emit()
	await process_frame
	assert(not overlay.visible and _authority_signature(_coordinator.current_snapshot()) == shop_before)
	assert(overlay.formal_shop_draft_instance_id() == draft_id)
	var shop_room := _coordinator.active_shop_room
	var start_x := _coordinator.player.global_position.x
	Input.action_press(&"move_right")
	var reached_portal := false
	for _frame: int in 360:
		await physics_frame
		if shop_room.exit_portal.can_interact(_coordinator.player.global_position):
			reached_portal = true
			break
	Input.action_release(&"move_right")
	assert(reached_portal and _coordinator.player.global_position.x > start_x + 300.0)
	assert(not overlay.visible and shop_room.visible and _coordinator.player.visible and shop_room.exit_portal.visible)
	assert(shop_room.exit_portal.prompt.visible and shop_room.exit_portal.prompt.text == "F · 离开商店")
	await _capture("task41_06_shop_exit_f_prompt_1366x768.png", Vector2i(1366, 768))
	assert(FileAccess.get_sha256("res://docs/agent_tasks/evidence/task41/screenshots/task41_06_shop_exit_f_prompt_1366x768.png") != panel_sha)
	await _press_interact_input()
	assert(await _wait_combat(&"combat_04_validation"))
	await _finish_normal_room()
	assert(await _wait_combat(&"combat_06_final_boss"))
	root.size = Vector2i(2560, 1440)
	room = _coordinator.active_room
	var boss := room.enemies[0]
	assert(is_equal_approx(boss.boss_visual_scale, 1.7) and boss.get_node_or_null("BossPurpleOutline") != null)
	boss.ai_enabled = false
	await _wait_frames(90)
	await _capture("task41_07_boss_purple_outline_2560x1440.png", Vector2i(2560, 1440))
	boss.player = _coordinator.player
	_coordinator.player.global_position = boss.global_position + Vector2(-320.0, 0.0)
	boss.call("_spawn_boss_projectile")
	await process_frame
	assert(boss.boss_projectiles_fired >= 1 and _first_projectile() != null)
	await _capture("task41_08_boss_low_projectile_jump_path_2560x1440.png", Vector2i(2560, 1440))
	_defeat_batch(room.enemies)
	await process_frame
	assert(room.room_is_cleared and room.chest.visible and room.portal == null)
	await _capture("task41_09_settlement_chest_2560x1440.png", Vector2i(2560, 1440))
	var balance_before := _coordinator.current_snapshot().economy.balance
	_interact_at(room.chest)
	assert(await _wait_phase(RunPhase.RUN_COMPLETE))
	var final := _coordinator.current_snapshot()
	assert(final.result != null and final.result.is_complete())
	assert(final.route.completed_combat_rooms == 4 and final.route.shop_visits == 1 and final.route.route_choices == 0)
	assert(final.economy.balance == balance_before)
	await _capture("task41_10_results_2560x1440.png", Vector2i(2560, 1440))
	print("TASK41 VISUAL CAPTURE PASSED: %d authority-checked screenshots" % _capture_count)
	quit(0)


func _finish_normal_room() -> void:
	var room := _coordinator.active_room
	assert(room != null and not room.room_definition.final_boss)
	_defeat_batch(room.initial_enemies)
	await process_frame
	assert(room.reinforcement_activated and not room.room_is_cleared)
	_defeat_batch(room.reinforcement_enemies)
	await process_frame
	assert(room.room_is_cleared and room.portal.locked)
	_interact_at(room.chest)
	await process_frame
	assert(room.chest.consumed and not room.portal.locked)
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


func _first_projectile() -> ProjectileDelivery:
	for child: Node in _coordinator.get_children():
		if child is ProjectileDelivery:
			return child as ProjectileDelivery
	return null


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


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [
		snapshot.revision,
		snapshot.route.phase,
		snapshot.route.run_id,
		snapshot.route.current_room_id,
		snapshot.economy.balance,
		snapshot.shop.session_id if snapshot.shop != null else &"",
	]


func _capture(file_name: String, expected_size: Vector2i) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty() and image.get_size() == expected_size)
	var error := image.save_png("res://docs/agent_tasks/evidence/task41/screenshots/%s" % file_name)
	assert(error == OK)
	_capture_count += 1
