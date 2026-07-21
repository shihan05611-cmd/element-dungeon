class_name ExperienceGainPlan
extends RefCounted

## Pure ExperienceService output committed as one ProgressionState mutation.

var valid: bool:
	get:
		return _valid

var error: StringName:
	get:
		return _error

var level_before: int:
	get:
		return _level_before

var level_after: int:
	get:
		return _level_after

var experience_after: int:
	get:
		return _experience_after

var levels_gained: int:
	get:
		return _level_after - _level_before

var _valid: bool
var _error: StringName
var _level_before: int
var _level_after: int
var _experience_after: int


func _init(
		p_valid: bool,
		p_error: StringName,
		p_level_before: int,
		p_level_after: int,
		p_experience_after: int
) -> void:
	_valid = p_valid
	_error = p_error
	_level_before = p_level_before
	_level_after = p_level_after
	_experience_after = p_experience_after


static func rejected(p_error: StringName, p_level: int, p_experience: int) -> ExperienceGainPlan:
	return ExperienceGainPlan.new(false, p_error, p_level, p_level, p_experience)
