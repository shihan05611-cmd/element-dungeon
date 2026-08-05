class_name ActiveSkillProgressionDefinition
extends Resource

@export var levels: Array[ActiveSkillLevelDefinition] = []


func validation_error() -> StringName:
	if levels.is_empty():
		return &"empty_active_skill_progression"
	var previous: ActiveSkillLevelDefinition
	for index: int in levels.size():
		var definition := levels[index]
		if definition == null:
			return &"null_active_skill_level"
		var level_error := definition.validation_error()
		if not level_error.is_empty():
			return level_error
		if definition.level != index + 1:
			return &"non_contiguous_active_skill_levels"
		if previous != null and (
			definition.damage_scale < previous.damage_scale
			or definition.healing_scale < previous.healing_scale
			or definition.shield_scale < previous.shield_scale
			or definition.resource_gain_scale < previous.resource_gain_scale
		):
			return &"decreasing_active_skill_level_effect"
		previous = definition
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func maximum_level() -> int:
	return levels.size() if is_valid() else 1


func definition_for_level(level: int) -> ActiveSkillLevelDefinition:
	if not is_valid() or level < 1 or level > levels.size():
		return null
	return levels[level - 1]


func upgrade_price_from(current_level: int) -> int:
	var target := definition_for_level(current_level + 1)
	return target.upgrade_price if target != null else -1


func effect_snapshot(skill_id: StringName, level: int) -> ActiveSkillLevelEffectSnapshot:
	var definition := definition_for_level(level)
	return (
		definition.effect_snapshot(skill_id)
		if definition != null
		else ActiveSkillLevelEffectSnapshot.neutral(skill_id, maxi(1, level))
	)
