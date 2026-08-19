extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task57/screenshots"

var _coordinator: RunFlowCoordinator
var _failures: Array[String] = []
var _saved: Array[String] = []
var _hit_sequence := 57_500_000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task57_full_room_capture"
	root.add_child(_coordinator)
	current_scene = _coordinator

	_assert(await _wait_combat(&"combat_01_entry"), "capture boots Battle Room 01")
	_assert(_active_background_path().ends_with("tidal_battle_room_01_full_v1.png"), "first combat uses Battle Room 01")
	for enemy: CombatEnemy in _coordinator.active_room.enemies:
		enemy.ai_enabled = false
	await _settle()
	await _save("task57_01_battle01_full_room_1920x1080.png")
	await _finish_normal_room()

	_assert(await _wait_combat(&"combat_02_swarm"), "second combat boots Battle Room 02")
	_assert(_active_background_path().ends_with("tidal_battle_room_02_full_v1.png"), "second combat uses Battle Room 02")
	for enemy: CombatEnemy in _coordinator.active_room.enemies:
		enemy.ai_enabled = false
	await create_timer(1.2).timeout
	await _settle()
	await _save("task57_02_battle02_full_room_1920x1080.png")
	_assert(await _jump_to_lower_platform(), "real player input reaches the visible Battle02 lower platform")
	var platform_enemy := _coordinator.active_room.initial_enemies[0]
	platform_enemy.global_position = Vector2(1225, 513)
	platform_enemy.velocity = Vector2.ZERO
	await create_timer(0.25).timeout
	await _settle()
	await _save("task57_03_battle02_platform_play_1920x1080.png")
	await _finish_normal_room()

	_assert(await _wait_phase(RunPhase.SHOP), "second combat reaches Shop Room")
	_assert(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 360), "Shop Room instantiates")
	_assert((_coordinator.active_shop_room.get_node("FullRoomBackground") as Sprite2D).texture.resource_path.ends_with("tidal_shop_room_full_v1.png"), "shop uses selected Shop Room background")
	var shop_overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	if shop_overlay.visible:
		shop_overlay.toggle_loadout()
		await process_frame
	await create_timer(1.2).timeout
	await _settle()
	await _save("task57_04_shop_full_room_1920x1080.png")
	await _leave_shop()

	_assert(await _wait_combat(&"combat_04_validation"), "third combat boots the reused Battle Room 01")
	_assert(_active_background_path().ends_with("tidal_battle_room_01_full_v1.png"), "third combat reuses Battle Room 01 exactly")
	for enemy: CombatEnemy in _coordinator.active_room.enemies:
		enemy.ai_enabled = false
	await create_timer(1.2).timeout
	await _settle()
	await _save("task57_05_battle03_reuses_battle01_1920x1080.png")
	await _finish_normal_room()

	_assert(await _wait_combat(&"combat_06_final_boss"), "final combat boots Boss Room")
	_assert(_active_background_path().ends_with("tidal_boss_room_full_v1.png"), "boss uses selected Boss Room background")
	_assert(_coordinator.active_room.get_node_or_null("BossDais") == null, "Boss evidence contains no BossDais")
	var boss := _coordinator.active_room.enemies[0]
	boss.ai_enabled = false
	_assert(await _wait_until(func() -> bool: return boss.is_on_floor(), 120, true), "Boss visibly settles on main ground")
	_coordinator.player.global_position = boss.global_position + Vector2(320, 0)
	boss.player = _coordinator.player
	var first_delivery: Array[Node] = []
	boss.delivery_created.connect(func(delivery: Node) -> void: first_delivery.append(delivery), CONNECT_ONE_SHOT)
	var boss_direction: Vector2 = boss.call("_resolve_accurate_direction", boss.ranged_projectile_profile, boss.player.global_position)
	boss.call("_apply_facing", boss_direction)
	boss.call("_launch_ranged_projectile", boss.ranged_projectile_profile, boss_direction, &"boss_arc")
	await physics_frame
	_assert(first_delivery.size() == 1 and boss.boss_projectiles_fired >= 1, "Boss evidence proves a live main-ground projectile")
	_assert(await _wait_until(func() -> bool:
		return first_delivery.is_empty() or not is_instance_valid(first_delivery[0]) or (first_delivery[0] as ProjectileDelivery).is_finished
	, 360, true), "Boss projectile completes its normal main-ground lifecycle")
	await create_timer(1.2).timeout
	_coordinator.player.global_position = boss.global_position + Vector2(-320, 0)
	var second_boss_direction: Vector2 = boss.call("_resolve_accurate_direction", boss.ranged_projectile_profile, boss.player.global_position)
	boss.call("_apply_facing", second_boss_direction)
	boss.call("_launch_ranged_projectile", boss.ranged_projectile_profile, second_boss_direction, &"boss_arc")
	await physics_frame
	await _settle()
	await _save("task57_06_boss_main_ground_no_dais_1920x1080.png")

	_assert(_saved.size() == 6, "capture writes exactly six fresh 1920x1080 images")
	print("Task57 visual capture: 1 test, %d images, %d failures" % [_saved.size(), _failures.size()])
	for path: String in _saved:
		print("CAPTURED: %s" % path)
	quit(0 if _failures.is_empty() else 1)


func _jump_to_lower_platform() -> bool:
	var player := _coordinator.player
	player.global_position = Vector2(1030, 588)
	player.velocity = Vector2.ZERO
	if not await _wait_until(func() -> bool: return player.is_on_floor(), 90, true):
		return false
	Input.action_press(&"move_right")
	var press := InputEventAction.new()
	press.action = &"jump"
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frame
	var release := InputEventAction.new()
	release.action = &"jump"
	release.pressed = false
	Input.parse_input_event(release)
	var airborne := false
	var landed := false
	for _frame: int in 180:
		await physics_frame
		airborne = airborne or not player.is_on_floor()
		if airborne and player.is_on_floor() and absf(player.global_position.y - 528.0) <= 3.0:
			landed = true
			break
	Input.action_release(&"move_right")
	return airborne and landed


func _finish_normal_room() -> void:
	var room := _coordinator.active_room
	_defeat_batch(room.initial_enemies)
	await process_frame
	if not room.reinforcement_enemies.is_empty():
		_assert(await _wait_until(func() -> bool: return room.reinforcement_activated, 90), "%s activates reinforcements" % String(room.room_id))
		_defeat_batch(room.reinforcement_enemies)
		await process_frame
	_assert(room.room_is_cleared, "%s clears through formal enemies" % String(room.room_id))
	_interact_at(room.chest)
	await process_frame
	_assert(room.chest.consumed and room.portal != null and not room.portal.locked, "%s chest unlocks its portal" % String(room.room_id))
	_interact_at(room.portal)


func _leave_shop() -> void:
	var shop := _coordinator.active_shop_room
	var overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	_assert(shop != null and shop.exit_portal != null, "shop exposes its marker-aligned physical exit")
	if overlay.visible:
		overlay.toggle_loadout()
		await process_frame
	_coordinator.player.global_position = shop.exit_portal.global_position
	_coordinator.player.interact_requested.emit()


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task57_capture_finisher", 57, 57, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var result := enemy.combat_receiver.receive_hit(request)
		_assert(result.accepted and enemy.defeated, "capture defeats a formal enemy through CombatReceiver")


func _interact_at(target: RunWorldInteractable) -> void:
	_coordinator.player.global_position = target.global_position
	_coordinator.player.interact_requested.emit()


func _active_background_path() -> String:
	return (_coordinator.active_room.get_node("FullRoomBackground") as Sprite2D).texture.resource_path


func _wait_combat(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator.active_room != null and _coordinator.active_room.room_id == room_id and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 480)


func _wait_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator.host.run_session != null and _coordinator.current_snapshot().route.phase == phase
	, 480)


func _wait_until(predicate: Callable, limit: int, physics := false) -> bool:
	for _frame: int in limit:
		if predicate.call():
			return true
		if physics:
			await physics_frame
		else:
			await process_frame
	return bool(predicate.call())


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty() and image.get_size() == Vector2i(1920, 1080), "%s preserves 1920x1080" % file_name)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	_assert(image.save_png(ProjectSettings.globalize_path(path)) == OK, "%s saves successfully" % file_name)
	_saved.append(path)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("CAPTURE FAIL: %s" % message)
