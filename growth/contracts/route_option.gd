class_name RouteOption
extends RefCounted

enum Kind {
	REWARD_ROOM,
	SHOP,
	RUN_COMPLETE,
}

var option_id: StringName:
	get:
		return _option_id

var kind: Kind:
	get:
		return _kind

var reward_type: int:
	get:
		return _reward_type

var _option_id: StringName
var _kind: Kind
var _reward_type: int


func _init(p_option_id: StringName, p_kind: Kind, p_reward_type: int = -1) -> void:
	_option_id = p_option_id
	_kind = p_kind
	_reward_type = p_reward_type


func is_valid() -> bool:
	if _option_id.is_empty():
		return false
	if _kind == Kind.REWARD_ROOM:
		return RewardType.is_valid(_reward_type)
	return _kind == Kind.SHOP or _kind == Kind.RUN_COMPLETE
