class_name RelicAcquiredEvent
extends RunEvent

var relic_id: StringName:
	get:
		return _relic_id

var _relic_id: StringName


func _init(p_event_id: StringName, p_room_id: StringName, p_relic_id: StringName) -> void:
	super(p_event_id, Kind.RELIC_ACQUIRED, p_room_id)
	_relic_id = p_relic_id


func is_valid() -> bool:
	return super() and not _relic_id.is_empty()
