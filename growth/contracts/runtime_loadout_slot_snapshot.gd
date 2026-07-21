class_name RuntimeLoadoutSlotSnapshot
extends RefCounted

## One immutable form/slot assignment. Empty skill_id represents an empty slot.

var form_id: StringName:
	get:
		return _form_id

var slot_id: StringName:
	get:
		return _slot_id

var skill_id: StringName:
	get:
		return _skill_id

var _form_id: StringName
var _slot_id: StringName
var _skill_id: StringName


func _init(p_form_id: StringName, p_slot_id: StringName, p_skill_id: StringName = &"") -> void:
	_form_id = p_form_id
	_slot_id = p_slot_id
	_skill_id = p_skill_id


func is_valid() -> bool:
	return not _form_id.is_empty() and not _slot_id.is_empty()
