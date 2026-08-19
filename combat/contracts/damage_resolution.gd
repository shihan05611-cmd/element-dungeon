class_name DamageResolution
extends RefCounted

## Immutable output of the minimal pure damage resolver.

var offensive_damage: float
var reaction_multiplier: float
var reacted_damage: float
var defense_flat: float
## Element-mitigation multiplier applied after the flat defense subtraction
## (Task 61 §3.6). 1.0 means "no mitigation" and is the default for every
## caller outside the Boss same-element path.
var mitigation_factor: float
var mitigated_damage: float
var final_damage: int
var validation_error: StringName

var mitigation_applied: bool:
	get:
		return mitigation_factor < 1.0


func _init(
		p_offensive_damage: float,
		p_reaction_multiplier: float,
		p_reacted_damage: float,
		p_defense_flat: float,
		p_mitigated_damage: float,
		p_final_damage: int,
		p_validation_error: StringName = &"",
		p_mitigation_factor: float = 1.0
) -> void:
	offensive_damage = p_offensive_damage
	reaction_multiplier = p_reaction_multiplier
	reacted_damage = p_reacted_damage
	defense_flat = p_defense_flat
	mitigated_damage = p_mitigated_damage
	final_damage = p_final_damage
	validation_error = p_validation_error
	mitigation_factor = p_mitigation_factor
	if validation_error.is_empty():
		validation_error = _validate_values()


func is_valid() -> bool:
	return validation_error.is_empty()


func _validate_values() -> StringName:
	if not is_finite(offensive_damage) or offensive_damage < 0.0:
		return &"invalid_offensive_damage"
	if not is_finite(reaction_multiplier) or reaction_multiplier < 1.0 or reaction_multiplier > 4.0:
		return &"invalid_reaction_multiplier"
	if not is_finite(reacted_damage) or reacted_damage < 0.0:
		return &"invalid_reacted_damage"
	if not is_finite(defense_flat) or defense_flat < 0.0:
		return &"invalid_defense"
	if not is_finite(mitigation_factor) or mitigation_factor <= 0.0 or mitigation_factor > 1.0:
		return &"invalid_mitigation_factor"
	if not is_finite(mitigated_damage):
		return &"invalid_mitigated_damage"
	if final_damage < 0:
		return &"invalid_final_damage"
	return &""
