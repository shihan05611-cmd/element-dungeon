class_name RuntimeLoadoutSlotSnapshot
extends RefCounted

## One immutable shared-slot assignment. Empty skill_id represents an empty
## slot. Slot activation/passive compatibility belongs to Agent B.

var slot_id: StringName:
	get:
		return _slot_id

var skill_id: StringName:
	get:
		return _skill_id

var _slot_id: StringName
var _skill_id: StringName


func _init(p_slot_id: StringName, p_skill_id: StringName = &"") -> void:
	_slot_id = p_slot_id
	_skill_id = p_skill_id


func is_valid() -> bool:
	return not _slot_id.is_empty()
