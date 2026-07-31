class_name RuntimeLoadoutSnapshot
extends RefCounted

## Immutable shared slot_id -> skill_id view represented by explicit entries.

var entries: Array[RuntimeLoadoutSlotSnapshot]:
	get:
		return _entries.duplicate()

var revision: int:
	get:
		return _revision

var validation_error: StringName:
	get:
		return _validation_error

var _entries: Array[RuntimeLoadoutSlotSnapshot] = []
var _revision: int
var _validation_error: StringName = &""


func _init(p_entries: Array[RuntimeLoadoutSlotSnapshot] = [], p_revision: int = 0) -> void:
	for entry in p_entries:
		if entry == null or not entry.is_valid():
			_set_first_validation_error(&"invalid_loadout_entry")
			continue
		if has_slot(entry.slot_id):
			_set_first_validation_error(&"duplicate_slot_id")
			continue
		_entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, entry.skill_id))
	_entries.sort_custom(_entry_before)
	_revision = maxi(0, p_revision)


func is_valid() -> bool:
	return _validation_error.is_empty()


func get_skill_id(slot_id: StringName) -> StringName:
	for entry in _entries:
		if entry.slot_id == slot_id:
			return entry.skill_id
	return &""


func has_slot(slot_id: StringName) -> bool:
	for entry in _entries:
		if entry.slot_id == slot_id:
			return true
	return false


func same_mapping(other: RuntimeLoadoutSnapshot) -> bool:
	if other == null or _entries.size() != other.entries.size():
		return false
	var other_entries := other.entries
	for index in _entries.size():
		var left := _entries[index]
		var right := other_entries[index]
		if left.slot_id != right.slot_id or left.skill_id != right.skill_id:
			return false
	return true


func _set_first_validation_error(error: StringName) -> void:
	if _validation_error.is_empty():
		_validation_error = error


static func _entry_before(left: RuntimeLoadoutSlotSnapshot, right: RuntimeLoadoutSlotSnapshot) -> bool:
	return String(left.slot_id) < String(right.slot_id)
