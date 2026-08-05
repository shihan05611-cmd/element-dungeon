class_name ActiveSkillLevelDefinition
extends Resource

@export_range(1, 1000, 1, "or_greater") var level: int = 1
@export_range(0, 1000000, 1, "or_greater") var upgrade_price: int = 0
@export_range(0.001, 1000.0, 0.001, "or_greater") var damage_scale: float = 1.0
@export_range(0.001, 1000.0, 0.001, "or_greater") var healing_scale: float = 1.0
@export_range(0.001, 1000.0, 0.001, "or_greater") var shield_scale: float = 1.0
@export_range(0.001, 1000.0, 0.001, "or_greater") var resource_gain_scale: float = 1.0


func validation_error() -> StringName:
	if level < 1:
		return &"invalid_active_skill_level"
	if level == 1 and upgrade_price != 0:
		return &"base_level_has_upgrade_price"
	if level > 1 and upgrade_price <= 0:
		return &"missing_active_skill_upgrade_price"
	for value: float in [damage_scale, healing_scale, shield_scale, resource_gain_scale]:
		if not is_finite(value) or value < 1.0:
			return &"invalid_active_skill_progression_scale"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func effect_snapshot(skill_id: StringName) -> ActiveSkillLevelEffectSnapshot:
	if skill_id.is_empty() or not is_valid():
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id)
	return ActiveSkillLevelEffectSnapshot.new(
		skill_id,
		level,
		damage_scale,
		healing_scale,
		shield_scale,
		resource_gain_scale
	)
