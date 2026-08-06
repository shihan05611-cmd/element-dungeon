class_name SevenSlotMigrationResult
extends RefCounted

var accepted: bool:
	get:
		return _accepted

var detail: StringName:
	get:
		return _detail

var snapshot: RuntimeLoadoutSnapshot:
	get:
		return _copy_snapshot(_snapshot)

var retained_owned_skill_ids: Array[StringName]:
	get:
		return _retained_owned_skill_ids.duplicate()

var unequipped_skill_ids: Array[StringName]:
	get:
		return _unequipped_skill_ids.duplicate()

var duplicate_skill_ids: Array[StringName]:
	get:
		return _duplicate_skill_ids.duplicate()

var unknown_skill_ids: Array[StringName]:
	get:
		return _unknown_skill_ids.duplicate()

var invalid_type_skill_ids: Array[StringName]:
	get:
		return _invalid_type_skill_ids.duplicate()

var passive_overflow_skill_ids: Array[StringName]:
	get:
		return _passive_overflow_skill_ids.duplicate()

var native_seven_slot: bool:
	get:
		return _native_seven_slot

var migrated_legacy_four_slot: bool:
	get:
		return _migrated_legacy_four_slot

var _accepted: bool
var _detail: StringName
var _snapshot: RuntimeLoadoutSnapshot
var _retained_owned_skill_ids: Array[StringName] = []
var _unequipped_skill_ids: Array[StringName] = []
var _duplicate_skill_ids: Array[StringName] = []
var _unknown_skill_ids: Array[StringName] = []
var _invalid_type_skill_ids: Array[StringName] = []
var _passive_overflow_skill_ids: Array[StringName] = []
var _native_seven_slot: bool
var _migrated_legacy_four_slot: bool


func _init(
		p_accepted: bool,
		p_detail: StringName,
		p_snapshot: RuntimeLoadoutSnapshot = null,
		p_retained_owned_skill_ids: Array[StringName] = [],
		p_unequipped_skill_ids: Array[StringName] = [],
		p_duplicate_skill_ids: Array[StringName] = [],
		p_unknown_skill_ids: Array[StringName] = [],
		p_invalid_type_skill_ids: Array[StringName] = [],
		p_passive_overflow_skill_ids: Array[StringName] = [],
		p_native_seven_slot: bool = false,
		p_migrated_legacy_four_slot: bool = false
) -> void:
	_accepted = p_accepted
	_detail = p_detail
	_snapshot = _copy_snapshot(p_snapshot)
	_retained_owned_skill_ids = _unique_copy(p_retained_owned_skill_ids)
	_unequipped_skill_ids = _unique_copy(p_unequipped_skill_ids)
	_duplicate_skill_ids = _unique_copy(p_duplicate_skill_ids)
	_unknown_skill_ids = _unique_copy(p_unknown_skill_ids)
	_invalid_type_skill_ids = _unique_copy(p_invalid_type_skill_ids)
	_passive_overflow_skill_ids = _unique_copy(p_passive_overflow_skill_ids)
	_native_seven_slot = p_native_seven_slot
	_migrated_legacy_four_slot = p_migrated_legacy_four_slot


static func rejected(error: StringName) -> SevenSlotMigrationResult:
	return SevenSlotMigrationResult.new(false, error)


static func success(
		result_snapshot: RuntimeLoadoutSnapshot,
		owned_skill_ids: Array[StringName],
		unequipped: Array[StringName] = [],
		duplicates: Array[StringName] = [],
		unknown: Array[StringName] = [],
		invalid_types: Array[StringName] = [],
		passive_overflow: Array[StringName] = [],
		is_native_seven_slot: bool = false,
		is_migrated_legacy_four_slot: bool = false
) -> SevenSlotMigrationResult:
	return SevenSlotMigrationResult.new(
		true,
		&"",
		result_snapshot,
		owned_skill_ids,
		unequipped,
		duplicates,
		unknown,
		invalid_types,
		passive_overflow,
		is_native_seven_slot,
		is_migrated_legacy_four_slot
	)


static func _copy_snapshot(value: RuntimeLoadoutSnapshot) -> RuntimeLoadoutSnapshot:
	if value == null:
		return null
	return RuntimeLoadoutSnapshot.new(value.entries, value.revision)


static func _unique_copy(values: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in values:
		if not value.is_empty() and not result.has(value):
			result.append(value)
	return result
