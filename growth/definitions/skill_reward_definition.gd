class_name SkillRewardDefinition
extends Resource

## Static reward metadata only. Ownership, equip state and runtime cooldowns do
## not belong to this shared Resource.

@export var skill_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var initial_pool: bool = false
@export var allowed_form_ids: Array[StringName] = []


func validation_error() -> StringName:
	if skill_id.is_empty():
		return &"missing_skill_id"
	if allowed_form_ids.is_empty():
		return &"missing_allowed_forms"
	var seen: Array[StringName] = []
	for form_id in allowed_form_ids:
		if form_id.is_empty():
			return &"empty_allowed_form"
		if seen.has(form_id):
			return &"duplicate_allowed_form"
		seen.append(form_id)
	return &""


func is_available_for(unlocked_form_ids: Array[StringName]) -> bool:
	if not validation_error().is_empty():
		return false
	for form_id in allowed_form_ids:
		if unlocked_form_ids.has(form_id):
			return true
	return false
