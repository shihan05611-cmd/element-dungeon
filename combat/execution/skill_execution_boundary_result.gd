class_name SkillExecutionBoundaryResult
extends RefCounted

var completed: bool
var end_result: SkillExecutionEndResult
var tick_snapshot: ChannelTickSnapshot
var energy_spent: int


func _init(
		p_completed: bool = false,
		p_end_result: SkillExecutionEndResult = null,
		p_tick_snapshot: ChannelTickSnapshot = null,
		p_energy_spent: int = 0
) -> void:
	completed = p_completed
	end_result = p_end_result
	tick_snapshot = p_tick_snapshot
	energy_spent = maxi(0, p_energy_spent)


static func tick(snapshot: ChannelTickSnapshot, spent: int) -> SkillExecutionBoundaryResult:
	return SkillExecutionBoundaryResult.new(false, null, snapshot, spent)


static func finished(result: SkillExecutionEndResult) -> SkillExecutionBoundaryResult:
	return SkillExecutionBoundaryResult.new(true, result)
