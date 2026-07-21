class_name SkillInventoryState
extends RefCounted

var _owned_skill_ids: Array[StringName] = []


func _init(initial_skill_ids: Array[StringName] = []) -> void:
	for skill_id in initial_skill_ids:
		if not skill_id.is_empty() and not _owned_skill_ids.has(skill_id):
			_owned_skill_ids.append(skill_id)


func snapshot() -> SkillInventorySnapshot:
	return SkillInventorySnapshot.new(_owned_skill_ids)


func owns(skill_id: StringName) -> bool:
	return _owned_skill_ids.has(skill_id)


func try_add(skill_id: StringName) -> RunCommandResult:
	if skill_id.is_empty():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"missing_skill_id")
	if owns(skill_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_OWNED, &"skill_already_owned")
	_owned_skill_ids.append(skill_id)
	return RunCommandResult.success()
