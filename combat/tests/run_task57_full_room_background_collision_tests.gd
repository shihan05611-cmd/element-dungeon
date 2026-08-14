extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BATTLE_01: PackedScene = preload("res://scenes/run/rooms/room_arena_flat.tscn")
const BATTLE_02: PackedScene = preload("res://scenes/run/rooms/room_arena_tidal_battle_02.tscn")
const SHOP: PackedScene = preload("res://scenes/run/rooms/room_shop_formal.tscn")
const BOSS: PackedScene = preload("res://scenes/run/rooms/room_arena_boss.tscn")

const ROOM_WIDTH := 1536.0
const ROOM_HEIGHT := 832.0
const PLAYER_MARKER_OFFSET := 46.0
const PLAYER_BODY_BOTTOM := 31.0

var _tests := 0
var _assertions := 0
var _failures: Array[String] = []
var _hit_sequence := 57_000_000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_test("runtime_art_camera_and_formal_mapping", _test_runtime_art_camera_and_formal_mapping)
	await _run_async_test("authored_markers_and_collision_geometry", _test_authored_markers_and_collision_geometry)
	await _run_async_test("every_required_platform_is_reachable_and_returns_to_ground", _test_every_required_platform_is_reachable_and_returns_to_ground)
	await _run_async_test("boss_has_only_main_ground_and_keeps_projectiles", _test_boss_has_only_main_ground_and_keeps_projectiles)
	await _run_async_test("formal_five_stage_roomcontainer_transaction", _test_formal_five_stage_roomcontainer_transaction)
	_finish()


func _test_runtime_art_camera_and_formal_mapping() -> void:
	var expected_hashes := {
		"tidal_battle_room_01_full_v1.png": "6d1bbba738358d0ab2c2f4fd517d3d6b2e3b488df95884c801957d6bac09c1c2",
		"tidal_battle_room_02_full_v1.png": "833258d65127a96f1016c7a71d0edc0296c698675dc885063833f83f18bf4a67",
		"tidal_shop_room_full_v1.png": "aad8eedf06b566e5efbddb6abc7ec1a0b3607095f0d972fe4041324f44688728",
		"tidal_boss_room_full_v1.png": "f2091eb108e93b48465eff41ffcb899d5899dacc37e2818da93b1b941dc94220",
	}
	for file_name: String in expected_hashes:
		var preview := "res://assets/art_preview/scene_preview/full_room_trials/%s" % file_name
		var runtime := "res://assets/world/rooms/tidal_dungeon/full_rooms/%s" % file_name
		_expect_eq(FileAccess.get_sha256(preview), expected_hashes[file_name], "%s preview keeps its frozen SHA" % file_name)
		_expect_eq(FileAccess.get_sha256(runtime), expected_hashes[file_name], "%s runtime copy is byte exact" % file_name)
		var texture := load(runtime) as Texture2D
		_expect(texture != null, "%s runtime image loads through the importer" % file_name)
		if texture != null:
			_expect_eq(texture.get_size(), Vector2(1536, 832), "%s keeps authored 1536x832 pixels" % file_name)

	var game := RUN_GAME.instantiate() as RunFlowCoordinator
	_expect(game != null, "RunGame instantiates")
	if game != null:
		var camera := game.get_node("Camera2D") as Camera2D
		_expect_eq(camera.position, Vector2(768, 416), "Camera centers the authored room")
		_expect_eq(camera.zoom, Vector2(0.75, 0.75), "Camera uses uniform 0.75 zoom")
		_expect(is_equal_approx(camera.zoom.x, camera.zoom.y), "Camera never stretches the room")
		_expect(game.get_node("CombatHUD") is CanvasLayer, "HUD remains outside Camera2D world scaling")
		game.free()

	_expect_eq(FLOW.combat_room_for(&"combat_01_entry").room_scene.resource_path, "res://scenes/run/rooms/room_arena_flat.tscn", "combat one maps to Battle Room 01")
	_expect_eq(FLOW.combat_room_for(&"combat_02_swarm").room_scene.resource_path, "res://scenes/run/rooms/room_arena_tidal_battle_02.tscn", "combat two maps to Battle Room 02")
	_expect_eq(FLOW.combat_room_for(&"combat_04_validation").room_scene.resource_path, "res://scenes/run/rooms/room_arena_flat.tscn", "combat three reuses Battle Room 01")
	_expect_eq(FLOW.combat_room_for(&"combat_06_final_boss").room_scene.resource_path, "res://scenes/run/rooms/room_arena_boss.tscn", "final combat maps to Boss Room")
	_expect_eq(_unique_scene_count(), 3, "four formal combats use exactly Battle01, Battle02, and Boss templates")


func _test_authored_markers_and_collision_geometry() -> void:
	var specs: Array[Dictionary] = [
		{
			"scene": BATTLE_01,
			"definition": FLOW.combat_room_for(&"combat_04_validation"),
			"texture": "res://assets/world/rooms/tidal_dungeon/full_rooms/tidal_battle_room_01_full_v1.png",
			"ground": 630.0,
			"platforms": {"LeftPlatform": 419.0, "CenterPlatform": 515.0, "RightPlatform": 419.0},
		},
		{
			"scene": BATTLE_02,
			"definition": FLOW.combat_room_for(&"combat_02_swarm"),
			"texture": "res://assets/world/rooms/tidal_dungeon/full_rooms/tidal_battle_room_02_full_v1.png",
			"ground": 634.0,
			"platforms": {"UpperPlatform": 302.0, "MiddlePlatform": 396.0, "LowerPlatform": 559.0},
		},
	]
	for spec: Dictionary in specs:
		var room := (spec["scene"] as PackedScene).instantiate() as RunRoomInstance
		root.add_child(room)
		var background := room.get_node("FullRoomBackground") as Sprite2D
		_expect_eq(background.texture.resource_path, spec["texture"], "%s uses its selected full-room background" % room.name)
		_expect_eq(background.texture.get_size(), Vector2(1536, 832), "%s background exposes 1:1 authored dimensions" % room.name)
		_expect_eq(background.position, Vector2(768, 416), "%s background is centered without cropping" % room.name)
		_expect_eq(background.scale, Vector2.ONE, "%s background scale is exact and uniform" % room.name)
		_expect(not _contains_tile_nodes(room), "%s contains no TileMap or TileMapLayer" % room.name)
		_assert_world_bounds(room, float(spec["ground"]), room.name)
		for platform_name: String in spec["platforms"]:
			var shape := room.get_node("%s/CollisionShape2D" % platform_name) as CollisionShape2D
			_expect(shape != null and shape.one_way_collision, "%s/%s is a one-way CollisionShape2D" % [room.name, platform_name])
			_expect_near(_shape_top(shape), float(spec["platforms"][platform_name]), 2.0, "%s/%s collision top matches the measured visual top" % [room.name, platform_name])
		var required_name := "CenterPlatform" if room.scene_path.ends_with("room_arena_flat.tscn") else "LowerPlatform"
		_expect((room.get_node(required_name) as StaticBody2D).is_in_group("task57_required_platform"), "%s explicitly identifies its player-required platform" % room.name)
		var definition: CombatRoomDefinition = spec["definition"]
		_expect(room.configure(definition), "%s configures only from authored markers" % room.name)
		_assert_spawn_marker_consumption(room)
		_assert_interactable_marker_consumption(room)
		_assert_spawn_supports(room, float(spec["ground"]), spec["platforms"].values(), false)
		room.queue_free()
		await process_frame

	var shop := SHOP.instantiate() as RunShopRoomInstance
	root.add_child(shop)
	_assert_background(shop, "res://assets/world/rooms/tidal_dungeon/full_rooms/tidal_shop_room_full_v1.png", "Shop Room")
	_assert_world_bounds(shop, 639.0, "Shop Room")
	_expect_eq(shop.player_spawn_global_position(), (shop.get_node("PlayerSpawn") as Marker2D).global_position, "shop consumes PlayerSpawn marker")
	_expect_eq(shop.exit_portal.position, (shop.get_node("ExitPortalSpawn") as Marker2D).position, "shop exit portal matches its authored marker")
	shop.queue_free()
	await process_frame


func _test_every_required_platform_is_reachable_and_returns_to_ground() -> void:
	var battle_one_legs: Array[Dictionary] = [
		{"start": Vector2(650, 584), "move": &"move_right", "target": "CenterPlatform", "top": 515.0},
	]
	var battle_two_legs: Array[Dictionary] = [
		{"start": Vector2(1030, 588), "move": &"move_right", "target": "LowerPlatform", "top": 559.0},
	]
	await _run_platform_legs(BATTLE_01, 630.0, battle_one_legs, "Battle01")
	await _run_platform_legs(BATTLE_02, 634.0, battle_two_legs, "Battle02")


func _test_boss_has_only_main_ground_and_keeps_projectiles() -> void:
	var definition := FLOW.combat_room_for(&"combat_06_final_boss")
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var room := BOSS.instantiate() as RunRoomInstance
	stage.add_child(room)
	_assert_background(room, "res://assets/world/rooms/tidal_dungeon/full_rooms/tidal_boss_room_full_v1.png", "Boss Room")
	_assert_world_bounds(room, 692.0, "Boss Room")
	_expect(room.get_node_or_null("BossDais") == null, "BossDais is absent")
	_expect_eq(_one_way_shape_count(room), 0, "Boss Room has no hidden or transparent one-way platform")
	_expect(room.configure(definition), "Boss Room configures from the main-ground marker")
	_assert_spawn_marker_consumption(room)
	_assert_interactable_marker_consumption(room)
	_assert_spawn_supports(room, 692.0, [], true)
	room.activate()
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	stage.add_child(player)
	player.global_position = room.player_spawn_global_position()
	var boss := room.enemies[0]
	boss.ai_enabled = false
	boss.player = player
	_expect(await _wait_until(func() -> bool: return boss.is_on_floor(), 120, true), "Boss settles on the main ground")
	_expect_near(boss.global_position.y, 660.0, 2.0, "Boss root settles 32px above the 692px main ground")
	for side: float in [-1.0, 1.0]:
		player.global_position = boss.global_position + Vector2(side * 320.0, 0.0)
		var fired_before: int = boss.boss_projectiles_fired
		boss.call("_spawn_boss_projectile")
		await physics_frame
		_expect_eq(boss.boss_projectiles_fired, fired_before + 1, "Boss fires from main ground toward side %d" % int(side))
		_expect(_delivery_count(stage) >= 1, "Boss main-ground projectile survives its first physics frame")
	_free_deliveries(stage)
	player.queue_free()
	room.queue_free()
	await process_frame
	stage.queue_free()
	current_scene = null
	await process_frame


func _test_formal_five_stage_roomcontainer_transaction() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task57_full_room_transaction"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_combat(coordinator, &"combat_01_entry"), "formal run boots Battle01")
	var persistent_ids := _persistent_ids(coordinator)
	var visited_ids: Array[StringName] = []
	var visited_paths: Array[String] = []
	var visited_instances: Array[int] = []
	_record_active_room(coordinator, visited_ids, visited_paths, visited_instances)
	_assert_roomcontainer_singleton(coordinator, "Battle01")
	await _finish_normal_room(coordinator)

	_expect(await _wait_combat(coordinator, &"combat_02_swarm"), "Battle01 portal reaches Battle02")
	_assert_persistent_ids(coordinator, persistent_ids, "Battle02")
	_record_active_room(coordinator, visited_ids, visited_paths, visited_instances)
	_assert_roomcontainer_singleton(coordinator, "Battle02")
	await _finish_normal_room(coordinator)

	_expect(await _wait_phase(coordinator, RunPhase.SHOP), "Battle02 reaches Shop")
	_expect(await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 360), "Shop Room becomes the sole active room")
	_assert_persistent_ids(coordinator, persistent_ids, "Shop")
	_assert_roomcontainer_singleton(coordinator, "Shop")
	var shop := coordinator.active_shop_room
	coordinator.player.global_position = shop.exit_portal.global_position
	coordinator.player.interact_requested.emit()

	_expect(await _wait_combat(coordinator, &"combat_04_validation"), "Shop exits to formal combat three")
	_assert_persistent_ids(coordinator, persistent_ids, "reused Battle01")
	_record_active_room(coordinator, visited_ids, visited_paths, visited_instances)
	_assert_roomcontainer_singleton(coordinator, "reused Battle01")
	await _finish_normal_room(coordinator)

	_expect(await _wait_combat(coordinator, &"combat_06_final_boss"), "formal combat three reaches Boss")
	_assert_persistent_ids(coordinator, persistent_ids, "Boss")
	_record_active_room(coordinator, visited_ids, visited_paths, visited_instances)
	_assert_roomcontainer_singleton(coordinator, "Boss")
	var boss := coordinator.active_room.enemies[0]
	_expect(await _wait_until(func() -> bool:
		return boss.is_on_floor() and is_instance_valid(boss.player) and boss.player == coordinator.player
	, 120, true), "formal Boss lands and acquires the formal RunGame player")
	boss.ai_enabled = false
	boss.set("_boss_projectile_cooldown", 9999.0)
	coordinator.player.global_position = boss.global_position + Vector2(-320, 0)
	var created_deliveries: Array[Node] = []
	boss.delivery_created.connect(func(delivery: Node) -> void: created_deliveries.append(delivery), CONNECT_ONE_SHOT)
	var fired_before: int = boss.boss_projectiles_fired
	boss.call("_spawn_boss_projectile")
	var delivery_entered_lifecycle := await _wait_until(func() -> bool:
		if created_deliveries.is_empty():
			return false
		var delivery := created_deliveries[0] as ProjectileDelivery
		return (
			is_instance_valid(delivery)
			and delivery.is_inside_tree()
			and delivery.get_parent() == coordinator
			and not delivery.is_finished
			and delivery.distance_travelled > 0.0
			and boss.boss_projectiles_fired == fired_before + 1
			and _delivery_count(coordinator) >= 1
		)
	, 30, true)
	_expect(delivery_entered_lifecycle, "formal Boss projectile remains operational without a dais")
	_defeat_batch(coordinator.active_room.enemies)
	await process_frame
	_interact_at(coordinator, coordinator.active_room.chest)
	_expect(await _wait_phase(coordinator, RunPhase.RUN_COMPLETE), "Boss settlement preserves the formal result transition")
	var final := coordinator.current_snapshot()
	_expect_eq(visited_ids, [&"combat_01_entry", &"combat_02_swarm", &"combat_04_validation", &"combat_06_final_boss"], "formal combat order remains exact")
	_expect_eq(visited_paths, ["res://scenes/run/rooms/room_arena_flat.tscn", "res://scenes/run/rooms/room_arena_tidal_battle_02.tscn", "res://scenes/run/rooms/room_arena_flat.tscn", "res://scenes/run/rooms/room_arena_boss.tscn"], "formal room mapping is Battle01, Battle02, Battle01, Boss")
	_expect_eq(_unique_int_count(visited_instances), 4, "every combat activation uses a fresh room instance")
	_expect(final.result != null and final.result.is_complete(), "formal result remains immutable and complete")
	_expect(final.route.completed_combat_rooms == 4 and final.route.shop_visits == 1 and final.route.route_choices == 0, "five-stage authority remains 4 combat / 1 shop / 0 route")
	coordinator.queue_free()
	await process_frame


func _assert_world_bounds(room: Node, ground_top: float, label: String) -> void:
	var ground := room.get_node("Ground/CollisionShape2D") as CollisionShape2D
	var left := room.get_node("LeftWall/CollisionShape2D") as CollisionShape2D
	var right := room.get_node("RightWall/CollisionShape2D") as CollisionShape2D
	_expect_near(_shape_top(ground), ground_top, 2.0, "%s ground collision matches its measured visual top" % label)
	_expect_near(_shape_right(left), 0.0, 0.01, "%s left blocker meets the image edge" % label)
	_expect_near(_shape_left(right), ROOM_WIDTH, 0.01, "%s right blocker meets the image edge" % label)
	_expect_eq((ground.get_parent() as StaticBody2D).collision_layer, 4, "%s ground stays on WorldBlocker layer" % label)
	_expect_eq((left.get_parent() as StaticBody2D).collision_layer, 4, "%s left wall stays on WorldBlocker layer" % label)
	_expect_eq((right.get_parent() as StaticBody2D).collision_layer, 4, "%s right wall stays on WorldBlocker layer" % label)


func _assert_background(room: Node, path: String, label: String) -> void:
	var background := room.get_node("FullRoomBackground") as Sprite2D
	_expect_eq(background.texture.resource_path, path, "%s uses its selected runtime image" % label)
	_expect_eq(background.texture.get_size(), Vector2(1536, 832), "%s background is authored 1536x832" % label)
	_expect_eq(background.position, Vector2(768, 416), "%s background center is exact" % label)
	_expect_eq(background.scale, Vector2.ONE, "%s background is not resampled or stretched" % label)
	_expect(not _contains_tile_nodes(room), "%s contains no TileMap or TileMapLayer" % label)


func _assert_spawn_marker_consumption(room: RunRoomInstance) -> void:
	_expect_eq(room.player_spawn_global_position(), (room.get_node("PlayerSpawn") as Marker2D).global_position, "%s consumes PlayerSpawn" % room.name)
	for index: int in room.initial_enemies.size():
		var marker := room.get_node("InitialEnemySpawns/Spawn%d" % (index + 1)) as Marker2D
		_expect_eq(room.initial_enemies[index].position, marker.position, "%s initial enemy %d consumes its marker" % [room.name, index + 1])
	for index: int in room.reinforcement_enemies.size():
		var marker := room.get_node("ReinforcementSpawns/Spawn%d" % (index + 1)) as Marker2D
		_expect_eq(room.reinforcement_enemies[index].position, marker.position, "%s reinforcement %d consumes its marker" % [room.name, index + 1])


func _assert_interactable_marker_consumption(room: RunRoomInstance) -> void:
	_expect_eq(room.chest.position, (room.get_node("RewardChestSpawn") as Marker2D).position, "%s chest consumes RewardChestSpawn" % room.name)
	if not room.room_definition.final_boss:
		_expect_eq(room.portal.position, (room.get_node("RoutePortalSpawn") as Marker2D).position, "%s portal consumes RoutePortalSpawn" % room.name)


func _assert_spawn_supports(room: RunRoomInstance, ground_top: float, platform_tops: Array, final_boss: bool) -> void:
	var normal_supports: Array[float] = [ground_top]
	for value: Variant in platform_tops:
		normal_supports.append(float(value))
	for enemy: CombatEnemy in room.enemies:
		_expect(enemy.position.x > 0.0 and enemy.position.x < ROOM_WIDTH, "%s enemy %s stays inside authored bounds" % [room.name, enemy.name])
		var offset := 32.0 if final_boss else PLAYER_MARKER_OFFSET
		var supported := false
		for support: float in normal_supports:
			if absf(enemy.position.y - (support - offset)) <= 2.0:
				supported = true
		_expect(supported, "%s enemy %s starts on an authored support" % [room.name, enemy.name])
	var chest_support := ground_top - 39.0
	_expect_near(room.chest.position.y, chest_support, 2.0, "%s chest marker is grounded" % room.name)
	if room.portal != null:
		_expect_near(room.portal.position.y, ground_top - 86.0, 2.0, "%s portal marker is grounded" % room.name)


func _run_platform_legs(scene: PackedScene, ground_top: float, legs: Array[Dictionary], label: String) -> void:
	for leg: Dictionary in legs:
		var room := scene.instantiate() as RunRoomInstance
		root.add_child(room)
		var player := PLAYER_SCENE.instantiate() as PlayerCharacter
		root.add_child(player)
		player.global_position = leg["start"]
		_expect(await _wait_until(func() -> bool: return player.is_on_floor(), 90, true), "%s/%s starts on a real support" % [label, leg["target"]])
		var move_action: StringName = leg["move"]
		Input.action_press(move_action)
		_send_jump(true)
		await physics_frame
		_send_jump(false)
		var airborne := false
		var landed := false
		for _frame: int in 240:
			await physics_frame
			airborne = airborne or not player.is_on_floor()
			if airborne and player.is_on_floor() and absf(player.global_position.y - (float(leg["top"]) - PLAYER_BODY_BOTTOM)) <= 3.0:
				landed = true
				break
		Input.action_release(move_action)
		_expect(airborne, "%s/%s jump input produces airborne motion" % [label, leg["target"]])
		_expect(landed, "%s/%s is reached by real player jump physics" % [label, leg["target"]])
		if landed:
			Input.action_press(move_action)
			var returned := await _wait_until(func() -> bool:
				return player.is_on_floor() and absf(player.global_position.y - (ground_top - PLAYER_BODY_BOTTOM)) <= 3.0
			, 360, true)
			Input.action_release(move_action)
			_expect(returned, "%s/%s can be exited and lands back on main ground" % [label, leg["target"]])
		player.queue_free()
		room.queue_free()
		await process_frame


func _finish_normal_room(coordinator: RunFlowCoordinator) -> void:
	var room := coordinator.active_room
	_defeat_batch(room.initial_enemies)
	await process_frame
	if not room.reinforcement_enemies.is_empty():
		_expect(await _wait_until(func() -> bool: return room.reinforcement_activated, 90), "%s activates its authored reinforcement markers" % String(room.room_id))
		_defeat_batch(room.reinforcement_enemies)
		await process_frame
	_expect(room.room_is_cleared, "%s clears through its unchanged authority" % String(room.room_id))
	_interact_at(coordinator, room.chest)
	await process_frame
	_expect(room.chest.consumed and room.portal != null and not room.portal.locked, "%s chest unlocks its marker-backed portal" % String(room.room_id))
	_interact_at(coordinator, room.portal)


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task57_finisher", 57, 57, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var result := enemy.combat_receiver.receive_hit(request)
		_expect(result.accepted and enemy.defeated, "formal enemy is defeated through CombatReceiver")


func _interact_at(coordinator: RunFlowCoordinator, target: RunWorldInteractable) -> void:
	coordinator.player.global_position = target.global_position
	coordinator.player.interact_requested.emit()


func _record_active_room(coordinator: RunFlowCoordinator, ids: Array[StringName], paths: Array[String], instances: Array[int]) -> void:
	ids.append(coordinator.active_room.room_id)
	paths.append(coordinator.active_room.scene_path)
	instances.append(coordinator.active_room.get_instance_id())


func _assert_roomcontainer_singleton(coordinator: RunFlowCoordinator, label: String) -> void:
	_expect_eq(coordinator.room_container.get_child_count(), 1, "%s is the only RoomContainer child" % label)
	_expect(coordinator.get_node("Player").get_parent() == coordinator, "%s does not replace the persistent Player" % label)
	_expect(coordinator.get_node("CombatHUD").get_parent() == coordinator, "%s does not replace the persistent HUD" % label)


func _persistent_ids(coordinator: RunFlowCoordinator) -> Array[int]:
	return [coordinator.host.get_instance_id(), coordinator.host.run_session.get_instance_id(), coordinator.player.get_instance_id(), coordinator.combat_hud.get_instance_id(), coordinator.get_node("Camera2D").get_instance_id()]


func _assert_persistent_ids(coordinator: RunFlowCoordinator, expected: Array[int], label: String) -> void:
	_expect_eq(_persistent_ids(coordinator), expected, "%s keeps Host, RunSession, Player, HUD, and Camera identities" % label)


func _wait_combat(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.active_room != null and coordinator.active_room.room_id == room_id and coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 480)


func _wait_phase(coordinator: RunFlowCoordinator, phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.host.run_session != null and coordinator.current_snapshot().route.phase == phase
	, 480)


func _wait_until(predicate: Callable, maximum_frames: int, physics := false) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		if physics:
			await physics_frame
		else:
			await process_frame
	return bool(predicate.call())


func _send_jump(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"jump"
	event.pressed = pressed
	Input.parse_input_event(event)


func _shape_top(shape_node: CollisionShape2D) -> float:
	var rectangle := shape_node.shape as RectangleShape2D
	return shape_node.position.y - rectangle.size.y * 0.5


func _shape_left(shape_node: CollisionShape2D) -> float:
	var rectangle := shape_node.shape as RectangleShape2D
	return shape_node.position.x - rectangle.size.x * 0.5


func _shape_right(shape_node: CollisionShape2D) -> float:
	var rectangle := shape_node.shape as RectangleShape2D
	return shape_node.position.x + rectangle.size.x * 0.5


func _contains_tile_nodes(node: Node) -> bool:
	if node.get_class() == "TileMap" or node.get_class() == "TileMapLayer":
		return true
	for child: Node in node.get_children():
		if _contains_tile_nodes(child):
			return true
	return false


func _one_way_shape_count(node: Node) -> int:
	var count := 1 if node is CollisionShape2D and (node as CollisionShape2D).one_way_collision else 0
	for child: Node in node.get_children():
		count += _one_way_shape_count(child)
	return count


func _delivery_count(node: Node) -> int:
	var count := 1 if node is DeliveryBase else 0
	for child: Node in node.get_children():
		count += _delivery_count(child)
	return count


func _free_deliveries(node: Node) -> void:
	for child: Node in node.get_children():
		if child is DeliveryBase:
			child.queue_free()
		else:
			_free_deliveries(child)


func _unique_scene_count() -> int:
	var paths: Array[String] = []
	for room_id: StringName in [&"combat_01_entry", &"combat_02_swarm", &"combat_04_validation", &"combat_06_final_boss"]:
		var path := FLOW.combat_room_for(room_id).room_scene.resource_path
		if not paths.has(path):
			paths.append(path)
	return paths.size()


func _unique_int_count(values: Array[int]) -> int:
	var unique: Array[int] = []
	for value: int in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _run_test(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callable.call()
	if _failures.size() == before:
		print("PASS: " + test_name)


func _run_async_test(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callable.call()
	if _failures.size() == before:
		print("PASS: " + test_name)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	_assertions += 1
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.2f±%.2f, got %.2f)" % [description, expected, tolerance, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 57 FULL ROOM TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 57 FULL ROOM TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
