extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

class RecordingEffectPort:
	extends GrowthEffectPort

	var restored_energy: int = 0
	var calls: int = 0

	func restore_energy(amount: int, _source_relic_id: StringName, _event_id: StringName) -> bool:
		restored_energy += amount
		calls += 1
		return true


class SharedSevenSlotPort:
	extends RuntimeLoadoutPort

	const ACTIVE_1: StringName = &"active_1"
	const ACTIVE_2: StringName = &"active_2"
	const ACTIVE_3: StringName = &"active_3"
	const PASSIVE_1: StringName = &"passive_1"
	const PASSIVE_2: StringName = &"passive_2"
	const PASSIVE_3: StringName = &"passive_3"
	const PASSIVE_4: StringName = &"passive_4"

	var current: RuntimeLoadoutSnapshot
	var passive_skill_ids: Array[StringName] = []
	var reject_validation: bool = false
	var commit_count: int = 0

	func _init(initial: RuntimeLoadoutSnapshot, p_passive_skill_ids: Array[StringName] = []) -> void:
		current = initial
		passive_skill_ids = p_passive_skill_ids.duplicate()

	func snapshot() -> RuntimeLoadoutSnapshot:
		return current

	func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		if reject_validation:
			return RuntimeLoadoutChangeResult.rejected(&"test_port_rejected", current)
		if candidate == null or not candidate.is_valid():
			return RuntimeLoadoutChangeResult.rejected(&"invalid_snapshot_structure", current)
		if candidate.revision != current.revision:
			return RuntimeLoadoutChangeResult.rejected(&"stale_loadout_revision", current)
		if candidate.entries.size() != 7:
			return RuntimeLoadoutChangeResult.rejected(&"expected_seven_shared_slots", current)
		for slot_id in [ACTIVE_1, ACTIVE_2, ACTIVE_3, PASSIVE_1, PASSIVE_2, PASSIVE_3, PASSIVE_4]:
			if not candidate.has_slot(slot_id):
				return RuntimeLoadoutChangeResult.rejected(&"missing_shared_slot", current)
		var seen_skills: Array[StringName] = []
		for entry in candidate.entries:
			if entry.skill_id.is_empty():
				continue
			if seen_skills.has(entry.skill_id):
				return RuntimeLoadoutChangeResult.rejected(&"duplicate_equipped_skill", current)
			seen_skills.append(entry.skill_id)
		for slot_id in [ACTIVE_1, ACTIVE_2, ACTIVE_3]:
			var active_skill_id := candidate.get_skill_id(slot_id)
			if not active_skill_id.is_empty() and passive_skill_ids.has(active_skill_id):
				return RuntimeLoadoutChangeResult.rejected(&"passive_skill_in_active_slot", current)
		for slot_id in [PASSIVE_1, PASSIVE_2, PASSIVE_3, PASSIVE_4]:
			var passive_skill_id := candidate.get_skill_id(slot_id)
			if not passive_skill_id.is_empty() and not passive_skill_ids.has(passive_skill_id):
				return RuntimeLoadoutChangeResult.rejected(&"active_skill_in_passive_slot", current)
		return RuntimeLoadoutChangeResult.success(candidate)

	func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		var validation := validate_snapshot(candidate)
		if not validation.accepted:
			return validation
		current = RuntimeLoadoutSnapshot.new(candidate.entries, current.revision + 1)
		commit_count += 1
		return RuntimeLoadoutChangeResult.success(current)


var _harness := TestHarness.new()


func _initialize() -> void:
	_run("shared_snapshot_sort_copy_revision", _test_shared_snapshot_sort_copy_revision)
	_run("shared_snapshot_rejects_invalid_entries", _test_shared_snapshot_rejects_invalid_entries)
	_run("shop_draft_shared_assign_reset_and_stale", _test_shop_draft_shared_assign_reset_and_stale)
	_run("run_session_rejects_unowned_shared_skill", _test_run_session_rejects_unowned_shared_skill)
	_run("four_passives_are_accepted_by_b_port", _test_four_passives_are_accepted_by_b_port)
	_run("same_element_event_is_invalid", _test_same_element_event_is_invalid)
	_run("manual_and_auto_relic_filters", _test_manual_and_auto_relic_filters)
	_run("event_id_and_sequence_are_both_deduplicated", _test_event_id_and_sequence_are_both_deduplicated)
	_run("event_fields_are_immutable_and_complete", _test_event_fields_are_immutable_and_complete)
	_run("sequence_state_isolated_between_sessions", _test_sequence_state_isolated_between_sessions)

	quit(_harness.report("GROWTH 06 CONTRACT TESTS"))


func _run(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _test_shared_snapshot_sort_copy_revision() -> void:
	var snapshot := RuntimeLoadoutSnapshot.new(_seven_entries(
		&"skill_a",
		&"skill_b",
		&"skill_c",
		&"skill_p"
	), 17)
	_expect(snapshot.is_valid(), "seven-slot snapshot valid")
	_expect_eq(snapshot.revision, 17, "revision preserved")
	var entries := snapshot.entries
	_expect_eq(entries[0].slot_id, &"active_1", "entries sorted by slot id")
	_expect_eq(entries[1].slot_id, &"active_2", "second entry sorted")
	_expect_eq(entries[2].slot_id, &"active_3", "third entry sorted")
	_expect_eq(entries[3].slot_id, &"passive_1", "passive entry sorted")
	entries.clear()
	_expect_eq(snapshot.entries.size(), 7, "entries getter returns copy")
	_expect_eq(snapshot.get_skill_id(&"active_2"), &"skill_b", "slot lookup uses no element id")


func _test_shared_snapshot_rejects_invalid_entries() -> void:
	var duplicates: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(&"active_1", &"a"),
		RuntimeLoadoutSlotSnapshot.new(&"active_1", &"b"),
	]
	var duplicate_snapshot := RuntimeLoadoutSnapshot.new(duplicates)
	_expect(not duplicate_snapshot.is_valid(), "duplicate slot rejected")
	_expect_eq(duplicate_snapshot.validation_error, &"duplicate_slot_id", "duplicate slot has typed error")
	var invalid_entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(&"", &"skill"),
	]
	var invalid_snapshot := RuntimeLoadoutSnapshot.new(invalid_entries)
	_expect(not invalid_snapshot.is_valid(), "empty slot rejected")
	_expect_eq(invalid_snapshot.validation_error, &"invalid_loadout_entry", "empty slot has typed error")


func _test_shop_draft_shared_assign_reset_and_stale() -> void:
	var baseline := RuntimeLoadoutSnapshot.new(_seven_entries(&"old", &"", &"", &""), 4)
	var progression := ProgressionSnapshot.new()
	var draft := ShopDraft.new(8, progression, baseline)
	_expect(draft.try_assign_slot(&"active_1", &"new").accepted, "shared slot assignment accepted")
	_expect_eq(draft.preview_loadout().get_skill_id(&"active_1"), &"new", "preview changed")
	_expect(draft.reset().accepted, "draft reset accepted")
	_expect_eq(draft.preview_loadout().get_skill_id(&"active_1"), &"old", "reset restores baseline")
	_expect(not draft.try_assign_slot(&"water_active_1", &"new").accepted, "legacy element slot rejected")
	var stale := draft.validate_baseline(9, progression, baseline)
	_expect_eq(stale.reject_reason, RunCommandResult.RejectReason.STALE_DRAFT, "run revision expiration detected")


func _test_run_session_rejects_unowned_shared_skill() -> void:
	var port := SharedSevenSlotPort.new(RuntimeLoadoutSnapshot.new(_seven_entries(), 1))
	var session := _make_session(port)
	_reach_shop(session)
	var draft := session.open_shop_draft().draft
	draft.try_assign_slot(&"active_1", &"not_owned")
	var before := session.snapshot()
	var result := session.confirm_shop(draft)
	var after := session.snapshot()
	_expect(not result.accepted, "unowned skill rejected")
	_expect_eq(result.reject_reason, RunCommandResult.RejectReason.LOADOUT_REJECTED, "typed loadout rejection")
	_expect_eq(result.detail, &"loadout_contains_unowned_skill", "ownership reason explicit")
	_expect(after.loadout.same_mapping(before.loadout), "loadout unchanged")
	_expect_eq(after.route.phase, RunPhase.SHOP, "phase unchanged")
	_expect_eq(port.commit_count, 0, "port not called for unowned skill")


func _test_four_passives_are_accepted_by_b_port() -> void:
	var passives: Array[StringName] = [&"passive_a", &"passive_b", &"passive_c", &"passive_d"]
	var port := SharedSevenSlotPort.new(RuntimeLoadoutSnapshot.new(_seven_entries(), 1), passives)
	var session := _make_session(port, passives)
	_reach_shop(session)
	var draft := session.open_shop_draft().draft
	draft.try_assign_slot(&"passive_1", passives[0])
	draft.try_assign_slot(&"passive_2", passives[1])
	draft.try_assign_slot(&"passive_3", passives[2])
	draft.try_assign_slot(&"passive_4", passives[3])
	var result := session.confirm_shop(draft)
	_expect(result.accepted, "zero active plus four passives accepted")
	_expect_eq(port.commit_count, 1, "seven-slot snapshot replaced atomically")
	for index in 4:
		var slot_id: StringName = [&"passive_1", &"passive_2", &"passive_3", &"passive_4"][index]
		_expect_eq(result.run_snapshot.loadout.get_skill_id(slot_id), passives[index], "passive mapping committed")


func _test_same_element_event_is_invalid() -> void:
	var event := FormChangedEvent.new(
		&"same",
		&"room",
		&"water",
		&"water",
		FormChangedEvent.Source.MANUAL,
		1,
		1000
	)
	_expect(not event.is_valid(), "same element event invalid")
	var controller := RelicController.new(RecordingEffectPort.new())
	_expect(not controller.handle_event(event).accepted, "invalid event does not enter relic dispatch")


func _test_manual_and_auto_relic_filters() -> void:
	var manual := _form_relic(&"manual", 3, FormChangeResponsePolicy.Value.MANUAL_ONLY)
	var automatic := _form_relic(&"automatic", 5, FormChangeResponsePolicy.Value.SKILL_AUTO_ONLY)
	var port := RecordingEffectPort.new()
	var controller := RelicController.new(port)
	_expect(controller.register_owned_relic(manual).accepted, "manual relic registered")
	_expect(controller.register_owned_relic(automatic).accepted, "auto relic registered")
	controller.handle_event(_form_event(&"manual_event", 1, FormChangedEvent.Source.MANUAL))
	_expect_eq(port.restored_energy, 3, "manual event triggers only manual relic")
	_expect_eq(port.calls, 1, "one manual filter call")
	controller.handle_event(_form_event(&"auto_event", 2, FormChangedEvent.Source.SKILL_AUTO))
	_expect_eq(port.restored_energy, 8, "auto event triggers only auto relic")
	_expect_eq(port.calls, 2, "one auto filter call")


func _test_event_id_and_sequence_are_both_deduplicated() -> void:
	var session := _make_session(null)
	_expect(session.begin_combat_room(&"room").accepted, "event authority room begins")
	var first := _form_event(&"event_1", 1, FormChangedEvent.Source.MANUAL)
	_expect(session.handle_event(first).accepted, "first event accepted")
	_expect(not session.handle_event(first).accepted, "duplicate event id rejected")
	_expect(not session.handle_event(_form_event(&"event_2", 1, FormChangedEvent.Source.SKILL_AUTO)).accepted, "duplicate sequence rejected")
	_expect(not session.handle_event(_form_event(&"event_3", 0, FormChangedEvent.Source.MANUAL)).accepted, "invalid zero sequence rejected")
	_expect(session.handle_event(_form_event(&"event_4", 2, FormChangedEvent.Source.SKILL_AUTO)).accepted, "next sequence accepted")
	_expect_eq(session.snapshot().revision, 3, "only unique monotonic events commit")


func _test_event_fields_are_immutable_and_complete() -> void:
	var event := FormChangedEvent.new(
		&"complete",
		&"room",
		&"water",
		&"fire",
		FormChangedEvent.Source.SKILL_AUTO,
		42,
		123456
	)
	_expect(event.is_valid(), "complete event valid")
	_expect_eq(event.previous_element_id, &"water", "previous element exposed")
	_expect_eq(event.current_element_id, &"fire", "current element exposed")
	_expect_eq(event.source, FormChangedEvent.Source.SKILL_AUTO, "source exposed")
	_expect_eq(event.sequence, 42, "sequence exposed")
	_expect_eq(event.timestamp_msec, 123456, "timestamp exposed")


func _test_sequence_state_isolated_between_sessions() -> void:
	var first := _make_session(null)
	var second := _make_session(null)
	first.begin_combat_room(&"room")
	second.begin_combat_room(&"room")
	var first_result := first.handle_event(_form_event(&"first_10", 10, FormChangedEvent.Source.MANUAL))
	var second_result := second.handle_event(_form_event(&"second_1", 1, FormChangedEvent.Source.MANUAL))
	_expect(first_result.accepted, "first session accepts its own sequence")
	_expect(second_result.accepted, "second session starts its own sequence")
	_expect_eq(first.snapshot().revision, second.snapshot().revision, "session sequence states remain isolated")


func _seven_entries(
		active_1_skill: StringName = &"",
		active_2_skill: StringName = &"",
		active_3_skill: StringName = &"",
		passive_1_skill: StringName = &"",
		passive_2_skill: StringName = &"",
		passive_3_skill: StringName = &"",
		passive_4_skill: StringName = &""
) -> Array[RuntimeLoadoutSlotSnapshot]:
	return [
		RuntimeLoadoutSlotSnapshot.new(&"passive_1", passive_1_skill),
		RuntimeLoadoutSlotSnapshot.new(&"passive_2", passive_2_skill),
		RuntimeLoadoutSlotSnapshot.new(&"passive_3", passive_3_skill),
		RuntimeLoadoutSlotSnapshot.new(&"passive_4", passive_4_skill),
		RuntimeLoadoutSlotSnapshot.new(&"active_3", active_3_skill),
		RuntimeLoadoutSlotSnapshot.new(&"active_1", active_1_skill),
		RuntimeLoadoutSlotSnapshot.new(&"active_2", active_2_skill),
	]


func _make_session(
		port: RuntimeLoadoutPort,
		initial_owned: Array[StringName] = []
) -> RunSession:
	var forms: Array[StringName] = [&"water", &"fire"]
	return RunSession.new(_skill_catalog(), _relic_catalog(), initial_owned, forms, port)


func _skill_catalog() -> Array[SkillRewardDefinition]:
	var result: Array[SkillRewardDefinition] = []
	for index in 8:
		var definition := SkillRewardDefinition.new()
		definition.skill_id = StringName("shop_skill_%d" % index)
		definition.display_name = "Shop Skill %d" % index
		definition.initial_pool = true
		definition.allowed_form_ids = [&"water", &"fire"]
		result.append(definition)
	return result


func _relic_catalog() -> Array[RelicDefinition]:
	var definition := RelicDefinition.new()
	definition.relic_id = &"shop_relic"
	definition.display_name = "Shop Relic"
	definition.effect_kind = RelicDefinition.EffectKind.ROOM_COMPLETE_HEAL
	definition.amount = 1
	return [definition]


func _reach_shop(session: RunSession) -> void:
	for room_number in range(1, 4):
		var room_id := StringName("room_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "room begins")
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("done_%d" % room_number),
			room_id,
			100
		)).accepted, "room completes")
		var generated := session.generate_reward(RoomRewardContext.new(room_id, RewardType.SKILL), 500 + room_number)
		_expect(generated.accepted, "reward generated")
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "reward claimed")
		if room_number < 3:
			_expect(session.choose_route(RunDirector.SKILL_ROUTE_ID).accepted, "skill route chosen")
		else:
			_expect(session.choose_route(RunDirector.SHOP_ROUTE_ID).accepted, "shop route chosen")


func _form_relic(
		relic_id: StringName,
		amount: int,
		policy: FormChangeResponsePolicy.Value
) -> FormChangeRelicDefinition:
	var definition := FormChangeRelicDefinition.new()
	definition.relic_id = relic_id
	definition.display_name = String(relic_id)
	definition.effect_kind = RelicDefinition.EffectKind.FORM_SWITCH_ENERGY_RESTORE
	definition.amount = amount
	definition.response_policy = policy
	return definition


func _form_event(
		event_id: StringName,
		sequence: int,
		source: FormChangedEvent.Source
) -> FormChangedEvent:
	return FormChangedEvent.new(event_id, &"room", &"water", &"fire", source, sequence, 1000 + sequence)


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_harness.expect_eq(actual, expected, message)
