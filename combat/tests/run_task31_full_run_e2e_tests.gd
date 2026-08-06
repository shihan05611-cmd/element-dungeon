extends SceneTree

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const PASSIVE_IDS: Array[StringName] = [
	&"burning",
	&"unending",
	&"passive_vitality",
	&"passive_energy",
]

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []
var _hit_sequence: int = 3100000
var _coordinator: RunFlowCoordinator
var _overlay: RunOverlayInterface
var _safe_metrics: Dictionary = {}
var _risk_metrics: Dictionary = {}
var _safe_scene_paths: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_expect(await _boot_new_coordinator(), "formal RunGame boots the safe run")
	if _coordinator == null:
		_finish()
		return
	await _run_async_test("safe_route_four_passives_and_main_specialization", _test_safe_run)
	await _run_async_test("complete_result_return_boundary_and_new_authority", _test_complete_result_and_new_run)
	await _run_async_test("failure_result_and_second_new_authority", _test_failure_and_new_run)
	await _run_async_test("risk_route_multi_active_four_passive_run", _test_risk_run)
	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _test_safe_run() -> void:
	_safe_metrics = _new_metrics("safe", [&"route_01_swarm", &"route_02_stable"])
	var persistent := _persistent_ids()
	await _cast_accepted_slot(SkillSlotIds.ACTIVE_1, &"element_bolt", _safe_metrics)
	await _record_and_defeat_current_room(_safe_metrics)
	_expect(await _wait_for_phase(RunPhase.SHOP), "safe room one reaches shop one")
	await _purchase_and_equip(&"burning", SkillSlotIds.PASSIVE_1)
	_expect(_press(&"leave_shop"), "safe shop one leaves through formal UI")
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "safe run reaches route one")
	await _choose_route(&"route_01_swarm", &"combat_02_swarm")
	await _record_and_defeat_current_room(_safe_metrics)
	_expect(await _wait_for_room(&"combat_03_layer_elite"), "safe combat two flows to combat three")
	await _record_and_defeat_current_room(_safe_metrics)
	_expect(await _wait_for_phase(RunPhase.SHOP), "safe combat three reaches shop two")
	await _purchase_and_equip(&"unending", SkillSlotIds.PASSIVE_2)
	await _purchase_and_equip(&"passive_vitality", SkillSlotIds.PASSIVE_3)
	await _purchase_and_equip(&"passive_energy", SkillSlotIds.PASSIVE_4)
	_assert_four_passive_authority("safe middle shop")
	var runtime_before := _runtime_instances()
	var registrations_before := _coordinator.host.runtime_loadout.passive_registration_commit_count
	var unregistrations_before := _coordinator.host.runtime_loadout.passive_unregistration_commit_count
	_expect(_press(&"leave_shop"), "safe shop two leaves through formal UI")
	_expect(await _wait_for_room(&"combat_04_validation"), "safe shop two loads combat four")
	_assert_four_passive_authority("safe combat four")
	_expect_eq(_coordinator.host.runtime_loadout.passive_registration_commit_count, registrations_before + 1, "safe room rebuild registers one passive batch")
	_expect_eq(_coordinator.host.runtime_loadout.passive_unregistration_commit_count, unregistrations_before + 1, "safe room rebuild unregisters one passive batch")
	_expect(not _same_instances(runtime_before, _runtime_instances()), "safe room rebuild replaces all four passive runtime objects")
	await _record_and_defeat_current_room(_safe_metrics)
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "safe combat four reaches route two")
	await _choose_route(&"route_02_stable", &"combat_05_stable")
	await _record_and_defeat_current_room(_safe_metrics)
	_expect(await _wait_for_phase(RunPhase.SHOP), "safe combat five reaches shop three")
	await _upgrade_skill(&"element_bolt", 2, 55)
	await _upgrade_skill(&"element_bolt", 3, 95)
	await _reset_skill(&"element_bolt", 105)
	await _upgrade_skill(&"element_bolt", 2, 55)
	await _upgrade_skill(&"element_bolt", 3, 95)
	_assert_four_passive_authority("safe preboss shop")
	_expect_eq(_coordinator.current_snapshot().economy.balance, 100, "safe preboss balance is 100 after specialization reset/rebuy")
	_expect(_press(&"leave_shop"), "safe shop three leaves through formal UI")
	_expect(await _wait_for_room(&"combat_06_final_boss"), "safe run loads the real boss room")
	var boss_balance := _coordinator.current_snapshot().economy.balance
	await _record_and_defeat_current_room(_safe_metrics)
	_expect(await _wait_for_phase(RunPhase.RUN_COMPLETE), "safe boss death reaches result directly")
	var final := _coordinator.current_snapshot()
	_assert_completed_run(final, [&"route_01_swarm", &"route_02_stable"], 595, 300, 300, 105, 100, boss_balance, "safe")
	_expect_eq(final.skills.progress_for(&"element_bolt").level, 3, "safe specialist finishes at bolt Lv3")
	_assert_final_loadout(final, &"element_bolt", &"", &"")
	_assert_persistent_ids(persistent, "safe")
	_expect_eq(_unique_int_count(final.route.activated_room_instance_ids), 6, "safe run uses six different RunRoomInstance IDs")
	_expect_eq(_unique_string_count(final.route.activated_scene_paths), 3, "safe route truthfully uses flat/platform/boss templates")
	_safe_scene_paths = final.route.activated_scene_paths
	_finalize_metrics(_safe_metrics, final)
	print("TASK31_SAFE_METRICS: " + JSON.stringify(_safe_metrics))


func _test_complete_result_and_new_run() -> void:
	var result_before := _authority_signature(_coordinator.current_snapshot())
	var return_button := _button(&"return_entry")
	_expect(return_button != null and return_button.disabled, "return-entry action is explicitly disabled")
	if return_button != null:
		return_button.pressed.emit()
	await process_frame
	_expect_eq(_authority_signature(_coordinator.current_snapshot()), result_before, "disabled return-entry action changes no authority")
	var old_coordinator_id := _coordinator.get_instance_id()
	var old_session_id := _coordinator.host.run_session.get_instance_id()
	var old_run_id := _coordinator.current_snapshot().route.run_id
	_expect(_press(&"new_run"), "complete result exposes enabled new-run action")
	await process_frame
	await process_frame
	_coordinator = current_scene as RunFlowCoordinator
	_expect(_coordinator != null and _coordinator.get_instance_id() != old_coordinator_id, "new run replaces the RunGame coordinator")
	if _coordinator == null:
		return
	_expect(await _wait_for_room(&"combat_01_entry"), "new authority boots combat one")
	_overlay = _coordinator.combat_hud.run_overlay as RunOverlayInterface
	var fresh := _coordinator.current_snapshot()
	_expect(_coordinator.host.run_session.get_instance_id() != old_session_id, "new run creates a new RunSession")
	_expect(fresh.route.run_id != old_run_id, "new run creates a distinct run ID")
	_assert_fresh_run(fresh, "post-safe new run")


func _test_failure_and_new_run() -> void:
	var before := _coordinator.current_snapshot()
	await _defeat_player()
	_expect(await _wait_for_phase(RunPhase.RUN_FAILED), "real lethal hit reaches failed result")
	var failed := _coordinator.current_snapshot()
	_expect(failed.result != null and not failed.result.is_complete(), "failed result is frozen and distinct")
	_expect_eq(failed.route.completed_combat_rooms, before.route.completed_combat_rooms, "failure completes no room")
	_expect_eq(failed.economy.total_earned, before.economy.total_earned, "failure awards no dream dust")
	_expect(_overlay.formal_kind() == &"result" and _visible_text(_overlay).contains("DEFEAT"), "failure uses the formal defeat result")
	var old_session_id := _coordinator.host.run_session.get_instance_id()
	var old_run_id := failed.route.run_id
	_expect(_press(&"new_run"), "failed result exposes enabled new-run recovery")
	await process_frame
	await process_frame
	_coordinator = current_scene as RunFlowCoordinator
	_expect(_coordinator != null, "failed-result new run creates a coordinator")
	if _coordinator == null:
		return
	_expect(await _wait_for_room(&"combat_01_entry"), "failed-result new run boots combat one")
	_overlay = _coordinator.combat_hud.run_overlay as RunOverlayInterface
	var fresh := _coordinator.current_snapshot()
	_expect(_coordinator.host.run_session.get_instance_id() != old_session_id, "failed-result new run replaces RunSession")
	_expect(fresh.route.run_id != old_run_id, "failed-result new run replaces run ID")
	_assert_fresh_run(fresh, "post-failure new run")


func _test_risk_run() -> void:
	_risk_metrics = _new_metrics("risk", [&"route_01_pressure", &"route_02_risk"])
	var persistent := _persistent_ids()
	await _cast_accepted_slot(SkillSlotIds.ACTIVE_1, &"element_bolt", _risk_metrics)
	await _record_and_defeat_current_room(_risk_metrics)
	_expect(await _wait_for_phase(RunPhase.SHOP), "risk room one reaches shop one")
	await _purchase_and_equip(&"element_reclaim", SkillSlotIds.ACTIVE_3)
	_expect(_press(&"leave_shop"), "risk shop one leaves through formal UI")
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "risk run reaches route one")
	await _choose_route(&"route_01_pressure", &"combat_02_pressure")
	await _record_and_defeat_current_room(_risk_metrics)
	_expect(await _wait_for_room(&"combat_03_layer_elite"), "risk combat two flows to combat three")
	await _record_and_defeat_current_room(_risk_metrics)
	_expect(await _wait_for_phase(RunPhase.SHOP), "risk combat three reaches shop two")
	await _purchase_and_equip(&"elemental_laser", SkillSlotIds.ACTIVE_2)
	await _purchase_and_equip(&"burning", SkillSlotIds.PASSIVE_1)
	await _purchase_and_equip(&"unending", SkillSlotIds.PASSIVE_2)
	_expect_eq(_coordinator.current_snapshot().economy.balance, 5, "risk middle shop spends down to five")
	_expect(_press(&"leave_shop"), "risk shop two leaves through formal UI")
	_expect(await _wait_for_room(&"combat_04_validation"), "risk shop two loads combat four")
	await _cast_accepted_slot(SkillSlotIds.ACTIVE_2, &"elemental_laser", _risk_metrics)
	await _record_and_defeat_current_room(_risk_metrics)
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "risk combat four reaches route two")
	await _choose_route(&"route_02_risk", &"combat_05_risk")
	await _record_and_defeat_current_room(_risk_metrics)
	_expect(await _wait_for_phase(RunPhase.SHOP), "risk combat five reaches shop three")
	await _purchase_and_equip(&"passive_vitality", SkillSlotIds.PASSIVE_3)
	await _purchase_and_equip(&"passive_energy", SkillSlotIds.PASSIVE_4)
	await _upgrade_skill(&"element_reclaim", 2, 50)
	await _upgrade_skill(&"elemental_laser", 2, 65)
	_assert_four_passive_authority("risk preboss shop")
	_expect_eq(_coordinator.current_snapshot().economy.balance, 75, "risk preboss balance is 75")
	var registrations_before := _coordinator.host.runtime_loadout.passive_registration_commit_count
	var unregistrations_before := _coordinator.host.runtime_loadout.passive_unregistration_commit_count
	var runtime_before := _runtime_instances()
	_expect(_press(&"leave_shop"), "risk shop three leaves through formal UI")
	_expect(await _wait_for_room(&"combat_06_final_boss"), "risk run loads the real boss room")
	_assert_four_passive_authority("risk boss room")
	_expect_eq(_coordinator.host.runtime_loadout.passive_registration_commit_count, registrations_before + 1, "risk boss rebuild registers one passive batch")
	_expect_eq(_coordinator.host.runtime_loadout.passive_unregistration_commit_count, unregistrations_before + 1, "risk boss rebuild unregisters one passive batch")
	_expect(not _same_instances(runtime_before, _runtime_instances()), "risk boss rebuild replaces all four passive runtimes")
	await _cast_accepted_slot(SkillSlotIds.ACTIVE_2, &"elemental_laser", _risk_metrics)
	var boss_balance := _coordinator.current_snapshot().economy.balance
	await _record_and_defeat_current_room(_risk_metrics)
	_expect(await _wait_for_phase(RunPhase.RUN_COMPLETE), "risk boss death reaches result directly")
	var final := _coordinator.current_snapshot()
	_assert_completed_run(final, [&"route_01_pressure", &"route_02_risk"], 700, 510, 115, 0, 75, boss_balance, "risk")
	_expect_eq(final.skills.progress_for(&"element_bolt").level, 1, "risk bolt remains Lv1")
	_expect_eq(final.skills.progress_for(&"elemental_laser").level, 2, "risk laser finishes Lv2")
	_expect_eq(final.skills.progress_for(&"element_reclaim").level, 2, "risk reclaim finishes Lv2")
	_assert_final_loadout(final, &"element_bolt", &"elemental_laser", &"element_reclaim")
	_assert_persistent_ids(persistent, "risk")
	_expect_eq(_unique_int_count(final.route.activated_room_instance_ids), 6, "risk run uses six different RunRoomInstance IDs")
	_expect_eq(_unique_string_count(final.route.activated_scene_paths), 4, "risk run uses all four real room templates")
	var combined := _safe_scene_paths.duplicate()
	combined.append_array(final.route.activated_scene_paths)
	_expect_eq(_unique_string_count(combined), 4, "safe and risk runs collectively cover all four templates")
	_expect(final.economy.total_earned > int(_safe_metrics["economy"]["earned"]), "risk route earns strictly more than safe route")
	_finalize_metrics(_risk_metrics, final)
	print("TASK31_RISK_METRICS: " + JSON.stringify(_risk_metrics))


func _purchase_and_equip(skill_id: StringName, slot_id: StringName) -> void:
	var before := _coordinator.current_snapshot()
	var content := CATALOG.content_for(skill_id)
	_expect(before.route.phase == RunPhase.SHOP and before.shop != null, "%s purchase occurs in a formal shop" % String(skill_id))
	_expect(content != null and content.is_shop_purchasable(), "%s is formal purchasable content" % String(skill_id))
	_expect(_press(StringName("purchase:%s" % String(skill_id))), "%s purchases through visible formal control" % String(skill_id))
	await process_frame
	var purchased := _coordinator.current_snapshot()
	_expect(purchased.skills.owns(skill_id), "%s ownership commits" % String(skill_id))
	_expect_eq(purchased.economy.balance, before.economy.balance - content.purchase_price, "%s charges exactly once" % String(skill_id))
	_expect_eq(purchased.revision, before.revision + 1, "%s purchase advances authority once" % String(skill_id))
	var progress := purchased.skills.progress_for(skill_id)
	_expect(progress != null and progress.level == 1 and progress.cumulative_upgrade_spend == 0, "%s starts at frozen Lv1/no spend" % String(skill_id))
	if content.gameplay_definition.is_passive_skill():
		_expect(progress.is_passive(), "%s has passive progress kind" % String(skill_id))
	_expect(_press(StringName("select:%s" % String(skill_id))), "%s selects through formal inventory" % String(skill_id))
	await process_frame
	var equip_revision := _coordinator.current_snapshot().revision
	_expect(_press(StringName("slot:%s" % String(slot_id))), "%s equips through %s" % [String(skill_id), String(slot_id)])
	await process_frame
	var equipped := _coordinator.current_snapshot()
	_expect_eq(equipped.loadout.get_skill_id(slot_id), skill_id, "%s authority mapping commits" % String(skill_id))
	_expect_eq(equipped.revision, equip_revision + 1, "%s equip advances authority once" % String(skill_id))
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(equipped.loadout), "%s RuntimeLoadout aligns immediately" % String(skill_id))


func _upgrade_skill(skill_id: StringName, target_level: int, price: int) -> void:
	var before := _coordinator.current_snapshot()
	_expect(_press(StringName("upgrade:%s" % String(skill_id))), "%s upgrade to Lv%d uses formal control" % [String(skill_id), target_level])
	await process_frame
	var after := _coordinator.current_snapshot()
	_expect_eq(after.skills.progress_for(skill_id).level, target_level, "%s reaches Lv%d" % [String(skill_id), target_level])
	_expect_eq(after.economy.balance, before.economy.balance - price, "%s Lv%d charges %d" % [String(skill_id), target_level, price])
	_expect_eq(after.economy.total_spent_on_upgrades, before.economy.total_spent_on_upgrades + price, "%s upgrade ledger advances once" % String(skill_id))


func _reset_skill(skill_id: StringName, expected_refund: int) -> void:
	var before := _coordinator.current_snapshot()
	_expect(_press(StringName("reset:%s" % String(skill_id))), "%s reset opens explicit confirmation" % String(skill_id))
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, before.revision, "reset focus changes no authority")
	_expect(_button(StringName("reset_confirm:%s" % String(skill_id))) != null, "reset exposes confirm control")
	_expect(_press(StringName("reset_confirm:%s" % String(skill_id))), "%s reset confirms through formal control" % String(skill_id))
	await process_frame
	var after := _coordinator.current_snapshot()
	_expect_eq(after.skills.progress_for(skill_id).level, 1, "%s reset returns to Lv1" % String(skill_id))
	_expect_eq(after.skills.progress_for(skill_id).cumulative_upgrade_spend, 0, "%s reset clears cumulative upgrade spend" % String(skill_id))
	_expect_eq(after.economy.total_refunded, before.economy.total_refunded + expected_refund, "%s reset refunds exact floor 70 percent" % String(skill_id))
	_expect_eq(after.economy.balance, before.economy.balance + expected_refund, "%s reset credits the wallet once" % String(skill_id))


func _choose_route(option_id: StringName, expected_room_id: StringName) -> void:
	var snapshot := _coordinator.current_snapshot()
	_expect(snapshot.route.phase == RunPhase.ROUTE_CHOICE, "%s selection occurs in route phase" % String(option_id))
	var index := -1
	for candidate_index: int in snapshot.route.next_options.size():
		if snapshot.route.next_options[candidate_index].option_id == option_id:
			index = candidate_index
	_expect(index >= 0, "%s exists in the frozen route options" % String(option_id))
	if index < 0:
		return
	_overlay.formal_route_cards()[index].pressed.emit()
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, snapshot.revision, "%s focus is non-committing" % String(option_id))
	_expect_eq(_overlay.formal_selected_route_id(), option_id, "%s focus stores exact option identity" % String(option_id))
	_overlay.formal_route_confirm_button().pressed.emit()
	_expect(await _wait_for_room(expected_room_id), "%s confirm loads %s" % [String(option_id), String(expected_room_id)])


func _cast_accepted_slot(slot_id: StringName, skill_id: StringName, metrics: Dictionary) -> void:
	_coordinator.player.facing = -1.0
	_coordinator.player.sprite.flip_h = false
	var cast := _coordinator.player.try_cast_slot(slot_id)
	_expect(cast != null and cast.accepted and cast.skill_id == skill_id, "%s records a real accepted cast" % String(skill_id))
	if cast != null and cast.accepted:
		var counts: Dictionary = metrics["skill_casts"]
		counts[String(skill_id)] = int(counts.get(String(skill_id), 0)) + 1
		metrics["skill_casts"] = counts
	if skill_id == &"elemental_laser":
		await process_frame
		await process_frame
		_expect(_coordinator.player.release_channel_for_slot(slot_id), "laser channel releases through the real slot path")
	_expect(await _wait_until(func() -> bool:
		return _coordinator.player.skill_executor.current_phase == SkillExecutor.Phase.IDLE
	, 180), "%s executor returns to idle" % String(skill_id))


func _record_and_defeat_current_room(metrics: Dictionary) -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "metrics observe a configured real RunRoomInstance")
	if room == null:
		return
	var started := Time.get_ticks_msec()
	var room_record := {
		"room_id": String(room.room_id),
		"template_id": String(room.template_id),
		"scene_path": room.scene_path,
		"instance_id": room.get_instance_id(),
		"enemy_count": room.enemies.size(),
	}
	await _defeat_current_room()
	room_record["duration_ms"] = maxi(1, Time.get_ticks_msec() - started)
	var rooms: Array = metrics["rooms"]
	rooms.append(room_record)
	metrics["rooms"] = rooms


func _defeat_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "E2E uses a configured real room")
	if room == null:
		return
	for enemy: CombatEnemy in room.enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(
			_hit_sequence,
			&"task31_e2e_finisher",
			_coordinator.player.get_instance_id(),
			_coordinator.player.get_instance_id(),
			&"player",
			ElementIds.NONE,
			CombatStatSnapshot.new()
		)
		var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
		var request := HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var hit := enemy.combat_receiver.receive_hit(request)
		_expect(hit.accepted and enemy.defeated, "room enemy is defeated through real CombatReceiver")
	await process_frame


func _defeat_player() -> void:
	_hit_sequence += 1
	var enemy := _coordinator.active_enemies[0]
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task31_e2e_player_defeat",
		enemy.get_instance_id(),
		enemy.get_instance_id(),
		&"enemy",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, _coordinator.player.global_position, Vector2.LEFT)
	_expect(_coordinator.player.combat_receiver.receive_hit(request).accepted, "failure uses the real player CombatReceiver")
	await process_frame


func _assert_four_passive_authority(context: String) -> void:
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.loadout.entries.size(), 7, "%s keeps exact seven-slot authority" % context)
	for index: int in PASSIVE_IDS.size():
		var slot_id := SkillSlotIds.passive()[index]
		_expect_eq(snapshot.loadout.get_skill_id(slot_id), PASSIVE_IDS[index], "%s P%d has the expected passive" % [context, index + 1])
		_expect(snapshot.skills.owns(PASSIVE_IDS[index]), "%s owns %s" % [context, String(PASSIVE_IDS[index])])
	_expect_eq(_coordinator.host.runtime_loadout.registered_passive_skill_ids, PASSIVE_IDS, "%s runtime registers four passives in slot order" % context)
	_expect_eq(_unique_string_name_count(_coordinator.host.runtime_loadout.registered_passive_skill_ids), 4, "%s runtime passives are unique" % context)
	_expect_eq(_coordinator.host.runtime_loadout.registered_passive_slot_ids, SkillSlotIds.passive(), "%s runtime covers P1-P4" % context)
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(snapshot.loadout), "%s runtime mapping matches authority" % context)


func _assert_completed_run(
		final: RunSnapshot,
		route_ids: Array[StringName],
		earned: int,
		purchase_spend: int,
		upgrade_spend: int,
		refunded: int,
		balance: int,
		boss_balance: int,
		label: String
) -> void:
	_expect(final.result != null and final.result.is_complete(), "%s result is frozen complete" % label)
	_expect_eq(final.route.completed_combat_rooms, 6, "%s completes six combats" % label)
	_expect_eq(final.route.shop_visits, 3, "%s visits three shops" % label)
	_expect_eq(final.route.route_choices, 2, "%s confirms two routes" % label)
	_expect_eq(final.route.selected_route_option_ids, route_ids, "%s freezes exact route IDs" % label)
	_expect_eq(final.route.activated_room_instance_ids.size(), 6, "%s records six room activations" % label)
	_expect_eq(final.economy.total_earned, earned, "%s earned ledger is exact" % label)
	_expect_eq(final.economy.total_spent_on_purchases, purchase_spend, "%s purchase ledger is exact" % label)
	_expect_eq(final.economy.total_spent_on_upgrades, upgrade_spend, "%s upgrade ledger is exact" % label)
	_expect_eq(final.economy.total_refunded, refunded, "%s refund ledger is exact" % label)
	_expect_eq(final.economy.balance, balance, "%s final balance is exact" % label)
	_expect(final.economy.is_valid() and final.economy.balance == final.economy.conserved_balance(), "%s wallet conserves" % label)
	_expect_eq(final.economy.balance, boss_balance, "%s boss enemy and room award zero dream dust" % label)
	_expect(final.shop == null and final.pending_reward == null, "%s result has no fourth shop or free reward" % label)
	_expect_eq(final.result.final_node_id, &"run_result", "%s boss transaction lands on result" % label)
	_expect_eq(final.result.completed_combat_rooms, 6, "%s result freezes six combats" % label)
	_expect_eq(final.result.shop_visits, 3, "%s result freezes three shops" % label)
	_expect_eq(final.result.route_choices, 2, "%s result freezes two routes" % label)


func _assert_final_loadout(final: RunSnapshot, a1: StringName, a2: StringName, a3: StringName) -> void:
	_expect_eq(final.loadout.entries.size(), 7, "final mapping has seven slots")
	_expect_eq(final.loadout.get_skill_id(SkillSlotIds.ACTIVE_1), a1, "final A1 mapping is exact")
	_expect_eq(final.loadout.get_skill_id(SkillSlotIds.ACTIVE_2), a2, "final A2 mapping is exact")
	_expect_eq(final.loadout.get_skill_id(SkillSlotIds.ACTIVE_3), a3, "final A3 mapping is exact")
	for index: int in PASSIVE_IDS.size():
		_expect_eq(final.loadout.get_skill_id(SkillSlotIds.passive()[index]), PASSIVE_IDS[index], "final P%d mapping is exact" % (index + 1))


func _assert_fresh_run(snapshot: RunSnapshot, label: String) -> void:
	_expect_eq(snapshot.route.phase, RunPhase.COMBAT, "%s is in combat one" % label)
	_expect_eq(snapshot.route.completed_combat_rooms, 0, "%s resets combat progress" % label)
	_expect_eq(snapshot.route.shop_visits, 0, "%s resets shop visits" % label)
	_expect_eq(snapshot.route.route_choices, 0, "%s resets route choices" % label)
	_expect_eq(snapshot.economy.balance, 0, "%s resets dream dust" % label)
	_expect_eq(snapshot.economy.total_earned, 0, "%s resets earned ledger" % label)
	_expect_eq(snapshot.skills.owned_skill_ids, [&"element_bolt"], "%s resets owned skills" % label)
	_expect_eq(snapshot.loadout.get_skill_id(SkillSlotIds.ACTIVE_1), &"element_bolt", "%s resets A1")
	for slot_id: StringName in SkillSlotIds.passive():
		_expect(snapshot.loadout.get_skill_id(slot_id).is_empty(), "%s resets %s" % [label, String(slot_id)])
	_expect(snapshot.result == null and snapshot.shop == null and snapshot.pending_reward == null, "%s has no stale result/shop/reward" % label)


func _persistent_ids() -> Array[int]:
	return [
		_coordinator.host.get_instance_id(),
		_coordinator.host.run_session.get_instance_id(),
		_coordinator.player.get_instance_id(),
		_coordinator.combat_hud.get_instance_id(),
		_coordinator.host.runtime_loadout.get_instance_id(),
		_coordinator.host.passive_adapter.get_instance_id(),
	]


func _assert_persistent_ids(ids: Array[int], label: String) -> void:
	_expect_eq(_coordinator.host.get_instance_id(), ids[0], "%s Host persists" % label)
	_expect_eq(_coordinator.host.run_session.get_instance_id(), ids[1], "%s RunSession persists" % label)
	_expect_eq(_coordinator.player.get_instance_id(), ids[2], "%s Player persists" % label)
	_expect_eq(_coordinator.combat_hud.get_instance_id(), ids[3], "%s HUD persists" % label)
	_expect_eq(_coordinator.host.runtime_loadout.get_instance_id(), ids[4], "%s seven-slot Runtime persists" % label)
	_expect_eq(_coordinator.host.passive_adapter.get_instance_id(), ids[5], "%s passive adapter persists" % label)


func _new_metrics(label: String, route_ids: Array[StringName]) -> Dictionary:
	return {
		"label": label,
		"started_ms": Time.get_ticks_msec(),
		"route_ids": [String(route_ids[0]), String(route_ids[1])],
		"rooms": [],
		"skill_casts": {},
	}


func _finalize_metrics(metrics: Dictionary, final: RunSnapshot) -> void:
	metrics["total_duration_ms"] = maxi(1, Time.get_ticks_msec() - int(metrics["started_ms"]))
	metrics.erase("started_ms")
	metrics["economy"] = {
		"earned": final.economy.total_earned,
		"purchases": final.economy.total_spent_on_purchases,
		"upgrades": final.economy.total_spent_on_upgrades,
		"refunded": final.economy.total_refunded,
		"balance": final.economy.balance,
	}
	var casts: Dictionary = metrics["skill_casts"]
	var total_casts := 0
	for count: Variant in casts.values():
		total_casts += int(count)
	var percentages: Dictionary = {}
	for skill_id: String in casts:
		percentages[skill_id] = snappedf(float(casts[skill_id]) * 100.0 / float(maxi(1, total_casts)), 0.1)
	metrics["skill_usage_percent"] = percentages
	metrics["final_levels"] = {
		"element_bolt": final.skills.progress_for(&"element_bolt").level,
		"elemental_laser": final.skills.progress_for(&"elemental_laser").level if final.skills.owns(&"elemental_laser") else 0,
		"element_reclaim": final.skills.progress_for(&"element_reclaim").level if final.skills.owns(&"element_reclaim") else 0,
	}
	metrics["final_loadout"] = _loadout_signature(final.loadout)


func _loadout_signature(loadout: RuntimeLoadoutSnapshot) -> Dictionary:
	var result: Dictionary = {}
	for entry: RuntimeLoadoutSlotSnapshot in loadout.entries:
		result[String(entry.slot_id)] = String(entry.skill_id)
	return result


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [
		snapshot.revision,
		snapshot.route.phase,
		snapshot.route.run_id,
		snapshot.route.completed_combat_rooms,
		snapshot.economy.balance,
		snapshot.economy.total_earned,
		_loadout_signature(snapshot.loadout),
	]


func _runtime_instances() -> Array[PassiveEffectRuntime]:
	var result: Array[PassiveEffectRuntime] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var runtime := _coordinator.host.runtime_loadout.passive_runtime_for_slot(slot_id)
		if runtime != null:
			result.append(runtime)
	return result


func _same_instances(left: Array[PassiveEffectRuntime], right: Array[PassiveEffectRuntime]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true


func _boot_new_coordinator() -> bool:
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	if _coordinator == null:
		return false
	root.add_child(_coordinator)
	current_scene = _coordinator
	var booted := await _wait_for_room(&"combat_01_entry")
	if booted:
		_overlay = _coordinator.combat_hud.run_overlay as RunOverlayInterface
	return booted


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button if _overlay != null else null


func _press(control_id: StringName) -> bool:
	var button := _button(control_id)
	if button == null or button.disabled:
		return false
	button.grab_focus()
	button.pressed.emit()
	return true


func _wait_for_room(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
			and _coordinator.active_room != null
			and _coordinator.active_room.room_id == room_id
		)
	, 480)


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == phase
		)
	, 480)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _visible_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_visible_text(node, lines)
	return "\n".join(PackedStringArray(lines))


func _collect_visible_text(node: Node, lines: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_visible_text(child, lines)


func _unique_int_count(values: Array[int]) -> int:
	var unique: Array[int] = []
	for value: int in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_string_count(values: Array[String]) -> int:
	var unique: Array[String] = []
	for value: String in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_string_name_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await test_callable.call()
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


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 31 FULL RUN E2E TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 31 FULL RUN E2E TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
