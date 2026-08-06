class_name RuntimeSkillLoadout
extends RuntimeLoadoutPort

signal loadout_replaced(previous: RuntimeLoadoutSnapshot, current: RuntimeLoadoutSnapshot)

var configuration_error: StringName:
	get:
		return _configuration_error

var registered_passive_skill_ids: Array[StringName]:
	get:
		return _passive_controller.registered_skill_ids

var registered_passive_slot_ids: Array[StringName]:
	get:
		return _passive_controller.registered_slot_ids

var passive_registration_commit_count: int:
	get:
		return _passive_controller.registration_commit_count

var passive_unregistration_commit_count: int:
	get:
		return _passive_controller.unregistration_commit_count


var _catalog: Dictionary[StringName, SkillDefinition] = {}
var _current: RuntimeLoadoutSnapshot
var _passive_controller: PassiveSkillController
var _configuration_error: StringName = &""


func _init(
		skill_definitions: Array[SkillDefinition] = [],
		initial: RuntimeLoadoutSnapshot = null,
		passive_effect_port: PassiveEffectPort = null
) -> void:
	_passive_controller = PassiveSkillController.new(passive_effect_port)
	for skill: SkillDefinition in skill_definitions:
		if skill == null or not skill.is_valid():
			_set_configuration_error(&"invalid_skill_catalog_entry")
			continue
		var execution_error := _execution_catalog_validation_error(skill)
		if not execution_error.is_empty():
			_set_configuration_error(execution_error)
			continue
		if _catalog.has(skill.skill_id):
			_set_configuration_error(&"duplicate_skill_catalog_id")
			continue
		_catalog[skill.skill_id] = skill
	# Construction restores persisted state; it is not a new equipment
	# transaction and therefore must preserve any persisted revision exactly.
	_current = _empty_snapshot(initial.revision if initial != null else 0)
	if initial != null:
		var validation := validate_snapshot(initial)
		if not validation.accepted:
			_set_configuration_error(validation.detail)
		else:
			_current = RuntimeLoadoutSnapshot.new(
				validation.snapshot.entries,
				validation.snapshot.revision
			)
			_passive_controller.commit_validated_replacement(
				_passive_bindings_for(_current),
				_passive_slot_ids_for(_current)
			)


func snapshot() -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new(_current.entries, _current.revision)


func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
	if not _configuration_error.is_empty():
		return RuntimeLoadoutChangeResult.rejected(_configuration_error, snapshot())
	if candidate == null or not candidate.is_valid():
		return RuntimeLoadoutChangeResult.rejected(&"invalid_snapshot_structure", snapshot())
	if candidate.revision != _current.revision:
		return RuntimeLoadoutChangeResult.rejected(&"stale_loadout_revision", snapshot())
	var normalized := candidate
	if _has_legacy_four_slot_shape(candidate):
		var migration := SharedFourSlotToSevenSlotMigrator.migrate(
			candidate,
			_catalog_definitions()
		)
		if not migration.accepted:
			return RuntimeLoadoutChangeResult.rejected(migration.detail, snapshot())
		normalized = migration.snapshot
	if normalized.entries.size() != SkillSlotIds.all().size():
		return RuntimeLoadoutChangeResult.rejected(&"expected_seven_shared_slots", snapshot())
	for entry: RuntimeLoadoutSlotSnapshot in normalized.entries:
		if not SkillSlotIds.is_known(entry.slot_id):
			return RuntimeLoadoutChangeResult.rejected(&"unknown_shared_slot", snapshot())
	for slot_id: StringName in SkillSlotIds.all():
		if not normalized.has_slot(slot_id):
			return RuntimeLoadoutChangeResult.rejected(&"missing_shared_slot", snapshot())
	var seen_skill_ids: Array[StringName] = []
	for entry: RuntimeLoadoutSlotSnapshot in normalized.entries:
		if entry.skill_id.is_empty():
			continue
		if seen_skill_ids.has(entry.skill_id):
			return RuntimeLoadoutChangeResult.rejected(&"duplicate_equipped_skill", snapshot())
		seen_skill_ids.append(entry.skill_id)
		var skill := _catalog.get(entry.skill_id) as SkillDefinition
		if skill == null:
			return RuntimeLoadoutChangeResult.rejected(&"unknown_skill_id", snapshot())
		if SkillSlotIds.is_active(entry.slot_id) and not skill.is_active_skill():
			return RuntimeLoadoutChangeResult.rejected(&"passive_skill_in_active_slot", snapshot())
		if SkillSlotIds.is_passive(entry.slot_id) and not skill.is_passive_skill():
			return RuntimeLoadoutChangeResult.rejected(&"active_skill_in_passive_slot", snapshot())
	var bindings := _passive_bindings_for(normalized)
	var passive_error := _passive_controller.validation_error(
		bindings,
		_passive_slot_ids_for(normalized)
	)
	if not passive_error.is_empty():
		return RuntimeLoadoutChangeResult.rejected(passive_error, snapshot())
	return RuntimeLoadoutChangeResult.success(normalized)


func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
	var validation := validate_snapshot(candidate)
	if not validation.accepted:
		return validation
	var normalized := validation.snapshot
	if _current.same_mapping(normalized):
		return RuntimeLoadoutChangeResult.success(snapshot())
	var previous := snapshot()
	var committed := RuntimeLoadoutSnapshot.new(normalized.entries, _current.revision + 1)
	var bindings := _passive_bindings_for(committed)
	# Both changes become observable only after pure validation has succeeded.
	_current = committed
	_passive_controller.commit_validated_replacement(
		bindings,
		_passive_slot_ids_for(committed)
	)
	loadout_replaced.emit(previous, snapshot())
	return RuntimeLoadoutChangeResult.success(snapshot())


func get_skill_for_slot(slot_id: StringName) -> SkillDefinition:
	var canonical := SkillSlotIds.canonicalize_input(slot_id)
	var skill_id := _current.get_skill_id(canonical)
	return _catalog.get(skill_id) as SkillDefinition


func get_skill(skill_id: StringName) -> SkillDefinition:
	return _catalog.get(skill_id) as SkillDefinition




func on_owner_died() -> void:
	_passive_controller.deactivate()


func on_owner_respawned() -> void:
	_passive_controller.reactivate()


func on_floor_changed() -> void:
	_passive_controller.rebuild()


func on_run_reloaded() -> void:
	_passive_controller.rebuild()


func clear_for_run_end() -> void:
	_passive_controller.clear()


func passive_runtime_for_slot(slot_id: StringName) -> PassiveEffectRuntime:
	return _passive_controller.runtime_for_slot(slot_id)


func _passive_bindings_for(candidate: RuntimeLoadoutSnapshot) -> Array[PassiveEffectBinding]:
	var result: Array[PassiveEffectBinding] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var skill_id := candidate.get_skill_id(slot_id)
		var skill := _catalog.get(skill_id) as SkillDefinition
		if skill == null or not skill.is_passive_skill():
			continue
		result.append(PassiveEffectBinding.new(
			skill.skill_id,
			skill.passive_effect_definition,
			skill.element_policy,
			skill.required_element_id
		))
	return result


func _passive_slot_ids_for(candidate: RuntimeLoadoutSnapshot) -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var skill_id := candidate.get_skill_id(slot_id)
		var skill := _catalog.get(skill_id) as SkillDefinition
		if skill != null and skill.is_passive_skill():
			result.append(slot_id)
	return result


func _set_configuration_error(error: StringName) -> void:
	if _configuration_error.is_empty():
		_configuration_error = error


func _catalog_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for skill_id: StringName in _catalog:
		result.append(_catalog[skill_id])
	return result


static func _has_legacy_four_slot_shape(candidate: RuntimeLoadoutSnapshot) -> bool:
	if candidate == null or candidate.entries.size() != 4:
		return false
	for slot_id: StringName in SharedFourSlotToSevenSlotMigrator.LEGACY_FOUR_SLOT_IDS:
		if not candidate.has_slot(slot_id):
			return false
	return true


static func _execution_catalog_validation_error(skill: SkillDefinition) -> StringName:
	if skill == null or not skill.is_active_skill():
		return &""
	if skill.execution_definition == null:
		return &"missing_execution_definition"
	return skill.execution_definition.catalog_validation_error()


static func _empty_snapshot(revision: int) -> RuntimeLoadoutSnapshot:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(slot_id))
	return RuntimeLoadoutSnapshot.new(entries, revision)
