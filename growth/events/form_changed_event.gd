class_name FormChangedEvent
extends RunEvent

var previous_form_id: StringName:
	get:
		return _previous_form_id

var current_form_id: StringName:
	get:
		return _current_form_id

var _previous_form_id: StringName
var _current_form_id: StringName


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_previous_form_id: StringName,
		p_current_form_id: StringName
) -> void:
	super(p_event_id, Kind.FORM_CHANGED, p_room_id)
	_previous_form_id = p_previous_form_id
	_current_form_id = p_current_form_id


func is_valid() -> bool:
	return (
		super()
		and not _previous_form_id.is_empty()
		and not _current_form_id.is_empty()
		and _previous_form_id != _current_form_id
	)
