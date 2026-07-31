class_name PassiveEffectDefinition
extends Resource

func validation_error() -> StringName:
	return &""


func runtime_validation_error(_context: PassiveRuntimeContext) -> StringName:
	return validation_error()


func create_runtime(
		_skill_id: StringName,
		_context: PassiveRuntimeContext
) -> PassiveEffectRuntime:
	return null
