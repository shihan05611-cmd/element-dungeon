class_name SharedFourSlotToSevenSlotMigrator
extends RefCounted

const LEGACY_FOUR_SLOT_IDS: Array[StringName] = [
	SkillSlotIds.ACTIVE_1,
	SkillSlotIds.ACTIVE_2,
	SkillSlotIds.ACTIVE_3,
	SkillSlotIds.PASSIVE_1,
]


static func migrate(
		legacy_or_native: RuntimeLoadoutSnapshot,
		skill_definitions: Array[SkillDefinition],
		owned_skill_ids: Array[StringName] = []
) -> SevenSlotMigrationResult:
	if legacy_or_native == null or not legacy_or_native.is_valid():
		return SevenSlotMigrationResult.rejected(&"invalid_snapshot_structure")
	var catalog: Dictionary[StringName, SkillDefinition] = {}
	for definition: SkillDefinition in skill_definitions:
		if definition == null or not definition.is_valid():
			return SevenSlotMigrationResult.rejected(&"invalid_skill_catalog_entry")
		if catalog.has(definition.skill_id):
			return SevenSlotMigrationResult.rejected(&"duplicate_skill_catalog_id")
		catalog[definition.skill_id] = definition

	var retained_owned := _owned_with_snapshot(owned_skill_ids, legacy_or_native)
	if _has_exact_shape(legacy_or_native, SkillSlotIds.all()):
		var native_error := _strict_validation_error(legacy_or_native, catalog)
		if not native_error.is_empty():
			return SevenSlotMigrationResult.rejected(native_error)
		return SevenSlotMigrationResult.success(
			legacy_or_native,
			retained_owned,
			_unequipped_owned(retained_owned, legacy_or_native),
			[],
			[],
			[],
			[],
			true,
			false
		)
	if not _has_exact_shape(legacy_or_native, LEGACY_FOUR_SLOT_IDS):
		return SevenSlotMigrationResult.rejected(&"unsupported_loadout_shape")

	var assignments: Dictionary[StringName, StringName] = {}
	for slot_id: StringName in SkillSlotIds.all():
		assignments[slot_id] = &""
	var duplicates: Array[StringName] = []
	var unknown: Array[StringName] = []
	var invalid_types: Array[StringName] = []
	var passive_overflow: Array[StringName] = []
	var seen: Array[StringName] = []
	var passive_index := 0
	var source_order: Array[StringName] = [
		SkillSlotIds.PASSIVE_1,
		SkillSlotIds.ACTIVE_1,
		SkillSlotIds.ACTIVE_2,
		SkillSlotIds.ACTIVE_3,
	]
	for source_slot: StringName in source_order:
		var skill_id := legacy_or_native.get_skill_id(source_slot)
		if skill_id.is_empty():
			continue
		if seen.has(skill_id):
			_append_unique(duplicates, skill_id)
			continue
		seen.append(skill_id)
		var skill := catalog.get(skill_id) as SkillDefinition
		if skill == null:
			_append_unique(unknown, skill_id)
			continue
		if source_slot == SkillSlotIds.PASSIVE_1:
			if not skill.is_passive_skill():
				_append_unique(invalid_types, skill_id)
				continue
			assignments[SkillSlotIds.PASSIVE_1] = skill_id
			passive_index = 1
			continue
		if skill.is_active_skill():
			assignments[source_slot] = skill_id
			continue
		if passive_index >= SkillSlotIds.passive().size():
			_append_unique(passive_overflow, skill_id)
			continue
		assignments[SkillSlotIds.passive()[passive_index]] = skill_id
		passive_index += 1

	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(slot_id, assignments[slot_id]))
	var migrated := RuntimeLoadoutSnapshot.new(entries, legacy_or_native.revision)
	return SevenSlotMigrationResult.success(
		migrated,
		retained_owned,
		_unequipped_owned(retained_owned, migrated),
		duplicates,
		unknown,
		invalid_types,
		passive_overflow,
		false,
		true
	)


static func _strict_validation_error(
		snapshot: RuntimeLoadoutSnapshot,
		catalog: Dictionary[StringName, SkillDefinition]
) -> StringName:
	var seen: Array[StringName] = []
	for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
		if not SkillSlotIds.is_known(entry.slot_id):
			return &"unknown_shared_slot"
		if entry.skill_id.is_empty():
			continue
		if seen.has(entry.skill_id):
			return &"duplicate_equipped_skill"
		seen.append(entry.skill_id)
		var skill := catalog.get(entry.skill_id) as SkillDefinition
		if skill == null:
			return &"unknown_skill_id"
		if SkillSlotIds.is_active(entry.slot_id) and not skill.is_active_skill():
			return &"passive_skill_in_active_slot"
		if SkillSlotIds.is_passive(entry.slot_id) and not skill.is_passive_skill():
			return &"active_skill_in_passive_slot"
	return &""


static func _has_exact_shape(
		snapshot: RuntimeLoadoutSnapshot,
		slot_ids: Array[StringName]
) -> bool:
	if snapshot == null or snapshot.entries.size() != slot_ids.size():
		return false
	for slot_id: StringName in slot_ids:
		if not snapshot.has_slot(slot_id):
			return false
	return true


static func _owned_with_snapshot(
		owned_skill_ids: Array[StringName],
		snapshot: RuntimeLoadoutSnapshot
) -> Array[StringName]:
	var result: Array[StringName] = []
	for skill_id: StringName in owned_skill_ids:
		_append_unique(result, skill_id)
	if snapshot != null:
		for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
			_append_unique(result, entry.skill_id)
	return result


static func _unequipped_owned(
		owned_skill_ids: Array[StringName],
		snapshot: RuntimeLoadoutSnapshot
) -> Array[StringName]:
	var equipped: Array[StringName] = []
	for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
		_append_unique(equipped, entry.skill_id)
	var result: Array[StringName] = []
	for skill_id: StringName in owned_skill_ids:
		if not equipped.has(skill_id):
			_append_unique(result, skill_id)
	return result


static func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)
