extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const PASSIVE_IDS: Array[StringName] = [&"burning", &"unending", &"passive_vitality", &"passive_energy"]

var _coordinator: RunFlowCoordinator
var _overlay: RunOverlayInterface
var _hit_sequence: int = 42_500_000
var _capture_count: int = 0
var _chest_dust: int = 0
var _chest_skills: Array[StringName] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _capture_safe_run()
	await _dispose_run()
	await _capture_risk_run()
	await _dispose_run()
	print("TASK42 VISUAL CAPTURE PASSED: %d authority-checked screenshots" % _capture_count)
	quit(0)


func _capture_safe_run() -> void:
	root.size = Vector2i(1920, 1080)
	var run_id := _pre_shop_dust_run_id("task42_safe", &"")
	await _boot(run_id)
	await _record_and_finish_normal_room()
	assert(await _wait_combat(&"combat_02_swarm"))
	await _record_and_finish_normal_room()
	assert(await _wait_phase(RunPhase.SHOP))
	assert(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 180))
	_assert_guaranteed_active_history()
	_assert_shop_authority(run_id, 370, 0, 0, 0, 370, 150, _chest_skills)
	await _capture("task42_01_safe_shop_before_1920x1080.png", Vector2i(1920, 1080))
	for index: int in PASSIVE_IDS.size():
		await _purchase_and_equip(PASSIVE_IDS[index], SkillSlotIds.passive()[index])
	_assert_shop_authority(run_id, 370, 300, 0, 0, 70, 150, _chest_skills)
	_assert_four_passives_and_active(&"", 1)
	await _capture("task42_02_safe_shop_after_1920x1080.png", Vector2i(1920, 1080))
	await _leave_physical_shop()
	assert(await _wait_combat(&"combat_04_validation"))
	await _record_and_finish_normal_room()
	assert(await _wait_combat(&"combat_06_final_boss"))
	await _finish_boss()
	assert(await _wait_phase(RunPhase.RUN_COMPLETE))
	var final := _coordinator.current_snapshot()
	_assert_result_authority(final, run_id, 495, 300, 0, 0, 195, 150, _chest_skills)
	_assert_four_passives_and_active(&"", 1)
	root.size = Vector2i(2560, 1440)
	await _capture("task42_03_safe_results_2560x1440.png", Vector2i(2560, 1440))


func _capture_risk_run() -> void:
	root.size = Vector2i(1920, 1080)
	var run_id := _pre_shop_dust_run_id("task42_risk", &"element_reclaim")
	await _boot(run_id)
	await _record_and_finish_normal_room()
	assert(await _wait_combat(&"combat_02_swarm"))
	await _record_and_finish_normal_room()
	assert(await _wait_phase(RunPhase.SHOP))
	assert(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 180))
	_assert_guaranteed_active_history()
	for index: int in PASSIVE_IDS.size():
		await _purchase_and_equip(PASSIVE_IDS[index], SkillSlotIds.passive()[index])
	await _upgrade(&"element_reclaim", 2)
	_assert_shop_authority(run_id, 370, 300, 50, 0, 20, 150, [&"element_reclaim"])
	_assert_four_passives_and_active(&"element_reclaim", 2)
	await _capture("task42_03_risk_shop_after_1920x1080.png", Vector2i(1920, 1080))
	await _leave_physical_shop()
	assert(await _wait_combat(&"combat_04_validation"))
	await _record_and_finish_normal_room()
	assert(await _wait_combat(&"combat_06_final_boss"))
	await _finish_boss()
	assert(await _wait_phase(RunPhase.RUN_COMPLETE))
	var final := _coordinator.current_snapshot()
	_assert_result_authority(final, run_id, 495, 300, 50, 0, 145, 150, _chest_skills)
	_assert_four_passives_and_active(&"element_reclaim", 2)
	root.size = Vector2i(2560, 1440)
	await _capture("task42_04_risk_results_2560x1440.png", Vector2i(2560, 1440))


func _boot(run_id: StringName) -> void:
	_chest_dust = 0
	_chest_skills = []
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	assert(_coordinator != null)
	_coordinator.run_id_override = run_id
	root.add_child(_coordinator)
	current_scene = _coordinator
	assert(await _wait_combat(&"combat_01_entry"))
	_overlay = _coordinator.combat_hud.run_overlay as RunOverlayInterface
	assert(_coordinator.current_snapshot().route.run_id == run_id)


func _dispose_run() -> void:
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_coordinator = null
	_overlay = null


func _record_and_finish_normal_room() -> void:
	var room := _coordinator.active_room
	assert(room != null and not room.room_definition.final_boss)
	var before := _coordinator.current_snapshot()
	var base_dust := _room_dust(room)
	_defeat_batch(room.initial_enemies)
	await process_frame
	if room.reinforcement_enemies.is_empty():
		assert(room.room_is_cleared)
	else:
		assert(room.reinforcement_activated and not room.room_is_cleared)
		_defeat_batch(room.reinforcement_enemies)
		await process_frame
	assert(room.room_is_cleared and room.chest.enabled and room.portal.locked)
	_interact_at(room.chest)
	await process_frame
	assert(room.chest.consumed and not room.portal.locked)
	_interact_at(room.portal)
	await process_frame
	var after := _coordinator.current_snapshot()
	var dust_reward := after.economy.total_earned - before.economy.total_earned - base_dust
	assert(dust_reward == 0 or dust_reward == RunChestRewardSnapshot.DREAM_DUST_AMOUNT)
	_chest_dust += dust_reward
	for skill_id: StringName in after.skills.owned_skill_ids:
		if not before.skills.owned_skill_ids.has(skill_id):
			_chest_skills.append(skill_id)


func _finish_boss() -> void:
	var room := _coordinator.active_room
	assert(room != null and room.room_definition.final_boss)
	var before := _coordinator.current_snapshot()
	_defeat_batch(room.enemies)
	await process_frame
	assert(room.room_is_cleared and room.chest.visible and room.portal == null)
	assert(_coordinator.current_snapshot().economy.balance == before.economy.balance)
	_interact_at(room.chest)
	await process_frame


func _purchase_and_equip(skill_id: StringName, slot_id: StringName) -> void:
	var before := _coordinator.current_snapshot()
	var content := CATALOG.content_for(skill_id)
	assert(before.route.phase == RunPhase.SHOP and before.shop != null and content != null)
	if before.skills.owns(skill_id):
		assert(_overlay.formal_control(StringName("purchase:%s" % String(skill_id))) == null)
	else:
		assert(_press(StringName("purchase:%s" % String(skill_id))))
		await process_frame
		var purchased := _coordinator.current_snapshot()
		assert(purchased.skills.owns(skill_id))
		assert(purchased.economy.balance == before.economy.balance - content.purchase_price)
	assert(_press(StringName("select:%s" % String(skill_id))))
	await process_frame
	assert(_press(StringName("slot:%s" % String(slot_id))))
	await process_frame
	assert(_coordinator.current_snapshot().loadout.get_skill_id(slot_id) == skill_id)


func _upgrade(skill_id: StringName, expected_level: int) -> void:
	assert(_press(StringName("upgrade:%s" % String(skill_id))))
	await process_frame
	assert(_coordinator.current_snapshot().skills.progress_for(skill_id).level == expected_level)


func _reset(skill_id: StringName) -> void:
	assert(_press(StringName("reset:%s" % String(skill_id))))
	await process_frame
	assert(_press(StringName("reset_confirm:%s" % String(skill_id))))
	await process_frame
	var progress := _coordinator.current_snapshot().skills.progress_for(skill_id)
	assert(progress.level == 1 and progress.cumulative_upgrade_spend == 0)


func _leave_physical_shop() -> void:
	var shop_room := _coordinator.active_shop_room
	assert(shop_room != null and shop_room.exit_portal != null)
	var before := _authority_signature(_coordinator.current_snapshot())
	var start_x := _coordinator.player.global_position.x
	var leave_button := _overlay.formal_control(&"leave_shop") as Button
	assert(leave_button != null and leave_button.disabled)
	_overlay.toggle_loadout()
	await process_frame
	assert(not _overlay.visible and _authority_signature(_coordinator.current_snapshot()) == before)
	Input.action_press(&"move_right")
	var reached := false
	for _frame: int in 360:
		await physics_frame
		if shop_room.exit_portal.can_interact(_coordinator.player.global_position):
			reached = true
			break
	Input.action_release(&"move_right")
	assert(reached and _coordinator.player.global_position.x > start_x + 300.0)
	assert(shop_room.exit_portal.prompt.visible and shop_room.exit_portal.prompt.text == "F · 离开商店")
	await _press_interact_input()


func _assert_shop_authority(run_id: StringName, earned: int, purchases: int, upgrades: int, refunded: int, balance: int, chest_dust: int, chest_skills: Array[StringName]) -> void:
	var snapshot := _coordinator.current_snapshot()
	assert(snapshot.route.run_id == run_id and snapshot.route.phase == RunPhase.SHOP)
	assert(snapshot.shop != null and not snapshot.shop.session_id.is_empty() and snapshot.revision > 0)
	assert(snapshot.route.shop_visits == 1 and snapshot.route.completed_combat_rooms == 2)
	assert(snapshot.economy.total_earned == earned)
	assert(snapshot.economy.total_spent_on_purchases == purchases)
	assert(snapshot.economy.total_spent_on_upgrades == upgrades)
	assert(snapshot.economy.total_refunded == refunded and snapshot.economy.balance == balance)
	assert(_chest_dust == chest_dust and _chest_skills == chest_skills)


func _assert_result_authority(final: RunSnapshot, run_id: StringName, earned: int, purchases: int, upgrades: int, refunded: int, balance: int, chest_dust: int, chest_skills: Array[StringName]) -> void:
	assert(final.route.run_id == run_id and final.route.phase == RunPhase.RUN_COMPLETE)
	assert(final.result != null and final.result.is_complete())
	assert(final.route.completed_combat_rooms == 4 and final.route.shop_visits == 1 and final.route.route_choices == 0)
	assert(final.economy.total_earned == earned)
	assert(final.economy.total_spent_on_purchases == purchases)
	assert(final.economy.total_spent_on_upgrades == upgrades)
	assert(final.economy.total_refunded == refunded and final.economy.balance == balance)
	assert(final.economy.is_valid() and final.economy.balance == final.economy.conserved_balance())
	assert(_chest_dust == chest_dust and _chest_skills == chest_skills)


func _assert_four_passives_and_active(expected_active: StringName, expected_level: int) -> void:
	var snapshot := _coordinator.current_snapshot()
	assert(snapshot.loadout.entries.size() == 7)
	assert(snapshot.loadout.get_skill_id(SkillSlotIds.ACTIVE_1) == &"element_bolt")
	assert(not snapshot.loadout.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty())
	if not expected_active.is_empty():
		assert(snapshot.skills.owns(expected_active) and snapshot.skills.progress_for(expected_active).level == expected_level)
	for index: int in PASSIVE_IDS.size():
		assert(snapshot.loadout.get_skill_id(SkillSlotIds.passive()[index]) == PASSIVE_IDS[index])
	assert(_coordinator.host.runtime_loadout.registered_passive_skill_ids == PASSIVE_IDS)


func _assert_guaranteed_active_history() -> void:
	assert(_chest_skills.size() == 1)
	var content := CATALOG.content_for(_chest_skills[0])
	assert(content != null and content.reward_pool and content.gameplay_definition.is_active_skill())


func _pre_shop_dust_run_id(prefix: String, required_first_skill: StringName) -> StringName:
	for index: int in 512:
		var run_id := StringName("%s_%03d" % [prefix, index])
		var session := RunSession.new(
			CATALOG.reward_definitions(), CATALOG.relic_definitions, CATALOG.initial_owned_skill_ids(),
			[ElementIds.WATER, ElementIds.FIRE], null, null, RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
		)
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
		if not session.handle_event(RoomCompletedEvent.new(&"complete_second", second.room_id, 0, 0, second.completion_dream_dust, false)).accepted:
			continue
		var shop := session.snapshot().shop
		if shop == null or not session.leave_formal_shop(&"leave", session.snapshot().revision, shop.session_id).accepted:
			continue
		var third := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_third", session.snapshot().revision, third.room_id, 42_500 + index, third.room_scene.resource_path).accepted:
			continue
		var third_claim := session.claim_formal_room_chest(&"claim_third", session.snapshot().revision, third.room_id)
		if third_claim.accepted and third_claim.chest_reward.kind == RunChestRewardSnapshot.Kind.SKILL:
			return run_id
	assert(false, "%s finds a deterministic second-room dust cohort" % prefix)
	return StringName("%s_fallback" % prefix)


func _defeat_batch(enemies: Array[CombatEnemy]) -> void:
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task42_capture", 42, 42, &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
		var hit := enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))
		assert(hit.accepted and enemy.defeated)


func _interact_at(target: RunWorldInteractable) -> void:
	_coordinator.player.global_position = target.global_position
	_coordinator.player.interact_requested.emit()


func _room_dust(room: RunRoomInstance) -> int:
	var total := room.room_definition.completion_dream_dust
	for enemy: CombatEnemy in room.enemies:
		total += enemy.dream_dust_reward
	for enemy: CombatEnemy in room.reinforcement_enemies:
		total += enemy.dream_dust_reward
	return total


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


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [snapshot.revision, snapshot.route.phase, snapshot.route.run_id, snapshot.route.current_room_id, snapshot.economy.balance, snapshot.shop.session_id if snapshot.shop != null else &""]


func _capture(file_name: String, expected_size: Vector2i) -> void:
	var snapshot := _coordinator.current_snapshot()
	assert(String(snapshot.route.run_id).begins_with("task42_safe") or String(snapshot.route.run_id).begins_with("task42_risk"))
	assert(snapshot.route.phase == RunPhase.SHOP or snapshot.route.phase == RunPhase.RUN_COMPLETE)
	assert(snapshot.economy.is_valid() and snapshot.loadout.entries.size() == 7)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty() and image.get_size() == expected_size)
	var error := image.save_png("res://docs/agent_tasks/evidence/task42/screenshots/%s" % file_name)
	assert(error == OK)
	_capture_count += 1
