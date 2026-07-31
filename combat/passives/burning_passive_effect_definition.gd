class_name BurningPassiveEffectDefinition
extends PassiveEffectDefinition

const OBSERVED_ELEMENT_ID: StringName = ElementIds.FIRE

@export_range(0.001, 60.0, 0.001, "or_greater") var tick_interval: float = 1.0
@export_range(0.0, 10.0, 0.001, "or_greater") var damage_multiplier_per_layer: float = 0.05

var observed_element_id: StringName:
	get:
		return OBSERVED_ELEMENT_ID


func validation_error() -> StringName:
	if not is_finite(tick_interval) or tick_interval <= 0.0:
		return &"invalid_tick_interval"
	if not is_finite(damage_multiplier_per_layer) or damage_multiplier_per_layer <= 0.0:
		return &"invalid_damage_multiplier_per_layer"
	return &""


func runtime_validation_error(context: PassiveRuntimeContext) -> StringName:
	var base_error := validation_error()
	if not base_error.is_empty():
		return base_error
	if context == null or context.owner_port == null:
		return &"missing_passive_owner_port"
	if context.target_port == null:
		return &"missing_passive_target_port"
	return &""


func create_runtime(
		skill_id: StringName,
		context: PassiveRuntimeContext
) -> PassiveEffectRuntime:
	return BurningPassiveEffectRuntime.new(skill_id, self, context)
