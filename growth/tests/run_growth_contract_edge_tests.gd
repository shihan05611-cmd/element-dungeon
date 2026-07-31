extends SceneTree

## Focused contract-edge checks kept separate from the behavior suite.

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	_test_loadout_snapshot_reports_duplicate_keys()
	_test_active_room_identity_is_frozen()
	_test_duplicate_catalog_ids_are_configuration_errors()
	_test_run_cannot_finish_before_six_rooms()
	if _failures.is_empty():
		print("GROWTH CONTRACT EDGE TESTS PASSED: 4 tests, %d assertions" % _assertions)
		quit(0)
	else:
		printerr("GROWTH CONTRACT EDGE TESTS FAILED: %d failures, %d assertions" % [_failures.size(), _assertions])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _test_loadout_snapshot_reports_duplicate_keys() -> void:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(&"active_1", &"skill_a"),
		RuntimeLoadoutSlotSnapshot.new(&"active_1", &"skill_b"),
	]
	var snapshot := RuntimeLoadoutSnapshot.new(entries, 2)
	_expect(not snapshot.is_valid(), "duplicate form/slot rejected")
	_expect_eq(snapshot.validation_error, &"duplicate_slot_id", "duplicate has explicit error")
	_expect_eq(snapshot.get_skill_id(&"active_1"), &"skill_a", "first valid entry remains stable")


func _test_active_room_identity_is_frozen() -> void:
	var director := RunDirector.new()
	_expect(director.begin_combat_room(&"room_a").accepted, "first room begins")
	var replacement := director.begin_combat_room(&"room_b")
	_expect(not replacement.accepted, "active room cannot be replaced")
	_expect_eq(director.snapshot().current_room_id, &"room_a", "room identity unchanged")


func _test_duplicate_catalog_ids_are_configuration_errors() -> void:
	var first := SkillRewardDefinition.new()
	first.skill_id = &"duplicate"
	first.initial_pool = true
	first.allowed_form_ids = [&"water"]
	var second := SkillRewardDefinition.new()
	second.skill_id = &"duplicate"
	second.initial_pool = true
	second.allowed_form_ids = [&"water"]
	var skills: Array[SkillRewardDefinition] = [first, second]
	var forms: Array[StringName] = [&"water"]
	var run := RunSnapshot.new(
		ProgressionSnapshot.new(),
		SkillInventorySnapshot.new(),
		RelicInventorySnapshot.new(),
		RuntimeLoadoutSnapshot.new(),
		RouteSnapshot.new(),
		null,
		false,
		forms
	)
	var offer := RewardGenerator.generate(
		run,
		RoomRewardContext.new(&"room", RewardType.SKILL, true),
		1,
		skills,
		[]
	)
	_expect(not offer.valid, "duplicate catalog fails")
	_expect_eq(offer.configuration_error, &"duplicate_skill_reward_definition", "duplicate catalog error explicit")


func _test_run_cannot_finish_before_six_rooms() -> void:
	var director := RunDirector.new()
	director.begin_combat_room(&"room_1")
	director.commit_room_completion(&"room_1")
	director.commit_reward_claim(true, true)
	# The first checkpoint is not a shop, so completing the run is unavailable.
	var result := director.commit_shop_exit(true)
	_expect(not result.accepted, "early completion rejected")
	_expect_eq(director.snapshot().phase, RunPhase.ROUTE_CHOICE, "phase preserved after early completion request")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])

