class_name SkillLoadout
extends Resource

## Static slot mapping for exactly one player form. Runtime equipment changes
## should copy this data into a separate runtime model instead of mutating a
## shared loadout Resource.

@export var form_element_id: StringName = ElementIds.WATER
@export var slots: Dictionary[StringName, SkillDefinition] = {}


func validation_error() -> StringName:
	if not ElementIds.is_combat_element(form_element_id):
		return &"invalid_loadout_form"
	for slot_id: StringName in slots:
		if slot_id.is_empty():
			return &"missing_slot_id"
		var skill: SkillDefinition = slots[slot_id]
		if skill == null or not skill.is_valid():
			return &"invalid_slot_skill"
		if not skill.is_form_allowed(form_element_id):
			return &"slot_skill_form_mismatch"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func get_skill(slot_id: StringName) -> SkillDefinition:
	return slots.get(slot_id) as SkillDefinition


func has_slot(slot_id: StringName) -> bool:
	return not slot_id.is_empty() and slots.has(slot_id) and get_skill(slot_id) != null


func get_slot_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_id: StringName in slots:
		result.append(slot_id)
	result.sort()
	return result
