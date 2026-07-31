extends SceneTree

## Dependency-free headless entry point:
## Godot --headless --path <project> --script res://growth/tests/run_growth_tests.gd

class RecordingEffectPort:
	extends GrowthEffectPort

	var energy_restored: int = 0
	var health_restored: int = 0
	var maximum_health_added: int = 0
	var maximum_energy_added: int = 0
	var temporary_attack_calls: int = 0
	var event_ids: Array[StringName] = []

	func restore_energy(amount: int, _source_relic_id: StringName, event_id: StringName) -> bool:
		energy_restored += amount
		event_ids.append(event_id)
		return true

	func restore_health(amount: int, _source_relic_id: StringName, event_id: StringName) -> bool:
		health_restored += amount
		event_ids.append(event_id)
		return true

	func apply_temporary_attack_multiplier(
			_multiplier: float,
			_duration_seconds: float,
			_source_relic_id: StringName,
			event_id: StringName
	) -> bool:
		temporary_attack_calls += 1
		event_ids.append(event_id)
		return true

	func increase_maximum_health(amount: int, _source_relic_id: StringName) -> bool:
		maximum_health_added += amount
		return true

	func increase_maximum_energy(amount: int, _source_relic_id: StringName) -> bool:
		maximum_energy_added += amount
		return true


class FakeRuntimeLoadoutPort:
	extends RuntimeLoadoutPort

	var current: RuntimeLoadoutSnapshot
	var fail_validation: bool = false
	var fail_commit: bool = false
	var commit_count: int = 0

	func _init(initial: RuntimeLoadoutSnapshot) -> void:
		current = initial

	func snapshot() -> RuntimeLoadoutSnapshot:
		return current

	func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		if fail_validation:
			return RuntimeLoadoutChangeResult.rejected(&"test_validation_rejected", current)
		if candidate == null or candidate.revision != current.revision:
			return RuntimeLoadoutChangeResult.rejected(&"stale_loadout_revision", current)
		if candidate.entries.size() != current.entries.size():
			return RuntimeLoadoutChangeResult.rejected(&"slot_shape_changed", current)
		for existing in current.entries:
			if not candidate.has_slot(existing.slot_id):
				return RuntimeLoadoutChangeResult.rejected(&"slot_shape_changed", current)
		return RuntimeLoadoutChangeResult.success(candidate)

	func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		if fail_commit:
			return RuntimeLoadoutChangeResult.rejected(&"test_commit_rejected", current)
		var validation := validate_snapshot(candidate)
		if not validation.accepted:
			return validation
		current = RuntimeLoadoutSnapshot.new(candidate.entries, current.revision + 1)
		commit_count += 1
		return RuntimeLoadoutChangeResult.success(current)


var _failures: Array[String] = []
var _assertions: int = 0
var _tests: int = 0


func _initialize() -> void:
	_run("experience_below_threshold", _test_experience_below_threshold)
	_run("experience_exact_level", _test_experience_exact_level)
	_run("experience_crosses_multiple_levels", _test_experience_crosses_multiple_levels)
	_run("negative_experience_is_atomic", _test_negative_experience_is_atomic)
	_run("level_only_grants_unspent_points", _test_level_only_grants_unspent_points)
	_run("stat_allocation_preview_and_commit", _test_stat_allocation_preview_and_commit)
	_run("stat_draft_rejects_invalid_allocations", _test_stat_draft_rejects_invalid_allocations)
	_run("reward_generation_is_deterministic", _test_reward_generation_is_deterministic)
	_run("reward_filters_owned_and_duplicates", _test_reward_filters_owned_and_duplicates)
	_run("first_room_requires_three_candidates", _test_first_room_requires_three_candidates)
	_run("relic_reward_filters_owned", _test_relic_reward_filters_owned)
	_run("pending_reward_reopens_and_claims_once", _test_pending_reward_reopens_and_claims_once)
	_run("exhausted_skill_pool_removes_route", _test_exhausted_skill_pool_removes_route)
	_run("relic_cooldown_room_limit_and_identity", _test_relic_cooldown_room_limit_and_identity)
	_run("reaction_relic_threshold_and_temporary_attack", _test_reaction_relic_threshold_and_temporary_attack)
	_run("room_completion_and_acquire_relic_effects", _test_room_completion_and_acquire_relic_effects)
	_run("relic_runtime_isolated_across_sessions", _test_relic_runtime_isolated_across_sessions)
	_run("run_phase_legal_and_illegal_transitions", _test_run_phase_legal_and_illegal_transitions)
	_run("kill_and_room_experience_are_deduplicated", _test_kill_and_room_experience_are_deduplicated)
	_run("shop_confirm_commits_stats_and_loadout", _test_shop_confirm_commits_stats_and_loadout)
	_run("shop_failure_has_no_partial_commit", _test_shop_failure_has_no_partial_commit)
	_run("shop_draft_cannot_confirm_twice", _test_shop_draft_cannot_confirm_twice)
	_run("notifications_observe_complete_state", _test_notifications_observe_complete_state)
	_run("snapshot_collections_are_copied", _test_snapshot_collections_are_copied)
	_run("invalid_events_do_not_mutate_run", _test_invalid_events_do_not_mutate_run)

	if _failures.is_empty():
		print("GROWTH TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("GROWTH TESTS FAILED: %d/%d tests, %d assertions" % [_failures.size(), _tests, _assertions])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _run(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var previous_failures := _failures.size()
	test_callable.call()
	if _failures.size() == previous_failures:
		print("PASS: " + test_name)
	else:
		for index in range(previous_failures, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _test_experience_below_threshold() -> void:
	var state := ProgressionState.new()
	_expect(state.try_add_experience(99).accepted, "gain accepted")
	var current := state.snapshot()
	_expect_eq(current.level, 1, "level unchanged")
	_expect_eq(current.experience, 99, "experience retained")
	_expect_eq(current.unspent_stat_points, 0, "no stat point")


func _test_experience_exact_level() -> void:
	var state := ProgressionState.new()
	_expect(state.try_add_experience(100).accepted, "exact gain accepted")
	var current := state.snapshot()
	_expect_eq(current.level, 2, "leveled once")
	_expect_eq(current.experience, 0, "threshold consumed")
	_expect_eq(current.unspent_stat_points, 1, "one point granted")


func _test_experience_crosses_multiple_levels() -> void:
	var state := ProgressionState.new()
	_expect(state.try_add_experience(460).accepted, "large gain accepted")
	var current := state.snapshot()
	_expect_eq(current.level, 4, "three levels gained")
	_expect_eq(current.experience, 10, "remainder retained")
	_expect_eq(current.unspent_stat_points, 3, "one point per level")
	_expect_eq(current.experience_required_for_next_level, 250, "next requirement follows curve")


func _test_negative_experience_is_atomic() -> void:
	var state := ProgressionState.new()
	state.try_add_experience(40)
	var before := state.snapshot()
	var rejected := state.try_add_experience(-1)
	var after := state.snapshot()
	_expect(not rejected.accepted, "negative gain rejected")
	_expect_eq(rejected.reject_reason, RunCommandResult.RejectReason.NEGATIVE_EXPERIENCE, "typed reason")
	_expect_eq(after.experience, before.experience, "experience unchanged")
	_expect_eq(after.revision, before.revision, "revision unchanged")


func _test_level_only_grants_unspent_points() -> void:
	var state := ProgressionState.new()
	state.try_add_experience(460)
	var current := state.snapshot()
	_expect_eq(current.allocated_stats.total_points, 0, "level does not allocate stats")
	_expect_float(current.allocated_stats.attack_multiplier, 1.0, "attack unchanged")
	_expect_eq(current.allocated_stats.maximum_health_bonus, 0, "health unchanged")
	_expect_eq(current.allocated_stats.maximum_energy_bonus, 0, "energy unchanged")


func _test_stat_allocation_preview_and_commit() -> void:
	var state := ProgressionState.new()
	state.try_add_experience(460)
	var empty_loadout := RuntimeLoadoutSnapshot.new()
	var draft := ShopDraft.new(7, state.snapshot(), empty_loadout)
	_expect(draft.try_allocate(GrowthStatIds.ATTACK, 1).accepted, "attack allocation accepted")
	_expect(draft.try_allocate(GrowthStatIds.VITALITY, 1).accepted, "vitality allocation accepted")
	_expect(draft.try_allocate(GrowthStatIds.ENERGY, 1).accepted, "energy allocation accepted")
	var preview := draft.preview_progression()
	_expect_float(preview.allocated_stats.attack_multiplier, 1.05, "attack effect preview")
	_expect_eq(preview.allocated_stats.maximum_health_bonus, 10, "vitality effect preview")
	_expect_eq(preview.allocated_stats.maximum_energy_bonus, 5, "energy effect preview")
	_expect(state.commit_allocation(draft.pending_allocation()).accepted, "allocation commits")
	_expect_eq(state.snapshot().unspent_stat_points, 0, "points consumed")


func _test_stat_draft_rejects_invalid_allocations() -> void:
	var state := ProgressionState.new()
	state.try_add_experience(100)
	var draft := ShopDraft.new(0, state.snapshot(), RuntimeLoadoutSnapshot.new())
	_expect_eq(
		draft.try_allocate(&"luck", 1).reject_reason,
		RunCommandResult.RejectReason.UNKNOWN_STAT,
		"unknown stat rejected"
	)
	_expect_eq(
		draft.try_allocate(GrowthStatIds.ATTACK, -1).reject_reason,
		RunCommandResult.RejectReason.NEGATIVE_ALLOCATION,
		"negative allocation rejected"
	)
	_expect_eq(
		draft.try_allocate(GrowthStatIds.ATTACK, 2).reject_reason,
		RunCommandResult.RejectReason.INSUFFICIENT_STAT_POINTS,
		"over allocation rejected"
	)
	_expect_eq(draft.pending_allocation().total_points, 0, "failed operations do not change draft")


func _test_reward_generation_is_deterministic() -> void:
	var catalog := _make_skill_catalog(6)
	var run := _make_snapshot([], [])
	var context := RoomRewardContext.new(&"room_1", RewardType.SKILL, true)
	var first := RewardGenerator.generate(run, context, 4123, catalog, _make_relic_catalog())
	var second := RewardGenerator.generate(run, context, 4123, catalog, _make_relic_catalog())
	_expect(first.valid and second.valid, "offers valid")
	_expect_eq(first.offer_id, second.offer_id, "same seed produces stable offer id")
	_expect_eq(_option_content(first), _option_content(second), "same seed produces same options")


func _test_reward_filters_owned_and_duplicates() -> void:
	var catalog := _make_skill_catalog(7)
	var owned: Array[StringName] = [&"skill_0", &"skill_1"]
	var run := _make_snapshot(owned, [])
	var offer := RewardGenerator.generate(
		run,
		RoomRewardContext.new(&"room_2", RewardType.SKILL),
		99,
		catalog,
		_make_relic_catalog()
	)
	_expect(offer.valid, "offer valid")
	_expect(not offer.contains_content(&"skill_0") and not offer.contains_content(&"skill_1"), "owned skills filtered")
	_expect(offer.has_unique_content(), "offer has no duplicate content")
	_expect(offer.options.size() <= 3, "at most three options")


func _test_first_room_requires_three_candidates() -> void:
	var catalog := _make_skill_catalog(2)
	var offer := RewardGenerator.generate(
		_make_snapshot([], []),
		RoomRewardContext.new(&"room_1", RewardType.SKILL, true),
		1,
		catalog,
		_make_relic_catalog()
	)
	_expect(not offer.valid, "short initial pool fails")
	_expect_eq(offer.configuration_error, &"insufficient_initial_skill_candidates", "explicit config error")


func _test_relic_reward_filters_owned() -> void:
	var owned: Array[StringName] = [&"relic_form"]
	var offer := RewardGenerator.generate(
		_make_snapshot([], owned),
		RoomRewardContext.new(&"room_2", RewardType.RELIC),
		10,
		_make_skill_catalog(4),
		_make_relic_catalog()
	)
	_expect(offer.valid, "relic offer valid")
	_expect(not offer.contains_content(&"relic_form"), "owned relic filtered")
	_expect(offer.has_unique_content(), "relic options unique")


func _test_pending_reward_reopens_and_claims_once() -> void:
	var session := _make_session()
	_expect(session.begin_combat_room(&"room_1").accepted, "room begins")
	_expect(session.handle_event(RoomCompletedEvent.new(&"room_done_1", &"room_1", 0)).accepted, "room completes")
	var context := RoomRewardContext.new(&"room_1", RewardType.SKILL, true)
	var first := session.generate_reward(context, 100)
	var reopened := session.generate_reward(context, 999)
	_expect(first.accepted and reopened.accepted, "open and reopen accepted")
	_expect_eq(first.reward_offer.offer_id, reopened.reward_offer.offer_id, "reopen does not reroll")
	var option := first.reward_offer.options[0]
	_expect(session.claim_reward(first.reward_offer.offer_id, option.option_id).accepted, "first claim accepted")
	var repeated := session.claim_reward(first.reward_offer.offer_id, option.option_id)
	_expect(not repeated.accepted, "second claim rejected")
	_expect_eq(session.snapshot().skills.size(), 2, "skill added exactly once")


func _test_exhausted_skill_pool_removes_route() -> void:
	var owned: Array[StringName] = [&"skill_0", &"skill_1", &"skill_2"]
	var run := _make_snapshot(owned, [])
	_expect(not RewardGenerator.has_legal_skill_candidate(run, _make_skill_catalog(3)), "no skill candidate remains")
	var director := RunDirector.new()
	director.begin_combat_room(&"room_1")
	director.commit_room_completion(&"room_1")
	_expect(director.commit_reward_claim(false, true).accepted, "relic-only route accepted")
	var options := director.snapshot().next_options
	_expect_eq(options.size(), 1, "only one route shown")
	_expect_eq(options[0].reward_type, RewardType.RELIC, "skill route omitted")


func _test_relic_cooldown_room_limit_and_identity() -> void:
	var definition := _make_relic(
		&"switch_battery",
		RelicDefinition.EffectKind.FORM_SWITCH_ENERGY_RESTORE,
		5,
		2.0,
		1
	)
	var port := RecordingEffectPort.new()
	var controller := RelicController.new(port)
	controller.register_owned_relic(definition)
	var first := FormChangedEvent.new(&"form_1", &"room_a", &"water", &"fire", FormChangedEvent.Source.MANUAL, 1, 1000)
	_expect(controller.handle_event(first).accepted, "first event accepted")
	_expect_eq(port.energy_restored, 5, "first switch restores")
	_expect(controller.handle_event(first).accepted and port.energy_restored == 5, "relic layer trusts upstream identity while cooldown still blocks repeat")
	controller.advance(2.0)
	controller.handle_event(FormChangedEvent.new(&"form_2", &"room_a", &"fire", &"water", FormChangedEvent.Source.MANUAL, 2, 1100))
	_expect_eq(port.energy_restored, 5, "per-room limit enforced")
	controller.handle_event(FormChangedEvent.new(&"form_3", &"room_b", &"water", &"fire", FormChangedEvent.Source.MANUAL, 3, 1200))
	_expect_eq(port.energy_restored, 10, "new room resets limit")


func _test_reaction_relic_threshold_and_temporary_attack() -> void:
	var energy_relic := _make_relic(&"reaction_cell", RelicDefinition.EffectKind.REACTION_ENERGY_RESTORE, 4)
	energy_relic.reaction_threshold = 2
	var attack_relic := _make_relic(&"reaction_fury", RelicDefinition.EffectKind.REACTION_TEMPORARY_ATTACK, 0)
	attack_relic.reaction_threshold = 1
	attack_relic.attack_multiplier = 1.2
	attack_relic.duration_seconds = 3.0
	var port := RecordingEffectPort.new()
	var controller := RelicController.new(port)
	controller.register_owned_relic(energy_relic)
	controller.register_owned_relic(attack_relic)
	controller.handle_event(_combat_event(&"hit_1", &"room_a", 1))
	_expect_eq(port.energy_restored, 0, "below energy threshold")
	_expect_eq(port.temporary_attack_calls, 1, "temporary attack triggered")
	controller.handle_event(_combat_event(&"hit_2", &"room_a", 2))
	_expect_eq(port.energy_restored, 4, "energy threshold triggered")


func _test_room_completion_and_acquire_relic_effects() -> void:
	var heal := _make_relic(&"room_heal", RelicDefinition.EffectKind.ROOM_COMPLETE_HEAL, 7)
	var health := _make_relic(&"health_core", RelicDefinition.EffectKind.ACQUIRE_MAXIMUM_HEALTH, 20)
	var port := RecordingEffectPort.new()
	var controller := RelicController.new(port)
	controller.register_owned_relic(heal)
	controller.register_owned_relic(health)
	controller.handle_event(RoomCompletedEvent.new(&"done", &"room_a", 0))
	controller.handle_event(RelicAcquiredEvent.new(&"acquired", &"room_a", &"health_core"))
	_expect_eq(port.health_restored, 7, "room heal invoked")
	_expect_eq(port.maximum_health_added, 20, "acquisition maximum health invoked")


func _test_relic_runtime_isolated_across_sessions() -> void:
	var shared := _make_relic(&"shared", RelicDefinition.EffectKind.FORM_SWITCH_ENERGY_RESTORE, 3, 5.0)
	var catalog: Array[RelicDefinition] = [shared]
	var first_inventory := RelicInventoryState.new(catalog)
	var second_inventory := RelicInventoryState.new(catalog)
	first_inventory.try_add(shared.relic_id)
	second_inventory.try_add(shared.relic_id)
	var first := RelicController.new(RecordingEffectPort.new())
	var second := RelicController.new(RecordingEffectPort.new())
	first.register_owned_relic(shared)
	second.register_owned_relic(shared)
	first.handle_event(FormChangedEvent.new(&"first", &"room", &"water", &"fire", FormChangedEvent.Source.MANUAL, 1, 1000))
	var first_state := first.snapshot(first_inventory).display_state_for(shared.relic_id)
	var second_state := second.snapshot(second_inventory).display_state_for(shared.relic_id)
	_expect_float(first_state.cooldown_remaining, 5.0, "first runtime enters cooldown")
	_expect_float(second_state.cooldown_remaining, 0.0, "second runtime unaffected")
	_expect_float(shared.internal_cooldown_seconds, 5.0, "shared Resource remains static")


func _test_run_phase_legal_and_illegal_transitions() -> void:
	var direct := RouteState.new()
	_expect(not direct.try_transition(RunPhase.SHOP).accepted, "combat cannot jump to shop")
	_expect_eq(direct.phase, RunPhase.COMBAT, "illegal transition preserves phase")
	_expect(direct.try_transition(RunPhase.REWARD).accepted, "combat to reward")
	_expect(direct.try_transition(RunPhase.ROUTE_CHOICE).accepted, "reward to route")
	_expect(direct.try_transition(RunPhase.COMBAT).accepted, "route to combat")
	var shop_path := RouteState.new()
	shop_path.try_transition(RunPhase.REWARD)
	shop_path.try_transition(RunPhase.ROUTE_CHOICE)
	_expect(shop_path.try_transition(RunPhase.SHOP).accepted, "route to shop")
	_expect(shop_path.try_transition(RunPhase.RUN_COMPLETE).accepted, "shop to complete")
	_expect(not shop_path.try_transition(RunPhase.COMBAT).accepted, "complete is terminal")


func _test_kill_and_room_experience_are_deduplicated() -> void:
	var session := _make_session()
	session.begin_combat_room(&"room_1")
	var kill := EnemyKilledEvent.new(&"kill_event", &"room_1", &"enemy_1", 60)
	_expect(session.handle_event(kill).accepted, "kill accepted")
	_expect(not session.handle_event(kill).accepted, "same kill event rejected")
	var alias := EnemyKilledEvent.new(&"kill_alias", &"room_1", &"enemy_1", 60)
	_expect(not session.handle_event(alias).accepted, "same enemy identity rejected")
	var room := RoomCompletedEvent.new(&"room_event", &"room_1", 40)
	_expect(session.handle_event(room).accepted, "room experience accepted")
	_expect(not session.handle_event(room).accepted, "room completion repeated rejected")
	_expect_eq(session.snapshot().progression.level, 2, "experience granted once per identity")
	_expect_eq(session.snapshot().progression.experience, 0, "exact combined threshold")


func _test_shop_confirm_commits_stats_and_loadout() -> void:
	var port := _make_loadout_port()
	var session := _make_session(port)
	_reach_first_shop(session)
	var opened := session.open_shop_draft()
	_expect(opened.accepted, "shop draft opens")
	var draft := opened.draft
	var owned := session.snapshot().skills.owned_skill_ids
	var replacement := owned[owned.size() - 1]
	_expect(draft.try_allocate(GrowthStatIds.VITALITY, 1).accepted, "stat drafted")
	_expect(draft.try_assign_slot(&"active_1", replacement).accepted, "loadout drafted")
	var committed := session.confirm_shop(draft)
	_expect(committed.accepted, "shop transaction commits")
	_expect_eq(committed.run_snapshot.progression.allocated_stats.vitality_points, 1, "stat committed")
	_expect_eq(port.snapshot().get_skill_id(&"active_1"), replacement, "loadout committed")
	_expect_eq(port.commit_count, 1, "loadout replaced once")
	_expect_eq(committed.run_snapshot.route.phase, RunPhase.COMBAT, "shop exits after full commit")


func _test_shop_failure_has_no_partial_commit() -> void:
	var port := _make_loadout_port()
	var session := _make_session(port)
	_reach_first_shop(session)
	var draft := session.open_shop_draft().draft
	var before := session.snapshot()
	var owned := before.skills.owned_skill_ids
	draft.try_allocate(GrowthStatIds.ATTACK, 1)
	draft.try_assign_slot(&"active_1", owned[owned.size() - 1])
	port.fail_validation = true
	var rejected := session.confirm_shop(draft)
	var after := session.snapshot()
	_expect(not rejected.accepted, "loadout validation failure rejects transaction")
	_expect_eq(after.progression.allocated_stats.attack_points, before.progression.allocated_stats.attack_points, "stats unchanged")
	_expect(after.loadout.same_mapping(before.loadout), "loadout unchanged")
	_expect_eq(after.route.phase, RunPhase.SHOP, "phase unchanged")
	_expect(not draft.confirmed, "draft remains editable")


func _test_shop_draft_cannot_confirm_twice() -> void:
	var session := _make_session(_make_loadout_port())
	_reach_first_shop(session)
	var draft := session.open_shop_draft().draft
	draft.try_allocate(GrowthStatIds.ENERGY, 1)
	_expect(session.confirm_shop(draft).accepted, "first confirmation accepted")
	var second := session.confirm_shop(draft)
	_expect(not second.accepted, "second confirmation rejected")
	_expect_eq(session.snapshot().progression.allocated_stats.energy_points, 1, "allocation applied once")


func _test_notifications_observe_complete_state() -> void:
	var session := _make_session()
	var observed: Array[RunSnapshot] = []
	session.snapshot_changed.connect(func(current: RunSnapshot, _cause: StringName) -> void:
		observed.append(current)
	)
	session.begin_combat_room(&"room_1")
	observed.clear()
	session.handle_event(RoomCompletedEvent.new(&"done", &"room_1", 100))
	_expect_eq(observed.size(), 1, "one aggregate notification")
	_expect_eq(observed[0].route.phase, RunPhase.REWARD, "observer sees committed phase")
	_expect_eq(observed[0].progression.level, 2, "observer sees committed experience")
	_expect_eq(observed[0].progression.unspent_stat_points, 1, "observer sees committed stat point")


func _test_snapshot_collections_are_copied() -> void:
	var port := _make_loadout_port()
	var session := _make_session(port)
	var before := session.snapshot()
	var skills := before.skills.owned_skill_ids
	skills.append(&"injected")
	var entries := before.loadout.entries
	entries.clear()
	var forms := before.unlocked_form_ids
	forms.clear()
	var after := session.snapshot()
	_expect(not after.skills.owns(&"injected"), "skill collection copy protects state")
	_expect_eq(after.loadout.entries.size(), 1, "loadout collection copy protects state")
	_expect_eq(after.unlocked_form_ids.size(), 2, "form collection copy protects state")


func _test_invalid_events_do_not_mutate_run() -> void:
	var session := _make_session()
	session.begin_combat_room(&"room_1")
	var before := session.snapshot()
	var wrong_room := EnemyKilledEvent.new(&"kill", &"room_2", &"enemy", 100)
	var result := session.handle_event(wrong_room)
	var after := session.snapshot()
	_expect(not result.accepted, "wrong-room event rejected")
	_expect_eq(after.revision, before.revision, "run revision unchanged")
	_expect_eq(after.progression.experience, before.progression.experience, "experience unchanged")


func _make_snapshot(
		owned_skills: Array[StringName],
		owned_relics: Array[StringName]
) -> RunSnapshot:
	var forms: Array[StringName] = [&"water", &"fire"]
	return RunSnapshot.new(
		ProgressionSnapshot.new(),
		SkillInventorySnapshot.new(owned_skills),
		RelicInventorySnapshot.new(owned_relics),
		RuntimeLoadoutSnapshot.new(),
		RouteSnapshot.new(),
		null,
		false,
		forms
	)


func _make_session(loadout_port: RuntimeLoadoutPort = null) -> RunSession:
	var initial: Array[StringName] = [&"initial_bolt"]
	var forms: Array[StringName] = [&"water", &"fire"]
	return RunSession.new(
		_make_skill_catalog(8),
		_make_relic_catalog(),
		initial,
		forms,
		loadout_port,
		RecordingEffectPort.new()
	)


func _make_skill_catalog(count: int) -> Array[SkillRewardDefinition]:
	var definitions: Array[SkillRewardDefinition] = []
	var forms: Array[StringName] = [&"water", &"fire"]
	for index in count:
		var definition := SkillRewardDefinition.new()
		definition.skill_id = StringName("skill_%d" % index)
		definition.display_name = "Skill %d" % index
		definition.description = "Test skill"
		definition.initial_pool = true
		definition.allowed_form_ids = forms.duplicate()
		definitions.append(definition)
	return definitions


func _make_relic_catalog() -> Array[RelicDefinition]:
	var definitions: Array[RelicDefinition] = []
	definitions.append(_make_relic(&"relic_form", RelicDefinition.EffectKind.FORM_SWITCH_ENERGY_RESTORE, 3))
	definitions.append(_make_relic(&"relic_heal", RelicDefinition.EffectKind.ROOM_COMPLETE_HEAL, 5))
	var reaction := _make_relic(&"relic_reaction", RelicDefinition.EffectKind.REACTION_ENERGY_RESTORE, 2)
	reaction.reaction_threshold = 1
	definitions.append(reaction)
	return definitions


func _make_relic(
		relic_id: StringName,
		effect_kind: RelicDefinition.EffectKind,
		amount: int,
		cooldown: float = 0.0,
		per_room_limit: int = 0
) -> RelicDefinition:
	var definition := RelicDefinition.new()
	definition.relic_id = relic_id
	definition.display_name = String(relic_id)
	definition.description = "Test relic"
	definition.effect_kind = effect_kind
	definition.amount = amount
	definition.internal_cooldown_seconds = cooldown
	definition.per_room_limit = per_room_limit
	return definition


func _make_loadout_port() -> FakeRuntimeLoadoutPort:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(&"active_1", &"initial_bolt"),
	]
	return FakeRuntimeLoadoutPort.new(RuntimeLoadoutSnapshot.new(entries, 1))


func _reach_first_shop(session: RunSession) -> void:
	for room_number in range(1, 4):
		var room_id := StringName("shop_path_room_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "shop path room begins")
		var done_id := StringName("shop_path_done_%d" % room_number)
		_expect(session.handle_event(RoomCompletedEvent.new(done_id, room_id, 100)).accepted, "shop path room completes")
		var context := RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1)
		var generated := session.generate_reward(context, 1000 + room_number)
		_expect(generated.accepted, "shop path reward generated")
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "shop path reward claimed")
		if room_number < 3:
			_expect(session.choose_route(RunDirector.SKILL_ROUTE_ID).accepted, "shop path skill route chosen")
		else:
			_expect(session.choose_route(RunDirector.SHOP_ROUTE_ID).accepted, "shop path shop chosen")


func _combat_event(event_id: StringName, room_id: StringName, reaction_consumed: int) -> CombatCommittedEvent:
	return CombatCommittedEvent.new(
		event_id,
		room_id,
		1,
		1,
		0,
		&"target",
		&"skill",
		&"water",
		10,
		reaction_consumed,
		50
	)


func _option_content(offer: RewardOffer) -> Array[StringName]:
	var ids: Array[StringName] = []
	for option in offer.options:
		ids.append(option.content_id)
	return ids


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertions += 1
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected=%s, actual=%s)" % [message, expected, actual])

