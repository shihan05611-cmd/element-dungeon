class_name RoomCompletedEvent
extends RunEvent

var completion_experience: int:
	get:
		return _completion_experience

var player_damage_taken: int:
	get:
		return _player_damage_taken

var _completion_experience: int
var _player_damage_taken: int


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_completion_experience: int,
		p_player_damage_taken: int = 0
) -> void:
	super(p_event_id, Kind.ROOM_COMPLETED, p_room_id)
	_completion_experience = p_completion_experience
	_player_damage_taken = p_player_damage_taken


func is_valid() -> bool:
	return super() and _completion_experience >= 0 and _player_damage_taken >= 0
