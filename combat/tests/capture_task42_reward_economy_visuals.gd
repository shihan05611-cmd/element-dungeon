extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const PASSIVE_IDS: Array[StringName] = [&"burning", &"unending", &"passive_vitality", &"passive_energy"]

var _coordinator: RunFlowCoordinator
var _overlay: RunOverlayInterface
var _hit_sequence: int = 42_500_000
var _capture_count: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


## Evidence capture intentionally performs the live flow without test asserts.
## Harness runners own economic and authority contracts; this file owns images.
func _run() -> void:
	await _capture_safe_run()
	await _dispose_run()
	await _capture_risk_run()
	await _dispose_run()
	print("TASK42 VISUAL CAPTURE COMPLETED: %d screenshots" % _capture_count)
	quit(0)


func _capture_safe_run() -> void:
	root.size = Vector2i(1920, 1080)
	await _boot(_pre_shop_dust_run_id("task42_safe", &""))
	await _record_and_finish_normal_room()
	await _wait_combat(&"combat_02_swarm")
	await _record_and_finish_normal_room()
	await _wait_phase(RunPhase.SHOP)
	await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 180)
	await _capture("task42_01_safe_shop_before_1920x1080.png", Vector2i(1920, 1080))
	for index: int in PASSIVE_IDS.size():
		await _purchase_and_equip(PASSIVE_IDS[index], SkillSlotIds.passive()[index])
	await _capture("task42_02_safe_shop_after_1920x1080.png", Vector2i(1920, 1080))
	await _leave_physical_shop()
	await _wait_combat(&"combat_04_validation")
	await _record_and_finish_normal_room()
	await _wait_combat(&"combat_06_final_boss")
	await _finish_boss()
	await _wait_phase(RunPhase.RUN_COMPLETE)
	root.size = Vector2i(2560, 1440)
	await _capture("task42_03_safe_results_2560x1440.png", Vector2i(2560, 1440))


func _capture_risk_run() -> void:
	root.size = Vector2i(1920, 1080)
	await _boot(_pre_shop_dust_run_id("task42_risk", &"element_reclaim"))
	await _record_and_finish_normal_room()
	await _wait_combat(&"combat_02_swarm")
	await _record_and_finish_normal_room()
	await _wait_phase(RunPhase.SHOP)
	await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 180)
	for index: int in PASSIVE_IDS.size():
		await _purchase_and_equip(PASSIVE_IDS[index], SkillSlotIds.passive()[index])
	await _upgrade(&"element_reclaim")
	await _capture("task42_03_risk_shop_after_1920x1080.png", Vector2i(1920, 1080))
	await _leave_physical_shop()
	await _wait_combat(&"combat_04_validation")
	await _record_and_finish_normal_room()
	await _wait_combat(&"combat_06_final_boss")
	await _finish_boss()
	await _wait_phase(RunPhase.RUN_COMPLETE)
	root.size = Vector2i(2560, 1440)
	await _capture("task42_04_risk_results_2560x1440.png", Vector2i(2560, 1440))


func _boot(run_id: StringName) -> void:
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = run_id
	root.add_child(_coordinator)
	current_scene = _coordinator
	await _wait_combat(&"combat_01_entry")
	_overlay = _coordinator.combat_hud.run_overlay as RunOverlayInterface


func _dispose_run() -> void:
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_coordinator = null
	_overlay = null


func _record_and_finish_normal_room() -> void:
	var room := _coordinator.active_room
	_defeat_batch(room.initial_enemies)
	await process_frame
	_defeat_batch(room.reinforcement_enemies)
	await process_frame
	_interact_at(room.chest)
	await process_frame
	_interact_at(room.route_transition)
	await process_frame


func _finish_boss() -> void:
	var room := _coordinator.active_room
	_defeat_batch(room.enemies)
	await process_frame
	_interact_at(room.chest)
	await process_frame


func _purchase_and_equip(skill_id: StringName, slot_id: StringName) -> void:
	var before := _coordinator.current_snapshot()
	if not before.skills.owns(skill_id):
		_press(StringName("purchase:%s" % String(skill_id)))
		await process_frame
	_press(StringName("select:%s" % String(skill_id)))
	await process_frame
	_press(StringName("slot:%s" % String(slot_id)))
	await process_frame


func _upgrade(skill_id: StringName) -> void:
	_press(StringName("upgrade:%s" % String(skill_id)))
	await process_frame


func _leave_physical_shop() -> void:
	var shop_room := _coordinator.active_shop_room
	_overlay.toggle_loadout()
	await process_frame
	Input.action_press(&"move_right")
	for _frame: int in 360:
		await physics_frame
		if shop_room.exit_transition.can_interact(_coordinator.player.global_position):
			break
	Input.action_release(&"move_right")
	await _press_interact_input()


func _pre_shop_dust_run_id(prefix: String, required_first_skill: StringName) -> StringName:
	for index: int in 512:
		var run_id := StringName("%s_%03d" % [prefix, index])
		var session := RunSession.new(CATALOG.reward_definitions(), CATALOG.relic_definitions, CATALOG.initial_owned_skill_ids(), [ElementIds.WATER, ElementIds.FIRE], null, null, RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id)
		if not session.start_formal_run(&"start", 0).accepted:
			continue
		var first := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_first", session.snapshot().revision, first.room_id, 42_000 + index * 2, first.room_scene.resource_path).accepted:
			continue
		var first_claim := session.claim_formal_room_chest(&"claim_first", session.snapshot().revision, first.room_id)
		if not first_claim.accepted or (not required_first_skill.is_empty() and first_claim.chest_reward.skill_id != required_first_skill):
			continue
		if not session.handle_event(RoomCompletedEvent.new(&"complete_first", first.room_id, 0, 0, first.completion_dream_dust, false)).accepted:
			continue
		var second := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_second", session.snapshot().revision, second.room_id, 42_001 + index * 2, second.room_scene.resource_path).accepted:
			continue
		var second_claim := session.claim_formal_room_chest(&"claim_second", session.snapshot().revision, second.room_id)
		if not second_claim.accepted or second_claim.chest_reward.kind != RunChestRewardSnapshot.Kind.DREAM_DUST:
			continue
		return run_id
	return StringName("%s_fallback" % prefix)


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task42_capture", 42, 42, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
		enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _interact_at(target: RunWorldInteractable) -> void:
	var room := _coordinator.active_room
	_coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center()) if room != null and target == room.route_transition else target.global_position
	_coordinator.player.interact_requested.emit()


func _press(control_id: StringName) -> bool:
	var button := _overlay.formal_control(control_id) as Button
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


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
		image.save_png("res://docs/agent_tasks/evidence/task42/screenshots/%s" % file_name)
		_capture_count += 1
