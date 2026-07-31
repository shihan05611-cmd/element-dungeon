class_name UnendingPassiveEffectDefinition
extends PassiveEffectDefinition

const OBSERVED_ELEMENT_ID: StringName = ElementIds.WATER

@export_range(1, 1000, 1, "or_greater") var health_per_layer: int = 1

var observed_element_id: StringName:
	get:
		return OBSERVED_ELEMENT_ID


func validation_error() -> StringName:
	return &"" if health_per_layer > 0 else &"invalid_health_per_layer"


func runtime_validation_error(context: PassiveRuntimeContext) -> StringName:
	var base_error := validation_error()
	if not base_error.is_empty():
		return base_error
	if context == null or context.owner_port == null:
		return &"missing_passive_owner_port"
	return &""


func create_runtime(
		skill_id: StringName,
		context: PassiveRuntimeContext
) -> PassiveEffectRuntime:
	return UnendingPassiveEffectRuntime.new(skill_id, self, context)
