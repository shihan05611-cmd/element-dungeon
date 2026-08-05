class_name SkillInventorySnapshot
extends RefCounted

## Immutable owned-skill set. The returned collection is always copied.

var owned_skill_ids: Array[StringName]:
	get:
		return _owned_skill_ids.duplicate()

var progress_entries: Array[SkillProgressSnapshot]:
	get:
		return _progress_entries.duplicate()

var _owned_skill_ids: Array[StringName] = []
var _progress_entries: Array[SkillProgressSnapshot] = []


func _init(
		p_owned_skill_ids: Array[StringName] = [],
		p_progress_entries: Array[SkillProgressSnapshot] = []
) -> void:
	for skill_id in p_owned_skill_ids:
		if not skill_id.is_empty() and not _owned_skill_ids.has(skill_id):
			_owned_skill_ids.append(skill_id)
	var seen_progress: Array[StringName] = []
	for progress: SkillProgressSnapshot in p_progress_entries:
		if (
			progress == null
			or not progress.is_valid()
			or seen_progress.has(progress.skill_id)
		):
			continue
		seen_progress.append(progress.skill_id)
		_progress_entries.append(progress)
		if not _owned_skill_ids.has(progress.skill_id):
			_owned_skill_ids.append(progress.skill_id)
	# Legacy callers only supplied an owned-ID set. Project those IDs as Lv1
	# active entries without inventing upgrade investment.
	for skill_id: StringName in _owned_skill_ids:
		if not seen_progress.has(skill_id):
			_progress_entries.append(SkillProgressSnapshot.new(skill_id))
	_owned_skill_ids.sort()
	_progress_entries.sort_custom(func(a: SkillProgressSnapshot, b: SkillProgressSnapshot) -> bool:
		return String(a.skill_id) < String(b.skill_id)
	)


func owns(skill_id: StringName) -> bool:
	return _owned_skill_ids.has(skill_id)


func size() -> int:
	return _owned_skill_ids.size()


func progress_for(skill_id: StringName) -> SkillProgressSnapshot:
	for progress: SkillProgressSnapshot in _progress_entries:
		if progress.skill_id == skill_id:
			return progress
	return null
