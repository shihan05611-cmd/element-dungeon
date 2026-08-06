extends SceneTree

const RECORDING_DELIVERY: PackedScene = preload("res://combat/tests/recording_skill_delivery.tscn")


class RecordingPassivePort:
	extends PassiveEffectPort

	var current: Array[PassiveEffectRuntime] = []
	var commit_count: int = 0
	var reject: bool = false

	func validation_error(bindings: Array[PassiveEffectBinding]) -> StringName:
		if reject:
			return &"passive_port_rejected"
		return super(bindings)

	func commit_replace_effects(runtimes: Array[PassiveEffectRuntime]) -> void:
		current = runtimes.duplicate()
		commit_count += 1

	func skill_ids() -> Array[StringName]:
		var result: Array[StringName] = []
		for runtime: PassiveEffectRuntime in current:
			result.append(runtime.skill_id)
		return result


class Rig:
	extends RefCounted

	var host: Node2D
	var delivery_parent: Node2D
	var energy: EnergyComponent
	var element: CurrentElementController
	var executor: SkillExecutor
	var controller: SkillController
	var loadout: RuntimeSkillLoadout

	func cleanup() -> void:
		if is_instance_valid(host):
			host.free()


var _failures: Array[String] = []
var _assertions: int = 0
var _tests: int = 0


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	_run("static_skill_dimensions", _test_static_skill_dimensions)
	_run("runtime_seven_slots_revision_and_stale", _test_runtime_seven_slots_revision_and_stale)
	_run("runtime_rejects_duplicate_and_active_in_passive_atomically", _test_runtime_rejects_duplicate_and_active_in_passive_atomically)
	_run("four_passives_and_passive_button", _test_four_passives_and_passive_button)
	_run("passive_lifecycle_has_no_leaks_or_duplicates", _test_passive_lifecycle_has_no_leaks_or_duplicates)
	_run("legacy_migration_order_dedup_overflow_idempotent", _test_legacy_migration_order_dedup_overflow_idempotent)
	_run("element_change_does_not_change_shared_mapping", _test_element_change_does_not_change_shared_mapping)
	_run("element_event_same_and_duplicate_sequence", _test_element_event_same_and_duplicate_sequence)
	_run("three_element_cycle_uses_configuration_order", _test_three_element_cycle_uses_configuration_order)
	_run("exclusive_insufficient_energy_is_atomic", _test_exclusive_insufficient_energy_is_atomic)
	_run("exclusive_unavailable_is_atomic", _test_exclusive_unavailable_is_atomic)
	_run("exclusive_cooldown_rejection_preserves_element", _test_exclusive_cooldown_rejection_preserves_element)
	_run("exclusive_success_switches_before_notifications", _test_exclusive_success_switches_before_notifications)
	_run("exclusive_same_element_emits_no_change", _test_exclusive_same_element_emits_no_change)
	_run("cancel_never_refunds_and_keeps_auto_element", _test_cancel_never_refunds_and_keeps_auto_element)
	_run("before_delivery_cancel_refunds_but_keeps_cooldown", _test_before_delivery_cancel_refunds_but_keeps_cooldown)
	_run("after_delivery_cancel_does_not_refund", _test_after_delivery_cancel_does_not_refund)
	_run("current_element_snapshot_survives_buffered_switch", _test_current_element_snapshot_survives_buffered_switch)
	_run("neutral_cast_locks_none", _test_neutral_cast_locks_none)
	_run("idle_and_recovery_switch_immediately", _test_idle_and_recovery_switch_immediately)
	_run("startup_active_keep_only_last_buffered_switch", _test_startup_active_keep_only_last_buffered_switch)
	_run("busy_double_cycle_cancels_buffer", _test_busy_double_cycle_cancels_buffer)
	_run("external_control_gate_buffers_and_flushes", _test_external_control_gate_buffers_and_flushes)
	_run("lifecycle_clears_buffer", _test_lifecycle_clears_buffer)
	_run("invalid_delivery_is_excluded_by_catalog", _test_invalid_delivery_is_excluded_by_catalog)
	_run("delivery_initialization_failure_is_atomic", _test_delivery_initialization_failure_is_atomic)
	_run("cast_started_reentry_is_busy", _test_cast_started_reentry_is_busy)
	_run("large_delta_spawns_once_and_finishes", _test_large_delta_spawns_once_and_finishes)

	if _failures.is_empty():
		print("AGENT B SKILL TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("AGENT B SKILL TESTS FAILED: %d/%d tests, %d assertions" % [
			_failures.size(),
			_tests,
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
		print("PASS: " + test_name)
	else:
		for index in range(before, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _test_static_skill_dimensions() -> void:
	var current := _active(&"current", SkillDefinition.ElementPolicy.CURRENT_ELEMENT)
	var neutral := _active(&"neutral", SkillDefinition.ElementPolicy.NEUTRAL)
	var exclusive := _active(
		&"exclusive",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	var passive := _passive(&"passive", &"effect")
	_expect(current.is_valid(), "current-element active is valid")
	_expect(neutral.is_valid(), "neutral active is valid")
	_expect(exclusive.is_valid(), "exclusive active is valid")
	_expect(passive.is_valid(), "passive is valid")
	var bad_passive := _passive(&"bad_passive", &"effect")
	bad_passive.execution_definition = InstantDeliveryExecution.new()
	_expect_eq(bad_passive.validation_error(), &"passive_skill_has_execution_definition", "passive cannot execute")
	var bad_neutral := _active(&"bad_neutral", SkillDefinition.ElementPolicy.NEUTRAL)
	_instant(bad_neutral).payload.element_mode = AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
	_instant(bad_neutral).payload.element_amount = 1
	_expect_eq(
		bad_neutral.validation_error(),
		&"neutral_skill_requires_neutral_payload",
		"neutral must use none payload"
	)
	var bad_active := _active(&"bad_active")
	_instant(bad_active).delivery_scene = null
	_expect_eq(bad_active.validation_error(), &"missing_delivery_scene", "active requires delivery")


func _test_runtime_seven_slots_revision_and_stale() -> void:
	var active := _active(&"active")
	var passive := _passive(&"passive", &"effect")
	var catalog: Array[SkillDefinition] = [active, passive]
	var port := RecordingPassivePort.new()
	var restored := _snapshot(&"active", &"", &"", &"passive", 7)
	var runtime := RuntimeSkillLoadout.new(catalog, restored, port)
	_expect_eq(runtime.snapshot().revision, 7, "persisted revision restored exactly")
	_expect_eq(runtime.snapshot().get_skill_id(SkillSlotIds.ACTIVE_1), &"active", "mapping restored")
	var next := _snapshot(&"", &"active", &"", &"passive", runtime.snapshot().revision)
	var result := runtime.try_replace_snapshot(next)
	_expect(result.accepted, "valid replacement accepted")
	_expect_eq(result.snapshot.revision, 8, "new replacement increments restored revision")
	_expect_eq(runtime.get_skill_for_slot(SkillSlotIds.ACTIVE_2).skill_id, &"active", "active skill moves between active slots")
	var stale := runtime.try_replace_snapshot(next)
	_expect(not stale.accepted, "stale candidate rejected")
	_expect_eq(stale.detail, &"stale_loadout_revision", "stale reason typed")
	_expect_eq(runtime.snapshot().revision, 8, "stale failure preserves restored revision")


func _test_runtime_rejects_duplicate_and_active_in_passive_atomically() -> void:
	var active := _active(&"active")
	var passive := _passive(&"passive", &"effect")
	var catalog: Array[SkillDefinition] = [active, passive]
	var port := RecordingPassivePort.new()
	var runtime := RuntimeSkillLoadout.new(catalog, _snapshot(&"", &"", &"", &"passive"), port)
	var before := runtime.snapshot()
	var commits := port.commit_count
	var duplicate := _snapshot(&"", &"", &"", &"passive", before.revision, &"passive")
	var duplicate_result := runtime.try_replace_snapshot(duplicate)
	_expect_eq(duplicate_result.detail, &"duplicate_equipped_skill", "duplicate rejected")
	_expect(runtime.snapshot().same_mapping(before), "duplicate preserves mapping")
	_expect_eq(port.commit_count, commits, "duplicate preserves passive registration")
	var bad_slot := _snapshot(&"", &"", &"", &"active", before.revision)
	var bad_result := runtime.try_replace_snapshot(bad_slot)
	_expect_eq(bad_result.detail, &"active_skill_in_passive_slot", "active rejected in passive slot")
	_expect(runtime.snapshot().same_mapping(before), "bad slot preserves mapping")
	_expect_eq(port.commit_count, commits, "bad slot preserves passive registrations")


func _test_four_passives_and_passive_button() -> void:
	var passives: Array[SkillDefinition] = [
		_passive(&"p1", &"e1"),
		_passive(&"p2", &"e2"),
		_passive(&"p3", &"e3"),
		_passive(&"p4", &"e4"),
	]
	var port := RecordingPassivePort.new()
	var rig := _make_rig(passives, _snapshot(&"", &"", &"", &"p1", 0, &"p2", &"p3", &"p4"), port)
	_expect_eq(port.skill_ids().size(), 4, "all four passives registered")
	_expect_eq(_unique_count(port.skill_ids()), 4, "passives registered once by skill id")
	var before_energy := rig.energy.current_energy
	var result := rig.controller.try_cast_slot(SkillSlotIds.PASSIVE_1)
	_expect(not result.accepted, "passive button rejected")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.NOT_CASTABLE, "structured not-castable result")
	_expect_eq(rig.energy.current_energy, before_energy, "passive button spends no energy")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "passive button starts no cast")
	rig.cleanup()


func _test_passive_lifecycle_has_no_leaks_or_duplicates() -> void:
	var p1 := _passive(&"p1", &"e1")
	var p2 := _passive(&"p2", &"e2")
	var p3 := _passive(&"p3", &"e3")
	var catalog: Array[SkillDefinition] = [p1, p2, p3]
	var port := RecordingPassivePort.new()
	var runtime := RuntimeSkillLoadout.new(catalog, _snapshot(&"", &"", &"", &"p1", 0, &"p2", &"p3"), port)
	_expect_eq(port.skill_ids().size(), 3, "three passive-slot effects active")
	runtime.on_owner_died()
	_expect_eq(port.skill_ids().size(), 0, "death unregisters all")
	var after_death := port.commit_count
	runtime.on_owner_died()
	_expect_eq(port.commit_count, after_death, "repeat death is idempotent")
	runtime.on_owner_respawned()
	_expect_eq(port.skill_ids().size(), 3, "respawn restores exact set")
	var after_respawn := port.commit_count
	runtime.on_owner_respawned()
	_expect_eq(port.commit_count, after_respawn, "repeat respawn is idempotent")
	runtime.on_floor_changed()
	_expect_eq(_unique_count(port.skill_ids()), 3, "floor rebuild has no duplicates")
	runtime.on_run_reloaded()
	_expect_eq(_unique_count(port.skill_ids()), 3, "reload rebuild has no duplicates")
	var replacement := _snapshot(&"", &"", &"", &"", runtime.snapshot().revision, &"p2")
	_expect(runtime.try_replace_snapshot(replacement).accepted, "passive replacement accepted")
	_expect_eq(port.skill_ids(), [&"p2"], "unequipped passives removed atomically")


func _test_legacy_migration_order_dedup_overflow_idempotent() -> void:
	var legacy: Array[LegacyElementLoadoutSnapshot] = [
		LegacyElementLoadoutSnapshot.new(ElementIds.WATER, [&"a", &"b", &"c"]),
		LegacyElementLoadoutSnapshot.new(ElementIds.FIRE, [&"b", &"d"]),
	]
	var ordered: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE]
	var first := LegacyElementLoadoutMigrator.migrate(ElementIds.FIRE, ordered, legacy)
	var second := LegacyElementLoadoutMigrator.migrate(ElementIds.FIRE, ordered, legacy)
	_expect(first.accepted, "migration accepted")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.ACTIVE_1), &"b", "current element first")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.ACTIVE_2), &"d", "current remainder second")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.ACTIVE_3), &"a", "ordered other element next")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.PASSIVE_1), &"", "passive defaults empty")
	_expect_eq(first.unequipped_skill_ids, [&"c"], "overflow remains unequipped")
	_expect(first.snapshot.same_mapping(second.snapshot), "migration is idempotent")
	_expect_eq(first.unequipped_skill_ids, second.unequipped_skill_ids, "overflow deterministic")
	var resource_loadouts: Array[SkillLoadout] = [
		load("res://resources/water_loadout.tres") as SkillLoadout,
		load("res://resources/fire_loadout.tres") as SkillLoadout,
	]
	var resource_result := LegacyElementLoadoutMigrator.migrate_resources(
		ElementIds.WATER,
		ordered,
		resource_loadouts
	)
	_expect_eq(
		resource_result.snapshot.get_skill_id(SkillSlotIds.ACTIVE_1),
		&"element_slash",
		"legacy melee deterministically maps to active_1"
	)
	_expect_eq(
		resource_result.snapshot.get_skill_id(SkillSlotIds.ACTIVE_2),
		&"element_bolt",
		"legacy primary deterministically maps to active_2"
	)


func _test_element_change_does_not_change_shared_mapping() -> void:
	var skill := _active(&"skill")
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"skill"))
	var before := rig.loadout.snapshot()
	_expect(rig.controller.request_element(ElementIds.FIRE).changed, "idle switch committed")
	_expect(rig.loadout.snapshot().same_mapping(before), "shared mapping unchanged")
	_expect_eq(rig.controller.get_skill_for_slot(SkillSlotIds.ACTIVE_1).skill_id, &"skill", "same slot skill")
	rig.cleanup()


func _test_element_event_same_and_duplicate_sequence() -> void:
	var controller := CurrentElementController.new()
	var elements: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE]
	controller.configure_runtime(ElementIds.WATER, elements)
	var observed := {"count": 0, "last": null}
	controller.element_changed.connect(func(result: ElementChangeResult) -> void:
		observed.count += 1
		observed.last = result
	)
	var same := controller.request_element(ElementIds.WATER, FormChangedEvent.Source.MANUAL, 9)
	_expect(same.accepted and not same.changed, "same element succeeds without change")
	_expect_eq(observed.count, 0, "same element emits nothing")
	var changed := controller.request_element(ElementIds.FIRE, FormChangedEvent.Source.MANUAL, 10)
	_expect(changed.changed, "new element changes")
	_expect_eq(changed.sequence, 1, "change sequence starts monotonic")
	_expect(changed.timestamp_msec >= 0, "timestamp present")
	_expect_eq(changed.source, FormChangedEvent.Source.MANUAL, "manual source present")
	var duplicate := controller.request_element(ElementIds.WATER, FormChangedEvent.Source.MANUAL, 10)
	_expect_eq(duplicate.detail, &"duplicate_request_sequence", "duplicate request rejected")
	_expect_eq(observed.count, 1, "duplicate emits nothing")
	_expect_eq(controller.current_element_id, ElementIds.FIRE, "duplicate preserves state")
	controller.free()


func _test_three_element_cycle_uses_configuration_order() -> void:
	var controller := CurrentElementController.new()
	var elements: Array[StringName] = [&"water", &"earth", &"air"]
	_expect(controller.configure_runtime(&"water", elements), "three elements configured")
	_expect_eq(controller.cycle_next().current_element_id, &"earth", "cycles to configured second")
	_expect_eq(controller.cycle_next().current_element_id, &"air", "cycles to configured third")
	_expect_eq(controller.cycle_next().current_element_id, &"water", "cycles back without switch branches")
	controller.free()


func _test_exclusive_insufficient_energy_is_atomic() -> void:
	var skill := _active(
		&"fire_skill",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	_instant(skill).energy_cost = 10
	skill.cooldown = 5.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_skill"), null, [ElementIds.WATER, ElementIds.FIRE], 5)
	var result := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, "energy rejection")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "failed cast does not auto-switch")
	_expect_eq(rig.energy.current_energy, 5, "failed cast does not spend")
	_expect(not rig.executor.is_skill_on_cooldown(skill.skill_id), "failed cast starts no cooldown")
	_expect_eq(rig.delivery_parent.get_child_count(), 0, "failed cast spawns no delivery")
	rig.cleanup()


func _test_exclusive_unavailable_is_atomic() -> void:
	var skill := _active(
		&"fire_skill",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	_instant(skill).energy_cost = 10
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_skill"), null, [ElementIds.WATER], 100)
	var result := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.ELEMENT_UNAVAILABLE, "unavailable typed")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "unavailable preserves element")
	_expect_eq(rig.energy.current_energy, 100, "unavailable preserves energy")
	_expect(not rig.executor.is_skill_on_cooldown(skill.skill_id), "unavailable starts no cooldown")
	rig.cleanup()


func _test_exclusive_cooldown_rejection_preserves_element() -> void:
	var skill := _active(
		&"fire_skill",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	skill.cooldown = 5.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_skill"))
	_expect(rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1).accepted, "first cast accepted")
	rig.executor.advance(1.0)
	rig.element.request_element(ElementIds.WATER)
	var remaining := rig.executor.get_cooldown_remaining(skill.skill_id)
	var result := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.COOLDOWN_ACTIVE, "cooldown rejection")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "cooldown failure does not switch")
	_expect_eq(rig.executor.get_cooldown_remaining(skill.skill_id), remaining, "cooldown unchanged by failure")
	rig.cleanup()


func _test_exclusive_success_switches_before_notifications() -> void:
	var skill := _active(
		&"fire_skill",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_skill"))
	var observed := {"count": 0, "whole": false, "source": -1}
	rig.element.element_changed.connect(func(change: ElementChangeResult) -> void:
		observed.count += 1
		observed.source = change.source
		observed.whole = (
			rig.element.current_element_id == ElementIds.FIRE
			and rig.executor.current_phase == SkillExecutor.Phase.STARTUP
			and rig.executor.current_cast_snapshot != null
			and rig.executor.current_cast_snapshot.cast_element_id == ElementIds.FIRE
		)
	)
	var result := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(result.accepted, "exclusive accepted")
	_expect_eq(observed.count, 1, "one auto change event")
	_expect(observed.whole, "element observer sees whole accepted transaction")
	_expect_eq(observed.source, FormChangedEvent.Source.SKILL_AUTO, "auto source")
	_expect_eq(result.cast_snapshot.cast_element_id, ElementIds.FIRE, "snapshot locks fire")
	rig.cleanup()


func _test_exclusive_same_element_emits_no_change() -> void:
	var skill := _active(
		&"fire_skill",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_skill"), null, [ElementIds.WATER, ElementIds.FIRE], 100, ElementIds.FIRE)
	var observed := {"count": 0}
	rig.element.element_changed.connect(func(_change: ElementChangeResult) -> void:
		observed.count += 1
	)
	_expect(rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1).accepted, "same-element exclusive accepted")
	_expect_eq(observed.count, 0, "same-element auto cast emits no element event")
	rig.cleanup()


func _test_cancel_never_refunds_and_keeps_auto_element() -> void:
	var skill := _active(
		&"fire_skill",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE
	)
	_instant(skill).energy_cost = 20
	skill.cooldown = 5.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_skill"))
	var accepted := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(accepted.accepted, "cast accepted")
	_expect(rig.executor.cancel_current_cast(&"test", accepted.cast_snapshot.cast_id), "startup cancelled")
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "auto switch never rolls back")
	_expect_eq(rig.energy.current_energy, 80, "NEVER does not refund")
	_expect(rig.executor.is_skill_on_cooldown(skill.skill_id), "cooldown remains")
	rig.cleanup()


func _test_before_delivery_cancel_refunds_but_keeps_cooldown() -> void:
	var skill := _active(
		&"fire_refund",
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT,
		ElementIds.FIRE,
		SkillDefinition.EnergyRefundPolicy.BEFORE_DELIVERY
	)
	_instant(skill).energy_cost = 20
	skill.cooldown = 5.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"fire_refund"))
	var accepted := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect_eq(rig.energy.current_energy, 80, "energy spent at accept")
	rig.executor.cancel_current_cast(&"test", accepted.cast_snapshot.cast_id)
	_expect_eq(rig.energy.current_energy, 100, "pre-delivery cancellation refunds")
	_expect(rig.executor.is_skill_on_cooldown(skill.skill_id), "refund does not roll back cooldown")
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "refund does not roll back element")
	rig.cleanup()


func _test_after_delivery_cancel_does_not_refund() -> void:
	var skill := _active(
		&"delivered",
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT,
		ElementIds.NONE,
		SkillDefinition.EnergyRefundPolicy.BEFORE_DELIVERY
	)
	_instant(skill).energy_cost = 20
	skill.startup_time = 0.1
	_instant(skill).active_time = 1.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"delivered"))
	var accepted := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	rig.executor.advance(0.1)
	_expect_eq(rig.delivery_parent.get_child_count(), 1, "delivery generated")
	rig.executor.cancel_current_cast(&"test", accepted.cast_snapshot.cast_id)
	_expect_eq(rig.energy.current_energy, 80, "successful delivery prevents refund")
	rig.cleanup()


func _test_current_element_snapshot_survives_buffered_switch() -> void:
	var skill := _active(&"current")
	skill.startup_time = 0.1
	_instant(skill).active_time = 0.1
	skill.recovery_time = 0.5
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"current"))
	var accepted := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	var queued := rig.controller.request_element(ElementIds.FIRE)
	_expect(queued.buffered, "startup manual switch buffered")
	_expect_eq(accepted.cast_snapshot.cast_element_id, ElementIds.WATER, "cast locks water")
	_expect_eq(accepted.payload.element_id, ElementIds.WATER, "payload locks water")
	rig.executor.advance(0.2)
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "buffer flushes entering recovery")
	_expect_eq(accepted.cast_snapshot.cast_element_id, ElementIds.WATER, "snapshot remains water")
	_expect_eq(accepted.payload.element_id, ElementIds.WATER, "payload remains water")
	rig.cleanup()


func _test_neutral_cast_locks_none() -> void:
	var skill := _active(&"neutral", SkillDefinition.ElementPolicy.NEUTRAL)
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"neutral"))
	var result := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(result.accepted, "neutral accepted")
	_expect_eq(result.cast_snapshot.cast_element_id, ElementIds.NONE, "neutral snapshot locks NONE")
	_expect_eq(result.payload.element_id, ElementIds.NONE, "neutral payload locks NONE")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "neutral does not switch")
	rig.cleanup()


func _test_idle_and_recovery_switch_immediately() -> void:
	var skill := _active(&"current")
	skill.startup_time = 0.1
	_instant(skill).active_time = 0.1
	skill.recovery_time = 1.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"current"))
	_expect(rig.controller.request_element(ElementIds.FIRE).changed, "idle switch immediate")
	rig.element.request_element(ElementIds.WATER)
	rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	rig.executor.advance(0.2)
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.RECOVERY, "entered recovery")
	var changed := rig.controller.request_element(ElementIds.FIRE)
	_expect(changed.changed and not changed.buffered, "recovery switch immediate")
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "recovery state committed")
	rig.cleanup()


func _test_startup_active_keep_only_last_buffered_switch() -> void:
	var skill := _active(&"current")
	skill.startup_time = 0.2
	_instant(skill).active_time = 0.2
	skill.recovery_time = 1.0
	var catalog: Array[SkillDefinition] = [skill]
	var elements: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE, &"earth"]
	var rig := _make_rig(catalog, _snapshot(&"current"), null, elements)
	var observed := {"count": 0}
	rig.element.element_changed.connect(func(_change: ElementChangeResult) -> void:
		observed.count += 1
	)
	rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(rig.controller.request_element(ElementIds.FIRE).buffered, "startup buffers")
	_expect(rig.controller.request_element(&"earth").buffered, "startup replaces buffer")
	rig.executor.advance(0.2)
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "active still locked")
	_expect(rig.controller.request_element(ElementIds.FIRE).buffered, "active keeps final request")
	rig.executor.advance(0.2)
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "only final request flushes")
	_expect_eq(observed.count, 1, "one buffered event published")
	rig.cleanup()


func _test_busy_double_cycle_cancels_buffer() -> void:
	var skill := _active(&"current")
	skill.startup_time = 0.2
	_instant(skill).active_time = 0.2
	skill.recovery_time = 1.0
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"current"))
	var observed := {"count": 0}
	rig.element.element_changed.connect(func(_change: ElementChangeResult) -> void:
		observed.count += 1
	)
	rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	var first := rig.controller.cycle_next()
	var second := rig.controller.cycle_next()
	_expect(first.buffered, "first busy cycle buffers alternate element")
	_expect(second.accepted and not second.buffered and not second.changed, "second busy cycle cancels buffer")
	rig.executor.advance(0.4)
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "cancelled buffer does not switch in recovery")
	_expect_eq(observed.count, 0, "cancelled buffer publishes no change event")
	rig.cleanup()


func _test_external_control_gate_buffers_and_flushes() -> void:
	var skill := _active(&"current")
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"current"))
	var gate := {"allowed": false}
	var callable := func() -> bool:
		return gate.allowed
	rig.controller.set_external_manual_element_gate(callable)
	_expect(rig.controller.request_element(ElementIds.FIRE).buffered, "external lock buffers idle request")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "locked request not committed")
	gate.allowed = true
	rig.controller.set_external_manual_element_gate(callable)
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "unlock flushes once")
	rig.element.request_element(ElementIds.WATER)
	rig.controller.set_external_manual_element_gate(Callable())
	gate.allowed = false
	rig.executor.set_external_action_gate(func(_skill: SkillDefinition) -> bool:
		return gate.allowed
	)
	_expect(rig.controller.request_element(ElementIds.FIRE).buffered, "executor control gate also buffers")
	gate.allowed = true
	rig.controller.call(&"_process", 0.0)
	_expect_eq(rig.element.current_element_id, ElementIds.FIRE, "control recovery flushes buffered request")
	rig.cleanup()


func _test_lifecycle_clears_buffer() -> void:
	var skill := _active(&"current")
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"current"))
	var gate := {"allowed": false}
	var callable := func() -> bool:
		return gate.allowed
	rig.controller.set_external_manual_element_gate(callable)
	rig.controller.request_element(ElementIds.FIRE)
	rig.controller.on_floor_changed()
	gate.allowed = true
	rig.controller.set_external_manual_element_gate(callable)
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "floor clears buffered request")
	gate.allowed = false
	rig.controller.set_external_manual_element_gate(callable)
	rig.controller.request_element(ElementIds.FIRE)
	rig.controller.handle_pause_exit()
	gate.allowed = true
	rig.controller.set_external_manual_element_gate(callable)
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "pause exit clears buffered request")
	rig.cleanup()


func _test_invalid_delivery_is_excluded_by_catalog() -> void:
	var skill := _active(&"bad_delivery")
	var invalid_scene := PackedScene.new()
	var invalid_root := Node2D.new()
	invalid_scene.pack(invalid_root)
	invalid_root.free()
	_instant(skill).delivery_scene = invalid_scene
	var requested := _snapshot(skill.skill_id)
	var catalog: Array[SkillDefinition] = [skill]
	var rejected_catalog := RuntimeSkillLoadout.new(catalog, requested)
	_expect_eq(
		rejected_catalog.configuration_error,
		&"delivery_scene_root_must_extend_delivery_base",
		"runtime catalog rejects a delivery root outside DeliveryBase"
	)
	var validation := rejected_catalog.validate_snapshot(requested)
	_expect(not validation.accepted, "invalid delivery cannot enter a runtime mapping")
	_expect_eq(validation.detail, &"delivery_scene_root_must_extend_delivery_base", "catalog rejection remains structured")
	_expect_eq(rejected_catalog.snapshot().get_skill_id(SkillSlotIds.ACTIVE_1), &"", "invalid mapping is not restored")
	_expect(rejected_catalog.get_skill(skill.skill_id) == null, "invalid delivery is not exposed by the runtime catalog")

func _test_delivery_initialization_failure_is_atomic() -> void:
	var skill := _active(&"rejecting_delivery")
	_instant(skill).energy_cost = 20
	var rejecting_scene := PackedScene.new()
	var rejecting_root := RecordingSkillDelivery.new()
	rejecting_root.reject_initialization = true
	rejecting_scene.pack(rejecting_root)
	rejecting_root.free()
	_instant(skill).delivery_scene = rejecting_scene
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(skill.skill_id))
	_expect_eq(rig.loadout.configuration_error, &"", "typed delivery is accepted by catalog validation")
	var result := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE, "initialization failure is structured")
	_expect_eq(result.detail, &"delivery_initialization_rejected", "initialization failure detail preserved")
	_expect_eq(rig.energy.current_energy, 100, "initialization failure spends no energy")
	_expect_eq(rig.executor.get_cooldown_remaining(skill.skill_id), 0.0, "initialization failure starts no cooldown")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "initialization failure starts no cast")
	_expect_eq(rig.delivery_parent.get_child_count(), 0, "initialization failure adds no delivery")
	rig.cleanup()

func _test_cast_started_reentry_is_busy() -> void:
	var skill := _active(&"reentry")
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"reentry"))
	var observed := {"nested": null}
	rig.executor.cast_started.connect(func(_snapshot_value: CastSnapshot, _payload: RuntimeAttackPayload) -> void:
		observed.nested = rig.executor._try_cast_configured(skill, SkillSlotIds.ACTIVE_1)
	)
	var outer := rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(outer.accepted, "outer accepted")
	_expect(observed.nested != null, "nested attempted")
	_expect_eq(observed.nested.reject_reason, CastAttemptResult.RejectReason.BUSY, "nested rejected busy")
	_expect_eq(rig.energy.current_energy, 100, "zero-cost reentry cannot double spend")
	rig.cleanup()


func _test_large_delta_spawns_once_and_finishes() -> void:
	var skill := _active(&"large_delta")
	skill.startup_time = 0.1
	_instant(skill).active_time = 0.1
	skill.recovery_time = 0.1
	var catalog: Array[SkillDefinition] = [skill]
	var rig := _make_rig(catalog, _snapshot(&"large_delta"))
	var observed := {"spawns": 0}
	rig.executor.delivery_spawned.connect(func(_cast_id: int, _delivery_id: int, _delivery: Node) -> void:
		observed.spawns += 1
	)
	_expect(rig.controller.try_cast_slot(SkillSlotIds.ACTIVE_1).accepted, "cast accepted")
	_expect(rig.executor.advance(1.0), "large delta succeeds")
	_expect_eq(observed.spawns, 1, "delivery spawned exactly once")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "large delta finishes")
	rig.cleanup()


func _make_rig(
	catalog: Array[SkillDefinition],
	initial: RuntimeLoadoutSnapshot,
	passive_port: PassiveEffectPort = null,
	elements: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE],
	energy_current: int = 100,
	current_element: StringName = ElementIds.WATER
) -> Rig:
	var rig := Rig.new()
	rig.host = Node2D.new()
	rig.delivery_parent = Node2D.new()
	rig.host.add_child(rig.delivery_parent)
	rig.energy = EnergyComponent.new()
	rig.energy.configure_runtime(100, energy_current)
	rig.host.add_child(rig.energy)
	rig.element = CurrentElementController.new()
	rig.element.configure_runtime(current_element, elements)
	rig.host.add_child(rig.element)
	rig.executor = SkillExecutor.new()
	rig.executor.configure_dependencies(rig.energy, rig.element, rig.delivery_parent)
	rig.executor.configure_cast_identity(1001, 1002, &"player")
	rig.host.add_child(rig.executor)
	rig.loadout = RuntimeSkillLoadout.new(catalog, initial, passive_port)
	rig.controller = SkillController.new()
	rig.controller.configure_runtime(rig.element, rig.executor, rig.loadout)
	rig.host.add_child(rig.controller)
	root.add_child(rig.host)
	rig.executor.set_process(false)
	rig.energy.set_process(false)
	return rig


func _active(
	skill_id: StringName,
	policy: SkillDefinition.ElementPolicy = SkillDefinition.ElementPolicy.CURRENT_ELEMENT,
	required_element: StringName = ElementIds.NONE,
	refund_policy: SkillDefinition.EnergyRefundPolicy = SkillDefinition.EnergyRefundPolicy.NEVER
) -> SkillDefinition:
	var payload := AttackPayloadDefinition.new()
	payload.damage_multiplier = 1.0
	match policy:
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
			payload.element_mode = AttackPayloadDefinition.ElementMode.FIXED_ELEMENT
			payload.fixed_element_id = required_element
			payload.element_amount = 1
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
			payload.element_mode = AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
			payload.element_amount = 1
		SkillDefinition.ElementPolicy.NEUTRAL:
			payload.element_mode = AttackPayloadDefinition.ElementMode.NONE
			payload.element_amount = 0
	var skill := SkillDefinition.new()
	skill.skill_id = skill_id
	skill.activation_kind = SkillDefinition.ActivationKind.ACTIVE
	skill.element_policy = policy
	skill.required_element_id = required_element
	skill.energy_refund_policy = refund_policy
	skill.startup_time = 0.1
	skill.recovery_time = 0.1
	var execution := InstantDeliveryExecution.new()
	execution.active_time = 0.1
	execution.delivery_scene = RECORDING_DELIVERY
	execution.payload = payload
	skill.execution_definition = execution
	return skill


func _passive(skill_id: StringName, effect_id: StringName) -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_id = skill_id
	skill.activation_kind = SkillDefinition.ActivationKind.PASSIVE
	skill.element_policy = SkillDefinition.ElementPolicy.CURRENT_ELEMENT
	var effect := StatModifierPassiveEffectDefinition.new()
	if effect_id.is_empty():
		effect.attack_multiplier = 1.0
	skill.passive_effect_definition = effect
	return skill


func _instant(skill: SkillDefinition) -> InstantDeliveryExecution:
	return skill.execution_definition as InstantDeliveryExecution


func _snapshot(
	active_1: StringName = &"",
	active_2: StringName = &"",
	active_3: StringName = &"",
	passive_1: StringName = &"",
	revision: int = 0,
	passive_2: StringName = &"",
	passive_3: StringName = &"",
	passive_4: StringName = &""
) -> RuntimeLoadoutSnapshot:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, active_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, active_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, active_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, passive_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, passive_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3, passive_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4, passive_4),
	]
	return RuntimeLoadoutSnapshot.new(entries, revision)


func _unique_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])
