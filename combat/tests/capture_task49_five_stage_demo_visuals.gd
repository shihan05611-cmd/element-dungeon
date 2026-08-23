extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task49/screenshots"

var _coordinator: RunFlowCoordinator
var _failures: Array[String] = []
var _saved: Array[String] = []
var _hit_sequence := 49_500_000
var _visited: Array[StringName] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task49_visual_five_stage"
	root.add_child(_coordinator)
	current_scene = _coordinator

	_assert(await _wait_combat(&"combat_01_entry"), "demo boots into combat_01_entry")
	var first := _coordinator.active_room
	_visited.append(first.room_id)
	_assert(first.room_definition.single_wave, "first room carries the authoritative single-wave policy")
	_assert(first.initial_enemies.size() == 2, "first room instantiates exactly two initial enemies")
	_assert(first.reinforcement_enemies.is_empty(), "first room instantiates zero reinforcements")
	await _settle()
	await _save("task49_01_first_room_two_enemies_1920x1080.png")

	var before_claim := _coordinator.current_snapshot()
	_defeat_batch(first.initial_enemies)
	await process_frame
	_assert(first.room_is_cleared and first.reinforcement_enemies.is_empty(), "second initial defeat clears immediately with no reinforcement nodes")
	_assert(first.chest.visible and first.route_transition.locked, "clear reveals the chest while keeping the route transition locked")
	await _settle()
	await _save("task49_02_first_room_immediate_clear_1920x1080.png")

	_interact_at(first.chest)
	await process_frame
	var after_claim := _coordinator.current_snapshot()
	var gained := _newly_owned_skill(before_claim, after_claim)
	var content := CATALOG.content_for(gained)
	_assert(not gained.is_empty() and after_claim.skills.owns(gained), "first chest grants one previously unowned skill")
	_assert(content != null and content.reward_pool, "first chest skill belongs to reward_pool")
	_assert(content != null and content.gameplay_definition.is_active_skill(), "first chest skill is active, never passive")
	_assert(first.chest.consumed and first.route_transition.enabled and not first.route_transition.locked, "active reward unlocks the first route transition")
	await _settle()
	await _save("task49_03_first_chest_active_guarantee_1920x1080.png")
	_coordinator.player.global_position = first.to_global(first.route_transition_zone.get_center())
	_coordinator.player.interact_requested.emit()

	_assert(await _wait_combat(&"combat_02_swarm"), "first route transition reaches combat_02_swarm directly")
	_visited.append(&"combat_02_swarm")
	await _finish_normal_room()
	_assert(await _wait_phase(RunPhase.SHOP), "second combat reaches the single shop")
	_assert(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 240), "physical shop is instantiated")
	_assert(_coordinator.current_snapshot().route.completed_combat_rooms == 2, "shop opens after exactly two combats")
	await _settle()
	await _save("task49_04_mid_shop_after_two_combats_1920x1080.png")
	await _leave_shop()

	_assert(await _wait_combat(&"combat_04_validation"), "shop exits directly to combat_04_validation")
	_visited.append(&"combat_04_validation")
	await _finish_normal_room()
	_assert(await _wait_combat(&"combat_06_final_boss"), "third combat reaches the boss directly")
	_visited.append(&"combat_06_final_boss")
	_assert(_coordinator.active_room.room_definition.final_boss, "final stage is the authoritative boss room")
	await create_timer(1.0).timeout
	await _settle()
	await _save("task49_05_final_boss_fourth_combat_1920x1080.png")

	_defeat_batch(_coordinator.active_room.enemies)
	await process_frame
	_assert(_coordinator.active_room.room_is_cleared and _coordinator.active_room.chest.visible, "boss defeat exposes settlement chest")
	_interact_at(_coordinator.active_room.chest)
	_assert(await _wait_phase(RunPhase.RUN_COMPLETE), "boss settlement reaches run_result")
	var final := _coordinator.current_snapshot()
	_assert(_visited == [&"combat_01_entry", &"combat_02_swarm", &"combat_04_validation", &"combat_06_final_boss"], "visited combat order is exact")
	_assert(final.result != null and final.result.is_complete(), "result is a completed formal run")
	_assert(final.route.completed_combat_rooms == 4 and final.route.shop_visits == 1 and final.route.route_choices == 0, "result freezes 4 combat / 1 shop / 0 route")
	await _settle()
	await _save("task49_06_result_four_one_zero_1920x1080.png")

	_assert(_saved.size() == 6, "capture writes one six-image 1920x1080 evidence group")
	print("Task49 visual capture: 1 test, %d images, %d failures" % [_saved.size(), _failures.size()])
	for path: String in _saved:
		print("CAPTURED: %s" % path)
	quit(0 if _failures.is_empty() else 1)


func _finish_normal_room() -> void:
	var room := _coordinator.active_room
	_assert(room != null and not room.room_definition.final_boss, "normal-room finisher has a live non-boss room")
	_defeat_batch(room.initial_enemies)
	await process_frame
	if not room.reinforcement_enemies.is_empty():
		_assert(await _wait_until(func() -> bool: return room.reinforcement_activated, 60), "%s activates its configured reinforcement wave" % String(room.room_id))
		_defeat_batch(room.reinforcement_enemies)
		await process_frame
	_assert(room.room_is_cleared, "%s clears through its formal enemy configuration" % String(room.room_id))
	_interact_at(room.chest)
	await process_frame
	_assert(room.chest.consumed and room.route_transition != null and not room.route_transition.locked, "%s chest unlocks its route transition zone" % String(room.room_id))
	_interact_at(room.route_transition)
	await process_frame


func _leave_shop() -> void:
	var shop := _coordinator.active_shop_room
	var overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	_assert(shop != null and shop.exit_transition != null, "shop exposes one physical exit transition zone")
	if overlay.visible:
		overlay.toggle_loadout()
		await process_frame
	_coordinator.player.global_position = shop.to_global(shop.exit_transition_zone.get_center())
	_coordinator.player.interact_requested.emit()
	await process_frame


func _newly_owned_skill(before: RunSnapshot, after: RunSnapshot) -> StringName:
	for candidate: SkillContentDefinition in CATALOG.skill_contents:
		if candidate != null and not before.skills.owns(candidate.skill_id) and after.skills.owns(candidate.skill_id):
			return candidate.skill_id
	return &""


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task49_capture_finisher", 49, 49, &"player", ElementIds.NONE, CombatStatSnapshot.new())
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
	, 360)


func _wait_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator.host.run_session != null and _coordinator.current_snapshot().route.phase == phase
	, 360)


func _wait_until(predicate: Callable, limit: int) -> bool:
	for _frame: int in limit:
		if predicate.call():
			return true
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
