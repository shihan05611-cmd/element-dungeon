class_name SkillExecutionRuntime
extends RefCounted

var snapshot: SkillExecutionSnapshot:
	get:
		return _snapshot

var is_complete: bool:
	get:
		return _complete

var end_result: SkillExecutionEndResult:
	get:
		return _end_result

var _snapshot: SkillExecutionSnapshot
var _remaining_active_time: float
var _complete: bool = false
var _end_result: SkillExecutionEndResult


func _init(p_snapshot: SkillExecutionSnapshot, active_time: float = 0.0) -> void:
	_snapshot = p_snapshot
	_remaining_active_time = maxf(0.0, active_time)


func time_to_boundary() -> float:
	return maxf(0.0, _remaining_active_time)


func advance_time(delta: float) -> void:
	_remaining_active_time = maxf(0.0, _remaining_active_time - maxf(0.0, delta))


func reach_boundary(_energy: EnergyComponent) -> SkillExecutionBoundaryResult:
	_complete = true
	_end_result = SkillExecutionEndResult.new(SkillExecutionEndResult.Reason.COMPLETED)
	return SkillExecutionBoundaryResult.finished(_end_result)


func supports_release() -> bool:
	return false


func request_release() -> bool:
	return false


func force_end(result: SkillExecutionEndResult) -> void:
	_complete = true
	_end_result = result
