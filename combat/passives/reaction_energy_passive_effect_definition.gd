class_name ReactionEnergyPassiveEffectDefinition
extends PassiveEffectDefinition

@export_range(1, 1000, 1, "or_greater") var energy_restore: int = 10


func validation_error() -> StringName:
	return &"" if energy_restore > 0 else &"invalid_reaction_energy_restore"


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
	return ReactionEnergyPassiveEffectRuntime.new(skill_id, self, context)
