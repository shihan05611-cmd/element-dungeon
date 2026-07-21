extends SceneTree

## Dependency-free Agent B test entry point:
## Godot --headless --path <project> --script res://combat/tests/run_skill_tests.gd

const SLOT_PRIMARY: StringName = &"primary"
const DELIVERY_SCENE: PackedScene = preload("res://combat/tests/recording_skill_delivery.tscn")

var _failures: Array[String] = []
var _assertions: int = 0
var _tests: int = 0
var _next_identity: int = 1000


func _initialize() -> void:
	call_deferred(&"_run_all_tests")


func _run_all_tests() -> void:
	_run("static_configuration_validation", _test_static_configuration_validation)
	_run("universal_skill_locks_water_form", _test_universal_skill_locks_water_form)
	_run("universal_skill_locks_fire_form", _test_universal_skill_locks_fire_form)
	_run("exclusive_skill_rejects_wrong_form_without_cost", _test_exclusive_skill_rejects_wrong_form_without_cost)
	_run("accepted_transaction_is_complete_before_notifications", _test_accepted_transaction_is_complete_before_notifications)
	_run("insufficient_energy_has_no_partial_state", _test_insufficient_energy_has_no_partial_state)
	_run("cooldown_rejection_has_no_partial_state", _test_cooldown_rejection_has_no_partial_state)
	_run("zero_cooldown_recasts_after_recovery", _test_zero_cooldown_recasts_after_recovery)
	_run("startup_cancel_does_not_refund", _test_startup_cancel_does_not_refund)
	_run("acceptance_callback_cancel_is_deferred", _test_acceptance_callback_cancel_is_deferred)
	_run("active_delivery_survives_cancel_and_switch", _test_active_delivery_survives_cancel_and_switch)
	_run("switch_during_cast_only_affects_next", _test_switch_during_cast_only_affects_next)
	_run("large_delta_crosses_every_phase_once", _test_large_delta_crosses_every_phase_once)
	_run("advance_reentry_is_rejected", _test_advance_reentry_is_rejected)
	_run("recovery_cancel_does_not_reclose_window", _test_recovery_cancel_does_not_reclose_window)
	_run("resource_mutation_cannot_change_cast", _test_resource_mutation_cannot_change_cast)
	_run("late_token_cannot_affect_new_cast", _test_late_token_cannot_affect_new_cast)
	_run("pause_and_exit_cancel_deterministically", _test_pause_and_exit_cancel_deterministically)
	_run("external_gate_has_no_side_effects", _test_external_gate_has_no_side_effects)
	_run("preflight_callback_reentry_is_rejected", _test_preflight_callback_reentry_is_rejected)
	_run("invalid_configuration_has_no_side_effects", _test_invalid_configuration_has_no_side_effects)
	_run("form_loadouts_are_independent", _test_form_loadouts_are_independent)
	_run("component_notifications_are_post_commit", _test_component_notifications_are_post_commit)
	_run("energy_regenerates_at_default_rate_and_pauses", _test_energy_regenerates_at_default_rate_and_pauses)
	_run("shared_resources_keep_runtime_isolated", _test_shared_resources_keep_runtime_isolated)

	if _failures.is_empty():
		print("SKILL TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("SKILL TESTS FAILED: %d/%d tests, %d assertions" % [_failures.size(), _tests, _assertions])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _run(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var failure_count := _failures.size()
	test_callable.call()
	if _failures.size() == failure_count:
		print("PASS " + test_name)
	else:
		for index in range(failure_count, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (expected %s, got %s)" % [message, expected, actual])


func _make_skill(
		skill_id: StringName = &"element_bolt",
		energy_cost: int = 10,
		cooldown: float = 0.0,
		startup: float = 0.1,
		active: float = 0.2,
		recovery: float = 0.3,
		required_form: StringName = ElementIds.NONE
) -> SkillDefinition:
	var payload := AttackPayloadDefinition.new()
	payload.base_damage = 10.0
	payload.element_mode = AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
	payload.element_amount = 3
	var skill := SkillDefinition.new()
	skill.skill_id = skill_id
	skill.energy_cost = energy_cost
	skill.cooldown = cooldown
	skill.startup_time = startup
	skill.active_time = active
	skill.recovery_time = recovery
	skill.delivery_scene = DELIVERY_SCENE
	skill.payload = payload
	if required_form != ElementIds.NONE:
		skill.form_policy = SkillDefinition.FormPolicy.REQUIRED_FORM
		skill.required_form_id = required_form
	return skill


func _make_loadout(form_id: StringName, skill: SkillDefinition) -> SkillLoadout:
	var loadout := SkillLoadout.new()
	loadout.form_element_id = form_id
	loadout.slots[SLOT_PRIMARY] = skill
	return loadout


func _make_rig(
		starting_energy: int = 100,
		form_id: StringName = ElementIds.WATER,
		shared_skill: SkillDefinition = null
) -> Dictionary:
	_next_identity += 10
	var host := Node2D.new()
	var delivery_parent := Node2D.new()
	root.add_child(host)
	root.add_child(delivery_parent)

	var energy := EnergyComponent.new()
	energy.configure_runtime(100, starting_energy)
	host.add_child(energy)
	var form := ElementFormController.new()
	form.configure_runtime(form_id)
	host.add_child(form)
	var executor := SkillExecutor.new()
	executor.configure_dependencies(energy, form, delivery_parent)
	executor.configure_cast_identity(_next_identity, _next_identity + 1, &"player")
	executor.set_stat_snapshot_provider(
		func(_skill: SkillDefinition) -> CombatStatSnapshot:
			return CombatStatSnapshot.new(1.5, 2.0)
	)
	executor.set_spawn_snapshot_provider(
		func(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
			return DeliverySpawnSnapshot.new(
				Transform2D(0.0, Vector2(12.0, 34.0)),
				Vector2.LEFT
			)
	)
	host.add_child(executor)
	executor.set_process(false)

	var skill := shared_skill if shared_skill != null else _make_skill()
	var controller := SkillController.new()
	controller.configure_runtime(
		form,
		executor,
		_make_loadout(ElementIds.WATER, skill),
		_make_loadout(ElementIds.FIRE, skill)
	)
	host.add_child(controller)
	return {
		"host": host,
		"delivery_parent": delivery_parent,
		"energy": energy,
		"form": form,
		"executor": executor,
		"controller": controller,
		"skill": skill,
	}


func _free_rig(rig: Dictionary) -> void:
	var host: Node = rig.host
	var delivery_parent: Node = rig.delivery_parent
	if is_instance_valid(host):
		host.free()
	if is_instance_valid(delivery_parent):
		delivery_parent.free()


func _finish_cast(executor: SkillExecutor) -> void:
	executor.advance(10.0)


func _get_only_delivery(rig: Dictionary) -> RecordingSkillDelivery:
	var delivery_parent: Node = rig.delivery_parent
	if delivery_parent.get_child_count() != 1:
		return null
	return delivery_parent.get_child(0) as RecordingSkillDelivery


func _test_static_configuration_validation() -> void:
	var universal := _make_skill()
	_expect(universal.is_valid(), "valid universal skill passes")
	_expect(_make_loadout(ElementIds.WATER, universal).is_valid(), "water loadout accepts universal")
	_expect(_make_loadout(ElementIds.FIRE, universal).is_valid(), "fire loadout accepts universal")
	var neutral := _make_skill(&"neutral_slash")
	neutral.payload.element_mode = AttackPayloadDefinition.ElementMode.NONE
	neutral.payload.element_amount = 0
	_expect(neutral.is_valid(), "neutral universal skill passes")
	_expect(_make_loadout(ElementIds.WATER, neutral).is_valid(), "water loadout accepts neutral universal")
	_expect(_make_loadout(ElementIds.FIRE, neutral).is_valid(), "fire loadout accepts neutral universal")
	var exclusive := _make_skill(&"water_only", 10, 0.0, 0.1, 0.2, 0.3, ElementIds.WATER)
	_expect(_make_loadout(ElementIds.WATER, exclusive).is_valid(), "water loadout accepts water skill")
	_expect(not _make_loadout(ElementIds.FIRE, exclusive).is_valid(), "fire loadout rejects water skill")
	var invalid := _make_skill()
	invalid.payload.element_amount = -1
	_expect(not invalid.is_valid(), "invalid payload invalidates skill")


func _test_universal_skill_locks_water_form() -> void:
	var rig := _make_rig(100, ElementIds.WATER)
	var result: CastAttemptResult = rig.controller.try_cast_slot(SLOT_PRIMARY)
	_expect(result.accepted, "water cast accepted")
	_expect_eq(result.cast_snapshot.cast_element_id, ElementIds.WATER, "cast locks water")
	_expect_eq(result.payload.element_id, ElementIds.WATER, "payload locks water")
	_free_rig(rig)


func _test_universal_skill_locks_fire_form() -> void:
	var rig := _make_rig(100, ElementIds.FIRE)
	var result: CastAttemptResult = rig.controller.try_cast_slot(SLOT_PRIMARY)
	_expect(result.accepted, "fire cast accepted")
	_expect_eq(result.cast_snapshot.cast_element_id, ElementIds.FIRE, "cast locks fire")
	_expect_eq(result.payload.element_id, ElementIds.FIRE, "payload locks fire")
	_free_rig(rig)


func _test_exclusive_skill_rejects_wrong_form_without_cost() -> void:
	var skill := _make_skill(&"water_only", 25, 3.0, 0.1, 0.2, 0.3, ElementIds.WATER)
	var rig := _make_rig(100, ElementIds.FIRE, skill)
	var result: CastAttemptResult = rig.executor.try_cast(skill)
	_expect(not result.accepted, "wrong-form skill rejected")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.FORM_MISMATCH, "structured form reason")
	_expect_eq(rig.energy.current_energy, 100, "wrong form spends no energy")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 0.0, "wrong form starts no cooldown")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "wrong form creates no cast")
	_free_rig(rig)


func _test_accepted_transaction_is_complete_before_notifications() -> void:
	var skill := _make_skill(&"special", 20, 5.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	var observed := {"complete": false, "delta": 0}
	rig.energy.energy_changed.connect(func(current: int, _maximum: int, delta: int) -> void:
		observed.complete = (
			current == 80
			and rig.executor.current_phase == SkillExecutor.Phase.STARTUP
			and is_equal_approx(rig.executor.get_cooldown_remaining(skill.skill_id), 5.0)
			and rig.executor.current_cast_snapshot != null
		)
		observed.delta = delta
	)
	var result: CastAttemptResult = rig.executor.try_cast(skill)
	_expect(result.accepted, "transaction accepted")
	_expect(observed.complete, "observer sees complete accepted state")
	_expect_eq(observed.delta, -20, "energy notification has actual delta")
	_expect_eq(rig.energy.current_energy, 80, "energy spent exactly once")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 5.0, "cooldown starts immediately")
	_expect_float(result.payload.offensive_damage, 17.0, "attack stats lock at acceptance")
	_free_rig(rig)


func _test_insufficient_energy_has_no_partial_state() -> void:
	var skill := _make_skill(&"expensive", 60, 4.0)
	var rig := _make_rig(50, ElementIds.WATER, skill)
	var result: CastAttemptResult = rig.executor.try_cast(skill)
	_expect(not result.accepted, "insufficient cast rejected")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, "structured energy reason")
	_expect_eq(rig.energy.current_energy, 50, "rejection preserves energy")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 0.0, "rejection starts no cooldown")
	_expect(result.cast_snapshot == null and result.payload == null, "rejection returns no half cast")
	_free_rig(rig)


func _test_cooldown_rejection_has_no_partial_state() -> void:
	var skill := _make_skill(&"special", 10, 3.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	_expect(rig.executor.try_cast(skill).accepted, "first special cast accepted")
	rig.executor.advance(0.6)
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "cast timing completed")
	var energy_before: int = rig.energy.current_energy
	var remaining_before: float = rig.executor.get_cooldown_remaining(skill.skill_id)
	var rejected: CastAttemptResult = rig.executor.try_cast(skill)
	_expect_eq(rejected.reject_reason, CastAttemptResult.RejectReason.COOLDOWN_ACTIVE, "structured cooldown reason")
	_expect_eq(rig.energy.current_energy, energy_before, "cooldown rejection spends no energy")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), remaining_before, "timer is not restarted")
	_free_rig(rig)


func _test_zero_cooldown_recasts_after_recovery() -> void:
	var skill := _make_skill(&"regular", 10, 0.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	var first: CastAttemptResult = rig.executor.try_cast(skill)
	_finish_cast(rig.executor)
	var second: CastAttemptResult = rig.executor.try_cast(skill)
	_expect(first.accepted and second.accepted, "regular skill recasts after timing")
	_expect(first.cast_snapshot.cast_id != second.cast_snapshot.cast_id, "recast gets unique cast id")
	_expect_eq(rig.energy.current_energy, 80, "each accepted cast spends once")
	_free_rig(rig)


func _test_startup_cancel_does_not_refund() -> void:
	var skill := _make_skill(&"interruptible", 25, 5.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	var reasons: Array[StringName] = []
	rig.executor.cast_cancelled.connect(
		func(_cast: CastSnapshot, reason: StringName) -> void:
			reasons.append(reason)
	)
	var accepted: CastAttemptResult = rig.executor.try_cast(skill)
	_expect(rig.executor.cancel_current_cast(&"hit", accepted.cast_snapshot.cast_id), "startup cancel accepted")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "cancel returns idle")
	_expect_eq(rig.energy.current_energy, 75, "cancel does not refund")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 5.0, "cancel keeps cooldown")
	_expect_eq(reasons, [&"hit"], "cancel event occurs exactly once")
	_free_rig(rig)


func _test_acceptance_callback_cancel_is_deferred() -> void:
	var skill := _make_skill(&"callback_interrupt", 20, 5.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	var cancelled := {"count": 0}
	rig.executor.cast_started.connect(func(cast: CastSnapshot, _payload: RuntimeAttackPayload) -> void:
		rig.executor.cancel_current_cast(&"hit", cast.cast_id)
	)
	rig.executor.cast_cancelled.connect(func(_cast: CastSnapshot, reason: StringName) -> void:
		if reason == &"hit":
			cancelled.count += 1
	)
	var result: CastAttemptResult = rig.executor.try_cast(skill)
	_expect(result.accepted, "release transaction was accepted")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "queued callback cancellation returns idle")
	_expect_eq(cancelled.count, 1, "queued cancellation publishes exactly once")
	_expect_eq(rig.energy.current_energy, 80, "queued cancellation does not refund")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 5.0, "queued cancellation keeps cooldown")
	_free_rig(rig)


func _test_active_delivery_survives_cancel_and_switch() -> void:
	var rig := _make_rig(100, ElementIds.WATER)
	var accepted: CastAttemptResult = rig.executor.try_cast(rig.skill)
	rig.executor.advance(0.1)
	var delivery := _get_only_delivery(rig)
	_expect(delivery != null, "delivery generated at ACTIVE entry")
	_expect(delivery.initialized and not delivery.initialized_inside_tree, "delivery initialized before add_child")
	_expect(delivery.ready_after_initialize, "ready observes initialized data")
	_expect_eq(delivery.delivery_id, 1, "first delivery id is one")
	_expect_eq(delivery.cast_snapshot.cast_id, accepted.cast_snapshot.cast_id, "delivery receives cast")
	_expect_eq(delivery.payload.element_id, ElementIds.WATER, "delivery starts water")
	_expect_eq(delivery.global_position, Vector2(12.0, 34.0), "delivery receives transform")
	_expect_eq(delivery.direction, Vector2.LEFT, "delivery receives direction")
	rig.form.request_form(ElementIds.FIRE)
	_expect(rig.executor.cancel_current_cast(&"death", accepted.cast_snapshot.cast_id), "active cancel accepted")
	_expect(is_instance_valid(delivery) and delivery.is_inside_tree(), "delivery survives cancellation")
	_expect_eq(delivery.payload.element_id, ElementIds.WATER, "delivery is not recolored")
	_expect_eq(delivery.close_count, 1, "active hit window closes once")
	_free_rig(rig)


func _test_switch_during_cast_only_affects_next() -> void:
	var rig := _make_rig(100, ElementIds.WATER)
	var first: CastAttemptResult = rig.executor.try_cast(rig.skill)
	_expect(rig.form.request_form(ElementIds.FIRE), "form can switch during cast")
	_expect_eq(first.cast_snapshot.cast_element_id, ElementIds.WATER, "current cast stays water")
	_expect_eq(first.payload.element_id, ElementIds.WATER, "current payload stays water")
	_finish_cast(rig.executor)
	var second: CastAttemptResult = rig.executor.try_cast(rig.skill)
	_expect(second.accepted, "next cast accepted")
	_expect_eq(second.cast_snapshot.cast_element_id, ElementIds.FIRE, "next cast reads fire")
	_expect_eq(second.payload.element_id, ElementIds.FIRE, "next payload reads fire")
	_free_rig(rig)


func _test_large_delta_crosses_every_phase_once() -> void:
	var rig := _make_rig()
	var phases: Array[int] = []
	var deliveries: Array[int] = []
	var finished_count := {"value": 0}
	rig.executor.phase_changed.connect(
		func(_cast_id: int, _previous: int, current: int) -> void:
			phases.append(current)
	)
	rig.executor.delivery_spawned.connect(
		func(_cast_id: int, delivery_id: int, _delivery: Node) -> void:
			deliveries.append(delivery_id)
	)
	rig.executor.cast_finished.connect(
		func(_cast: CastSnapshot) -> void:
			finished_count.value += 1
	)
	_expect(rig.executor.try_cast(rig.skill).accepted, "cast accepted")
	_expect(rig.executor.advance(10.0), "large delta accepted")
	_expect_eq(
		phases,
		[
			SkillExecutor.Phase.STARTUP,
			SkillExecutor.Phase.ACTIVE,
			SkillExecutor.Phase.RECOVERY,
			SkillExecutor.Phase.IDLE,
		],
		"large delta preserves phase order"
	)
	_expect_eq(deliveries, [1], "large delta generates one delivery")
	_expect_eq(finished_count.value, 1, "finish event occurs once")
	var delivery := _get_only_delivery(rig)
	_expect(delivery != null and delivery.close_count == 1, "ACTIVE exit closes once")
	_free_rig(rig)


func _test_advance_reentry_is_rejected() -> void:
	var rig := _make_rig()
	var nested_result := {"called": 0, "accepted": true}
	rig.executor.phase_changed.connect(
		func(_cast_id: int, _previous: int, current: int) -> void:
			if current == SkillExecutor.Phase.ACTIVE:
				nested_result.called += 1
				nested_result.accepted = rig.executor.advance(10.0)
	)
	_expect(rig.executor.try_cast(rig.skill).accepted, "cast accepted")
	_expect(rig.executor.advance(10.0), "outer advance succeeds")
	_expect_eq(nested_result.called, 1, "ACTIVE entry occurs once")
	_expect(not nested_result.accepted, "nested advance is rejected")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "outer advance finishes cleanly")
	_expect_eq(rig.delivery_parent.get_child_count(), 1, "reentry cannot duplicate delivery")
	_free_rig(rig)


func _test_recovery_cancel_does_not_reclose_window() -> void:
	var rig := _make_rig()
	var accepted: CastAttemptResult = rig.executor.try_cast(rig.skill)
	rig.executor.advance(0.31)
	var delivery := _get_only_delivery(rig)
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.RECOVERY, "cast reached recovery")
	_expect(delivery != null and delivery.close_count == 1, "ACTIVE exit closed once")
	_expect(rig.executor.cancel_current_cast(&"death", accepted.cast_snapshot.cast_id), "recovery cancel accepted")
	_expect_eq(delivery.close_count, 1, "recovery cancel does not close a second time")
	_free_rig(rig)


func _test_resource_mutation_cannot_change_cast() -> void:
	var rig := _make_rig(100, ElementIds.WATER)
	var accepted: CastAttemptResult = rig.executor.try_cast(rig.skill)
	rig.skill.startup_time = 99.0
	rig.skill.active_time = 99.0
	rig.skill.recovery_time = 99.0
	rig.skill.payload.element_amount = 10
	_expect(rig.executor.advance(0.6), "locked timings advance")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "Resource edits do not extend cast")
	var delivery := _get_only_delivery(rig)
	_expect(delivery != null, "delivery still generated")
	_expect_eq(delivery.payload.element_amount, 3, "delivery payload ignores Resource mutation")
	_expect_eq(accepted.payload.element_amount, 3, "attempt payload remains immutable")
	_free_rig(rig)


func _test_late_token_cannot_affect_new_cast() -> void:
	var rig := _make_rig()
	var first: CastAttemptResult = rig.executor.try_cast(rig.skill)
	rig.executor.cancel_current_cast(&"hit", first.cast_snapshot.cast_id)
	var second: CastAttemptResult = rig.executor.try_cast(rig.skill)
	_expect(second.accepted, "second cast accepted")
	_expect(not rig.executor.cancel_current_cast(&"late_animation", first.cast_snapshot.cast_id), "old token cannot cancel")
	_expect(not rig.executor.notify_presentation_marker(first.cast_snapshot.cast_id, &"active"), "old marker rejected")
	_expect(rig.executor.notify_presentation_marker(second.cast_snapshot.cast_id, &"swing"), "current marker accepted")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.STARTUP, "marker cannot advance gameplay")
	_free_rig(rig)


func _test_pause_and_exit_cancel_deterministically() -> void:
	var paused_rig := _make_rig()
	var pause_cancelled := {"value": false}
	paused_rig.executor.cast_cancelled.connect(
		func(_cast: CastSnapshot, reason: StringName) -> void:
			pause_cancelled.value = reason == &"scene_tree_paused"
	)
	paused_rig.executor.try_cast(paused_rig.skill)
	_expect(paused_rig.executor.handle_pause(), "pause cancellation accepted")
	_expect(pause_cancelled.value and paused_rig.executor.current_phase == SkillExecutor.Phase.IDLE, "pause leaves no busy cast")
	_free_rig(paused_rig)

	var exit_rig := _make_rig()
	var exit_cancelled := {"value": false}
	exit_rig.executor.cast_cancelled.connect(
		func(_cast: CastSnapshot, reason: StringName) -> void:
			exit_cancelled.value = reason == &"caster_left_tree"
	)
	exit_rig.executor.try_cast(exit_rig.skill)
	var host: Node = exit_rig.host
	var executor: SkillExecutor = exit_rig.executor
	host.remove_child(executor)
	_expect(exit_cancelled.value, "leaving tree emits cancellation")
	_expect_eq(executor.current_phase, SkillExecutor.Phase.IDLE, "removed executor is idle")
	executor.free()
	_free_rig(exit_rig)


func _test_external_gate_has_no_side_effects() -> void:
	var skill := _make_skill(&"gated", 15, 2.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	rig.executor.set_external_action_gate(
		func(_skill: SkillDefinition) -> bool:
			return false
	)
	var result: CastAttemptResult = rig.executor.try_cast(skill)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.EXTERNAL_GATE_REJECTED, "structured gate reason")
	_expect_eq(rig.energy.current_energy, 100, "gate spends no energy")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 0.0, "gate starts no cooldown")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "gate creates no cast")
	_free_rig(rig)


func _test_preflight_callback_reentry_is_rejected() -> void:
	var skill := _make_skill(&"reentry_guarded", 20, 2.0)
	var rig := _make_rig(100, ElementIds.WATER, skill)
	var nested_result := {"value": null}
	var cast_starts := {"count": 0}
	rig.executor.cast_started.connect(
		func(_cast: CastSnapshot, _payload: RuntimeAttackPayload) -> void:
			cast_starts.count += 1
	)
	rig.executor.set_external_action_gate(
		func(_skill: SkillDefinition) -> bool:
			nested_result.value = rig.executor.try_cast(skill)
			return true
	)
	var outer_result: CastAttemptResult = rig.executor.try_cast(skill)
	var nested: CastAttemptResult = nested_result.value
	_expect(outer_result.accepted, "outer cast remains accepted")
	_expect(nested != null and not nested.accepted, "nested cast is rejected")
	_expect_eq(nested.reject_reason, CastAttemptResult.RejectReason.BUSY, "nested cast has structured busy reason")
	_expect_eq(rig.energy.current_energy, 80, "reentry cannot double-spend energy")
	_expect_float(rig.executor.get_cooldown_remaining(skill.skill_id), 2.0, "reentry cannot restart cooldown")
	_expect_eq(cast_starts.count, 1, "reentry publishes one cast")
	_free_rig(rig)


func _test_invalid_configuration_has_no_side_effects() -> void:
	var rig := _make_rig()
	var invalid := _make_skill(&"invalid")
	invalid.delivery_scene = null
	var result: CastAttemptResult = rig.executor.try_cast(invalid)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.INVALID_CONFIGURATION, "structured config reason")
	_expect_eq(result.detail, &"missing_delivery_scene", "config detail preserved")
	_expect_eq(rig.energy.current_energy, 100, "invalid config spends no energy")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "invalid config creates no cast")
	_free_rig(rig)


func _test_form_loadouts_are_independent() -> void:
	var rig := _make_rig()
	var water_skill := _make_skill(&"water_slot")
	var fire_skill := _make_skill(&"fire_slot")
	rig.controller.water_loadout = _make_loadout(ElementIds.WATER, water_skill)
	rig.controller.fire_loadout = _make_loadout(ElementIds.FIRE, fire_skill)
	_expect_eq(rig.controller.get_skill_for_slot(SLOT_PRIMARY).skill_id, &"water_slot", "water selects water mapping")
	rig.controller.request_form(ElementIds.FIRE)
	_expect_eq(rig.controller.get_skill_for_slot(SLOT_PRIMARY).skill_id, &"fire_slot", "fire selects own mapping")
	_expect(rig.controller.water_loadout.slots[SLOT_PRIMARY] != rig.controller.fire_loadout.slots[SLOT_PRIMARY], "slots are distinct")
	_free_rig(rig)


func _test_component_notifications_are_post_commit() -> void:
	var energy := EnergyComponent.new()
	var energy_observation := {"current": -1, "maximum": -1, "delta": 0}
	energy.energy_changed.connect(func(current: int, maximum: int, delta: int) -> void:
		energy_observation.current = current
		energy_observation.maximum = maximum
		energy_observation.delta = delta
	)
	energy.configure_runtime(50, 40)
	_expect(energy.try_spend(15), "energy spend accepted")
	_expect_eq(
		[energy_observation.current, energy_observation.maximum, energy_observation.delta],
		[25, 50, -15],
		"energy signal reports committed state"
	)
	_expect_eq(energy.current_energy, 25, "energy getter matches signal")

	var form := ElementFormController.new()
	var form_observation: Array[StringName] = []
	form.form_changed.connect(func(current: StringName, previous: StringName) -> void:
		form_observation.append(previous)
		form_observation.append(current)
	)
	_expect(form.request_form(ElementIds.FIRE), "valid form switch accepted")
	_expect_eq(form_observation, [ElementIds.WATER, ElementIds.FIRE], "form signal reports committed transition")
	_expect(not form.request_form(&"earth"), "unknown form rejected")
	_expect_eq(form.current_form_id, ElementIds.FIRE, "rejected form preserves state")
	energy.free()
	form.free()


func _test_energy_regenerates_at_default_rate_and_pauses() -> void:
	var energy := EnergyComponent.new()
	var observed_deltas: Array[int] = []
	energy.energy_changed.connect(
		func(_current: int, _maximum: int, delta: int) -> void:
			observed_deltas.append(delta)
	)
	energy.configure_runtime(100, 100)
	_expect_float(energy.regeneration_per_second, 5.0, "default recovery is five per second")
	_expect_float(energy.regeneration_delay_after_spend, 1.0, "spend delay defaults to one second")
	_expect(energy.try_spend(20), "energy spend starts recovery delay")
	_expect_eq(energy.advance_regeneration(0.75), 0, "recovery does not start during spend delay")
	energy.set_regeneration_paused(true)
	_expect(energy.regeneration_paused, "recovery pause is observable")
	_expect_eq(energy.advance_regeneration(10.0), 0, "paused recovery does not advance delay")
	energy.set_regeneration_paused(false)
	_expect_eq(energy.advance_regeneration(0.25), 0, "remaining delay resumes after pause")
	_expect_eq(energy.advance_regeneration(0.4), 2, "recovery grants five energy per second")
	_expect_eq(energy.advance_regeneration(0.1), 0, "fractional recovery is retained without early rounding")
	_expect_eq(energy.advance_regeneration(0.1), 1, "fractional recovery commits at a whole point")
	_expect_eq(energy.current_energy, 83, "recovery commits the expected total")
	_expect_eq(observed_deltas, [-20, 2, 1], "recovery notifications report committed integer deltas")
	energy.free()


func _test_shared_resources_keep_runtime_isolated() -> void:
	var shared_skill := _make_skill(&"shared_special", 20, 4.0)
	var shared_water_loadout := _make_loadout(ElementIds.WATER, shared_skill)
	var shared_fire_loadout := _make_loadout(ElementIds.FIRE, shared_skill)
	var first := _make_rig(100, ElementIds.WATER, shared_skill)
	var second := _make_rig(70, ElementIds.FIRE, shared_skill)
	first.controller.water_loadout = shared_water_loadout
	first.controller.fire_loadout = shared_fire_loadout
	second.controller.water_loadout = shared_water_loadout
	second.controller.fire_loadout = shared_fire_loadout
	var first_result: CastAttemptResult = first.controller.try_cast_slot(SLOT_PRIMARY)
	var second_result: CastAttemptResult = second.controller.try_cast_slot(SLOT_PRIMARY)
	_expect(first_result.accepted and second_result.accepted, "both actors use shared skill")
	_expect(first_result.cast_snapshot.cast_id != second_result.cast_snapshot.cast_id, "cast ids globally unique")
	_expect_eq(first.energy.current_energy, 80, "first energy independent")
	_expect_eq(second.energy.current_energy, 50, "second energy independent")
	_expect_eq(first_result.payload.element_id, ElementIds.WATER, "first payload water")
	_expect_eq(second_result.payload.element_id, ElementIds.FIRE, "second payload fire")
	first.executor.advance(1.0)
	_expect_float(first.executor.get_cooldown_remaining(shared_skill.skill_id), 3.0, "first cooldown advances")
	_expect_float(second.executor.get_cooldown_remaining(shared_skill.skill_id), 4.0, "second cooldown untouched")
	_expect_float(shared_skill.cooldown, 4.0, "Resource has no remaining cooldown")
	_expect(first.controller.water_loadout == second.controller.water_loadout, "actors share the same loadout Resource")
	_free_rig(first)
	_free_rig(second)
