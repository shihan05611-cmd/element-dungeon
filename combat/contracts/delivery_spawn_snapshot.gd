class_name DeliverySpawnSnapshot
extends RefCounted

## Immutable transform and direction captured when a cast is accepted. This is
## delivery placement data, not a replacement for Agent A's CastSnapshot.

var initial_transform: Transform2D:
	get:
		return _initial_transform

var direction: Vector2:
	get:
		return _direction

var validation_error: StringName:
	get:
		return _validation_error

var _initial_transform: Transform2D
var _direction: Vector2
var _validation_error: StringName = &""


func _init(
		p_initial_transform: Transform2D = Transform2D.IDENTITY,
		p_direction: Vector2 = Vector2.RIGHT
) -> void:
	_initial_transform = p_initial_transform
	_direction = p_direction.normalized() if not p_direction.is_zero_approx() else Vector2.ZERO
	_validation_error = _validate_values(p_direction)


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values(original_direction: Vector2) -> StringName:
	if not _is_finite_vector(_initial_transform.x):
		return &"invalid_transform_x"
	if not _is_finite_vector(_initial_transform.y):
		return &"invalid_transform_y"
	if not _is_finite_vector(_initial_transform.origin):
		return &"invalid_transform_origin"
	if not _is_finite_vector(original_direction) or original_direction.is_zero_approx():
		return &"invalid_direction"
	return &""


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
