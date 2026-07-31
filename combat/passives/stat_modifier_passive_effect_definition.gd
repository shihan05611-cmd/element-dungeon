class_name StatModifierPassiveEffectDefinition
extends PassiveEffectDefinition

@export_range(0, 1000000, 1, "or_greater") var maximum_health_bonus: int = 0
@export_range(0, 1000000, 1, "or_greater") var maximum_energy_bonus: int = 0
@export_range(1.0, 1000.0, 0.01, "or_greater") var attack_multiplier: float = 1.0


func validation_error() -> StringName:
	var snapshot := PassiveStatModifierSnapshot.new(
		maximum_health_bonus,
		maximum_energy_bonus,
		attack_multiplier
	)
	return snapshot.validation_error


func create_runtime(
		skill_id: StringName,
		context: PassiveRuntimeContext
) -> PassiveEffectRuntime:
	var modifier := PassiveStatModifierSnapshot.new(
		maximum_health_bonus,
		maximum_energy_bonus,
		attack_multiplier
	)
	return StatModifierPassiveEffectRuntime.new(skill_id, self, context, modifier)
