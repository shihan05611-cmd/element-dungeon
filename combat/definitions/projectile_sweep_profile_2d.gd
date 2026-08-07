class_name ProjectileSweepProfile2D
extends Resource

## Shared, data-only authority for swept projectile contact rules.

@export var shape: Shape2D
@export_range(0.001, 1000000.0, 0.001, "or_greater") var speed: float = 600.0
@export_range(0.001, 1000000.0, 0.001, "or_greater") var max_distance: float = 1000.0
@export_flags_2d_physics var hurtbox_collision_mask: int = 1
@export_flags_2d_physics var blocking_collision_mask: int = 2
@export_range(0.0, 10.0, 0.001, "or_greater") var query_margin: float = 0.001
@export_range(0.0, 10.0, 0.001, "or_greater") var wall_tie_distance: float = 0.01
@export_range(1, 256, 1) var max_contact_results: int = 64


func validation_error() -> StringName:
	if shape == null:
		return &"missing_projectile_shape"
	if not is_finite(speed) or speed <= 0.0:
		return &"invalid_speed"
	if not is_finite(max_distance) or max_distance <= 0.0:
		return &"invalid_max_distance"
	if hurtbox_collision_mask < 0:
		return &"invalid_hurtbox_collision_mask"
	if blocking_collision_mask < 0:
		return &"invalid_blocking_collision_mask"
	if not is_finite(query_margin) or query_margin < 0.0:
		return &"invalid_query_margin"
	if not is_finite(wall_tie_distance) or wall_tie_distance < 0.0:
		return &"invalid_wall_tie_distance"
	if max_contact_results <= 0:
		return &"invalid_max_contact_results"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func configure_from_legacy(
		p_shape: Shape2D,
		p_speed: float,
		p_max_distance: float,
		p_hurtbox_collision_mask: int,
		p_blocking_collision_mask: int,
		p_query_margin: float,
		p_wall_tie_distance: float,
		p_max_contact_results: int
) -> void:
	shape = p_shape
	speed = p_speed
	max_distance = p_max_distance
	hurtbox_collision_mask = p_hurtbox_collision_mask
	blocking_collision_mask = p_blocking_collision_mask
	query_margin = p_query_margin
	wall_tie_distance = p_wall_tie_distance
	max_contact_results = p_max_contact_results
