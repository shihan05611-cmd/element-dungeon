extends SceneTree

const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BATTLE_01_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_04_validation.tres")
const BATTLE_02_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_02_swarm.tres")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task43/screenshots"

var _failures: Array[String] = []
var _saved: Array[String] = []
var _hit_sequence := 43_500_000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = _first_chest_skill_run_id()
	root.add_child(coordinator)
	current_scene = coordinator
	_assert(await _wait_until(func() -> bool: return coordinator.active_room != null and coordinator.current_snapshot().route.phase == RunPhase.COMBAT, 240), "capture RunGame boots")
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	overlay.toggle_loadout()
	await _settle()
	_assert(overlay.visible and overlay.formal_kind() == &"combat_loadout", "live combat page is visible")
	_assert(not coordinator.combat_loadout_available() and _visible_text(overlay).contains("清场后可调整"), "live page proves read-only clear gate")
	await _save("task43_01_live_combat_loadout_readonly_1920x1080.png", Vector2i(1920, 1080))

	var room := coordinator.active_room
	var refs: Array[WeakRef] = []
	for enemy: CombatEnemy in room.initial_enemies:
		refs.append(weakref(enemy))
		_defeat(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		refs.append(weakref(enemy))
		_defeat(enemy)
	await process_frame
	_assert(room.room_is_cleared and coordinator.combat_loadout_available(), "all configured enemies open the same page authority gate")
	_assert(_all_freed(refs), "all formal corpse nodes are absent before evidence")
	overlay.toggle_loadout()
	coordinator.player.global_position = room.chest.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	var after_claim := coordinator.current_snapshot()
	var auto_skill := _new_equipped_skill(after_claim.loadout)
	_assert(not auto_skill.is_empty() and after_claim.skills.owns(auto_skill), "first formal chest grants and auto-equips a real skill")
	overlay.toggle_loadout()
	await _settle()
	_assert(overlay.visible and coordinator.combat_loadout_available() and _visible_text(overlay).contains("可点击或拖拽调整"), "cleared page is visibly writable")
	_assert(_visible_text(overlay).contains(CATALOG.content_for(auto_skill).display_name), "cleared page displays the real auto-equipped skill")
	await _save("task43_02_cleared_combat_loadout_auto_equipped_1920x1080.png", Vector2i(1920, 1080))

	overlay.toggle_loadout()
	await _settle()
	_assert(not overlay.visible and _all_freed(refs), "world evidence has zero corpse nodes")
	_assert(room.chest.visible and room.chest.consumed and _chest_grounded(room), "opened chest is visible and grounded")
	_assert(coordinator.host.runtime_loadout.snapshot().get_skill_id(_slot_for_skill(after_claim.loadout, auto_skill)) == auto_skill, "HUD authority retains the auto-equipped skill")
	await _save("task43_03_world_no_corpses_grounded_chest_hud_1920x1080.png", Vector2i(1920, 1080))
	coordinator.queue_free()
	await process_frame
	await _capture_platform(BATTLE_01_ROOM, "task43_04_battle01_center_platform_real_jump_2560x1440.png", "res://scenes/run/rooms/room_arena_flat.tscn", 484.0, 699.0, 837.0)
	await _capture_platform(BATTLE_02_ROOM, "task43_05_battle02_lower_platform_real_jump_2560x1440.png", "res://scenes/run/rooms/room_arena_tidal_battle_02.tscn", 528.0, 1110.0, 1252.0)
	_assert(_saved.size() == 5, "capture writes exactly five Task43 PNG files")
	print("Task43 visual capture: 1 test, %d images, %d failures" % [_saved.size(), _failures.size()])
	for path: String in _saved:
		print("CAPTURED: %s" % path)
	quit(0 if _failures.is_empty() else 1)


func _first_chest_skill_run_id() -> StringName:
	for index: int in 256:
		var run_id := StringName("task43_capture_%03d" % index)
		var runtime := RuntimeSkillLoadout.new(CATALOG.gameplay_definitions(), CATALOG.default_loadout_snapshot())
		var session := RunSession.new(
			CATALOG.reward_definitions(), CATALOG.relic_definitions, CATALOG.initial_owned_skill_ids(),
			[ElementIds.WATER, ElementIds.FIRE], runtime, null,
			RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
		)
		if not session.start_formal_run(&"start", 0).accepted:
			continue
		var pending := session.snapshot().route.pending_node_id
		var definition := FLOW.combat_room_for(pending)
		if not session.accept_room_transition(&"accept", 1, pending, 43_900 + index, definition.room_scene.resource_path).accepted:
			continue
		var claim := session.claim_formal_room_chest(&"claim", 2, pending)
		if (
			claim.accepted
			and claim.chest_reward.kind == RunChestRewardSnapshot.Kind.SKILL
			and not _slot_for_skill(claim.run_snapshot.loadout, claim.chest_reward.skill_id).is_empty()
		):
			return run_id
	_assert(false, "a formal first-chest skill cohort member exists")
	return &"task43_capture_fallback"


func _capture_platform(definition: CombatRoomDefinition, file_name: String, scene_path: String, target_y: float, target_min_x: float, target_max_x: float) -> void:
	root.size = Vector2i(2560, 1440)
	var room_id := definition.room_id
	_assert(definition.room_scene.resource_path == scene_path, "%s uses its formal full-room platform template" % String(room_id))
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var room := definition.room_scene.instantiate() as RunRoomInstance
	stage.add_child(room)
	_assert(room.configure(definition), "%s retained room resource configures" % String(room_id))
	room.activate()
	for enemy: CombatEnemy in room.enemies:
		enemy.ai_enabled = false
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	stage.add_child(player)
	player.global_position = room.player_spawn_global_position()
	var grounded_frames := 0
	for _frame: int in 120:
		await physics_frame
		if player.is_on_floor():
			grounded_frames += 1
			if grounded_frames >= 2:
				break
		else:
			grounded_frames = 0
	_assert(grounded_frames >= 2, "%s player stays grounded for two consecutive physics frames before capture jump" % String(room_id))
	var spawn := player.global_position
	Input.action_press(&"move_right")
	var jump := InputEventAction.new()
	jump.action = &"jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	var rising_airborne := false
	var landed := false
	var platform_floor_frames := 0
	for _frame: int in 120:
		await physics_frame
		if player.velocity.y < 0.0 and not player.is_on_floor():
			rising_airborne = true
		if (
			rising_airborne
			and player.is_on_floor()
			and absf(player.global_position.y - target_y) <= 3.0
			and player.global_position.x >= target_min_x
			and player.global_position.x <= target_max_x
		):
			Input.action_release(&"move_right")
			platform_floor_frames += 1
			if platform_floor_frames >= 2:
				landed = true
				break
		else:
			platform_floor_frames = 0
	Input.action_release(&"move_right")
	var release := InputEventAction.new()
	release.action = &"jump"
	release.pressed = false
	Input.parse_input_event(release)
	_assert(rising_airborne, "%s real jump input produces upward velocity while airborne" % String(room_id))
	_assert(landed and player.global_position.distance_to(spawn) > 80.0, "%s reaches its first formal platform only through real input/physics" % String(room_id))
	await _settle()
	await _save(file_name, Vector2i(2560, 1440))
	stage.queue_free()
	await process_frame


func _clear_claim_and_exit(coordinator: RunFlowCoordinator) -> void:
	var room := coordinator.active_room
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat(enemy)
	await process_frame
	_assert(room.room_is_cleared, "%s clears through both formal waves" % String(room.room_id))
	coordinator.player.global_position = room.chest.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	_assert(room.chest.consumed and room.portal != null and not room.portal.locked, "%s chest unlocks its world portal" % String(room.room_id))
	coordinator.player.global_position = room.portal.global_position
	coordinator.player.interact_requested.emit()
	await process_frame


func _wait_combat(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			coordinator.active_room != null
			and coordinator.current_snapshot().route.phase == RunPhase.COMBAT
			and coordinator.active_room.room_id == room_id
		)
	, 360)


func _save(file_name: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_assert(image.get_size() == expected_size, "%s keeps original viewport size" % file_name)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	_assert(image.save_png(ProjectSettings.globalize_path(path)) == OK, "%s saves successfully" % file_name)
	_saved.append(path)


func _defeat(enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task43_capture_finisher", 43, 43, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	var result := enemy.combat_receiver.receive_hit(request)
	_assert(result.accepted and enemy.defeated, "capture defeats a formal enemy through CombatReceiver")


func _new_equipped_skill(loadout: RuntimeLoadoutSnapshot) -> StringName:
	for entry: RuntimeLoadoutSlotSnapshot in loadout.entries:
		if entry.skill_id != &"" and entry.skill_id != &"element_bolt":
			return entry.skill_id
	return &""


func _slot_for_skill(loadout: RuntimeLoadoutSnapshot, skill_id: StringName) -> StringName:
	for entry: RuntimeLoadoutSlotSnapshot in loadout.entries:
		if entry.skill_id == skill_id:
			return entry.slot_id
	return &""


func _all_freed(refs: Array[WeakRef]) -> bool:
	for ref: WeakRef in refs:
		if is_instance_valid(ref.get_ref()):
			return false
	return true


func _chest_grounded(room: RunRoomInstance) -> bool:
	var sprite := room.chest.get_node("Sprite2D") as Sprite2D
	var image := sprite.texture.get_image()
	var max_y := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				max_y = maxi(max_y, y)
	var bottom := room.chest.global_position.y + (float(max_y) - float(image.get_height()) * 0.5) * sprite.scale.y
	var ground_shape := room.get_node("Ground/CollisionShape2D") as CollisionShape2D
	var rectangle := ground_shape.shape as RectangleShape2D
	var ground_top := ground_shape.global_position.y - rectangle.size.y * 0.5
	return absf(bottom - ground_top) <= 2.0


func _visible_text(node: Node) -> String:
	var result := ""
	if node is Label and node.visible:
		result += (node as Label).text + "\n"
	if node is Button and node.visible:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _visible_text(child)
	return result


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _wait_until(predicate: Callable, limit: int) -> bool:
	for _frame: int in limit:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("CAPTURE FAIL: %s" % message)
