class_name RoomRewardContext
extends RefCounted

## Untrusted reward request data supplied by an integration layer. Whether this
## is the first combat reward and which reward type is allowed are derived from
## RunSnapshot.route, never from this DTO.

var room_id: StringName:
	get:
		return _room_id

var reward_type: int:
	get:
		return _reward_type

var _room_id: StringName
var _reward_type: int


func _init(
		p_room_id: StringName,
		p_reward_type: int,
		_ignored_legacy_first_room_hint: Variant = null
) -> void:
	_room_id = p_room_id
	_reward_type = p_reward_type


func is_valid() -> bool:
	return not _room_id.is_empty() and RewardType.is_valid(_reward_type)
