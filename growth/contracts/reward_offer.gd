class_name RewardOffer
extends RefCounted

## Immutable, room-bound reward proposal. Invalid instances carry a typed
## configuration error and cannot be installed as PendingReward.

var offer_id: StringName:
	get:
		return _offer_id

var room_id: StringName:
	get:
		return _room_id

var reward_type: int:
	get:
		return _reward_type

var seed: int:
	get:
		return _seed

var options: Array[RewardOption]:
	get:
		return _options.duplicate()

var valid: bool:
	get:
		return _valid

var configuration_error: StringName:
	get:
		return _configuration_error

var _offer_id: StringName
var _room_id: StringName
var _reward_type: int
var _seed: int
var _options: Array[RewardOption] = []
var _valid: bool
var _configuration_error: StringName


func _init(
		p_offer_id: StringName,
		p_room_id: StringName,
		p_reward_type: int,
		p_seed: int,
		p_options: Array[RewardOption],
		p_valid: bool = true,
		p_configuration_error: StringName = &""
) -> void:
	_offer_id = p_offer_id
	_room_id = p_room_id
	_reward_type = p_reward_type
	_seed = p_seed
	_options = p_options.duplicate()
	_valid = p_valid
	_configuration_error = p_configuration_error


static func configuration_failure(
		p_room_id: StringName,
		p_reward_type: int,
		p_seed: int,
		error: StringName
) -> RewardOffer:
	return RewardOffer.new(&"", p_room_id, p_reward_type, p_seed, [], false, error)


func find_option(option_id: StringName) -> RewardOption:
	for option in _options:
		if option.option_id == option_id:
			return option
	return null


func contains_content(content_id: StringName) -> bool:
	for option in _options:
		if option.content_id == content_id:
			return true
	return false


func has_unique_content() -> bool:
	var seen: Array[StringName] = []
	for option in _options:
		if seen.has(option.content_id):
			return false
		seen.append(option.content_id)
	return true
