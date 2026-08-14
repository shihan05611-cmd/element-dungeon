extends SceneTree

const FLOW: RunFlowDefinition = preload(
	"res://resources/run/flows/prototype_five_stage_demo.tres"
)
const CATALOG: RunContentCatalog = preload(
	"res://resources/content/run_content_catalog.tres"
)

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []
var _command_sequence: int = 0
var _room_instance_sequence: int = 1000


func _initialize() -> void:
	_run("five_stage_linear_graph", _test_flow_graph_and_route_targets)
	_run("linear_run_a_completes", _test_linear_run_a_completes)
	_run("linear_run_b_completes", _test_linear_run_b_completes)
	_run("duplicate_completion_and_stale_activation_atomic", _test_duplicate_completion_and_stale_activation_atomic)
	_run("scene_transition_failure_atomic", _test_scene_transition_failure_atomic)
	_run("death_and_repeated_result_are_terminal", _test_death_and_repeated_result_are_terminal)

	if _failures.is_empty():
		print("TASK 29 RUN FLOW CONTRACT TESTS PASSED: %d tests, %d assertions" % [
			_tests,
			_assertions,
		])
		quit(0)
	else:
		printerr("TASK 29 RUN FLOW CONTRACT TESTS FAILED: %d failures / %d assertions" % [
			_failures.size(),
			_assertions,
		])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _run(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callable.call()
	if _failures.size() == before:
		print("PASS task29_" + test_name)
	else:
		for index: int in range(before, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _test_flow_graph_and_route_targets() -> void:
	_expect(FLOW != null and FLOW.is_valid(), "formal flow resource validates")
	_expect_eq(FLOW.nodes.size(), 7, "formal graph has entry, five playable stages, and result")
	var ids: Array[StringName] = []
	var combat_nodes := 0
	var shop_nodes := 0
	var route_nodes := 0
	var boss_nodes := 0
	for node: RunNodeDefinition in FLOW.nodes:
		_expect(not ids.has(node.node_id), "node id is unique: %s" % String(node.node_id))
		ids.append(node.node_id)
		if RunNodeKind.is_combat(node.kind):
			combat_nodes += 1
			_expect(node.combat_room != null and not node.combat_room.resource_path.is_empty(), "combat node owns static room resource")
		if node.kind == RunNodeKind.SHOP:
			shop_nodes += 1
		if node.kind == RunNodeKind.ROUTE:
			route_nodes += 1
		if node.kind == RunNodeKind.BOSS:
			boss_nodes += 1
	_expect_eq(combat_nodes, 4, "graph exposes four fixed combat configs including Boss")
	_expect_eq(shop_nodes, 1, "graph fixes one shop node")
	_expect_eq(route_nodes, 0, "graph removes route nodes")
	_expect_eq(boss_nodes, 1, "graph fixes one boss node")
	_expect_eq(FLOW.node_for(&"combat_01_entry").next_node_id, &"combat_02_swarm", "combat one reaches combat two directly")
	_expect_eq(FLOW.node_for(&"combat_02_swarm").next_node_id, &"shop_demo_mid", "combat two reaches the demo shop")
	_expect_eq(FLOW.node_for(&"shop_demo_mid").next_node_id, &"combat_04_validation", "shop reaches combat three")
	_expect_eq(FLOW.node_for(&"combat_04_validation").next_node_id, &"combat_06_final_boss", "combat three reaches Boss directly")
	var boss := FLOW.combat_room_for(&"combat_06_final_boss")
	_expect(boss.final_boss and boss.completion_dream_dust == 0, "boss room completion awards zero dream dust")
	for spawn: EnemySpawnDefinition in boss.enemy_spawns:
		_expect_eq(spawn.dream_dust_reward, 0, "boss enemy awards zero dream dust")


func _test_linear_run_a_completes() -> void:
	var session := _new_session(&"safe_run")
	var replay := _start(session, &"safe_start")
	_expect(replay.accepted, "formal run starts")
	var repeated := session.start_formal_run(&"safe_start", 0)
	_expect(repeated == replay, "identical start command replays original result")
	_expect_eq(session.snapshot().revision, 1, "start replay adds no revision")
	_finish_run(session)
	_assert_completed_run(session)
	_expect(session.snapshot().route.activated_scene_paths.has("res://scenes/run/rooms/room_arena_flat.tscn"), "linear run records flat PackedScene")


func _test_linear_run_b_completes() -> void:
	var session := _new_session(&"risk_run")
	_expect(_start(session, &"risk_start").accepted, "risk run starts")
	_finish_run(session)
	_assert_completed_run(session)
	var scenes := session.snapshot().route.activated_scene_paths
	_expect(scenes.has("res://scenes/run/rooms/room_arena_flat.tscn"), "linear run records the reused validation PackedScene")
	_expect(scenes.has("res://scenes/run/rooms/room_arena_boss.tscn"), "linear run records boss PackedScene")


func _test_duplicate_completion_and_stale_activation_atomic() -> void:
	var session := _new_session(&"atomic_run")
	_start(session, &"atomic_start")
	_expect(_activate_pending(session).accepted, "first room activates")
	var completed := _complete_current_room(session)
	_expect(completed.accepted and completed.run_snapshot.route.phase == RunPhase.ROOM_LOADING, "first room reaches combat two loading")
	var before_duplicate := session.snapshot()
	var duplicate := session.handle_event(RoomCompletedEvent.new(
		&"duplicate_room_new_event",
		&"combat_01_entry",
		0,
		0,
		100,
		false
	))
	_expect(not duplicate.accepted and duplicate.reject_reason == RunCommandResult.RejectReason.DUPLICATE_ROOM, "duplicate completion is structurally rejected")
	_expect_same_authority(before_duplicate, session.snapshot(), "duplicate completion")
	var activation_before := session.snapshot()
	var pending_room := FLOW.combat_room_for(activation_before.route.pending_node_id)
	var stale_revision := session.accept_room_transition(
		&"stale_activation", activation_before.revision - 1,
		pending_room.room_id, 2901, pending_room.room_scene.resource_path
	)
	_expect(not stale_revision.accepted and stale_revision.reject_reason == RunCommandResult.RejectReason.STALE_RUN_REVISION, "stale direct activation revision rejected")
	_expect_same_authority(activation_before, session.snapshot(), "stale direct activation")
	var wrong_scene := session.accept_room_transition(
		&"wrong_direct_scene", activation_before.revision,
		pending_room.room_id, 2902, "res://scenes/run/rooms/not_the_configured_scene.tscn"
	)
	_expect(not wrong_scene.accepted and wrong_scene.reject_reason == RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED, "wrong direct successor scene rejected")
	_expect_same_authority(activation_before, session.snapshot(), "wrong direct successor scene")


func _test_scene_transition_failure_atomic() -> void:
	var session := _new_session(&"scene_failure_run")
	_start(session, &"scene_start")
	var before := session.snapshot()
	var room := FLOW.combat_room_for(before.route.pending_node_id)
	var rejected := session.accept_room_transition(
		&"bad_scene_transition",
		before.revision,
		before.route.pending_node_id,
		9090,
		"res://scenes/run/rooms/not_the_configured_scene.tscn"
	)
	_expect(not rejected.accepted and rejected.reject_reason == RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED, "scene path mismatch rejected")
	_expect_eq(room.room_scene.resource_path, "res://scenes/run/rooms/room_arena_flat.tscn", "expected scene remains known")
	_expect_same_authority(before, session.snapshot(), "failed scene activation")
	var failed := session.fail_formal_run(
		&"scene_failure_terminal",
		session.snapshot().revision,
		&"scene_transition_failed"
	)
	_expect(failed.accepted, "scene failure creates explicit failed result")
	_expect_eq(failed.run_snapshot.route.phase, RunPhase.RUN_FAILED, "scene failure phase is terminal")
	_expect_eq(failed.run_snapshot.result.failure_reason, &"scene_transition_failed", "scene failure reason frozen")
	_expect_eq(failed.run_snapshot.result.completed_combat_rooms, 0, "scene failure awards no room completion")


func _test_death_and_repeated_result_are_terminal() -> void:
	var session := _new_session(&"death_run")
	_start(session, &"death_start")
	_activate_pending(session)
	var before := session.snapshot()
	var failed := session.fail_formal_run(
		&"player_death",
		before.revision,
		&"player_defeated"
	)
	_expect(failed.accepted and failed.run_snapshot.result != null, "player death freezes failed result")
	_expect_eq(failed.run_snapshot.result.completed_combat_rooms, 0, "death grants no room completion")
	_expect_eq(failed.run_snapshot.economy.total_earned, before.economy.total_earned, "death grants no dream dust")
	var terminal_before := session.snapshot()
	var repeated := session.fail_formal_run(
		&"player_death_again",
		terminal_before.revision,
		&"player_defeated"
	)
	_expect(not repeated.accepted and repeated.reject_reason == RunCommandResult.RejectReason.RUN_ALREADY_FINISHED, "repeated failure rejected as terminal")
	_expect_same_authority(terminal_before, session.snapshot(), "repeated terminal request")
	var completion_after_result := session.handle_event(RoomCompletedEvent.new(
		&"post_result_completion",
		&"combat_01_entry",
		0
	))
	_expect(not completion_after_result.accepted and completion_after_result.reject_reason == RunCommandResult.RejectReason.RUN_ALREADY_FINISHED, "room event after result rejected")
	_expect_same_authority(terminal_before, session.snapshot(), "post-result room event")


func _new_session(run_id: StringName) -> RunSession:
	return RunSession.new(
		CATALOG.reward_definitions(),
		[],
		CATALOG.initial_owned_skill_ids(),
		[ElementIds.WATER, ElementIds.FIRE],
		null,
		GrowthEffectPort.new(),
		RunRulesSnapshot.formal_disabled(),
		CATALOG,
		0,
		FLOW,
		run_id
	)


func _start(session: RunSession, command_id: StringName) -> RunCommandResult:
	return session.start_formal_run(command_id, session.snapshot().revision)


func _activate_pending(session: RunSession) -> RunCommandResult:
	var snapshot := session.snapshot()
	var room := FLOW.combat_room_for(snapshot.route.pending_node_id)
	_room_instance_sequence += 1
	return session.accept_room_transition(
		_next_command(&"activate"),
		snapshot.revision,
		room.room_id,
		_room_instance_sequence,
		room.room_scene.resource_path
	)


func _complete_current_room(session: RunSession) -> RunCommandResult:
	var snapshot := session.snapshot()
	var room := FLOW.combat_room_for(snapshot.route.current_room_id)
	return session.handle_event(RoomCompletedEvent.new(
		_next_command(&"room_complete"),
		room.room_id,
		0,
		0,
		room.completion_dream_dust,
		room.final_boss
	))


func _leave_shop(session: RunSession) -> RunCommandResult:
	var snapshot := session.snapshot()
	return session.leave_formal_shop(
		_next_command(&"leave_shop"),
		snapshot.revision,
		snapshot.shop.session_id
	)


func _finish_run(session: RunSession) -> void:
	_expect(_activate_pending(session).accepted, "combat one activates")
	_expect(_complete_current_room(session).accepted, "combat one completes")
	_expect(_activate_pending(session).accepted, "combat two activates")
	_expect(_complete_current_room(session).accepted, "combat two completes")
	_expect(_leave_shop(session).accepted, "single shop leaves")
	_expect(_activate_pending(session).accepted, "combat three activates")
	_expect(_complete_current_room(session).accepted, "combat three completes")
	_expect(_activate_pending(session).accepted, "boss activates")
	_expect(_complete_current_room(session).accepted, "boss completes")


func _assert_completed_run(session: RunSession) -> void:
	var snapshot := session.snapshot()
	_expect_eq(snapshot.route.phase, RunPhase.RUN_COMPLETE, "full run reaches complete phase")
	_expect(snapshot.result != null and snapshot.result.is_complete(), "complete result is frozen")
	_expect_eq(snapshot.route.completed_combat_rooms, 4, "exactly four combat rooms complete")
	_expect_eq(snapshot.route.shop_visits, 1, "exactly one shop visited")
	_expect_eq(snapshot.route.route_choices, 0, "exactly zero routes chosen")
	_expect_eq(snapshot.route.selected_route_option_ids, [], "no route identities are frozen")
	_expect_eq(snapshot.route.activated_room_instance_ids.size(), 4, "four different room instances activated")
	_expect_eq(_unique_int_count(snapshot.route.activated_room_instance_ids), 4, "room instance ids never reused")
	_expect_eq(snapshot.result.final_node_id, &"run_result", "boss transaction lands directly at result")
	_expect_eq(snapshot.result.shop_visits, 1, "result freezes shop count")
	_expect_eq(snapshot.result.route_choices, 0, "result freezes route count")
	var terminal_before := session.snapshot()
	var repeated := session.handle_event(RoomCompletedEvent.new(
		_next_command(&"duplicate_boss"),
		&"combat_06_final_boss",
		0,
		0,
		0,
		true
	))
	_expect(not repeated.accepted and repeated.reject_reason == RunCommandResult.RejectReason.RUN_ALREADY_FINISHED, "duplicate boss result rejected")
	_expect_same_authority(terminal_before, session.snapshot(), "duplicate boss result")


func _expect_same_authority(before: RunSnapshot, after: RunSnapshot, label: String) -> void:
	_expect_eq(after.revision, before.revision, "%s keeps run revision" % label)
	_expect_eq(after.route.phase, before.route.phase, "%s keeps phase" % label)
	_expect_eq(after.route.completed_combat_rooms, before.route.completed_combat_rooms, "%s keeps room count" % label)
	_expect_eq(after.economy.balance, before.economy.balance, "%s keeps balance" % label)
	_expect_eq(after.economy.total_earned, before.economy.total_earned, "%s keeps earnings" % label)


func _unique_int_count(values: Array[int]) -> int:
	var unique: Array[int] = []
	for value: int in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _next_command(prefix: StringName) -> StringName:
	_command_sequence += 1
	return StringName("task29:%s:%d" % [String(prefix), _command_sequence])


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])
