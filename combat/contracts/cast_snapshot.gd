class_name CastSnapshot
extends RefCounted

## Immutable cast-time data. Delivery identity deliberately does not belong in
## this snapshot and cannot be filled in after construction.

var cast_id: int:
	get:
		return _cast_id

var skill_id: StringName:
	get:
		return _skill_id

var root_owner_id: int:
	get:
		return _root_owner_id

var caster_id: int:
	get:
		return _caster_id

var team_id: StringName:
	get:
		return _team_id

var cast_element_id: StringName:
	get:
		return _cast_element_id

var stat_snapshot: CombatStatSnapshot:
	get:
		return _stat_snapshot

var validation_error: StringName:
	get:
		return _validation_error

var _cast_id: int
var _skill_id: StringName
var _root_owner_id: int
var _caster_id: int
var _team_id: StringName
var _cast_element_id: StringName
var _stat_snapshot: CombatStatSnapshot
var _validation_error: StringName = &""


func _init(
		p_cast_id: int,
		p_skill_id: StringName,
		p_root_owner_id: int,
		p_caster_id: int,
		p_team_id: StringName,
		p_cast_element_id: StringName,
		p_stat_snapshot: CombatStatSnapshot
) -> void:
	_cast_id = p_cast_id
	_skill_id = p_skill_id
	_root_owner_id = p_root_owner_id
	_caster_id = p_caster_id
	_team_id = p_team_id
	_cast_element_id = p_cast_element_id
	_stat_snapshot = p_stat_snapshot
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values() -> StringName:
	if _cast_id <= 0:
		return &"missing_cast_id"
	if _skill_id.is_empty():
		return &"missing_skill_id"
	if _root_owner_id <= 0:
		return &"missing_root_owner_id"
	if _caster_id <= 0:
		return &"missing_caster_id"
	if _team_id.is_empty():
		return &"missing_team_id"
	if not ElementIds.is_valid_payload_element(_cast_element_id):
		return &"unknown_cast_element_id"
	if _stat_snapshot == null or not _stat_snapshot.is_valid():
		return &"invalid_stat_snapshot"
	return &""
