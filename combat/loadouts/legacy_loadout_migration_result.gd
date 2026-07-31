class_name LegacyLoadoutMigrationResult
extends RefCounted

var accepted: bool:
	get:
		return _accepted

var detail: StringName:
	get:
		return _detail

var snapshot: RuntimeLoadoutSnapshot:
	get:
		return _snapshot

var unequipped_skill_ids: Array[StringName]:
	get:
		return _unequipped_skill_ids.duplicate()

var _accepted: bool
var _detail: StringName
var _snapshot: RuntimeLoadoutSnapshot
var _unequipped_skill_ids: Array[StringName] = []


func _init(
		p_accepted: bool,
		p_detail: StringName,
		p_snapshot: RuntimeLoadoutSnapshot,
		p_unequipped_skill_ids: Array[StringName] = []
) -> void:
	_accepted = p_accepted
	_detail = p_detail
	_snapshot = p_snapshot
	_unequipped_skill_ids = p_unequipped_skill_ids.duplicate()


static func success(
		p_snapshot: RuntimeLoadoutSnapshot,
		p_unequipped_skill_ids: Array[StringName]
) -> LegacyLoadoutMigrationResult:
	return LegacyLoadoutMigrationResult.new(true, &"", p_snapshot, p_unequipped_skill_ids)


static func rejected(detail: StringName) -> LegacyLoadoutMigrationResult:
	return LegacyLoadoutMigrationResult.new(false, detail, null)
