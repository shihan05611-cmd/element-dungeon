class_name CombatStatSnapshot
extends RefCounted

## Whitelisted, immutable offensive stats captured when a cast is accepted.
## `from_dictionary` exists for integration code but rejects every unknown key
## and copies only validated scalar values.

const ATTACK_MULTIPLIER: StringName = &"attack_multiplier"
const FLAT_DAMAGE_BONUS: StringName = &"flat_damage_bonus"
const ALLOWED_FIELDS: Array[StringName] = [ATTACK_MULTIPLIER, FLAT_DAMAGE_BONUS]

var attack_multiplier: float:
	get:
		return _attack_multiplier

var flat_damage_bonus: float:
	get:
		return _flat_damage_bonus

var validation_error: StringName:
	get:
		return _validation_error

var _attack_multiplier: float = 1.0
var _flat_damage_bonus: float = 0.0
var _validation_error: StringName = &""


func _init(
		p_attack_multiplier: float = 1.0,
		p_flat_damage_bonus: float = 0.0,
		p_validation_error: StringName = &""
) -> void:
	_attack_multiplier = p_attack_multiplier
	_flat_damage_bonus = p_flat_damage_bonus
	_validation_error = p_validation_error
	if _validation_error.is_empty():
		_validation_error = _validate_values()


static func from_dictionary(values: Dictionary) -> CombatStatSnapshot:
	var copied := values.duplicate(true)
	for raw_key: Variant in copied.keys():
		var key := StringName(str(raw_key))
		if not ALLOWED_FIELDS.has(key):
			return CombatStatSnapshot.new(1.0, 0.0, &"unknown_stat_field")
		if not (copied[raw_key] is int or copied[raw_key] is float):
			return CombatStatSnapshot.new(1.0, 0.0, &"invalid_stat_type")
	var multiplier := float(copied.get(ATTACK_MULTIPLIER, 1.0))
	var flat_bonus := float(copied.get(FLAT_DAMAGE_BONUS, 0.0))
	return CombatStatSnapshot.new(multiplier, flat_bonus)


func is_valid() -> bool:
	return _validation_error.is_empty()


func calculate_offensive_damage(base_damage: float) -> float:
	if not is_valid() or not is_finite(base_damage):
		return NAN
	return maxf(0.0, base_damage * _attack_multiplier + _flat_damage_bonus)


func to_dictionary() -> Dictionary:
	return {
		ATTACK_MULTIPLIER: _attack_multiplier,
		FLAT_DAMAGE_BONUS: _flat_damage_bonus,
	}.duplicate(true)


func _validate_values() -> StringName:
	if not is_finite(_attack_multiplier) or _attack_multiplier < 0.0:
		return &"invalid_attack_multiplier"
	if not is_finite(_flat_damage_bonus):
		return &"invalid_flat_damage_bonus"
	return &""
