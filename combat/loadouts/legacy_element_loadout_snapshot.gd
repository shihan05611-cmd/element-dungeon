class_name LegacyElementLoadoutSnapshot
extends RefCounted

var element_id: StringName:
	get:
		return _element_id

var ordered_skill_ids: Array[StringName]:
	get:
		return _ordered_skill_ids.duplicate()

var _element_id: StringName
var _ordered_skill_ids: Array[StringName] = []


func _init(p_element_id: StringName, p_ordered_skill_ids: Array[StringName]) -> void:
	_element_id = p_element_id
	_ordered_skill_ids = p_ordered_skill_ids.duplicate()


func is_valid() -> bool:
	if _element_id.is_empty() or _element_id == ElementIds.NONE:
		return false
	for skill_id: StringName in _ordered_skill_ids:
		if skill_id.is_empty():
			return false
	return true


static func from_resource(loadout: SkillLoadout) -> LegacyElementLoadoutSnapshot:
	if loadout == null:
		return LegacyElementLoadoutSnapshot.new(&"", [])
	var skill_ids: Array[StringName] = []
	for slot_id: StringName in loadout.get_slot_ids():
		var skill := loadout.get_skill(slot_id)
		if skill != null:
			skill_ids.append(skill.skill_id)
	return LegacyElementLoadoutSnapshot.new(loadout.form_element_id, skill_ids)
