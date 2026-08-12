extends SceneTree

const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_two_layer_six_combat.tres")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const COHORT_SIZE: int = 512
const FIRST_ROOM_ID: StringName = &"combat_01_entry"
const FOUR_POOL_OWNED_ID: StringName = &"burning"

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []
var _distribution: Dictionary = {}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("formal_cohort_repeatability_and_distribution", _test_formal_cohort_repeatability_and_distribution)
	_run_test("empty_pool_and_transaction_guards", _test_empty_pool_and_transaction_guards)
	_run_test("frozen_reward_and_room_economy", _test_frozen_reward_and_room_economy)
	_finish()


func _test_formal_cohort_repeatability_and_distribution() -> void:
	var reward_ids := _reward_pool_ids()
	_expect_eq(reward_ids.size(), 5, "formal reward_pool remains the five accepted Task41 skills")
	_expect(reward_ids.has(FOUR_POOL_OWNED_ID), "four-candidate fixture owns one real reward_pool skill")
	var initial_ids := CATALOG.initial_owned_skill_ids()
	initial_ids.append(FOUR_POOL_OWNED_ID)
	var candidate_ids := reward_ids.duplicate()
	candidate_ids.erase(FOUR_POOL_OWNED_ID)
	var skill_count := 0
	var dust_count := 0
	var candidate_counts: Dictionary = {}
	for candidate_id: StringName in candidate_ids:
		candidate_counts[candidate_id] = 0
	for index: int in COHORT_SIZE:
		var run_id := StringName("task42_cohort_%04d" % index)
		var first := _claim_first_formal_chest(run_id, initial_ids, index * 2 + 1)
		var rebuilt := _claim_first_formal_chest(run_id, initial_ids, index * 2 + 2)
		_expect(first != null and rebuilt != null, "%s creates two accepted formal claims" % String(run_id))
		if first == null or rebuilt == null:
			continue
		_expect_eq(_reward_signature(rebuilt), _reward_signature(first), "%s is identical after a fresh RunSession rebuild" % String(run_id))
		if first.kind == RunChestRewardSnapshot.Kind.SKILL:
			skill_count += 1
			_expect(candidate_ids.has(first.skill_id), "%s drops only an unowned formal reward_pool skill" % String(run_id))
			_expect(first.skill_id != FOUR_POOL_OWNED_ID, "%s never drops the already-owned fixture skill" % String(run_id))
			candidate_counts[first.skill_id] = int(candidate_counts.get(first.skill_id, 0)) + 1
		else:
			dust_count += 1
			_expect_eq(first.kind, RunChestRewardSnapshot.Kind.DREAM_DUST, "%s has only the typed dust alternative" % String(run_id))
			_expect_eq(first.dream_dust, 150, "%s dust branch is exactly 150" % String(run_id))
	var skill_percent := float(skill_count) * 100.0 / float(COHORT_SIZE)
	var dust_percent := float(dust_count) * 100.0 / float(COHORT_SIZE)
	_expect(skill_percent >= 45.0 and skill_percent <= 55.0, "first-chest skill share stays within 45-55 percent")
	_expect(dust_percent >= 45.0 and dust_percent <= 55.0, "first-chest dust share stays within 45-55 percent")
	_expect_eq(skill_count + dust_count, COHORT_SIZE, "cohort accounts for every formal claim")
	for candidate_id: StringName in candidate_ids:
		var count := int(candidate_counts[candidate_id])
		var percent := float(count) * 100.0 / float(maxi(1, skill_count))
		_expect(count > 0, "%s is reachable on the skill branch" % String(candidate_id))
		_expect(percent >= 20.0 and percent <= 30.0, "%s occupies 20-30 percent of four-candidate skill claims" % String(candidate_id))
	_distribution = {
		"cohort_size": COHORT_SIZE,
		"skill_count": skill_count,
		"dust_count": dust_count,
		"skill_percent": snappedf(skill_percent, 0.01),
		"dust_percent": snappedf(dust_percent, 0.01),
		"four_candidate_skill_counts": _string_key_dictionary(candidate_counts),
	}


func _test_empty_pool_and_transaction_guards() -> void:
	var all_owned := CATALOG.initial_owned_skill_ids()
	for skill_id: StringName in _reward_pool_ids():
		if not all_owned.has(skill_id):
			all_owned.append(skill_id)
	for index: int in 64:
		var reward := _claim_first_formal_chest(StringName("task42_empty_%03d" % index), all_owned, 20_000 + index)
		_expect(reward != null and reward.kind == RunChestRewardSnapshot.Kind.DREAM_DUST, "empty pool claim %d is typed dust" % index)
		if reward != null:
			_expect_eq(reward.dream_dust, 150, "empty pool claim %d is exactly 150" % index)
	var session := _new_formal_session(&"task42_transaction_guards", CATALOG.initial_owned_skill_ids())
	_expect(session.start_formal_run(&"start", 0).accepted, "guard session starts through formal command")
	var pending := session.snapshot().route.pending_node_id
	var room := FLOW.combat_room_for(pending)
	_expect(session.accept_room_transition(&"accept", 1, pending, 42_424, room.room_scene.resource_path).accepted, "guard session accepts the formal room")
	var before := session.snapshot()
	var stale := session.claim_formal_room_chest(&"stale", before.revision - 1, pending)
	_expect(not stale.accepted and stale.reject_reason == RunCommandResult.RejectReason.STALE_RUN_REVISION, "stale claim is rejected")
	_expect_eq(_authority_signature(session.snapshot()), _authority_signature(before), "stale claim changes no authority")
	var claimed := session.claim_formal_room_chest(&"claim", before.revision, pending)
	_expect(claimed.accepted and claimed.chest_reward != null and claimed.chest_reward.is_valid(), "fresh claim commits one typed reward")
	var after := session.snapshot()
	var replay := session.claim_formal_room_chest(&"claim", before.revision, pending)
	_expect(replay == claimed, "identical command replays the original result")
	_expect_eq(_authority_signature(session.snapshot()), _authority_signature(after), "replay changes no authority")
	var duplicate := session.claim_formal_room_chest(&"duplicate", after.revision, pending)
	_expect(not duplicate.accepted and duplicate.reject_reason == RunCommandResult.RejectReason.ALREADY_CLAIMED, "new command cannot claim the room twice")
	_expect_eq(_authority_signature(session.snapshot()), _authority_signature(after), "duplicate claim changes no authority")


func _test_frozen_reward_and_room_economy() -> void:
	_expect_eq(RunChestRewardSnapshot.DREAM_DUST_AMOUNT, 150, "normal chest dust amount is frozen at 150")
	var safe_pre_shop := _room_dust(&"combat_01_entry") + _room_dust(&"combat_02_swarm") + _room_dust(&"combat_03_layer_elite")
	var risk_pre_shop := _room_dust(&"combat_01_entry") + _room_dust(&"combat_02_pressure") + _room_dust(&"combat_03_layer_elite")
	var safe_total := safe_pre_shop + _room_dust(&"combat_04_validation") + _room_dust(&"combat_05_stable")
	var risk_total := risk_pre_shop + _room_dust(&"combat_04_validation") + _room_dust(&"combat_05_risk")
	_expect_eq(safe_total, 595, "safe five-room base income is frozen at 595")
	_expect_eq(risk_total, 700, "risk five-room base income is frozen at 700")
	_expect_eq(safe_pre_shop, 345, "safe base income before the single shop is frozen at 345")
	_expect_eq(risk_pre_shop, 365, "risk base income before the single shop is frozen at 365")
	var boss := FLOW.combat_room_for(&"combat_06_final_boss")
	_expect(boss != null and boss.final_boss, "final room remains the formal Boss")
	_expect_eq(_spawn_dust(boss), 0, "Boss kill dream dust is frozen at zero")
	_expect_eq(boss.completion_dream_dust, 0, "Boss completion dream dust is frozen at zero")
	var boss_session := _new_formal_session(&"task42_boss_chest_contract", CATALOG.initial_owned_skill_ids())
	_expect(boss_session.start_formal_run(&"start", 0).accepted, "Boss contract session starts formally")
	var pending := boss_session.snapshot().route.pending_node_id
	var first_room := FLOW.combat_room_for(pending)
	_expect(boss_session.accept_room_transition(&"accept", 1, pending, 42_999, first_room.room_scene.resource_path).accepted, "Boss contract session accepts a formal room")
	var normal_claim := boss_session.claim_formal_room_chest(&"claim", 2, pending)
	_expect(normal_claim.accepted and normal_claim.chest_reward != null, "only normal rooms expose a typed reward claim")
	_expect_eq(boss.completion_dream_dust, 0, "Boss settlement chest grants zero dream dust by the accepted final-room contract")


func _claim_first_formal_chest(run_id: StringName, initial_ids: Array[StringName], instance_id: int) -> RunChestRewardSnapshot:
	var session := _new_formal_session(run_id, initial_ids)
	var started := session.start_formal_run(&"start", 0)
	if not started.accepted:
		return null
	var pending := session.snapshot().route.pending_node_id
	var room := FLOW.combat_room_for(pending)
	if room == null:
		return null
	var accepted := session.accept_room_transition(&"accept", session.snapshot().revision, pending, instance_id, room.room_scene.resource_path)
	if not accepted.accepted:
		return null
	var claimed := session.claim_formal_room_chest(&"claim", session.snapshot().revision, pending)
	return claimed.chest_reward if claimed.accepted else null


func _new_formal_session(run_id: StringName, initial_ids: Array[StringName]) -> RunSession:
	return RunSession.new(
		CATALOG.reward_definitions(), CATALOG.relic_definitions, initial_ids,
		[ElementIds.WATER, ElementIds.FIRE], null, null,
		RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
	)


func _reward_pool_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for content: SkillContentDefinition in CATALOG.skill_contents:
		if content != null and content.reward_pool:
			result.append(content.skill_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


func _room_dust(room_id: StringName) -> int:
	var room := FLOW.combat_room_for(room_id)
	return room.completion_dream_dust + _spawn_dust(room)


func _spawn_dust(room: CombatRoomDefinition) -> int:
	var total := 0
	for spawn: EnemySpawnDefinition in room.enemy_spawns:
		total += spawn.dream_dust_reward
	for spawn: EnemySpawnDefinition in room.reinforcement_spawns:
		total += spawn.dream_dust_reward
	return total


func _reward_signature(reward: RunChestRewardSnapshot) -> Array:
	return [reward.kind, reward.room_id, reward.skill_id, reward.dream_dust]


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [snapshot.revision, snapshot.route.phase, snapshot.route.run_id, snapshot.route.current_room_id, snapshot.economy.balance, snapshot.skills.owned_skill_ids]


func _string_key_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in source:
		result[String(key)] = source[key]
	return result


func _run_test(name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callable.call()
	if before == _failures.size():
		print("PASS task42_" + name)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])


func _finish() -> void:
	print("TASK42_COHORT_DISTRIBUTION: " + JSON.stringify(_distribution))
	if _failures.is_empty():
		print("TASK 42 REWARD ECONOMY TUNING TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 42 REWARD ECONOMY TUNING TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
