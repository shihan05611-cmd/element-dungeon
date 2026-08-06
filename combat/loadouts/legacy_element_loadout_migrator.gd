class_name LegacyElementLoadoutMigrator
extends RefCounted

## Pure and deterministic one-time migration: current element first, then the
## remaining configured order. Known active/passive skills fill their strict
## seven-slot partitions; overflow remains owned but unequipped.

static func migrate(
		current_element_id: StringName,
		available_element_ids: Array[StringName],
		legacy_snapshots: Array[LegacyElementLoadoutSnapshot],
		revision: int = 0,
		skill_definitions: Array[SkillDefinition] = []
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
	var definitions_by_id: Dictionary[StringName, SkillDefinition] = {}
	for definition: SkillDefinition in skill_definitions:
		if definition == null or not definition.is_valid():
			return LegacyLoadoutMigrationResult.rejected(&"invalid_skill_catalog_entry")
		if definitions_by_id.has(definition.skill_id):
			return LegacyLoadoutMigrationResult.rejected(&"duplicate_skill_catalog_id")
		definitions_by_id[definition.skill_id] = definition
	var active_skill_ids: Array[StringName] = []
	var passive_skill_ids: Array[StringName] = []
	var overflow: Array[StringName] = []
	for skill_id: StringName in unique_skill_ids:
		var definition := definitions_by_id.get(skill_id) as SkillDefinition
		if definition == null and not skill_definitions.is_empty():
			overflow.append(skill_id)
		elif definition != null and definition.is_passive_skill():
			if passive_skill_ids.size() < SkillSlotIds.passive().size():
				passive_skill_ids.append(skill_id)
			else:
				overflow.append(skill_id)
		elif active_skill_ids.size() < SkillSlotIds.active().size():
			active_skill_ids.append(skill_id)
		else:
			overflow.append(skill_id)
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	var active_slots := SkillSlotIds.active()
	for index in active_slots.size():
		var skill_id := active_skill_ids[index] if index < active_skill_ids.size() else StringName()
		entries.append(RuntimeLoadoutSlotSnapshot.new(active_slots[index], skill_id))
	var passive_slots := SkillSlotIds.passive()
	for index in passive_slots.size():
		var skill_id := passive_skill_ids[index] if index < passive_skill_ids.size() else StringName()
		entries.append(RuntimeLoadoutSlotSnapshot.new(passive_slots[index], skill_id))
	return LegacyLoadoutMigrationResult.success(
		RuntimeLoadoutSnapshot.new(entries, revision),
		overflow
	)


static func migrate_resources(
		current_element_id: StringName,
		available_element_ids: Array[StringName],
		legacy_loadouts: Array[SkillLoadout],
		revision: int = 0,
		skill_definitions: Array[SkillDefinition] = []
) -> LegacyLoadoutMigrationResult:
	var snapshots: Array[LegacyElementLoadoutSnapshot] = []
	var definitions := skill_definitions.duplicate()
	for loadout: SkillLoadout in legacy_loadouts:
		snapshots.append(LegacyElementLoadoutSnapshot.from_resource(loadout))
		if loadout == null:
			continue
		for slot_id: StringName in loadout.slots:
			var definition := loadout.get_skill(slot_id)
			if definition != null and not definitions.has(definition):
				definitions.append(definition)
	return migrate(current_element_id, available_element_ids, snapshots, revision, definitions)
