class_name RouteOption
extends RefCounted

enum Kind {
	REWARD_ROOM,
	SHOP,
	RUN_COMPLETE,
	COMBAT_ROOM,
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

var target_node_id: StringName:
	get:
		return _target_node_id

var title: String:
	get:
		return _title

var encounter_label: String:
	get:
		return _encounter_label

var environment_label: String:
	get:
		return _environment_label

var risk_label: String:
	get:
		return _risk_label

var risk_tier: int:
	get:
		return _risk_tier

var expected_dream_dust_label: String:
	get:
		return _expected_dream_dust_label

var _option_id: StringName
var _kind: Kind
var _reward_type: int
var _target_node_id: StringName
var _title: String
var _encounter_label: String
var _environment_label: String
var _risk_label: String
var _risk_tier: int
var _expected_dream_dust_label: String


func _init(
		p_option_id: StringName,
		p_kind: Kind,
		p_reward_type: int = -1,
		p_target_node_id: StringName = &"",
		p_title: String = "",
		p_encounter_label: String = "",
		p_environment_label: String = "",
		p_risk_label: String = "",
		p_risk_tier: int = 0,
		p_expected_dream_dust_label: String = ""
) -> void:
	_option_id = p_option_id
	_kind = p_kind
	_reward_type = p_reward_type
	_target_node_id = p_target_node_id
	_title = p_title
	_encounter_label = p_encounter_label
	_environment_label = p_environment_label
	_risk_label = p_risk_label
	_risk_tier = maxi(0, p_risk_tier)
	_expected_dream_dust_label = p_expected_dream_dust_label


func is_valid() -> bool:
	if _option_id.is_empty():
		return false
	if _kind == Kind.REWARD_ROOM:
		return RewardType.is_valid(_reward_type)
	if _kind == Kind.COMBAT_ROOM:
		return (
			not _target_node_id.is_empty()
			and not _title.is_empty()
			and not _encounter_label.is_empty()
			and not _environment_label.is_empty()
			and not _risk_label.is_empty()
			and not _expected_dream_dust_label.is_empty()
		)
	return _kind == Kind.SHOP or _kind == Kind.RUN_COMPLETE
