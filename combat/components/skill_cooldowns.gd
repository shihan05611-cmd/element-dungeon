class_name SkillCooldowns
extends RefCounted

## Per-executor cooldown state keyed by skill ID. SkillDefinition Resources are
## never modified, allowing any number of actors to share them safely.

var _remaining_by_skill: Dictionary[StringName, float] = {}


func is_on_cooldown(skill_id: StringName) -> bool:
	return get_remaining(skill_id) > 0.0


func get_remaining(skill_id: StringName) -> float:
	return maxf(0.0, _remaining_by_skill.get(skill_id, 0.0))


func start(skill_id: StringName, duration: float) -> bool:
	if skill_id.is_empty() or not is_finite(duration) or duration < 0.0:
		return false
	if is_on_cooldown(skill_id):
		return false
	if duration > 0.0:
		_remaining_by_skill[skill_id] = duration
	else:
		_remaining_by_skill.erase(skill_id)
	return true


func advance(delta: float) -> Array[StringName]:
	var finished: Array[StringName] = []
	if not is_finite(delta) or delta < 0.0 or delta == 0.0:
		return finished
	var skill_ids: Array[StringName] = []
	for skill_id: StringName in _remaining_by_skill:
		skill_ids.append(skill_id)
	skill_ids.sort()
	for skill_id: StringName in skill_ids:
		var next_remaining := maxf(0.0, get_remaining(skill_id) - delta)
		if next_remaining <= 0.0:
			_remaining_by_skill.erase(skill_id)
			finished.append(skill_id)
		else:
			_remaining_by_skill[skill_id] = next_remaining
	return finished


func clear() -> void:
	_remaining_by_skill.clear()


func snapshot() -> Dictionary[StringName, float]:
	return _remaining_by_skill.duplicate(true)
