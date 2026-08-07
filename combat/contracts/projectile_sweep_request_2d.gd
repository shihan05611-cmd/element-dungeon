class_name ProjectileSweepRequest2D
extends RefCounted

## Immutable input for one synchronous swept-shape contact query.

var source: Node2D:
	get:
		return _source

var world: World2D:
	get:
		return _world

var start_transform: Transform2D:
	get:
		return _start_transform

var direction: Vector2:
	get:
		return _direction

var distance: float:
	get:
		return _distance

var profile: ProjectileSweepProfile2D:
	get:
		return _profile

var source_team_id: StringName:
	get:
		return _source_team_id

var require_legal_enemy: bool:
	get:
		return _require_legal_enemy

var _source: Node2D
var _world: World2D
var _start_transform: Transform2D
var _direction: Vector2
var _distance: float
var _profile: ProjectileSweepProfile2D
var _source_team_id: StringName
var _require_legal_enemy: bool


func _init(
		p_source: Node2D,
		p_world: World2D,
		p_start_transform: Transform2D,
		p_direction: Vector2,
		p_distance: float,
		p_profile: ProjectileSweepProfile2D,
		p_source_team_id: StringName = &"",
		p_require_legal_enemy: bool = false
) -> void:
	_source = p_source
	_world = p_world
	_start_transform = p_start_transform
	_direction = p_direction.normalized() if not p_direction.is_zero_approx() else Vector2.ZERO
	_distance = p_distance
	_profile = p_profile
	_source_team_id = p_source_team_id
	_require_legal_enemy = p_require_legal_enemy


func validation_error() -> StringName:
	var live_source := source
	if (
		live_source == null
		or not is_instance_valid(live_source)
		or live_source.is_queued_for_deletion()
		or not live_source.is_inside_tree()
	):
		return &"invalid_sweep_source"
	if _world == null or live_source.get_world_2d() != _world:
		return &"invalid_sweep_world"
	if not _is_finite_transform(_start_transform):
		return &"invalid_sweep_transform"
	if not _is_finite_vector(_direction) or _direction.is_zero_approx():
		return &"invalid_sweep_direction"
	if not is_finite(_distance) or _distance <= 0.0:
		return &"invalid_sweep_distance"
	if _profile == null:
		return &"missing_sweep_profile"
	var profile_error := _profile.validation_error()
	if not profile_error.is_empty():
		return profile_error
	if _distance > _profile.max_distance + 0.000001:
		return &"sweep_distance_exceeds_profile"
	if _require_legal_enemy and _source_team_id.is_empty():
		return &"missing_sweep_source_team"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


static func _is_finite_transform(value: Transform2D) -> bool:
	return (
		_is_finite_vector(value.x)
		and _is_finite_vector(value.y)
		and _is_finite_vector(value.origin)
	)


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
