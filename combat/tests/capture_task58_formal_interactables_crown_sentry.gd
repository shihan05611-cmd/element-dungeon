extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task58/screenshots"

var _coordinator: RunFlowCoordinator
var _failures: Array[String] = []
var _saved: Array[String] = []
var _hit_sequence := 58_500_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task58_formal_capture"
	root.add_child(_coordinator)
	current_scene = _coordinator

	_assert(await _wait_combat(&"combat_01_entry"), "capture boots Battle01")
	for enemy: CombatEnemy in _coordinator.active_room.enemies:
		enemy.ai_enabled = false
	await _clear_active_room()
	var room := _coordinator.active_room
	_assert(room.chest.visible and not room.chest.consumed, "closed chest is visible after clear")
	_assert(room.route_transition.visible and room.route_transition.locked, "locked route transition zone is visible before chest claim")
	_assert(room.chest.sprite.texture.resource_path.ends_with("chest_closed_v2.png"), "closed screenshot uses formal closed v2")
	_assert(room.route_transition.sprite == null, "locked route transition zone has no portal art")
	await create_timer(1.2).timeout
	_coordinator.player.global_position = room.chest.global_position + Vector2(-92, 0)
	await _settle()
	await _save("task58_01_closed_chest_1920x1080.png")
	_coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center())
	await create_timer(0.75).timeout
	await _settle()
	await _save("task58_02_locked_transition_zone_1920x1080.png")

	_interact_at(room.chest)
	await process_frame
	_assert(room.chest.consumed and room.chest.sprite.texture.resource_path.ends_with("chest_open_v2.png"), "open screenshot uses formal open v2")
	_assert(not room.route_transition.locked and room.route_transition.sprite == null, "unlocked route transition zone remains art-free")
	_coordinator.player.global_position = room.chest.global_position + Vector2(-92, 0)
	await _settle()
	await _save("task58_03_open_chest_1920x1080.png")
	_coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center())
	await create_timer(0.75).timeout
	await _settle()
	await _save("task58_04_unlocked_transition_zone_1920x1080.png")
	_interact_at(room.route_transition)

	_assert(await _wait_combat(&"combat_02_swarm"), "capture reaches Battle02")
	room = _coordinator.active_room
	var sentry := room.initial_enemies[0] as TidalSentry
	_assert(sentry != null and sentry.scene_file_path.ends_with("tidal_sentry.tscn"), "Battle02 capture has dedicated Sentry at Spawn1")
	for enemy: CombatEnemy in room.enemies:
		if enemy != sentry:
			enemy.ai_enabled = false
	_assert(await _wait_until(func() -> bool: return sentry.is_on_floor() and sentry.player == _coordinator.player, 180, true), "Sentry lands and acquires Player")
	_coordinator.player.global_position = Vector2(650, 588)
	var live_projectiles: Array[ProjectileDelivery] = []
	sentry.delivery_created.connect(func(node: Node) -> void:
		var delivery := node as ProjectileDelivery
		if delivery != null:
			live_projectiles.append(delivery)
	, CONNECT_ONE_SHOT)
	_assert(await _wait_until(func() -> bool:
		return (
			live_projectiles.size() == 1
			and is_instance_valid(live_projectiles[0])
			and not live_projectiles[0].is_finished
			and live_projectiles[0].distance_travelled >= 48.0
			and live_projectiles[0].distance_travelled <= 220.0
		)
	, 240, true), "Sentry capture observes one live moved projectile")
	sentry.ai_enabled = false
	_assert(absf(sentry.global_position.x - 1200.0) <= 1.0, "Sentry remains horizontally static on its platform")
	await _settle()
	await _save("task58_05_battle02_tidal_sentry_live_projectile_1920x1080.png")
	await _finish_active_room()

	_assert(await _wait_phase(RunPhase.SHOP), "Battle02 reaches Shop")
	_assert(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 360), "shop room becomes active")
	var shop := _coordinator.active_shop_room
	var overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	_assert(shop.wishing_crown.visible and shop.wishing_crown.sprite.texture.resource_path.ends_with("wishing_crown_v1.png"), "shop world shows standalone crown")
	_assert(not overlay.visible and overlay.formal_kind() != &"shop", "shop UI and merchant content are initially closed")
	_assert(overlay.formal_shop_draft_instance_id() == 0, "initial SHOP snapshot opens no ShopDraft")
	await create_timer(1.2).timeout
	_coordinator.player.global_position = shop.wishing_crown.global_position + Vector2(-96, 0)
	await _settle()
	await _save("task58_06_shop_crown_ui_closed_1920x1080.png")
	var authority_before := _authority_signature(_coordinator.current_snapshot())
	_coordinator.player.global_position = shop.wishing_crown.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	_assert(overlay.visible and overlay.formal_kind() == &"shop", "crown F interaction opens existing shop UI")
	_assert(overlay.formal_shop_draft_instance_id() != 0, "crown F creates the formal ShopDraft")
	_assert(_authority_signature(_coordinator.current_snapshot()) == authority_before, "opening UI commits no economy or flow transaction")
	await _settle()
	await _save("task58_07_shop_crown_ui_open_1920x1080.png")

	_assert(_saved.size() == 7, "capture writes exactly seven fresh 1920x1080 images")
	print("Task58 visual capture: 1 test, %d images, %d failures" % [_saved.size(), _failures.size()])
	for path: String in _saved:
		print("CAPTURED: %s" % path)
	quit(0 if _failures.is_empty() else 1)


func _clear_active_room() -> void:
	var room := _coordinator.active_room
	_defeat_batch(room.initial_enemies)
	await process_frame
	if not room.reinforcement_enemies.is_empty():
		_assert(await _wait_until(func() -> bool: return room.reinforcement_activated, 90), "%s activates reinforcements" % String(room.room_id))
		_defeat_batch(room.reinforcement_enemies)
		await process_frame
	_assert(room.room_is_cleared, "%s clears through formal enemies" % String(room.room_id))


func _finish_active_room() -> void:
	await _clear_active_room()
	var room := _coordinator.active_room
	_interact_at(room.chest)
	await process_frame
	_assert(room.chest.consumed and room.route_transition != null and not room.route_transition.locked, "%s formal chest unlocks route transition zone" % String(room.room_id))
	_interact_at(room.route_transition)


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task58_capture_finisher", 58, 58, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var result := enemy.combat_receiver.receive_hit(request)
		_assert(result.accepted and enemy.defeated, "capture defeats a formal enemy through CombatReceiver")


func _interact_at(target: RunWorldInteractable) -> void:
	var room := _coordinator.active_room
	_coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center()) if room != null and target == room.route_transition else target.global_position
	_coordinator.player.interact_requested.emit()


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


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [snapshot.revision, snapshot.route.phase, snapshot.economy.balance, snapshot.shop.session_id if snapshot.shop != null else &""]


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("CAPTURE FAIL: %s" % message)
