class_name ProjectileDelivery
extends DeliveryBase

## Swept projectile backed by a private, bounded Physics query adapter.

signal blocker_contact(hit_position: Vector2)

@export var projectile_shape: Shape2D
@export var sweep_profile: ProjectileSweepProfile2D
@export_range(0.001, 1000000.0, 0.001, "or_greater") var speed: float = 600.0
@export_range(0.001, 1000000.0, 0.001, "or_greater") var max_distance: float = 1000.0
@export_flags_2d_physics var hurtbox_collision_mask: int = 1
@export_flags_2d_physics var blocking_collision_mask: int = 2
@export_range(0.0, 10.0, 0.001, "or_greater") var query_margin: float = 0.001
@export_range(0.0, 10.0, 0.001, "or_greater") var wall_tie_distance: float = 0.01
@export_range(1, 256, 1) var max_contact_results: int = 64
@export var hit_index: int = 0

var distance_travelled: float:
	get:
		return _distance_travelled

var _distance_travelled: float = 0.0
var _runtime_profile: ProjectileSweepProfile2D
var _sweep_query: PhysicsProjectileSweepQuery2D
var _sweep_metrics_enabled: bool = false
var _space_state: PhysicsDirectSpaceState2D
var _step_direction: Vector2 = Vector2.ZERO
var _runtime_speed: float = 0.0
var _runtime_max_distance: float = 0.0


func _on_delivery_ready() -> void:
	_runtime_profile = sweep_profile
	if _runtime_profile == null:
		_runtime_profile = ProjectileSweepProfile2D.new()
		_runtime_profile.configure_from_legacy(
			projectile_shape,
			speed,
			max_distance,
			hurtbox_collision_mask,
			blocking_collision_mask,
			query_margin,
			wall_tie_distance,
			max_contact_results
		)
	var profile_error := _runtime_profile.validation_error()
	if not profile_error.is_empty():
		_fail_configuration(profile_error)
		return
	if hit_index < 0:
		_fail_configuration(&"invalid_hit_index")
		return
	_sweep_query = PhysicsProjectileSweepQuery2D.new()
	_sweep_query.set_metrics_enabled(_sweep_metrics_enabled)
	if not _sweep_query.configure_consumer(
		_runtime_profile,
		cast_snapshot.team_id,
		false
	):
		_fail_configuration(&"invalid_projectile_sweep_consumer")
		return
	var world := get_world_2d()
	_space_state = world.direct_space_state if world != null else null
	_step_direction = direction
	_runtime_speed = _runtime_profile.speed
	_runtime_max_distance = _runtime_profile.max_distance
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not _runtime_is_ready() or not is_finite(delta) or delta <= 0.0:
		return
	var remaining := _runtime_max_distance - _distance_travelled
	if remaining <= 0.000001:
		finish(FINISH_MAX_DISTANCE)
		return
	var step_distance := minf(_runtime_speed * delta, remaining)
	if step_distance <= 0.0:
		return
	var motion := _step_direction * step_distance
	if _space_state == null:
		return
	var contact_status := _sweep_query.query_first_contact_for_ready_delivery(
		_space_state,
		global_transform,
		motion,
		step_distance
	)
	match contact_status:
		ProjectileSweepResult2D.Status.BLOCKER_CONTACT:
			_move_fraction(motion, _sweep_query.ready_delivery_contact_fraction())
			blocker_contact.emit(_sweep_query.ready_delivery_contact_point())
			finish(FINISH_BLOCKED)
			return
		ProjectileSweepResult2D.Status.ENEMY_CONTACT:
			_move_fraction(motion, _sweep_query.ready_delivery_contact_fraction())
			var hurtbox := _sweep_query.ready_delivery_contact_hurtbox()
			var hit_position := _sweep_query.ready_delivery_contact_point()
			_submit_hurtbox_hit(hurtbox, hit_index, hit_position, _step_direction)
			finish(FINISH_HIT)
			return
		ProjectileSweepResult2D.Status.INVALID_CONTEXT, ProjectileSweepResult2D.Status.QUERY_FAILED:
			return

	global_position += motion
	_distance_travelled += step_distance
	if _distance_travelled >= _runtime_max_distance - 0.000001:
		finish(FINISH_MAX_DISTANCE)


func _on_delivery_cleanup() -> void:
	_distance_travelled = 0.0
	hit_index = 0
	if _sweep_query != null:
		_sweep_query.release_scratch()
	_sweep_query = null
	_runtime_profile = null
	_space_state = null
	_step_direction = Vector2.ZERO
	_runtime_speed = 0.0
	_runtime_max_distance = 0.0
	_disconnect_owned_signal(&"blocker_contact")
	super()


func sweep_metrics_snapshot() -> Dictionary:
	if _sweep_query == null:
		return {
			&"query_calls": 0,
			&"parameter_build_count": 0,
			&"intersect_shape_count": 0,
			&"cast_motion_count": 0,
			&"rest_info_count": 0,
			&"probe_count": 0,
			&"candidate_scan_count": 0,
			&"sort_comparison_count": 0,
			&"scratch_parameter_count": 0,
		}
	return _sweep_query.metrics_snapshot()


func set_sweep_metrics_enabled(enabled: bool) -> bool:
	if is_initialized or is_inside_tree():
		return false
	_sweep_metrics_enabled = enabled
	return true


func _move_fraction(motion: Vector2, fraction: float) -> void:
	var safe_fraction := clampf(fraction, 0.0, 1.0)
	global_position += motion * safe_fraction
	_distance_travelled += motion.length() * safe_fraction
