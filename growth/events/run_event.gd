class_name RunEvent
extends RefCounted

## Base identity shared by every typed event consumed by one RunSession.

enum Kind {
	FORM_CHANGED,
	COMBAT_COMMITTED,
	ENEMY_KILLED,
	ROOM_COMPLETED,
	RELIC_ACQUIRED,
}

var event_id: StringName:
	get:
		return _event_id

var kind: Kind:
	get:
		return _kind

var room_id: StringName:
	get:
		return _room_id

var _event_id: StringName
var _kind: Kind
var _room_id: StringName


func _init(p_event_id: StringName, p_kind: Kind, p_room_id: StringName) -> void:
	_event_id = p_event_id
	_kind = p_kind
	_room_id = p_room_id


func is_valid() -> bool:
	return not _event_id.is_empty() and not _room_id.is_empty()


func identity_key() -> StringName:
	return StringName("%d:%s" % [int(_kind), String(_event_id)])
