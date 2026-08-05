class_name ActiveSkillLevelEffectPort
extends RefCounted

## Narrow read port queried once at cast acceptance.

func effect_for(skill_id: StringName) -> ActiveSkillLevelEffectSnapshot:
	return ActiveSkillLevelEffectSnapshot.neutral(skill_id)
