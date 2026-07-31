class_name SkillExecutionSnapshot
extends RefCounted

enum MovementPolicy {
	LOCK_MOVEMENT,
	ALLOW_MOVEMENT,
}

var cast_snapshot: CastSnapshot:
	get:
		return _cast_snapshot

var skill_id: StringName:
	get:
		return _cast_snapshot.skill_id if _cast_snapshot != null else StringName()

var cast_id: int:
	get:
		return _cast_snapshot.cast_id if _cast_snapshot != null else 0

var cast_element_id: StringName:
	get:
		return _cast_snapshot.cast_element_id if _cast_snapshot != null else ElementIds.NONE

var stat_snapshot: CombatStatSnapshot:
	get:
		return _cast_snapshot.stat_snapshot if _cast_snapshot != null else null

var energy_before: int:
	get:
		return _energy_before

var maximum_energy: int:
	get:
		return _maximum_energy

var energy_spent: int:
	get:
		return _energy_spent

var movement_policy: MovementPolicy:
	get:
		return _movement_policy

var validation_error: StringName:
	get:
		return _validation_error

var _cast_snapshot: CastSnapshot
var _energy_before: int
var _maximum_energy: int
var _energy_spent: int
var _movement_policy: MovementPolicy
var _validation_error: StringName = &""


func _init(
		p_cast_snapshot: CastSnapshot,
		p_energy_before: int,
		p_maximum_energy: int,
		p_energy_spent: int,
		p_movement_policy: MovementPolicy,
		p_validation_error: StringName = &""
) -> void:
	_cast_snapshot = p_cast_snapshot
	_energy_before = p_energy_before
	_maximum_energy = p_maximum_energy
	_energy_spent = p_energy_spent
	_movement_policy = p_movement_policy
	_validation_error = p_validation_error
	if _validation_error.is_empty():
		_validation_error = _validate_base()


func is_valid() -> bool:
	return _validation_error.is_empty()


func runtime_payload() -> RuntimeAttackPayload:
	return null


func _validate_base() -> StringName:
	if _cast_snapshot == null or not _cast_snapshot.is_valid():
		return &"invalid_cast_snapshot"
	if _maximum_energy < 0 or _energy_before < 0 or _energy_before > _maximum_energy:
		return &"invalid_energy_snapshot"
	if _energy_spent < 0 or _energy_spent > _energy_before:
		return &"invalid_energy_spent"
	if _movement_policy not in [MovementPolicy.LOCK_MOVEMENT, MovementPolicy.ALLOW_MOVEMENT]:
		return &"invalid_movement_policy"
	return &""
