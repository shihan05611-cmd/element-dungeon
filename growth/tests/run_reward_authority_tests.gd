extends SceneTree

## Regression coverage for untrusted RoomRewardContext bypass attempts.

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	_test_first_room_hint_cannot_bypass_three_skill_rule()
	_test_selected_relic_route_rejects_skill_request()
	_test_pure_generator_rejects_authoritative_route_mismatch()
	if _failures.is_empty():
		print("REWARD AUTHORITY TESTS PASSED: 3 tests, %d assertions" % _assertions)
		quit(0)
	else:
		printerr("REWARD AUTHORITY TESTS FAILED: %d failures, %d assertions" % [_failures.size(), _assertions])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _test_first_room_hint_cannot_bypass_three_skill_rule() -> void:
	var session := _make_session(_make_skill_catalog(2))
	session.begin_combat_room(&"first_room")
	session.handle_event(RoomCompletedEvent.new(&"first_done", &"first_room", 0))
	var before := session.snapshot()
	# Legacy third argument is deliberately false. The route snapshot remains
	# authoritative and must still enforce the first-room rule.
	var result := session.generate_reward(
		RoomRewardContext.new(&"first_room", RewardType.SKILL, false),
		10
	)
	var after := session.snapshot()
	_expect(not result.accepted, "first-room bypass request rejected")
	_expect_eq(result.reject_reason, RunCommandResult.RejectReason.CONFIGURATION_ERROR, "structured rejection")
	_expect_eq(result.detail, &"insufficient_initial_skill_candidates", "first-room rule derived from route")
	_expect(after.pending_reward == null, "failed request installs no pending reward")
	_expect_eq(after.revision, before.revision, "failed request does not mutate run")


func _test_selected_relic_route_rejects_skill_request() -> void:
	var session := _make_session(_make_skill_catalog(5))
	session.begin_combat_room(&"room_1")
	session.handle_event(RoomCompletedEvent.new(&"done_1", &"room_1", 0))
	var first := session.generate_reward(RoomRewardContext.new(&"room_1", RewardType.SKILL), 11)
	var first_option := first.reward_offer.options[0]
	_expect(session.claim_reward(first.reward_offer.offer_id, first_option.option_id).accepted, "first reward claimed")
	_expect(session.choose_route(RunDirector.RELIC_ROUTE_ID).accepted, "relic route selected")
	session.begin_combat_room(&"room_2")
	session.handle_event(RoomCompletedEvent.new(&"done_2", &"room_2", 0))
	var before := session.snapshot()
	var bypass := session.generate_reward(RoomRewardContext.new(&"room_2", RewardType.SKILL), 12)
	var after_bypass := session.snapshot()
	_expect(not bypass.accepted, "skill request on relic route rejected")
	_expect_eq(bypass.detail, &"reward_type_route_mismatch", "route mismatch is explicit")
	_expect(after_bypass.pending_reward == before.pending_reward, "mismatch installs no new pending reward")
	_expect_eq(after_bypass.revision, before.revision, "mismatch has no state mutation")
	var allowed := session.generate_reward(RoomRewardContext.new(&"room_2", RewardType.RELIC), 12)
	_expect(allowed.accepted, "selected relic reward remains available")
	_expect_eq(allowed.reward_offer.reward_type, RewardType.RELIC, "offer matches selected route")


func _test_pure_generator_rejects_authoritative_route_mismatch() -> void:
	var forms: Array[StringName] = [&"water"]
	var route := RouteSnapshot.new(RunPhase.REWARD, 2, &"room_2", RewardType.RELIC)
	var run := RunSnapshot.new(
		ProgressionSnapshot.new(),
		SkillInventorySnapshot.new(),
		RelicInventorySnapshot.new(),
		RuntimeLoadoutSnapshot.new(),
		route,
		null,
		false,
		forms
	)
	var offer := RewardGenerator.generate(
		run,
		RoomRewardContext.new(&"room_2", RewardType.SKILL),
		99,
		_make_skill_catalog(5),
		_make_relic_catalog()
	)
	_expect(not offer.valid, "pure generator rejects route mismatch")
	_expect_eq(offer.configuration_error, &"reward_type_route_mismatch", "pure generator reports authority error")


func _make_session(skills: Array[SkillRewardDefinition]) -> RunSession:
	var forms: Array[StringName] = [&"water"]
	return RunSession.new(skills, _make_relic_catalog(), [], forms)


func _make_skill_catalog(count: int) -> Array[SkillRewardDefinition]:
	var result: Array[SkillRewardDefinition] = []
	for index in count:
		var definition := SkillRewardDefinition.new()
		definition.skill_id = StringName("authority_skill_%d" % index)
		definition.display_name = "Authority Skill %d" % index
		definition.initial_pool = true
		definition.allowed_form_ids = [&"water"]
		result.append(definition)
	return result


func _make_relic_catalog() -> Array[RelicDefinition]:
	var result: Array[RelicDefinition] = []
	for index in 2:
		var definition := RelicDefinition.new()
		definition.relic_id = StringName("authority_relic_%d" % index)
		definition.display_name = "Authority Relic %d" % index
		definition.effect_kind = RelicDefinition.EffectKind.ROOM_COMPLETE_HEAL
		definition.amount = 1
		result.append(definition)
	return result


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])
