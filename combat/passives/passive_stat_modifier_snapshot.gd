class_name PassiveStatModifierSnapshot
extends RefCounted

var maximum_health_bonus: int
var maximum_energy_bonus: int
var attack_multiplier: float
var validation_error: StringName = &""


func _init(
		p_maximum_health_bonus: int = 0,
		p_maximum_energy_bonus: int = 0,
		p_attack_multiplier: float = 1.0
) -> void:
	maximum_health_bonus = p_maximum_health_bonus
	maximum_energy_bonus = p_maximum_energy_bonus
	attack_multiplier = p_attack_multiplier
	if maximum_health_bonus < 0:
		validation_error = &"invalid_health_bonus"
	elif maximum_energy_bonus < 0:
		validation_error = &"invalid_energy_bonus"
	elif not is_finite(attack_multiplier) or attack_multiplier < 1.0:
		validation_error = &"invalid_attack_multiplier"


func is_valid() -> bool:
	return validation_error.is_empty()
