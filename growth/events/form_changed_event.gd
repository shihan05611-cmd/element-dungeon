class_name FormChangedEvent
extends RunEvent

enum Source {
	MANUAL,
	SKILL_AUTO,
}

var previous_element_id: StringName:
	get:
		return _previous_element_id

var current_element_id: StringName:
	get:
		return _current_element_id

var source: Source:
	get:
		return _source

var sequence: int:
	get:
		return _sequence

var timestamp_msec: int:
	get:
		return _timestamp_msec

var _previous_element_id: StringName
var _current_element_id: StringName
var _source: Source
var _sequence: int
var _timestamp_msec: int


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_previous_element_id: StringName,
		p_current_element_id: StringName,
		p_source: Source,
		p_sequence: int,
		p_timestamp_msec: int
) -> void:
	super(p_event_id, Kind.FORM_CHANGED, p_room_id)
	_previous_element_id = p_previous_element_id
	_current_element_id = p_current_element_id
	_source = p_source
	_sequence = p_sequence
	_timestamp_msec = p_timestamp_msec


func is_valid() -> bool:
	return (
		super()
		and not _previous_element_id.is_empty()
		and not _current_element_id.is_empty()
		and _previous_element_id != _current_element_id
		and (_source == Source.MANUAL or _source == Source.SKILL_AUTO)
		and _sequence > 0
		and _timestamp_msec >= 0
	)
