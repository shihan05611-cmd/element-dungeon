class_name AttackPayloadDefinition
extends Resource

## Static attack configuration. It does not store caster, cooldown, remaining
## lifetime, or per-target hit state.

enum ElementMode {
	NONE,
	FOLLOW_CAST_FORM,
	FIXED_ELEMENT,
}

@export_range(0.0, 100000.0, 0.01, "or_greater") var damage_multiplier: float = 0.0
@export var element_mode: ElementMode = ElementMode.NONE
@export var fixed_element_id: StringName = ElementIds.NONE
@export_range(0, 10, 1) var element_amount: int = 0
@export_range(1.0, 10.0, 0.001, "or_greater") var melee_query_multiplier: float = 1.0
@export var presentation_tags: PackedStringArray = PackedStringArray()


func validation_error() -> StringName:
	if not is_finite(damage_multiplier) or damage_multiplier < 0.0:
		return &"invalid_damage_multiplier"
	if element_amount < 0 or element_amount > 10:
		return &"invalid_element_amount"
	if not is_finite(melee_query_multiplier) or melee_query_multiplier < 1.0:
		return &"invalid_melee_query_multiplier"
	match element_mode:
		ElementMode.NONE:
			if element_amount != 0:
				return &"none_mode_has_element_amount"
		ElementMode.FOLLOW_CAST_FORM:
			if element_amount <= 0:
				return &"element_mode_missing_amount"
		ElementMode.FIXED_ELEMENT:
			if not ElementIds.is_combat_element(fixed_element_id):
				return &"unknown_fixed_element_id"
			if element_amount <= 0:
				return &"element_mode_missing_amount"
		_:
			return &"unknown_element_mode"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func build_runtime(cast_snapshot: CastSnapshot) -> RuntimeAttackPayload:
	if not is_valid():
		return RuntimeAttackPayload.invalid(validation_error())
	if cast_snapshot == null or not cast_snapshot.is_valid():
		return RuntimeAttackPayload.invalid(&"invalid_cast_snapshot")

	var resolved_element := ElementIds.NONE
	match element_mode:
		ElementMode.FOLLOW_CAST_FORM:
			resolved_element = cast_snapshot.cast_element_id
		ElementMode.FIXED_ELEMENT:
			resolved_element = fixed_element_id
		ElementMode.NONE:
			pass

	if element_mode != ElementMode.NONE and not ElementIds.is_combat_element(resolved_element):
		return RuntimeAttackPayload.invalid(&"invalid_resolved_element")

	var stats := cast_snapshot.stat_snapshot
	var offensive_damage := stats.calculate_offensive_damage(damage_multiplier)
	return RuntimeAttackPayload.from_locked_inputs(
		stats.effective_attack,
		damage_multiplier,
		stats.flat_damage_bonus,
		offensive_damage,
		resolved_element,
		element_amount,
		presentation_tags,
		&"",
		melee_query_multiplier
	)
