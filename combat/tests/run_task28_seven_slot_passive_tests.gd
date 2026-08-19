extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const ACTIVE_BOLT: SkillDefinition = preload("res://resources/element_bolt.tres")
const ACTIVE_WATER: SkillDefinition = preload("res://resources/skills/water_lance.tres")
const ACTIVE_FIRE: SkillDefinition = preload("res://resources/skills/fire_lance.tres")
const PASSIVE_VITALITY: SkillDefinition = preload("res://resources/skills/passive_vitality.tres")
const PASSIVE_ENERGY: SkillDefinition = preload("res://resources/skills/passive_energy.tres")
const PASSIVE_FOCUS: SkillDefinition = preload("res://resources/skills/passive_focus.tres")
const PASSIVE_BALANCE: SkillDefinition = preload("res://resources/skills/passive_balance.tres")
const FORMAL_CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")


class RecordingPassivePort:
	extends PassiveEffectPort

	var current: Array[PassiveEffectRuntime] = []
	var commit_count: int = 0
	var reject_validation: bool = false

	func validation_error(bindings: Array[PassiveEffectBinding]) -> StringName:
		if reject_validation:
			return &"task28_passive_port_rejected"
		return super(bindings)

	func commit_replace_effects(runtimes: Array[PassiveEffectRuntime]) -> void:
		current = runtimes.duplicate()
		commit_count += 1

	func skill_ids() -> Array[StringName]:
		var result: Array[StringName] = []
		for runtime: PassiveEffectRuntime in current:
			result.append(runtime.skill_id)
		return result


class RejectingRuntimePort:
	extends RuntimeLoadoutPort

	var inner: RuntimeSkillLoadout
	var reject_commit: bool = false
	var validate_calls: int = 0
	var commit_calls: int = 0

	func _init(runtime: RuntimeSkillLoadout) -> void:
		inner = runtime

	func snapshot() -> RuntimeLoadoutSnapshot:
		return inner.snapshot()

	func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		validate_calls += 1
		return inner.validate_snapshot(candidate)

	func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		commit_calls += 1
		if reject_commit:
			return RuntimeLoadoutChangeResult.rejected(&"task28_final_port_rejected", snapshot())
		return inner.try_replace_snapshot(candidate)


var _harness := TestHarness.new()


func _initialize() -> void:
	_run("slot_order_empty_and_resource_contract", _test_slot_order_empty_and_resource_contract)
	_run("runtime_strict_partition_and_atomic_rejections", _test_runtime_strict_partition_and_atomic_rejections)
	_run("shared_four_to_seven_migration_and_persistence", _test_shared_four_to_seven_migration_and_persistence)
	_run("legacy_fifth_passive_overflow", _test_legacy_fifth_passive_overflow)
	_run("four_passive_runtime_lifecycle", _test_four_passive_runtime_lifecycle)
	_run("run_session_immediate_authority_and_task27_protection", _test_run_session_immediate_authority_and_task27_protection)

	quit(_harness.report("TASK 28 SEVEN SLOT PASSIVE TESTS"))


func _run(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _test_slot_order_empty_and_resource_contract() -> void:
	_expect_eq(SkillSlotIds.all(), [
		SkillSlotIds.ACTIVE_1,
		SkillSlotIds.ACTIVE_2,
		SkillSlotIds.ACTIVE_3,
		SkillSlotIds.PASSIVE_1,
		SkillSlotIds.PASSIVE_2,
		SkillSlotIds.PASSIVE_3,
		SkillSlotIds.PASSIVE_4,
	], "seven slot order is frozen")
	_expect_eq(SkillSlotIds.active().size(), 3, "three active slots exposed")
	_expect_eq(SkillSlotIds.passive().size(), 4, "four passive slots exposed")
	_expect_eq(SkillSlotIds.kind_for(SkillSlotIds.ACTIVE_3), SkillSlotIds.SlotKind.ACTIVE, "active kind query")
	_expect_eq(SkillSlotIds.kind_for(SkillSlotIds.PASSIVE_4), SkillSlotIds.SlotKind.PASSIVE, "passive kind query")
	_expect_eq(SkillSlotIds.kind_for(&"foreign"), SkillSlotIds.SlotKind.UNKNOWN, "unknown kind query")

	var empty := _seven_snapshot()
	var runtime := RuntimeSkillLoadout.new(_task28_definitions(), empty)
	_expect(empty.is_valid() and empty.entries.size() == 7, "all seven slots may be empty")
	_expect(runtime.configuration_error.is_empty(), "empty seven-slot runtime configures")
	_expect(runtime.snapshot().same_mapping(empty), "empty mapping round-trips")

	var template := SkillLoadout.new()
	template.form_element_id = ElementIds.NONE
	template.slots = _template_slots()
	_expect(template.is_shared(), "resource template accepts seven typed empty slots")
	template.slots[SkillSlotIds.ACTIVE_1] = PASSIVE_VITALITY
	_expect_eq(template.validation_error(), &"passive_skill_in_active_slot", "resource rejects passive in active")
	template.slots = _template_slots()
	template.slots[SkillSlotIds.PASSIVE_4] = ACTIVE_BOLT
	_expect_eq(template.validation_error(), &"active_skill_in_passive_slot", "resource rejects active in passive")
	var malformed := _template_slots()
	malformed.erase(SkillSlotIds.PASSIVE_4)
	malformed[&"foreign"] = null
	template.slots = malformed
	_expect_eq(template.validation_error(), &"unknown_shared_slot", "resource reports unknown shared slot")

	var passive_content := SkillContentDefinition.new()
	passive_content.skill_id = PASSIVE_VITALITY.skill_id
	passive_content.display_name = "Task28 passive"
	passive_content.description = "Strict default slot fixture"
	passive_content.gameplay_definition = PASSIVE_VITALITY
	passive_content.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
	passive_content.initially_owned = true
	passive_content.default_slot_id = SkillSlotIds.ACTIVE_1
	_expect_eq(passive_content.validation_error(), &"passive_skill_in_active_default_slot", "content rejects passive active default")


func _test_runtime_strict_partition_and_atomic_rejections() -> void:
	var port := RecordingPassivePort.new()
	var initial := _seven_snapshot(
		ACTIVE_BOLT.skill_id,
		&"",
		&"",
		PASSIVE_VITALITY.skill_id,
		9
	)
	var runtime := RuntimeSkillLoadout.new(_task28_definitions(), initial, port)
	var before := runtime.snapshot()
	var before_commits := port.commit_count

	var passive_in_active := _seven_snapshot(
		PASSIVE_ENERGY.skill_id,
		&"",
		&"",
		PASSIVE_VITALITY.skill_id,
		before.revision
	)
	_expect_rejected_unchanged(runtime, passive_in_active, &"passive_skill_in_active_slot", before, port, before_commits)
	var active_in_passive := _seven_snapshot(
		ACTIVE_BOLT.skill_id,
		&"",
		&"",
		ACTIVE_WATER.skill_id,
		before.revision
	)
	_expect_rejected_unchanged(runtime, active_in_passive, &"active_skill_in_passive_slot", before, port, before_commits)
	var duplicate := _seven_snapshot(
		ACTIVE_BOLT.skill_id,
		ACTIVE_BOLT.skill_id,
		&"",
		PASSIVE_VITALITY.skill_id,
		before.revision
	)
	_expect_rejected_unchanged(runtime, duplicate, &"duplicate_equipped_skill", before, port, before_commits)

	var unknown_entries := before.entries
	for index: int in unknown_entries.size():
		if unknown_entries[index].slot_id == SkillSlotIds.PASSIVE_4:
			unknown_entries[index] = RuntimeLoadoutSlotSnapshot.new(&"foreign")
	var unknown := RuntimeLoadoutSnapshot.new(unknown_entries, before.revision)
	_expect_rejected_unchanged(runtime, unknown, &"unknown_shared_slot", before, port, before_commits)

	var short_entries := before.entries
	short_entries.pop_back()
	var short := RuntimeLoadoutSnapshot.new(short_entries, before.revision)
	_expect_rejected_unchanged(runtime, short, &"expected_seven_shared_slots", before, port, before_commits)

	port.reject_validation = true
	var rejected_by_port := _seven_snapshot(
		ACTIVE_BOLT.skill_id,
		&"",
		&"",
		PASSIVE_ENERGY.skill_id,
		before.revision
	)
	_expect_rejected_unchanged(runtime, rejected_by_port, &"task28_passive_port_rejected", before, port, before_commits)
	port.reject_validation = false


func _test_shared_four_to_seven_migration_and_persistence() -> void:
	var legacy := _legacy_four_snapshot(
		PASSIVE_ENERGY.skill_id,
		ACTIVE_WATER.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_VITALITY.skill_id,
		12
	)
	var owned: Array[StringName] = [
		ACTIVE_WATER.skill_id,
		PASSIVE_VITALITY.skill_id,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id,
	]
	var first := SharedFourSlotToSevenSlotMigrator.migrate(legacy, _task28_definitions(), owned)
	var second := SharedFourSlotToSevenSlotMigrator.migrate(legacy, _task28_definitions(), owned)
	_expect(first.accepted and first.migrated_legacy_four_slot, "legacy four-slot snapshot migrates")
	_expect_eq(first.snapshot.entries.size(), 7, "migration produces seven slots")
	_expect_eq(first.snapshot.revision, 12, "migration preserves revision")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.ACTIVE_1), &"", "legacy active passive is removed from active one")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.ACTIVE_2), ACTIVE_WATER.skill_id, "legal active stays in original slot")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.PASSIVE_1), PASSIVE_VITALITY.skill_id, "legacy passive one has priority")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.PASSIVE_2), PASSIVE_ENERGY.skill_id, "active one passive fills passive two")
	_expect_eq(first.snapshot.get_skill_id(SkillSlotIds.PASSIVE_3), PASSIVE_FOCUS.skill_id, "active three passive fills passive three")
	_expect(first.snapshot.same_mapping(second.snapshot), "repeated migration is deterministic")
	_expect_eq(first.snapshot.revision, second.snapshot.revision, "repeated migration does not advance revision")
	_expect(first.retained_owned_skill_ids.has(PASSIVE_BALANCE.skill_id), "owned unequipped passive is retained")
	_expect(first.unequipped_skill_ids.has(PASSIVE_BALANCE.skill_id), "retained overflow is reported unequipped")

	var duplicate_legacy := _legacy_four_snapshot(
		PASSIVE_VITALITY.skill_id,
		PASSIVE_ENERGY.skill_id,
		ACTIVE_FIRE.skill_id,
		PASSIVE_VITALITY.skill_id
	)
	var duplicate_result := SharedFourSlotToSevenSlotMigrator.migrate(
		duplicate_legacy,
		_task28_definitions(),
		owned
	)
	_expect_eq(duplicate_result.duplicate_skill_ids, [PASSIVE_VITALITY.skill_id], "first duplicate wins deterministically")
	_expect_eq(duplicate_result.snapshot.get_skill_id(SkillSlotIds.PASSIVE_1), PASSIVE_VITALITY.skill_id, "priority duplicate stays in passive one")
	_expect_eq(duplicate_result.snapshot.get_skill_id(SkillSlotIds.PASSIVE_2), PASSIVE_ENERGY.skill_id, "next distinct passive fills passive two")

	var invalid_legacy := _legacy_four_snapshot(
		&"unknown_owned",
		PASSIVE_ENERGY.skill_id,
		ACTIVE_FIRE.skill_id,
		ACTIVE_BOLT.skill_id
	)
	var invalid_owned := owned.duplicate()
	invalid_owned.append(&"unknown_owned")
	invalid_owned.append(ACTIVE_BOLT.skill_id)
	var invalid_result := SharedFourSlotToSevenSlotMigrator.migrate(
		invalid_legacy,
		_task28_definitions(),
		invalid_owned
	)
	_expect_eq(invalid_result.unknown_skill_ids, [&"unknown_owned"], "unknown legacy skill is typed")
	_expect_eq(invalid_result.invalid_type_skill_ids, [ACTIVE_BOLT.skill_id], "active in legacy passive one is typed")
	_expect(invalid_result.unequipped_skill_ids.has(&"unknown_owned"), "unknown owned skill remains unequipped rather than deleted")
	_expect(invalid_result.unequipped_skill_ids.has(ACTIVE_BOLT.skill_id), "invalid-type owned skill remains unequipped")

	var native := SharedFourSlotToSevenSlotMigrator.migrate(first.snapshot, _task28_definitions(), owned)
	_expect(native.accepted and native.native_seven_slot, "native seven-slot snapshot is recognized")
	_expect(native.snapshot.same_mapping(first.snapshot), "native seven-slot snapshot is not reordered")
	_expect_eq(native.snapshot.revision, first.snapshot.revision, "native snapshot revision is unchanged")

	var persistence := SharedLoadoutPersistenceAdapter.new()
	_expect(persistence.restore(
		legacy,
		ElementIds.WATER,
		[ElementIds.WATER, ElementIds.FIRE],
		[],
		_task28_definitions(),
		owned
	), "persistence restores legacy shared snapshot")
	_expect(persistence.migrated_shared_four_slot and persistence.migrated_legacy, "persistence reports one-time four-slot migration")
	_expect(persistence.saved_snapshot.same_mapping(first.snapshot), "persistence stores exactly one seven-slot mapping")
	_expect(persistence.migration_overflow_skill_ids.has(PASSIVE_BALANCE.skill_id), "persistence exposes retained unequipped ownership")
	_expect(persistence.save_shared(persistence.saved_snapshot), "persistence accepts native seven-slot save")
	_expect(not persistence.save_shared(legacy), "persistence rejects writing legacy four-slot state")


func _test_legacy_fifth_passive_overflow() -> void:
	var fifth := PASSIVE_BALANCE.duplicate(true) as SkillDefinition
	fifth.skill_id = &"passive_fifth"
	var definitions := _task28_definitions()
	definitions.append(fifth)
	var water_ids: Array[StringName] = [
		PASSIVE_VITALITY.skill_id,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
	]
	var fire_ids: Array[StringName] = [PASSIVE_BALANCE.skill_id, fifth.skill_id]
	var legacy: Array[LegacyElementLoadoutSnapshot] = [
		LegacyElementLoadoutSnapshot.new(ElementIds.WATER, water_ids),
		LegacyElementLoadoutSnapshot.new(ElementIds.FIRE, fire_ids),
	]
	var result := LegacyElementLoadoutMigrator.migrate(
		ElementIds.WATER,
		[ElementIds.WATER, ElementIds.FIRE],
		legacy,
		4,
		definitions
	)
	_expect(result.accepted, "legacy element migration accepts five passive definitions")
	_expect_eq(result.snapshot.entries.size(), 7, "legacy element migration produces seven slots")
	_expect_eq(result.snapshot.get_skill_id(SkillSlotIds.PASSIVE_1), PASSIVE_VITALITY.skill_id, "first passive maps to passive one")
	_expect_eq(result.snapshot.get_skill_id(SkillSlotIds.PASSIVE_4), PASSIVE_BALANCE.skill_id, "fourth passive maps to passive four")
	_expect_eq(result.unequipped_skill_ids, [fifth.skill_id], "fifth passive remains owned overflow")
	_expect_eq(result.snapshot.revision, 4, "legacy element migration preserves revision")


func _test_four_passive_runtime_lifecycle() -> void:
	var port := RecordingPassivePort.new()
	var runtime := RuntimeSkillLoadout.new(
		_task28_definitions(),
		_seven_snapshot(
			ACTIVE_WATER.skill_id,
			&"",
			&"",
			PASSIVE_VITALITY.skill_id,
			0,
			PASSIVE_ENERGY.skill_id,
			PASSIVE_FOCUS.skill_id,
			PASSIVE_BALANCE.skill_id
		),
		port
	)
	_expect_eq(runtime.registered_passive_skill_ids, _passive_ids(), "four passives register in slot order")
	_expect_eq(runtime.registered_passive_slot_ids, SkillSlotIds.passive(), "slot-to-runtime audit covers passive one through four")
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "each passive skill is registered once")
	_expect_eq(runtime.passive_registration_commit_count, 1, "initial four-passive registration is one batch")
	var initial_instances := _runtime_instances(runtime)
	_expect_eq(_unique_object_count(initial_instances), 4, "each passive slot owns one distinct runtime")

	var active_only := _seven_snapshot(
		&"",
		ACTIVE_WATER.skill_id,
		&"",
		PASSIVE_VITALITY.skill_id,
		runtime.snapshot().revision,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id
	)
	var commits_before_active_move := port.commit_count
	_expect(runtime.try_replace_snapshot(active_only).accepted, "active-only move succeeds")
	_expect_eq(port.commit_count, commits_before_active_move, "active-only move does not rebuild passives")
	_expect(_same_instances(initial_instances, _runtime_instances(runtime)), "active-only move preserves passive instances")

	var registration_before_swap := runtime.passive_registration_commit_count
	var unregistration_before_swap := runtime.passive_unregistration_commit_count
	var swapped := _seven_snapshot(
		&"",
		ACTIVE_WATER.skill_id,
		&"",
		PASSIVE_ENERGY.skill_id,
		runtime.snapshot().revision,
		PASSIVE_VITALITY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id
	)
	_expect(runtime.try_replace_snapshot(swapped).accepted, "passive slot swap succeeds")
	_expect(runtime.passive_runtime_for_slot(SkillSlotIds.PASSIVE_1) == initial_instances[1], "passive one audit follows swapped energy runtime")
	_expect(runtime.passive_runtime_for_slot(SkillSlotIds.PASSIVE_2) == initial_instances[0], "passive two audit follows swapped vitality runtime")
	_expect_eq(runtime.passive_registration_commit_count, registration_before_swap, "swap registers no new runtime")
	_expect_eq(runtime.passive_unregistration_commit_count, unregistration_before_swap, "swap unregisters no runtime")

	var without_four := _seven_snapshot(
		&"",
		ACTIVE_WATER.skill_id,
		&"",
		PASSIVE_ENERGY.skill_id,
		runtime.snapshot().revision,
		PASSIVE_VITALITY.skill_id,
		PASSIVE_FOCUS.skill_id
	)
	var unregistration_before_remove := runtime.passive_unregistration_commit_count
	_expect(runtime.try_replace_snapshot(without_four).accepted, "single passive unequip succeeds")
	_expect(runtime.passive_runtime_for_slot(SkillSlotIds.PASSIVE_4) == null, "unequipped passive leaves no runtime")
	_expect_eq(runtime.passive_unregistration_commit_count, unregistration_before_remove + 1, "unequip records one unregistration batch")
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 3, "three unchanged passives remain unique")

	var restored_four := _seven_snapshot(
		&"",
		ACTIVE_WATER.skill_id,
		&"",
		PASSIVE_ENERGY.skill_id,
		runtime.snapshot().revision,
		PASSIVE_VITALITY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id
	)
	var registration_before_add := runtime.passive_registration_commit_count
	_expect(runtime.try_replace_snapshot(restored_four).accepted, "fourth passive re-equip succeeds")
	_expect_eq(runtime.passive_registration_commit_count, registration_before_add + 1, "re-equip registers only one new batch")
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "re-equipped four passives remain unique")

	var commits_before_death := port.commit_count
	var unregistration_before_death := runtime.passive_unregistration_commit_count
	runtime.on_owner_died()
	_expect(port.current.is_empty(), "death unregisters all passives")
	_expect_eq(runtime.passive_unregistration_commit_count, unregistration_before_death + 1, "death records one unregistration")
	runtime.on_owner_died()
	_expect_eq(port.commit_count, commits_before_death + 1, "repeat death is idempotent")

	var registration_before_respawn := runtime.passive_registration_commit_count
	runtime.on_owner_respawned()
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "respawn restores four unique passives")
	_expect_eq(runtime.passive_registration_commit_count, registration_before_respawn + 1, "respawn registers one batch")
	var commits_after_respawn := port.commit_count
	runtime.on_owner_respawned()
	_expect_eq(port.commit_count, commits_after_respawn, "repeat respawn is idempotent")

	var before_floor := _runtime_instances(runtime)
	var registration_before_floor := runtime.passive_registration_commit_count
	var unregistration_before_floor := runtime.passive_unregistration_commit_count
	runtime.on_floor_changed()
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "floor rebuild keeps four unique passives")
	_expect(not _same_instances(before_floor, _runtime_instances(runtime)), "floor rebuild creates one fresh runtime per passive")
	_expect_eq(runtime.passive_registration_commit_count, registration_before_floor + 1, "floor rebuild registers once")
	_expect_eq(runtime.passive_unregistration_commit_count, unregistration_before_floor + 1, "floor rebuild unregisters prior set once")

	var before_reload := _runtime_instances(runtime)
	var registration_before_reload := runtime.passive_registration_commit_count
	var unregistration_before_reload := runtime.passive_unregistration_commit_count
	runtime.on_run_reloaded()
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "run reload keeps four unique passives")
	_expect(not _same_instances(before_reload, _runtime_instances(runtime)), "run reload creates one fresh runtime per passive")
	_expect_eq(runtime.passive_registration_commit_count, registration_before_reload + 1, "run reload registers once")
	_expect_eq(runtime.passive_unregistration_commit_count, unregistration_before_reload + 1, "run reload unregisters prior set once")

	var commits_before_end := port.commit_count
	runtime.clear_for_run_end()
	_expect(runtime.registered_passive_skill_ids.is_empty(), "run end releases every passive")
	_expect(runtime.registered_passive_slot_ids.is_empty(), "run end clears slot audit")
	runtime.clear_for_run_end()
	runtime.on_run_reloaded()
	_expect_eq(port.commit_count, commits_before_end + 1, "repeat run end and later reload cannot resurrect passives")


func _test_run_session_immediate_authority_and_task27_protection() -> void:
	var catalog := _session_catalog()
	_expect(catalog.validation_error().is_empty(), "task28 RunSession catalog validates")
	var passive_port := RecordingPassivePort.new()
	passive_port.set_runtime_context(PassiveRuntimeContext.new(
		PassiveOwnerPort.new(),
		PassiveTargetPort.new()
	))
	var initial := _seven_snapshot(
		&"element_bolt",
		&"",
		&"",
		&"burning",
		3
	)
	var runtime := RuntimeSkillLoadout.new(catalog.equippable_gameplay_definitions(), initial, passive_port)
	var final_port := RejectingRuntimePort.new(runtime)
	var owned: Array[StringName] = [&"element_bolt", &"burning", &"unending"]
	var session := RunSession.new(
		catalog.reward_definitions(),
		catalog.relic_definitions,
		owned,
		[ElementIds.WATER, ElementIds.FIRE],
		final_port,
		GrowthEffectPort.new(),
		RunRulesSnapshot.legacy_enabled(),
		catalog,
		500
	)
	_reach_shop(session)
	var opened := session.open_shop_draft()
	_expect(opened.accepted and opened.draft != null, "RunSession opens authoritative shop draft")
	if not opened.accepted or opened.draft == null:
		return
	var draft := opened.draft
	var causes: Array[StringName] = []
	session.snapshot_changed.connect(func(_snapshot: RunSnapshot, cause: StringName) -> void:
		causes.append(cause)
	)
	var before := session.snapshot()
	var passive_commits_before := passive_port.commit_count
	var final_validate_before := final_port.validate_calls
	var illegal := _seven_snapshot(
		&"burning",
		&"",
		&"",
		&"",
		before.loadout.revision
	)
	var illegal_result := session.apply_shop_loadout_immediately(draft, illegal)
	_expect(not illegal_result.accepted and illegal_result.detail == &"passive_skill_in_active_slot", "RunSession rejects passive in active before final port")
	_expect_eq(final_port.validate_calls, final_validate_before, "RunSession type rejection does not call final port")
	_expect_session_unchanged(session, before, passive_port, passive_commits_before, causes, "type rejection")

	var valid := _seven_snapshot(
		&"element_bolt",
		&"",
		&"",
		&"unending",
		before.loadout.revision,
		&"burning"
	)
	var valid_result := session.apply_shop_loadout_immediately(draft, valid)
	_expect(valid_result.accepted, "owned strict seven-slot mapping commits immediately")
	_expect_eq(valid_result.run_snapshot.revision, before.revision + 1, "successful mapping advances run revision once")
	_expect_eq(valid_result.run_snapshot.loadout.revision, before.loadout.revision + 1, "successful mapping advances loadout revision once")
	_expect_eq(causes, [&"shop_loadout_applied"], "successful mapping publishes one notification")
	_expect(_economy_equal(before.economy, valid_result.run_snapshot.economy), "loadout change preserves Task27 dream dust ledger")
	_expect(_progress_equal(
		before.skills.progress_for(&"element_bolt"),
		valid_result.run_snapshot.skills.progress_for(&"element_bolt")
	), "loadout change preserves Task27 skill level and spend")

	var before_idempotent := session.snapshot()
	var passive_commits_before_idempotent := passive_port.commit_count
	var causes_before_idempotent := causes.size()
	var idempotent := session.apply_shop_loadout_immediately(draft, before_idempotent.loadout)
	_expect(idempotent.accepted, "same authoritative mapping is accepted idempotently")
	_expect_eq(session.snapshot().revision, before_idempotent.revision, "idempotent mapping advances no run revision")
	_expect_eq(session.snapshot().loadout.revision, before_idempotent.loadout.revision, "idempotent mapping advances no loadout revision")
	_expect_eq(passive_port.commit_count, passive_commits_before_idempotent, "idempotent mapping changes no passive registration")
	_expect_eq(causes.size(), causes_before_idempotent, "idempotent mapping emits no notification")

	final_port.reject_commit = true
	var before_rejection := session.snapshot()
	var passive_commits_before_rejection := passive_port.commit_count
	var rejected_candidate := _seven_snapshot(
		&"",
		&"element_bolt",
		&"",
		&"unending",
		before_rejection.loadout.revision,
		&"burning"
	)
	var final_rejection := session.apply_shop_loadout_immediately(draft, rejected_candidate)
	_expect(not final_rejection.accepted and final_rejection.detail == &"task28_final_port_rejected", "final port rejection is returned")
	_expect_session_unchanged(
		session,
		before_rejection,
		passive_port,
		passive_commits_before_rejection,
		causes,
		"final port rejection"
	)


func _expect_rejected_unchanged(
		runtime: RuntimeSkillLoadout,
		candidate: RuntimeLoadoutSnapshot,
		detail: StringName,
		before: RuntimeLoadoutSnapshot,
		port: RecordingPassivePort,
		before_commits: int
) -> void:
	var result := runtime.try_replace_snapshot(candidate)
	_expect(not result.accepted and result.detail == detail, "%s is rejected structurally" % String(detail))
	_expect(runtime.snapshot().same_mapping(before), "%s leaves mapping unchanged" % String(detail))
	_expect_eq(runtime.snapshot().revision, before.revision, "%s leaves revision unchanged" % String(detail))
	_expect_eq(port.commit_count, before_commits, "%s leaves passive registrations unchanged" % String(detail))


func _expect_session_unchanged(
		session: RunSession,
		before: RunSnapshot,
		passive_port: RecordingPassivePort,
		passive_commit_count: int,
		causes: Array[StringName],
		label: String
) -> void:
	var after := session.snapshot()
	_expect(after.loadout.same_mapping(before.loadout), "%s leaves RunSession mapping unchanged" % label)
	_expect_eq(after.loadout.revision, before.loadout.revision, "%s leaves loadout revision unchanged" % label)
	_expect_eq(after.revision, before.revision, "%s leaves run revision unchanged" % label)
	_expect_eq(passive_port.commit_count, passive_commit_count, "%s leaves passive port unchanged" % label)
	_expect(_economy_equal(after.economy, before.economy), "%s leaves dream dust unchanged" % label)
	_expect(_progress_equal(
		after.skills.progress_for(&"element_bolt"),
		before.skills.progress_for(&"element_bolt")
	), "%s leaves active level state unchanged" % label)
	_expect_eq(causes.size(), 1 if label == "final port rejection" else 0, "%s emits no new notification" % label)


func _reach_shop(session: RunSession) -> void:
	for room_number: int in range(1, 4):
		var room_id := StringName("task28_room_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "RunSession fixture begins room %d" % room_number)
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("task28_done_%d" % room_number),
			room_id,
			0
		)).accepted, "RunSession fixture completes room %d" % room_number)
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1),
			2800 + room_number
		)
		_expect(generated.accepted and not generated.reward_offer.options.is_empty(), "RunSession fixture generates reward %d" % room_number)
		if not generated.accepted or generated.reward_offer.options.is_empty():
			return
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "RunSession fixture claims reward %d" % room_number)
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		_expect(session.choose_route(route_id).accepted, "RunSession fixture chooses route %d" % room_number)


func _session_catalog() -> RunContentCatalog:
	var contents: Array[SkillContentDefinition] = FORMAL_CATALOG.skill_contents.duplicate()
	for index: int in 8:
		var skill := ACTIVE_WATER.duplicate(true) as SkillDefinition
		skill.skill_id = StringName("task28_filler_%d" % index)
		var content := SkillContentDefinition.new()
		content.skill_id = skill.skill_id
		content.display_name = "Task28 filler %d" % index
		content.description = "Deterministic reward route fixture"
		content.gameplay_definition = skill
		content.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
		content.reward_pool = true
		content.initial_reward_pool = true
		contents.append(content)
	var catalog := RunContentCatalog.new()
	catalog.skill_contents = contents
	catalog.fixed_basic_attack_id = FORMAL_CATALOG.fixed_basic_attack_id
	catalog.relic_definitions = []
	return catalog


func _task28_definitions() -> Array[SkillDefinition]:
	return [
		ACTIVE_BOLT,
		ACTIVE_WATER,
		ACTIVE_FIRE,
		PASSIVE_VITALITY,
		PASSIVE_ENERGY,
		PASSIVE_FOCUS,
		PASSIVE_BALANCE,
	]


func _passive_ids() -> Array[StringName]:
	return [
		PASSIVE_VITALITY.skill_id,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id,
	]


func _template_slots() -> Dictionary[StringName, SkillDefinition]:
	var result: Dictionary[StringName, SkillDefinition] = {}
	for slot_id: StringName in SkillSlotIds.all():
		result[slot_id] = null
	return result


func _seven_snapshot(
		active_1: StringName = &"",
		active_2: StringName = &"",
		active_3: StringName = &"",
		passive_1: StringName = &"",
		revision: int = 0,
		passive_2: StringName = &"",
		passive_3: StringName = &"",
		passive_4: StringName = &""
) -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new([
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, active_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, active_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, active_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, passive_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, passive_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3, passive_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4, passive_4),
	], revision)


func _legacy_four_snapshot(
		active_1: StringName,
		active_2: StringName,
		active_3: StringName,
		passive_1: StringName,
		revision: int = 0
) -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new([
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, active_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, active_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, active_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, passive_1),
	], revision)


func _runtime_instances(runtime: RuntimeSkillLoadout) -> Array[PassiveEffectRuntime]:
	var result: Array[PassiveEffectRuntime] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var instance := runtime.passive_runtime_for_slot(slot_id)
		if instance != null:
			result.append(instance)
	return result


func _same_instances(
		left: Array[PassiveEffectRuntime],
		right: Array[PassiveEffectRuntime]
) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true


func _unique_object_count(values: Array[PassiveEffectRuntime]) -> int:
	var unique: Array[PassiveEffectRuntime] = []
	for value: PassiveEffectRuntime in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _economy_equal(left: DreamDustSnapshot, right: DreamDustSnapshot) -> bool:
	return (
		left != null
		and right != null
		and left.balance == right.balance
		and left.total_earned == right.total_earned
		and left.total_spent_on_purchases == right.total_spent_on_purchases
		and left.total_spent_on_upgrades == right.total_spent_on_upgrades
		and left.total_refunded == right.total_refunded
	)


func _progress_equal(left: SkillProgressSnapshot, right: SkillProgressSnapshot) -> bool:
	return (
		left != null
		and right != null
		and left.skill_id == right.skill_id
		and left.activation_kind == right.activation_kind
		and left.level == right.level
		and left.cumulative_upgrade_spend == right.cumulative_upgrade_spend
		and left.acquisition_kind == right.acquisition_kind
	)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)
