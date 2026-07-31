class_name SkillExecutionEndResult
extends RefCounted

enum Reason {
	COMPLETED,
	RELEASED,
	INSUFFICIENT_ENERGY,
	CANCELLED,
	INTERRUPTED,
	DEATH,
	TREE_EXITED,
	PAUSED,
	INTERNAL_FAILURE,
}

var reason: Reason:
	get:
		return _reason

var detail: StringName:
	get:
		return _detail

var _reason: Reason
var _detail: StringName


func _init(p_reason: Reason, p_detail: StringName = &"") -> void:
	_reason = p_reason
	_detail = p_detail


static func from_cancel_reason(cancel_reason: StringName) -> SkillExecutionEndResult:
	match cancel_reason:
		&"death":
			return SkillExecutionEndResult.new(Reason.DEATH, cancel_reason)
		&"hit":
			return SkillExecutionEndResult.new(Reason.INTERRUPTED, cancel_reason)
		&"caster_left_tree":
			return SkillExecutionEndResult.new(Reason.TREE_EXITED, cancel_reason)
		&"scene_tree_paused":
			return SkillExecutionEndResult.new(Reason.PAUSED, cancel_reason)
		_:
			return SkillExecutionEndResult.new(Reason.CANCELLED, cancel_reason)
