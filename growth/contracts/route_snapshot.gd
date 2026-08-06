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

var run_id: StringName:
	get:
		return _run_id

var current_node_id: StringName:
	get:
		return _current_node_id

var pending_node_id: StringName:
	get:
		return _pending_node_id

var selected_option_id: StringName:
	get:
		return _selected_option_id

var active_room_instance_id: int:
	get:
		return _active_room_instance_id

var active_scene_path: String:
	get:
		return _active_scene_path

var completed_node_ids: Array[StringName]:
	get:
		return _completed_node_ids.duplicate()

var selected_route_option_ids: Array[StringName]:
	get:
		return _selected_route_option_ids.duplicate()

var activated_scene_paths: Array[String]:
	get:
		return _activated_scene_paths.duplicate()

var activated_room_instance_ids: Array[int]:
	get:
		return _activated_room_instance_ids.duplicate()

var shop_visits: int:
	get:
		return _shop_visits

var route_choices: int:
	get:
		return _route_choices

var _phase: int
var _completed_combat_rooms: int
var _current_room_id: StringName
var _selected_reward_type: int
var _next_options: Array[RouteOption] = []
var _run_id: StringName
var _current_node_id: StringName
var _pending_node_id: StringName
var _selected_option_id: StringName
var _active_room_instance_id: int
var _active_scene_path: String
var _completed_node_ids: Array[StringName] = []
var _selected_route_option_ids: Array[StringName] = []
var _activated_scene_paths: Array[String] = []
var _activated_room_instance_ids: Array[int] = []
var _shop_visits: int
var _route_choices: int


func _init(
		p_phase: int = RunPhase.COMBAT,
		p_completed_combat_rooms: int = 0,
		p_current_room_id: StringName = &"",
		p_selected_reward_type: int = -1,
		p_next_options: Array[RouteOption] = [],
		p_run_id: StringName = &"",
		p_current_node_id: StringName = &"",
		p_pending_node_id: StringName = &"",
		p_selected_option_id: StringName = &"",
		p_active_room_instance_id: int = 0,
		p_active_scene_path: String = "",
		p_completed_node_ids: Array[StringName] = [],
		p_selected_route_option_ids: Array[StringName] = [],
		p_activated_scene_paths: Array[String] = [],
		p_activated_room_instance_ids: Array[int] = [],
		p_shop_visits: int = 0,
		p_route_choices: int = 0
) -> void:
	_phase = p_phase
	_completed_combat_rooms = maxi(0, p_completed_combat_rooms)
	_current_room_id = p_current_room_id
	_selected_reward_type = p_selected_reward_type
	_next_options = p_next_options.duplicate()
	_run_id = p_run_id
	_current_node_id = p_current_node_id
	_pending_node_id = p_pending_node_id
	_selected_option_id = p_selected_option_id
	_active_room_instance_id = p_active_room_instance_id
	_active_scene_path = p_active_scene_path
	_completed_node_ids = p_completed_node_ids.duplicate()
	_selected_route_option_ids = p_selected_route_option_ids.duplicate()
	_activated_scene_paths = p_activated_scene_paths.duplicate()
	_activated_room_instance_ids = p_activated_room_instance_ids.duplicate()
	_shop_visits = maxi(0, p_shop_visits)
	_route_choices = maxi(0, p_route_choices)
