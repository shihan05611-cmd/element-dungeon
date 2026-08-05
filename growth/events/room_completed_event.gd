class_name RoomCompletedEvent
extends RunEvent

var completion_experience: int:
	get:
		return _completion_experience

var player_damage_taken: int:
	get:
		return _player_damage_taken

var completion_dream_dust: int:
	get:
		return _completion_dream_dust

var terminal_room: bool:
	get:
		return _terminal_room

var _completion_experience: int
var _player_damage_taken: int
var _completion_dream_dust: int
var _terminal_room: bool


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_completion_experience: int,
		p_player_damage_taken: int = 0,
		p_completion_dream_dust: int = 0,
		p_terminal_room: bool = false
) -> void:
	super(p_event_id, Kind.ROOM_COMPLETED, p_room_id)
	_completion_experience = p_completion_experience
	_player_damage_taken = p_player_damage_taken
	_completion_dream_dust = p_completion_dream_dust
	_terminal_room = p_terminal_room


func is_valid() -> bool:
	return (
		super()
		and _completion_experience >= 0
		and _player_damage_taken >= 0
		and _completion_dream_dust >= 0
		and (not _terminal_room or _completion_dream_dust == 0)
	)
