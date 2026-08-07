class_name ElementRageDelivery
extends DeliveryBase

## One logical area-burst window driven entirely by the accepted
## AllEnergyBurstExecutionSnapshot.

signal burst_submitted(origin: Vector2, radius: float, target_count: int)

const FINISH_BURST_COMPLETE: StringName = &"burst_complete"

@export_range(0.001, 100000.0, 0.1, "or_greater") var base_radius: float = 96.0
@export_flags_2d_physics var hurtbox_collision_mask: int = 8
@export var walls_block_targets: bool = true
@export_flags_2d_physics var blocking_collision_mask: int = 4
@export_range(1, 4096, 1) var max_query_results: int = 256
@export var trigger_on_ready: bool = true

var effective_radius: float:
	get:
		return _effective_radius

var _burst_snapshot: AllEnergyBurstExecutionSnapshot
var _effective_radius: float = 0.0
var _burst_submitted: bool = false


func initialize_burst(
		snapshot: AllEnergyBurstExecutionSnapshot,
		p_delivery_id: int,
		p_start_world_transform: Transform2D,
		p_direction: Vector2
) -> bool:
	if snapshot == null or not snapshot.is_valid():
		return false
	if not initialize_delivery(
		snapshot.cast_snapshot,
		snapshot.payload,
		p_delivery_id,
		p_start_world_transform,
		p_direction
	):
		return false
	_burst_snapshot = snapshot
	return true


func trigger_burst() -> bool:
	if not _runtime_is_ready() or _burst_submitted:
		return false
	if _burst_snapshot == null or not _burst_snapshot.is_valid():
		_fail_configuration(&"invalid_burst_snapshot")
		return false
	var world := get_world_2d()
	if world == null:
		_fail_configuration(&"missing_burst_world")
		return false
	_burst_submitted = true
	clear_hit_records()
	var candidates := CombatTargetQuery2D.query_circle(
		self,
		_effective_radius,
		hurtbox_collision_mask,
		max_query_results,
		cast_snapshot.team_id,
		false
	)
	var origin := global_position
	for candidate: CombatTargetCandidate2D in candidates:
		if not candidate.is_valid():
			continue
		if (
			walls_block_targets
			and CombatTargetQuery2D.is_world_blocked(
				world,
				origin,
				candidate.hit_position,
				blocking_collision_mask
			)
		):
			continue
		var hit_direction := candidate.hit_position - origin
		if hit_direction.is_zero_approx():
			hit_direction = direction
		_submit_hurtbox_hit(
			candidate.hurtbox,
			0,
			candidate.hit_position,
			hit_direction.normalized()
		)
	var target_count := get_recorded_target_count(0)
	burst_submitted.emit(origin, _effective_radius, target_count)
	finish(FINISH_BURST_COMPLETE)
	return true


func trigger_prepared_delivery() -> bool:
	return trigger_burst()


func preparation_validation_error() -> StringName:
	if _burst_snapshot == null or not _burst_snapshot.is_valid():
		return &"invalid_burst_snapshot"
	if not is_initialized or not validation_error.is_empty():
		return &"invalid_burst_initialization"
	if not is_finite(base_radius) or base_radius <= 0.0:
		return &"invalid_base_radius"
	if hurtbox_collision_mask <= 0 or max_query_results <= 0:
		return &"invalid_burst_query_configuration"
	if walls_block_targets and blocking_collision_mask <= 0:
		return &"invalid_burst_blocking_mask"
	var prepared_radius := base_radius * _burst_snapshot.radius_scale
	if not is_finite(prepared_radius) or prepared_radius <= 0.0:
		return &"invalid_effective_radius"
	if not _start_world_transform.origin.is_equal_approx(_burst_snapshot.impact_position):
		return &"burst_impact_position_mismatch"
	return &""


func close_hit_window() -> void:
	if not is_finished:
		finish(FINISH_CANCELLED)


func _on_delivery_ready() -> void:
	var prepared_error := preparation_validation_error()
	if not prepared_error.is_empty():
		_fail_configuration(prepared_error)
		return
	_effective_radius = base_radius * _burst_snapshot.radius_scale
	if trigger_on_ready:
		call_deferred(&"_trigger_ready_burst", reuse_generation)


func _trigger_ready_burst(expected_generation: int) -> void:
	if expected_generation == reuse_generation:
		trigger_burst()


func _on_delivery_cleanup() -> void:
	_burst_snapshot = null
	_effective_radius = 0.0
	_burst_submitted = false
	_disconnect_owned_signal(&"burst_submitted")
	super()
