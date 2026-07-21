class_name SkillInventorySnapshot
extends RefCounted

## Immutable owned-skill set. The returned collection is always copied.

var owned_skill_ids: Array[StringName]:
	get:
		return _owned_skill_ids.duplicate()

var _owned_skill_ids: Array[StringName] = []


func _init(p_owned_skill_ids: Array[StringName] = []) -> void:
	for skill_id in p_owned_skill_ids:
		if not skill_id.is_empty() and not _owned_skill_ids.has(skill_id):
			_owned_skill_ids.append(skill_id)
	_owned_skill_ids.sort()


func owns(skill_id: StringName) -> bool:
	return _owned_skill_ids.has(skill_id)


func size() -> int:
	return _owned_skill_ids.size()
