class_name RunRulesSnapshot
extends RefCounted

## Immutable product rules copied into RunSession at run creation.

const BASIS_POINTS_DENOMINATOR: int = 10000

var progression_mode: RunFeatureMode.Value:
	get:
		return _progression_mode

var relic_mode: RunFeatureMode.Value:
	get:
		return _relic_mode

var upgrade_refund_basis_points: int:
	get:
		return _upgrade_refund_basis_points

var legacy_free_rewards_enabled: bool:
	get:
		return _legacy_free_rewards_enabled

var terminal_enemy_dream_dust_reward: int:
	get:
		return 0

var terminal_room_dream_dust_reward: int:
	get:
		return 0

var terminal_shop_enabled: bool:
	get:
		return false

var validation_error: StringName:
	get:
		return _validation_error

var _progression_mode: RunFeatureMode.Value
var _relic_mode: RunFeatureMode.Value
var _upgrade_refund_basis_points: int
var _legacy_free_rewards_enabled: bool
var _validation_error: StringName = &""


func _init(
		p_progression_mode: RunFeatureMode.Value = RunFeatureMode.Value.ENABLED,
		p_relic_mode: RunFeatureMode.Value = RunFeatureMode.Value.ENABLED,
		p_upgrade_refund_basis_points: int = 7000,
		p_legacy_free_rewards_enabled: bool = true
) -> void:
	_progression_mode = p_progression_mode
	_relic_mode = p_relic_mode
	_upgrade_refund_basis_points = p_upgrade_refund_basis_points
	_legacy_free_rewards_enabled = p_legacy_free_rewards_enabled
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func copy() -> RunRulesSnapshot:
	return RunRulesSnapshot.new(
		_progression_mode,
		_relic_mode,
		_upgrade_refund_basis_points,
		_legacy_free_rewards_enabled
	)


static func legacy_enabled() -> RunRulesSnapshot:
	return RunRulesSnapshot.new(
		RunFeatureMode.Value.ENABLED,
		RunFeatureMode.Value.ENABLED,
		7000,
		true
	)


static func formal_disabled() -> RunRulesSnapshot:
	return RunRulesSnapshot.new(
		RunFeatureMode.Value.DISABLED,
		RunFeatureMode.Value.DISABLED,
		7000,
		false
	)


func _validate_values() -> StringName:
	if not RunFeatureMode.is_valid(_progression_mode):
		return &"invalid_progression_mode"
	if not RunFeatureMode.is_valid(_relic_mode):
		return &"invalid_relic_mode"
	if (
		_upgrade_refund_basis_points < 0
		or _upgrade_refund_basis_points > BASIS_POINTS_DENOMINATOR
	):
		return &"invalid_upgrade_refund_basis_points"
	return &""
