class_name ActiveSkillLevelEffectSnapshot
extends RefCounted

## Typed effect values frozen at cast acceptance. No timing, SP, element,
## range, cooldown, slot or behavior fields can enter this narrow contract.

var skill_id: StringName:
	get:
		return _skill_id

var level: int:
	get:
		return _level

var damage_scale: float:
	get:
		return _damage_scale

var healing_scale: float:
	get:
		return _healing_scale

var shield_scale: float:
	get:
		return _shield_scale

var resource_gain_scale: float:
	get:
		return _resource_gain_scale

var validation_error: StringName:
	get:
		return _validation_error

var _skill_id: StringName
var _level: int
var _damage_scale: float
var _healing_scale: float
var _shield_scale: float
var _resource_gain_scale: float
var _validation_error: StringName = &""


func _init(
		p_skill_id: StringName = &"",
		p_level: int = 1,
		p_damage_scale: float = 1.0,
		p_healing_scale: float = 1.0,
		p_shield_scale: float = 1.0,
		p_resource_gain_scale: float = 1.0
) -> void:
	_skill_id = p_skill_id
	_level = p_level
	_damage_scale = p_damage_scale
	_healing_scale = p_healing_scale
	_shield_scale = p_shield_scale
	_resource_gain_scale = p_resource_gain_scale
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func is_neutral() -> bool:
	return (
		is_equal_approx(_damage_scale, 1.0)
		and is_equal_approx(_healing_scale, 1.0)
		and is_equal_approx(_shield_scale, 1.0)
		and is_equal_approx(_resource_gain_scale, 1.0)
	)


static func neutral(p_skill_id: StringName = &"", p_level: int = 1) -> ActiveSkillLevelEffectSnapshot:
	return ActiveSkillLevelEffectSnapshot.new(p_skill_id, p_level)


func _validate_values() -> StringName:
	if _level < 1:
		return &"invalid_active_skill_level"
	for value: float in [_damage_scale, _healing_scale, _shield_scale, _resource_gain_scale]:
		if not is_finite(value) or value <= 0.0:
			return &"invalid_active_skill_level_scale"
	return &""
