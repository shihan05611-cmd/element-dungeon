class_name RunSkillLevelEffectAdapter
extends ActiveSkillLevelEffectPort

## Combat-facing adapter over one RunSession. It exposes no inventory or
## economy mutation and always returns an immutable effect snapshot.

var _session: RunSession


func _init(session: RunSession = null) -> void:
	_session = session


func configure(session: RunSession) -> bool:
	if session == null:
		return false
	_session = session
	return true


func effect_for(skill_id: StringName) -> ActiveSkillLevelEffectSnapshot:
	if _session == null or skill_id.is_empty():
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id)
	var effect := _session.active_skill_level_effect(skill_id)
	return (
		effect
		if effect != null and effect.is_valid()
		else ActiveSkillLevelEffectSnapshot.neutral(skill_id)
	)
