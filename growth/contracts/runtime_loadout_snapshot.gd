class_name RuntimeLoadoutSnapshot
extends RefCounted

## Immutable form_id -> slot_id -> skill_id view represented by explicit entries.

var entries: Array[RuntimeLoadoutSlotSnapshot]:
	get:
		return _entries.duplicate()

var revision: int:
	get:
		return _revision

var _entries: Array[RuntimeLoadoutSlotSnapshot] = []
var _revision: int


func _init(p_entries: Array[RuntimeLoadoutSlotSnapshot] = [], p_revision: int = 0) -> void:
	for entry in p_entries:
		if entry != null and entry.is_valid() and not _has_key(entry.form_id, entry.slot_id):
			_entries.append(RuntimeLoadoutSlotSnapshot.new(entry.form_id, entry.slot_id, entry.skill_id))
	_entries.sort_custom(_entry_before)
	_revision = maxi(0, p_revision)


func get_skill_id(form_id: StringName, slot_id: StringName) -> StringName:
	for entry in _entries:
		if entry.form_id == form_id and entry.slot_id == slot_id:
			return entry.skill_id
	return &""


func has_slot(form_id: StringName, slot_id: StringName) -> bool:
	return _has_key(form_id, slot_id)


func same_mapping(other: RuntimeLoadoutSnapshot) -> bool:
	if other == null or _entries.size() != other.entries.size():
		return false
	var other_entries := other.entries
	for index in _entries.size():
		var left := _entries[index]
		var right := other_entries[index]
		if left.form_id != right.form_id or left.slot_id != right.slot_id or left.skill_id != right.skill_id:
			return false
	return true


func _has_key(form_id: StringName, slot_id: StringName) -> bool:
	for entry in _entries:
		if entry.form_id == form_id and entry.slot_id == slot_id:
			return true
	return false


static func _entry_before(left: RuntimeLoadoutSlotSnapshot, right: RuntimeLoadoutSlotSnapshot) -> bool:
	if left.form_id == right.form_id:
		return String(left.slot_id) < String(right.slot_id)
	return String(left.form_id) < String(right.form_id)
