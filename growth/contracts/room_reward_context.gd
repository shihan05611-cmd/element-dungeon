class_name RoomRewardContext
extends RefCounted

## Explicit reward-generation context; candidate catalogs are supplied
## separately so this DTO remains room-focused.

var room_id: StringName:
	get:
		return _room_id

var reward_type: int:
	get:
		return _reward_type

var first_combat_room: bool:
	get:
		return _first_combat_room

var _room_id: StringName
var _reward_type: int
var _first_combat_room: bool


func _init(p_room_id: StringName, p_reward_type: int, p_first_combat_room: bool = false) -> void:
	_room_id = p_room_id
	_reward_type = p_reward_type
	_first_combat_room = p_first_combat_room


func is_valid() -> bool:
	return not _room_id.is_empty() and RewardType.is_valid(_reward_type)
