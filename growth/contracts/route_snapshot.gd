class_name RouteSnapshot
extends RefCounted

## Immutable RunDirector state exposed to UI and reward services.

var phase: int:
	get:
		return _phase

var completed_combat_rooms: int:
	get:
		return _completed_combat_rooms

var current_room_id: StringName:
	get:
		return _current_room_id

var selected_reward_type: int:
	get:
		return _selected_reward_type

var next_options: Array[RouteOption]:
	get:
		return _next_options.duplicate()

var _phase: int
var _completed_combat_rooms: int
var _current_room_id: StringName
var _selected_reward_type: int
var _next_options: Array[RouteOption] = []


func _init(
		p_phase: int = RunPhase.COMBAT,
		p_completed_combat_rooms: int = 0,
		p_current_room_id: StringName = &"",
		p_selected_reward_type: int = -1,
		p_next_options: Array[RouteOption] = []
) -> void:
	_phase = p_phase
	_completed_combat_rooms = maxi(0, p_completed_combat_rooms)
	_current_room_id = p_current_room_id
	_selected_reward_type = p_selected_reward_type
	_next_options = p_next_options.duplicate()
