class_name SharedLoadoutPersistenceAdapter
extends RefCounted

var restored: bool:
	get:
		return _restored

var migrated_legacy: bool:
	get:
		return _migrated_legacy

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
var _saved_snapshot: RuntimeLoadoutSnapshot
var _migration_overflow_skill_ids: Array[StringName] = []
var _legacy_state_retained: bool = false


func restore(
		shared_snapshot: RuntimeLoadoutSnapshot,
		current_element_id: StringName,
		available_element_ids: Array[StringName],
		legacy_loadouts: Array[SkillLoadout] = []
) -> bool:
	if _restored:
		return false
	if shared_snapshot != null:
		if not _has_shared_shape(shared_snapshot):
			return false
		_saved_snapshot = _copy_snapshot(shared_snapshot)
		_restored = true
		return true
	var migration := LegacyElementLoadoutMigrator.migrate_resources(
		current_element_id,
		available_element_ids,
		legacy_loadouts
	)
	if not migration.accepted or not _has_shared_shape(migration.snapshot):
		_legacy_state_retained = true
		return false
	_saved_snapshot = _copy_snapshot(migration.snapshot)
	_migration_overflow_skill_ids = migration.unequipped_skill_ids
	_migrated_legacy = true
	_restored = true
	_legacy_state_retained = false
	return true


func save_shared(snapshot: RuntimeLoadoutSnapshot) -> bool:
	if not _has_shared_shape(snapshot):
		return false
	_saved_snapshot = _copy_snapshot(snapshot)
	_restored = true
	_legacy_state_retained = false
	return true


static func _has_shared_shape(snapshot: RuntimeLoadoutSnapshot) -> bool:
	if snapshot == null or not snapshot.is_valid():
		return false
	if snapshot.entries.size() != SkillSlotIds.all().size():
		return false
	for slot_id: StringName in SkillSlotIds.all():
		if not snapshot.has_slot(slot_id):
			return false
	return true


static func _copy_snapshot(snapshot: RuntimeLoadoutSnapshot) -> RuntimeLoadoutSnapshot:
	if snapshot == null:
		return null
	return RuntimeLoadoutSnapshot.new(snapshot.entries, snapshot.revision)
