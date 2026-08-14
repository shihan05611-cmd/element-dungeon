extends SceneTree

const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const OLD_FLOW_PATH := "res://resources/run/flows/prototype_two_layer_six_combat.tres"

var _tests := 0
var _assertions := 0
var _failures: Array[String] = []
var _room_instance_sequence := 4900
var _command_sequence := 0
var _hit_sequence := 0
var _clear_events := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_test("five_stage_graph_is_linear", _test_five_stage_graph_is_linear)
	await _run_async_test("first_room_is_immediate_single_wave", _test_first_room_is_immediate_single_wave)
	_run_test("first_room_guarantees_unowned_active", _test_first_room_guarantees_unowned_active)
	_run_test("active_pool_exhaustion_falls_back_idempotently", _test_active_pool_exhaustion_falls_back_idempotently)
	_run_test("domain_progression_is_combat_combat_shop_combat_boss", _test_domain_progression)
	_finish()


func _test_five_stage_graph_is_linear() -> void:
	_expect(FLOW.is_valid(), "five-stage flow validates")
	_expect_eq(FLOW.flow_id, &"prototype_five_stage_demo", "flow has the demo identity")
	_expect(not FileAccess.file_exists(OLD_FLOW_PATH), "deleted six-combat resource path is absent")
	var expected_ids: Array[StringName] = [
		&"run_entry",
		&"combat_01_entry",
		&"combat_02_swarm",
		&"shop_demo_mid",
		&"combat_04_validation",
		&"combat_06_final_boss",
		&"run_result",
	]
	var actual_ids: Array[StringName] = []
	var combat_count := 0
	var shop_count := 0
	var route_count := 0
	for node: RunNodeDefinition in FLOW.nodes:
		actual_ids.append(node.node_id)
		combat_count += 1 if RunNodeKind.is_combat(node.kind) else 0
		shop_count += 1 if node.kind == RunNodeKind.SHOP else 0
		route_count += 1 if node.kind == RunNodeKind.ROUTE else 0
	_expect_eq(actual_ids, expected_ids, "flow contains only entry, five playable stages, and result")
	_expect_eq(combat_count, 4, "flow has four combat stages including Boss")
	_expect_eq(shop_count, 1, "flow has one shop")
	_expect_eq(route_count, 0, "flow has no route choices")
	for index: int in range(expected_ids.size() - 1):
		_expect_eq(FLOW.node_for(expected_ids[index]).next_node_id, expected_ids[index + 1], "stage %d links directly to its successor" % index)


func _test_first_room_is_immediate_single_wave() -> void:
	var definition := FLOW.combat_room_for(&"combat_01_entry")
	_expect(definition != null and definition.validation_error().is_empty(), "first room definition validates")
	_expect(definition.single_wave and definition.guaranteed_active_skill_reward, "first room owns both narrow policies")
	_expect_eq(definition.enemy_spawns.size(), 2, "first room has exactly two initial enemies")
	_expect_eq(definition.reinforcement_spawns.size(), 0, "first room has no reinforcement definitions")
	var room := definition.room_scene.instantiate() as RunRoomInstance
	root.add_child(room)
	_expect(room.configure(definition), "first room configures in the real room runtime")
	room.room_cleared.connect(_on_room_cleared)
	room.activate()
	_expect_eq(room.initial_enemies.size(), 2, "runtime instantiates exactly two initial enemies")
	_expect_eq(room.reinforcement_enemies.size(), 0, "runtime instantiates no reinforcement enemies")
	_defeat(room.initial_enemies[0])
	await process_frame
	_expect(not room.room_is_cleared and _clear_events == 0, "one surviving initial enemy keeps the room active")
	_defeat(room.initial_enemies[1])
	_expect(room.room_is_cleared and _clear_events == 1, "second defeat clears in the same callback")
	_expect(room.chest.visible and room.portal.visible, "immediate clear reveals the chest and portal")
	await process_frame
	_expect_eq(_clear_events, 1, "no delayed reinforcement or duplicate clear follows")
	room.queue_free()
	await process_frame


func _test_first_room_guarantees_unowned_active() -> void:
	for cohort: int in 8:
		var session := _new_session(StringName("task49_active_%d" % cohort), CATALOG.initial_owned_skill_ids())
		_expect(_start_and_activate_first(session), "active guarantee cohort %d reaches first room" % cohort)
		var before := session.snapshot()
		var claimed := session.claim_formal_room_chest(StringName("claim_%d" % cohort), before.revision, &"combat_01_entry")
		_expect(claimed.accepted and claimed.chest_reward != null, "active guarantee cohort %d claims a typed reward" % cohort)
		_expect_eq(claimed.chest_reward.kind, RunChestRewardSnapshot.Kind.SKILL, "active guarantee cohort %d never receives dust" % cohort)
		var content := CATALOG.content_for(claimed.chest_reward.skill_id)
		_expect(content != null and content.reward_pool, "guaranteed skill comes from reward_pool")
		_expect(content.gameplay_definition != null and content.gameplay_definition.is_active_skill(), "guaranteed skill is active")
		_expect(not before.skills.owns(content.skill_id) and claimed.run_snapshot.skills.owns(content.skill_id), "guaranteed skill was unowned and commits once")


func _test_active_pool_exhaustion_falls_back_idempotently() -> void:
	var owned := CATALOG.initial_owned_skill_ids()
	for content: SkillContentDefinition in CATALOG.skill_contents:
		if content != null and content.reward_pool and content.gameplay_definition.is_active_skill() and not owned.has(content.skill_id):
			owned.append(content.skill_id)
	var session := _new_session(&"task49_active_exhausted", owned)
	_expect(_start_and_activate_first(session), "exhausted fixture reaches first room")
	var before := session.snapshot()
	var claimed := session.claim_formal_room_chest(&"claim_exhausted", before.revision, &"combat_01_entry")
	_expect(claimed.accepted and claimed.chest_reward != null, "exhausted active pool still completes the chest")
	_expect_eq(claimed.chest_reward.kind, RunChestRewardSnapshot.Kind.DREAM_DUST, "exhausted active pool explicitly degrades to dream dust")
	_expect_eq(claimed.chest_reward.dream_dust, RunChestRewardSnapshot.DREAM_DUST_AMOUNT, "fallback reports the existing typed dust amount")
	_expect_eq(claimed.run_snapshot.economy.balance, before.economy.balance + RunChestRewardSnapshot.DREAM_DUST_AMOUNT, "fallback commits exactly one dust grant")
	var replay := session.claim_formal_room_chest(&"claim_exhausted", before.revision, &"combat_01_entry")
	_expect(replay == claimed, "same command replays the original fallback result")
	_expect_eq(session.snapshot().revision, claimed.run_snapshot.revision, "replay adds no revision or reward")
	var duplicate := session.claim_formal_room_chest(&"claim_exhausted_duplicate", session.snapshot().revision, &"combat_01_entry")
	_expect(not duplicate.accepted and duplicate.reject_reason == RunCommandResult.RejectReason.ALREADY_CLAIMED, "new command cannot claim the exhausted chest twice")


func _test_domain_progression() -> void:
	var session := _new_session(&"task49_linear_progression", CATALOG.initial_owned_skill_ids())
	_expect(session.start_formal_run(_next_command(&"start"), 0).accepted, "linear run starts")
	_expect(_activate_pending(session).accepted, "combat one activates")
	_expect_eq(session.snapshot().route.current_room_id, &"combat_01_entry", "stage one is combat one")
	_expect(_complete_current_room(session).accepted, "combat one completes")
	_expect(_activate_pending(session).accepted, "combat two activates directly")
	_expect_eq(session.snapshot().route.current_room_id, &"combat_02_swarm", "stage two is the swarm combat")
	_expect(_complete_current_room(session).accepted, "combat two completes")
	_expect_eq(session.snapshot().route.phase, RunPhase.SHOP, "second combat enters the shop")
	_expect_eq(session.snapshot().route.current_node_id, &"shop_demo_mid", "the only shop has the demo identity")
	var shop := session.snapshot().shop
	_expect(shop != null and session.leave_formal_shop(_next_command(&"leave"), session.snapshot().revision, shop.session_id).accepted, "shop leaves through the formal transaction")
	_expect(_activate_pending(session).accepted, "combat three activates after shop")
	_expect_eq(session.snapshot().route.current_room_id, &"combat_04_validation", "stage four is the validation combat")
	_expect(_complete_current_room(session).accepted, "combat three completes")
	_expect(_activate_pending(session).accepted, "Boss activates directly")
	_expect_eq(session.snapshot().route.current_room_id, &"combat_06_final_boss", "stage five is Boss")
	_expect(_complete_current_room(session).accepted, "Boss completes")
	var final := session.snapshot()
	_expect_eq(final.route.phase, RunPhase.RUN_COMPLETE, "Boss enters result")
	_expect_eq(final.route.completed_combat_rooms, 4, "result freezes four completed combats")
	_expect_eq(final.route.shop_visits, 1, "result freezes one shop")
	_expect_eq(final.route.route_choices, 0, "result freezes zero routes")
	_expect(final.result != null and final.result.is_complete(), "complete result is valid")


func _new_session(run_id: StringName, owned: Array[StringName]) -> RunSession:
	return RunSession.new(
		CATALOG.reward_definitions(), CATALOG.relic_definitions, owned,
		[ElementIds.WATER, ElementIds.FIRE], null, GrowthEffectPort.new(),
		RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
	)


func _start_and_activate_first(session: RunSession) -> bool:
	if not session.start_formal_run(_next_command(&"start"), session.snapshot().revision).accepted:
		return false
	return _activate_pending(session).accepted


func _activate_pending(session: RunSession) -> RunCommandResult:
	var snapshot := session.snapshot()
	var room := FLOW.combat_room_for(snapshot.route.pending_node_id)
	_room_instance_sequence += 1
	return session.accept_room_transition(
		_next_command(&"activate"), snapshot.revision, room.room_id,
		_room_instance_sequence, room.room_scene.resource_path
	)


func _complete_current_room(session: RunSession) -> RunCommandResult:
	var room := FLOW.combat_room_for(session.snapshot().route.current_room_id)
	return session.handle_event(RoomCompletedEvent.new(
		_next_command(&"complete"), room.room_id, 0, 0,
		room.completion_dream_dust, room.final_boss
	))


func _defeat(enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task49_finisher", 49, 49, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	var result := enemy.combat_receiver.receive_hit(request)
	_expect(result.accepted and enemy.defeated, "real CombatReceiver defeats first-room enemy")


func _on_room_cleared(_room_id: StringName, _room_instance_id: int) -> void:
	_clear_events += 1


func _next_command(prefix: StringName) -> StringName:
	_command_sequence += 1
	return StringName("%s_%d" % [String(prefix), _command_sequence])


func _run_test(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callable.call()
	print("PASS: %s" % test_name if _failures.size() == before else "FAIL: %s" % test_name)


func _run_async_test(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callable.call()
	print("PASS: %s" % test_name if _failures.size() == before else "FAIL: %s" % test_name)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_expect(actual == expected, "%s (expected=%s actual=%s)" % [description, str(expected), str(actual)])


func _finish() -> void:
	print("SUMMARY: %d tests, %d assertions, %d failures" % [_tests, _assertions, _failures.size()])
	for failure: String in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
