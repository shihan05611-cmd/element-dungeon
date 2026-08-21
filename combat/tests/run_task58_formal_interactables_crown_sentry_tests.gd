extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/run/interactables/run_reward_chest.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/run/interactables/run_route_portal.tscn")
const CROWN_SCENE: PackedScene = preload("res://scenes/run/interactables/run_wishing_crown.tscn")

const OLD_CHEST_ROOT := "assets/generated/vfx/" + "run_reward_chest"
const OLD_PORTAL_ROOT := "assets/generated/vfx/" + "run_route_portal"

const FORMAL_ASSETS := {
	"res://assets/world/interactables/run_reward_chest/chest_closed_v2.png": {
		"size": Vector2i(80, 72), "sha": "2714dac5a5ec44b7c092a7d2f3574fb0e71a6529090138051de1fa154c400d97", "bbox": Rect2i(8, 16, 63, 55),
	},
	"res://assets/world/interactables/run_reward_chest/chest_open_v2.png": {
		"size": Vector2i(80, 72), "sha": "cbc4344454b8d0d969545046a53a1b037cdb354091a4d526b5009285e0f74d68", "bbox": Rect2i(6, 3, 68, 68),
	},
	"res://assets/world/interactables/run_route_portal/portal_locked_v2.png": {
		"size": Vector2i(64, 96), "sha": "b9cffeac3d5037feb793072e6a8317a01a8d2422a230ed9671fc5a59acc30ffd", "bbox": Rect2i(6, 5, 51, 88),
	},
	"res://assets/world/interactables/run_route_portal/portal_active_v2.png": {
		"size": Vector2i(64, 96), "sha": "0eddaa9c484fedb119c31da6e081141549fcd4297e7823151c4a2bd330a7c2ea", "bbox": Rect2i(6, 5, 52, 88),
	},
	"res://assets/art_preview/world_objects/wishing_crown_v1.png": {
		"size": Vector2i(160, 128), "sha": "3cc3557eaa97349116a7ef5251abd0586aebd9f3e3bb283b89585c5e76fd7095", "bbox": Rect2i(8, 9, 144, 109),
	},
	"res://assets/world/enemies/tidal_sentry/tidal_sentry_idle_v1.png": {
		"size": Vector2i(100, 100), "sha": "10c931dd8823f5da24aa6a6efc13d00944a0eb57f07bf7aaee6ec531786f65f1", "bbox": Rect2i(37, 42, 27, 18),
	},
}

var _harness := TestHarness.new()
var _hit_sequence := 58_000_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("formal_asset_bytes_and_real_texture_states", _test_formal_asset_bytes_and_real_texture_states)
	await _run_async_test("shop_crown_opens_existing_ui_without_authority_mutation", _test_shop_crown_opens_existing_ui_without_authority_mutation)
	await _run_async_test("battle02_static_sentry_projectile_and_clear_protocol", _test_battle02_static_sentry_projectile_and_clear_protocol)
	_finish()


func _test_formal_asset_bytes_and_real_texture_states() -> void:
	for path: String in FORMAL_ASSETS:
		var expected: Dictionary = FORMAL_ASSETS[path]
		_expect_eq(FileAccess.get_sha256(path), expected["sha"], "%s keeps frozen SHA" % path.get_file())
		var image := Image.new()
		var load_error := image.load(ProjectSettings.globalize_path(path))
		_expect(load_error == OK and not image.is_empty(), "%s loads as an image" % path.get_file())
		if load_error != OK or image.is_empty():
			continue
		_expect_eq(image.get_size(), expected["size"], "%s keeps frozen dimensions" % path.get_file())
		var scan := _alpha_scan(image)
		_expect_eq(scan["bbox"], expected["bbox"], "%s keeps frozen alpha bbox" % path.get_file())
		_expect_eq(scan["partial"], 0, "%s uses hard alpha" % path.get_file())

	var chest := CHEST_SCENE.instantiate() as RunWorldInteractable
	root.add_child(chest)
	var closed_path := chest.sprite.texture.resource_path
	chest.open_chest(load("res://assets/world/interactables/run_reward_chest/chest_open_v2.png"), "opened")
	_expect_eq(closed_path, "res://assets/world/interactables/run_reward_chest/chest_closed_v2.png", "chest starts on the formal closed image")
	_expect_eq(chest.sprite.texture.resource_path, "res://assets/world/interactables/run_reward_chest/chest_open_v2.png", "open_chest switches to the real open image")
	_expect(closed_path != chest.sprite.texture.resource_path, "chest state is a real texture change")
	_expect_near(_sprite_visible_bottom(chest.sprite, FORMAL_ASSETS[closed_path]["bbox"]), 39.0, 0.01, "chest bottom-center offset matches authored room markers")
	chest.queue_free()

	var portal := PORTAL_SCENE.instantiate() as RunWorldInteractable
	root.add_child(portal)
	var locked_path := portal.sprite.texture.resource_path
	portal.set_locked(false)
	_expect_eq(locked_path, "res://assets/world/interactables/run_route_portal/portal_locked_v2.png", "portal starts on the formal locked image")
	_expect_eq(portal.sprite.texture.resource_path, "res://assets/world/interactables/run_route_portal/portal_active_v2.png", "unlock switches to the real active image")
	_expect(locked_path != portal.sprite.texture.resource_path, "portal state is a real texture change")
	_expect_near(_sprite_visible_bottom(portal.sprite, FORMAL_ASSETS[locked_path]["bbox"]), 87.0, 0.01, "portal bottom-center offset matches authored room markers")
	portal.queue_free()

	var crown := CROWN_SCENE.instantiate() as RunWorldInteractable
	root.add_child(crown)
	_expect_eq(crown.kind, RunWorldInteractable.Kind.SHOP_CROWN, "crown has an independent interaction kind")
	_expect_eq(crown.sprite.texture.resource_path, "res://assets/art_preview/world_objects/wishing_crown_v1.png", "crown consumes the frozen standalone image")
	_expect_near(_sprite_visible_bottom(crown.sprite, FORMAL_ASSETS[crown.sprite.texture.resource_path]["bbox"]), 1.0, 0.01, "crown visible baseline is grounded at its root")
	crown.queue_free()

	var runtime_hits := _runtime_old_asset_references("res://")
	_expect(runtime_hits.is_empty(), "production gd/tscn/tres runtime references to retired chest/portal roots are zero: %s" % str(runtime_hits))


func _test_shop_crown_opens_existing_ui_without_authority_mutation() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task58_shop_crown"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_combat(coordinator, &"combat_01_entry"), "formal RunGame starts Battle01")
	await _finish_normal_room(coordinator)
	_expect(await _wait_combat(coordinator, &"combat_02_swarm"), "Battle01 reaches Battle02")
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	var shop_snapshot := {
		"seen": false,
		"overlay_visible": true,
		"shop_room_active": true,
	}
	var shop_snapshot_callback := func(snapshot: RunSnapshot, _cause: StringName) -> void:
		if (
			not bool(shop_snapshot["seen"])
			and snapshot != null
			and snapshot.route.phase == RunPhase.SHOP
		):
			shop_snapshot["seen"] = true
			shop_snapshot["overlay_visible"] = overlay.visible
			shop_snapshot["shop_room_active"] = coordinator.active_shop_room != null
	coordinator.host.session_snapshot_changed.connect(shop_snapshot_callback)
	await _finish_normal_room(coordinator, false)
	_expect(bool(shop_snapshot["seen"]), "SHOP authority snapshot is captured synchronously")
	_expect(not bool(shop_snapshot["overlay_visible"]), "formal Overlay is hidden in the SHOP snapshot signal stack")
	_expect(not bool(shop_snapshot["shop_room_active"]), "SHOP snapshot assertion does not wait for active_shop_room")
	_expect(not overlay.visible and coordinator.active_shop_room == null, "SHOP signal stack ends hidden before deferred room entry")
	_expect(await _wait_phase(coordinator, RunPhase.SHOP), "Battle02 reaches the formal shop")
	_expect(await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 360, false), "shop room becomes active")
	var shop := coordinator.active_shop_room
	_expect(shop.wishing_crown.visible and shop.wishing_crown.kind == RunWorldInteractable.Kind.SHOP_CROWN, "standalone crown is visible in the shop world")
	_expect(not overlay.visible and overlay.formal_kind() != &"shop", "SHOP starts hidden without merchant content")
	_expect_eq(overlay.formal_shop_draft_instance_id(), 0, "SHOP snapshot opens no ShopDraft before crown F")
	_expect_eq(shop.wishing_crown.position, (shop.get_node("WishingCrownSpawn") as Marker2D).position, "crown consumes the authored shop marker")
	_expect_near(shop.wishing_crown.position.y + 1.0, 585.0, 1.0, "crown visible bottom sits on the center pedestal")
	_expect_eq(shop.exit_portal.sprite.texture.resource_path, "res://assets/world/interactables/run_route_portal/portal_active_v2.png", "shop exit uses the formal active portal image")
	_expect_near(shop.exit_portal.position.y + 87.0, 640.0, 1.0, "shop exit portal is grounded within one world pixel")

	var commands: Array[StringName] = []
	coordinator.ui_command_result.connect(func(command: StringName, _result: RunCommandResult) -> void: commands.append(command))
	var before := _authority_signature(coordinator.current_snapshot())
	await _press_physical_loadout(coordinator)
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "real CombatHUD physical L opens the existing global loadout content")
	_expect(overlay.formal_control(&"leave_shop") == null and overlay.formal_control(&"purchase:burning") == null and overlay.formal_control(&"upgrade:element_bolt") == null, "L content exposes no merchant, product, purchase, or upgrade controls")
	_expect_eq(overlay.formal_shop_draft_instance_id(), 0, "physical L creates no ShopDraft")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), before, "physical L mutates no run/economy authority")
	_expect(commands.is_empty(), "physical L submits no authority or leave command")
	await _press_physical_loadout(coordinator)
	_expect(not overlay.visible, "second physical L closes the global loadout content")
	await _press_interact_input()
	_expect(not overlay.visible and overlay.formal_kind() != &"shop", "F away from the crown opens no merchant content")
	_expect_eq(overlay.formal_shop_draft_instance_id(), 0, "far F creates no ShopDraft")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), before, "far F mutates no authority")

	coordinator.player.global_position = shop.wishing_crown.global_position
	await _press_interact_input()
	_expect(overlay.visible and overlay.formal_kind() == &"shop", "nearby F crown interaction opens the existing shop UI")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), before, "opening the crown UI mutates no run/economy authority")
	var draft_before := overlay.formal_shop_draft_instance_id()
	_expect(draft_before != 0, "crown F creates one formal ShopDraft")
	await _press_interact_input()
	_expect_eq(_authority_signature(coordinator.current_snapshot()), before, "repeated crown interaction submits no transaction")
	_expect_eq(overlay.formal_shop_draft_instance_id(), draft_before, "repeated crown interaction creates no duplicate draft")
	_expect(commands.is_empty(), "repeated crown F emits no authority command")

	var purchase_skill_id := &""
	for offer: ShopOfferSnapshot in coordinator.current_snapshot().shop.offers:
		if not coordinator.current_snapshot().skills.owns(offer.skill_id) and offer.purchase_price <= coordinator.current_snapshot().economy.balance:
			purchase_skill_id = offer.skill_id
			break
	_expect(not purchase_skill_id.is_empty(), "shop exposes one deterministic affordable unowned offer")
	var purchase_button := overlay.formal_control(StringName("purchase:%s" % String(purchase_skill_id))) as Button
	_expect(purchase_button != null and not purchase_button.disabled, "crown-open shop exposes the affordable purchase control")
	var transaction_before := coordinator.current_snapshot()
	if purchase_button != null:
		purchase_button.pressed.emit()
	await process_frame
	var transaction_after := coordinator.current_snapshot()
	_expect(transaction_after.revision == transaction_before.revision + 1 and transaction_after.skills.owns(purchase_skill_id), "purchase transaction advances authority exactly once")
	_expect(overlay.visible and overlay.formal_kind() == &"shop", "transaction snapshot keeps the crown-open merchant content visible")
	_expect_eq(overlay.formal_shop_draft_instance_id(), draft_before, "transaction snapshot refreshes the same ShopDraft")
	_expect_eq(commands, [&"purchase_skill"], "transaction snapshot records exactly one purchase command")

	var close_button := overlay.formal_control(&"close_shop_panel") as Button
	_expect(close_button != null and not close_button.disabled, "existing shop UI still exposes its close-to-world control")
	if close_button != null:
		close_button.pressed.emit()
	await process_frame
	_expect(not overlay.visible, "existing close control returns to the crown world")
	var after_transaction := _authority_signature(coordinator.current_snapshot())
	await _press_physical_loadout(coordinator)
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "L after shop close still opens only global loadout content")
	_expect(overlay.formal_control(&"leave_shop") == null and overlay.formal_control(StringName("purchase:%s" % String(purchase_skill_id))) == null, "post-close L still exposes no merchant controls")
	_expect_eq(overlay.formal_shop_draft_instance_id(), draft_before, "post-close L creates no replacement ShopDraft")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), after_transaction, "post-close L mutates no transaction state")
	_expect_eq(commands, [&"purchase_skill"], "post-close L emits no extra authority command")
	await _press_physical_loadout(coordinator)
	_expect(not overlay.visible, "second post-close L returns to the crown world")
	await _press_interact_input()
	_expect(overlay.visible and overlay.formal_kind() == &"shop" and overlay.formal_shop_draft_instance_id() == draft_before, "crown F reopens the same shop after global loadout close")
	if close_button != null:
		close_button = overlay.formal_control(&"close_shop_panel") as Button
		close_button.pressed.emit()
	await process_frame
	coordinator.player.global_position = shop.exit_portal.global_position
	await _press_interact_input()
	_expect(await _wait_combat(coordinator, &"combat_04_validation"), "active world exit still uses the existing leave-shop transaction")
	coordinator.queue_free()
	await process_frame
	current_scene = null


func _test_battle02_static_sentry_projectile_and_clear_protocol() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var definition := FLOW.combat_room_for(&"combat_02_swarm")
	var room := definition.room_scene.instantiate() as RunRoomInstance
	stage.add_child(room)
	_expect(room.configure(definition), "Battle02 configures with the dedicated Sentry scene")
	room.activate()
	var sentry := room.initial_enemies[0] as TidalSentry
	_expect(sentry != null and sentry.scene_file_path == "res://scenes/run/enemies/tidal_sentry.tscn", "InitialEnemySpawns/Spawn1 instantiates the dedicated Tidal Sentry")
	_expect_eq(sentry.growth_enemy_id, &"swarm_left", "Sentry preserves the formal spawn identity")
	_expect_eq(sentry.damage_receiver.maximum_health, 55, "Sentry preserves Spawn1 55 HP")
	_expect_eq(sentry.dream_dust_reward, 15, "Sentry preserves Spawn1 15 dream dust")
	for enemy: CombatEnemy in room.enemies:
		if enemy != sentry:
			enemy.ai_enabled = false

	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	stage.add_child(player)
	player.global_position = Vector2(900, 519)
	player.set_physics_process(false)
	player.set_process(false)
	_expect(await _wait_until(func() -> bool: return sentry.is_on_floor() and sentry.player == player, 180, true), "Sentry deterministically acquires the single formal Player and lands")
	var settled_x := sentry.global_position.x
	_expect_near(sentry.global_position.y + 32.0, 559.0, 2.0, "Sentry settles on the Battle02 lower one-way platform")

	var lifecycle := {"created": 0, "finished": 0, "moved": {}, "deliveries": [], "reasons": []}
	sentry.delivery_created.connect(func(node: Node) -> void:
		var delivery := node as ProjectileDelivery
		if delivery == null:
			return
		lifecycle["created"] = int(lifecycle["created"]) + 1
		(lifecycle["deliveries"] as Array).append(weakref(delivery))
		delivery.delivery_finished.connect(func(reason: StringName) -> void:
			lifecycle["finished"] = int(lifecycle["finished"]) + 1
			(lifecycle["reasons"] as Array).append(reason)
		)
	)
	for _frame: int in 600:
		await physics_frame
		for reference: WeakRef in lifecycle["deliveries"]:
			var delivery: Variant = reference.get_ref()
			if is_instance_valid(delivery) and delivery is ProjectileDelivery and delivery.distance_travelled > 0.0:
				(lifecycle["moved"] as Dictionary)[delivery.get_instance_id()] = true
		if int(lifecycle["created"]) >= 3 and int(lifecycle["finished"]) >= 3:
			break
	_expect(int(lifecycle["created"]) >= 3, "Sentry fires at least three projectiles on deterministic cooldown")
	_expect((lifecycle["moved"] as Dictionary).size() >= 3, "every observed projectile enters lifecycle and moves before cleanup")
	_expect(int(lifecycle["finished"]) >= 3, "every observed projectile reaches a cleanup boundary")
	_expect((lifecycle["reasons"] as Array).has(DeliveryBase.FINISH_HIT), "horizontal Sentry projectile can hit the aligned Player: %s" % str(lifecycle["reasons"]))
	_expect_near(sentry.global_position.x, settled_x, 1.0, "Sentry horizontal displacement remains within one pixel")
	_expect(sentry.combat_receiver != null and sentry.element_carrier != null and sentry.damage_receiver != null, "Sentry reuses CombatEnemy receiver, element, and health components")

	for enemy: CombatEnemy in room.initial_enemies:
		_defeat(enemy)
	await process_frame
	_expect(room.reinforcement_activated, "Sentry death participates in the existing wave protocol")
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat(enemy)
	await process_frame
	_expect(room.room_is_cleared and room.chest.visible, "Sentry death and remaining enemies clear the room normally")
	player.queue_free()
	room.queue_free()
	await process_frame
	stage.queue_free()
	current_scene = null
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
	coordinator.player.global_position = room.portal.global_position
	coordinator.player.interact_requested.emit()
	if wait_after_portal:
		await process_frame


func _defeat(enemy: CombatEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.defeated:
		return
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task58_finisher", 58, 58, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _wait_combat(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.active_room != null and coordinator.active_room.room_id == room_id and coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 360, false)


func _wait_phase(coordinator: RunFlowCoordinator, phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.host.run_session != null and coordinator.current_snapshot().route.phase == phase
	, 360, false)


func _press_physical_loadout(coordinator: RunFlowCoordinator) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_L
	coordinator.combat_hud._unhandled_input(event)
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


func _wait_until(predicate: Callable, frames: int, physics: bool) -> bool:
	for _frame: int in frames:
		if predicate.call():
			return true
		if physics:
			await physics_frame
		else:
			await process_frame
	return bool(predicate.call())


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [
		snapshot.revision,
		snapshot.route.phase,
		snapshot.route.run_id,
		snapshot.route.current_room_id,
		snapshot.economy.balance,
		snapshot.shop.session_id if snapshot.shop != null else &"",
	]


func _alpha_scan(image: Image) -> Dictionary:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	var partial := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a8
			if alpha <= 0:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
			if alpha < 255:
				partial += 1
	return {"bbox": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1), "partial": partial}


func _sprite_visible_bottom(sprite: Sprite2D, bbox: Rect2i) -> float:
	return sprite.position.y + (float(bbox.end.y) - sprite.texture.get_height() * 0.5) * sprite.scale.y


func _runtime_old_asset_references(path: String) -> Array[String]:
	var hits: Array[String] = []
	var directory := DirAccess.open(path)
	if directory == null:
		return hits
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry == ".godot" or entry == "docs" or entry == ".git" or entry == "tests":
			entry = directory.get_next()
			continue
		var child := path.path_join(entry)
		if directory.current_is_dir():
			hits.append_array(_runtime_old_asset_references(child))
		elif entry.get_extension() in ["gd", "tscn", "tres", "res", "gdshader"]:
			var text := FileAccess.get_file_as_string(child)
			if text.contains(OLD_CHEST_ROOT) or text.contains(OLD_PORTAL_ROOT):
				hits.append(child)
		entry = directory.get_next()
	directory.list_dir_end()
	return hits


func _run_test(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _run_async_test(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _expect_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	_harness.expect_near(actual, expected, tolerance, description)


func _finish() -> void:
	quit(_harness.report("TASK 58 FORMAL INTERACTABLES CROWN SENTRY TESTS"))
