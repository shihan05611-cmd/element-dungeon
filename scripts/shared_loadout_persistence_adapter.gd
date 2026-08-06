class_name SharedLoadoutPersistenceAdapter
extends RefCounted

var restored: bool:
	get:
		return _restored

var migrated_legacy: bool:
	get:
		return _migrated_legacy

var migrated_shared_four_slot: bool:
	get:
		return _migrated_shared_four_slot

var seven_slot_migration_result: SevenSlotMigrationResult:
	get:
		return _seven_slot_migration_result

var saved_snapshot: RuntimeLoadoutSnapshot:
	get:
		return _copy_snapshot(_saved_snapshot)

var migration_overflow_skill_ids: Array[StringName]:
	get:
		return _migration_overflow_skill_ids.duplicate()

var legacy_state_retained: bool:
	get:
		return _legacy_state_retained

var _restored: bool = false
var _migrated_legacy: bool = false
var _migrated_shared_four_slot: bool = false
var _saved_snapshot: RuntimeLoadoutSnapshot
var _migration_overflow_skill_ids: Array[StringName] = []
var _legacy_state_retained: bool = false
var _seven_slot_migration_result: SevenSlotMigrationResult


func restore(
		shared_snapshot: RuntimeLoadoutSnapshot,
		current_element_id: StringName,
		available_element_ids: Array[StringName],
		legacy_loadouts: Array[SkillLoadout] = [],
		skill_definitions: Array[SkillDefinition] = [],
		owned_skill_ids: Array[StringName] = []
) -> bool:
	if _restored:
		return false
	if shared_snapshot != null:
		if _has_seven_slot_shape(shared_snapshot):
			_saved_snapshot = _copy_snapshot(shared_snapshot)
			_restored = true
			return true
		if not _has_legacy_four_slot_shape(shared_snapshot):
			_legacy_state_retained = true
			return false
		var definitions := _resolved_definitions(skill_definitions, legacy_loadouts)
		_seven_slot_migration_result = SharedFourSlotToSevenSlotMigrator.migrate(
			shared_snapshot,
			definitions,
			owned_skill_ids
		)
		if (
			not _seven_slot_migration_result.accepted
			or not _has_seven_slot_shape(_seven_slot_migration_result.snapshot)
		):
			_legacy_state_retained = true
			return false
		_saved_snapshot = _seven_slot_migration_result.snapshot
		_migration_overflow_skill_ids = _seven_slot_migration_result.unequipped_skill_ids
		_migrated_shared_four_slot = true
		_migrated_legacy = true
		_restored = true
		_legacy_state_retained = false
		return true
	var migration := LegacyElementLoadoutMigrator.migrate_resources(
		current_element_id,
		available_element_ids,
		legacy_loadouts,
		0,
		skill_definitions
	)
	if not migration.accepted or not _has_seven_slot_shape(migration.snapshot):
		_legacy_state_retained = true
		return false
	_saved_snapshot = _copy_snapshot(migration.snapshot)
	_migration_overflow_skill_ids = migration.unequipped_skill_ids
	_migrated_legacy = true
	_restored = true
	_legacy_state_retained = false
	return true


func save_shared(snapshot: RuntimeLoadoutSnapshot) -> bool:
	if not _has_seven_slot_shape(snapshot):
		return false
	_saved_snapshot = _copy_snapshot(snapshot)
	_restored = true
	_legacy_state_retained = false
	return true


static func _has_seven_slot_shape(snapshot: RuntimeLoadoutSnapshot) -> bool:
	if snapshot == null or not snapshot.is_valid():
		return false
	if snapshot.entries.size() != SkillSlotIds.all().size():
		return false
	for slot_id: StringName in SkillSlotIds.all():
		if not snapshot.has_slot(slot_id):
			return false
	return true


static func _has_legacy_four_slot_shape(snapshot: RuntimeLoadoutSnapshot) -> bool:
	if snapshot == null or not snapshot.is_valid() or snapshot.entries.size() != 4:
		return false
	for slot_id: StringName in SharedFourSlotToSevenSlotMigrator.LEGACY_FOUR_SLOT_IDS:
		if not snapshot.has_slot(slot_id):
			return false
	return true


static func _resolved_definitions(
		explicit_definitions: Array[SkillDefinition],
		legacy_loadouts: Array[SkillLoadout]
) -> Array[SkillDefinition]:
	var result := explicit_definitions.duplicate()
	for loadout: SkillLoadout in legacy_loadouts:
		if loadout == null:
			continue
		for slot_id: StringName in loadout.slots:
			var definition := loadout.get_skill(slot_id)
			if definition != null and not result.has(definition):
				result.append(definition)
	var formal := load("res://resources/content/run_content_catalog.tres") as RunContentCatalog
	if formal != null:
		for definition: SkillDefinition in formal.gameplay_definitions():
			if definition != null and not result.has(definition):
				result.append(definition)
	return result


static func _copy_snapshot(snapshot: RuntimeLoadoutSnapshot) -> RuntimeLoadoutSnapshot:
	if snapshot == null:
		return null
	return RuntimeLoadoutSnapshot.new(snapshot.entries, snapshot.revision)
