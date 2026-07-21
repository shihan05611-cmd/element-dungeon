class_name RewardOption
extends RefCounted

## Immutable reward choice. content_id is a stable skill or relic ID.

var option_id: StringName:
	get:
		return _option_id

var reward_type: int:
	get:
		return _reward_type

var content_id: StringName:
	get:
		return _content_id

var display_name: String:
	get:
		return _display_name

var description: String:
	get:
		return _description

var _option_id: StringName
var _reward_type: int
var _content_id: StringName
var _display_name: String
var _description: String


func _init(
		p_option_id: StringName,
		p_reward_type: int,
		p_content_id: StringName,
		p_display_name: String,
		p_description: String = ""
) -> void:
	_option_id = p_option_id
	_reward_type = p_reward_type
	_content_id = p_content_id
	_display_name = p_display_name
	_description = p_description


func is_valid() -> bool:
	return (
		not _option_id.is_empty()
		and RewardType.is_valid(_reward_type)
		and not _content_id.is_empty()
	)
