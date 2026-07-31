class_name LegacyElementLoadoutMigrator
extends RefCounted

## Pure and deterministic one-time migration: current element first, then the
## remaining configured order. The first three unique skills fill active slots;
## passive_1 stays empty and overflow remains owned but unequipped.

static func migrate(
		current_element_id: StringName,
		available_element_ids: Array[StringName],
		legacy_snapshots: Array[LegacyElementLoadoutSnapshot],
		revision: int = 0
) -> LegacyLoadoutMigrationResult:
	if current_element_id.is_empty() or not available_element_ids.has(current_element_id):
		return LegacyLoadoutMigrationResult.rejected(&"invalid_current_element")
	var ordered_elements: Array[StringName] = [current_element_id]
	for element_id: StringName in available_element_ids:
		if element_id.is_empty() or element_id == ElementIds.NONE:
			return LegacyLoadoutMigrationResult.rejected(&"invalid_available_element")
		if ordered_elements.has(element_id):
			continue
		ordered_elements.append(element_id)
	var by_element: Dictionary[StringName, LegacyElementLoadoutSnapshot] = {}
	for legacy: LegacyElementLoadoutSnapshot in legacy_snapshots:
		if legacy == null or not legacy.is_valid():
			return LegacyLoadoutMigrationResult.rejected(&"invalid_legacy_loadout")
		if by_element.has(legacy.element_id):
			return LegacyLoadoutMigrationResult.rejected(&"duplicate_legacy_element")
		by_element[legacy.element_id] = legacy
	var unique_skill_ids: Array[StringName] = []
	for element_id: StringName in ordered_elements:
		var legacy := by_element.get(element_id) as LegacyElementLoadoutSnapshot
		if legacy == null:
			continue
		for skill_id: StringName in legacy.ordered_skill_ids:
			if not unique_skill_ids.has(skill_id):
				unique_skill_ids.append(skill_id)
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	var active_slots := SkillSlotIds.active()
	for index in active_slots.size():
		var skill_id := unique_skill_ids[index] if index < unique_skill_ids.size() else StringName()
		entries.append(RuntimeLoadoutSlotSnapshot.new(active_slots[index], skill_id))
	entries.append(RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1))
	var overflow: Array[StringName] = []
	for index in range(active_slots.size(), unique_skill_ids.size()):
		overflow.append(unique_skill_ids[index])
	return LegacyLoadoutMigrationResult.success(
		RuntimeLoadoutSnapshot.new(entries, revision),
		overflow
	)


static func migrate_resources(
		current_element_id: StringName,
		available_element_ids: Array[StringName],
		legacy_loadouts: Array[SkillLoadout],
		revision: int = 0
) -> LegacyLoadoutMigrationResult:
	var snapshots: Array[LegacyElementLoadoutSnapshot] = []
	for loadout: SkillLoadout in legacy_loadouts:
		snapshots.append(LegacyElementLoadoutSnapshot.from_resource(loadout))
	return migrate(current_element_id, available_element_ids, snapshots, revision)
