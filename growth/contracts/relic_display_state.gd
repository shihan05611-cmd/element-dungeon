class_name RelicDisplayState
extends RefCounted

## Immutable display/runtime summary for one owned relic.

var relic_id: StringName:
	get:
		return _relic_id

var display_name: String:
	get:
		return _display_name

var description: String:
	get:
		return _description

var cooldown_remaining: float:
	get:
		return _cooldown_remaining

var triggers_this_room: int:
	get:
		return _triggers_this_room

var _relic_id: StringName
var _display_name: String
var _description: String
var _cooldown_remaining: float
var _triggers_this_room: int


func _init(
		p_relic_id: StringName,
		p_display_name: String,
		p_description: String,
		p_cooldown_remaining: float = 0.0,
		p_triggers_this_room: int = 0
) -> void:
	_relic_id = p_relic_id
	_display_name = p_display_name
	_description = p_description
	_cooldown_remaining = maxf(0.0, p_cooldown_remaining)
	_triggers_this_room = maxi(0, p_triggers_this_room)
