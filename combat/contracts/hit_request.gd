class_name HitRequest
extends RefCounted

## Immutable delivery-to-target request. The target is the CombatReceiver on
## which `receive_hit` is called, so this contract contains no target_receiver.

var cast_snapshot: CastSnapshot:
	get:
		return _cast_snapshot

var payload: RuntimeAttackPayload:
	get:
		return _payload

var delivery_id: int:
	get:
		return _delivery_id

var hit_index: int:
	get:
		return _hit_index

var hit_position: Vector2:
	get:
		return _hit_position

var hit_direction: Vector2:
	get:
		return _hit_direction

var validation_error: StringName:
	get:
		return _validation_error

var _cast_snapshot: CastSnapshot
var _payload: RuntimeAttackPayload
var _delivery_id: int
var _hit_index: int
var _hit_position: Vector2
var _hit_direction: Vector2
var _validation_error: StringName = &""


func _init(
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload,
		p_delivery_id: int,
		p_hit_index: int,
		p_hit_position: Vector2,
		p_hit_direction: Vector2
) -> void:
	_cast_snapshot = p_cast_snapshot
	_payload = p_payload
	_delivery_id = p_delivery_id
	_hit_index = p_hit_index
	_hit_position = p_hit_position
	_hit_direction = p_hit_direction
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func identity_key() -> String:
	if _cast_snapshot == null:
		return "invalid"
	return "%d:%d:%d" % [_cast_snapshot.cast_id, _delivery_id, _hit_index]


func _validate_values() -> StringName:
	if _cast_snapshot == null or not _cast_snapshot.is_valid():
		return &"invalid_cast_snapshot"
	if _payload == null or not _payload.is_valid():
		return &"invalid_payload"
	if _delivery_id <= 0:
		return &"missing_delivery_id"
	if _hit_index < 0:
		return &"missing_hit_index"
	if not _is_finite_vector(_hit_position):
		return &"invalid_hit_position"
	if not _is_finite_vector(_hit_direction):
		return &"invalid_hit_direction"
	return &""


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
