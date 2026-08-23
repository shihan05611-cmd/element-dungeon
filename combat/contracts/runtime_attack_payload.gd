class_name RuntimeAttackPayload
extends RefCounted

## Immutable attack values locked at cast acceptance. Delivery passes this
## object through unchanged for every target/hit index.

var effective_attack: float:
	get:
		return _effective_attack

var damage_multiplier: float:
	get:
		return _damage_multiplier

var fixed_damage_bonus: float:
	get:
		return _fixed_damage_bonus

var offensive_damage: float:
	get:
		return _offensive_damage

var element_id: StringName:
	get:
		return _element_id

var element_amount: int:
	get:
		return _element_amount

var melee_query_multiplier: float:
	get:
		return _melee_query_multiplier

var presentation_tags: PackedStringArray:
	get:
		return _presentation_tags.duplicate()

var validation_error: StringName:
	get:
		return _validation_error

var _effective_attack: float
var _damage_multiplier: float
var _fixed_damage_bonus: float
var _offensive_damage: float
var _element_id: StringName
var _element_amount: int
var _melee_query_multiplier: float = 1.0
var _presentation_tags: PackedStringArray
var _validation_error: StringName = &""


func _init(
		p_effective_attack: float,
		p_offensive_damage: float,
		p_element_id: StringName,
		p_element_amount: int,
		p_presentation_tags: PackedStringArray = PackedStringArray(),
		p_validation_error: StringName = &"",
		p_melee_query_multiplier: float = 1.0
) -> void:
	_effective_attack = p_effective_attack
	_damage_multiplier = (
		p_offensive_damage / p_effective_attack
		if p_effective_attack > 0.0 and is_finite(p_effective_attack)
		else 0.0
	)
	_fixed_damage_bonus = 0.0
	_offensive_damage = p_offensive_damage
	_element_id = p_element_id
	_element_amount = p_element_amount
	_melee_query_multiplier = p_melee_query_multiplier
	_presentation_tags = p_presentation_tags.duplicate()
	_validation_error = p_validation_error
	if _validation_error.is_empty():
		_validation_error = _validate_values()


static func invalid(error: StringName) -> RuntimeAttackPayload:
	return from_locked_inputs(
		0.0,
		0.0,
		0.0,
		0.0,
		ElementIds.NONE,
		0,
		PackedStringArray(),
		error,
		1.0
	)


static func from_locked_inputs(
		p_effective_attack: float,
		p_damage_multiplier: float,
		p_fixed_damage_bonus: float,
		p_offensive_damage: float,
		p_element_id: StringName,
		p_element_amount: int,
		p_presentation_tags: PackedStringArray = PackedStringArray(),
		p_validation_error: StringName = &"",
		p_melee_query_multiplier: float = 1.0
) -> RuntimeAttackPayload:
	var result := RuntimeAttackPayload.new(0.0, 0.0, ElementIds.NONE, 0)
	result._effective_attack = p_effective_attack
	result._damage_multiplier = p_damage_multiplier
	result._fixed_damage_bonus = p_fixed_damage_bonus
	result._offensive_damage = p_offensive_damage
	result._element_id = p_element_id
	result._element_amount = p_element_amount
	result._melee_query_multiplier = p_melee_query_multiplier
	result._presentation_tags = p_presentation_tags.duplicate()
	result._validation_error = p_validation_error
	if result._validation_error.is_empty():
		result._validation_error = result._validate_values()
	return result


static func from_locked_stats(
		stats: CombatStatSnapshot,
		p_damage_multiplier: float,
		p_element_id: StringName,
		p_element_amount: int,
		p_presentation_tags: PackedStringArray = PackedStringArray(),
		p_melee_query_multiplier: float = 1.0
) -> RuntimeAttackPayload:
	if stats == null or not stats.is_valid():
		return invalid(&"invalid_stat_snapshot")
	var damage := stats.calculate_offensive_damage(p_damage_multiplier)
	return from_locked_inputs(
		stats.effective_attack,
		p_damage_multiplier,
		stats.flat_damage_bonus,
		damage,
		p_element_id,
		p_element_amount,
		p_presentation_tags,
		&"",
		p_melee_query_multiplier
	)


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values() -> StringName:
	if not is_finite(_effective_attack) or _effective_attack < 0.0:
		return &"invalid_effective_attack"
	if not is_finite(_damage_multiplier) or _damage_multiplier < 0.0:
		return &"invalid_damage_multiplier"
	if not is_finite(_fixed_damage_bonus):
		return &"invalid_fixed_damage_bonus"
	if not is_finite(_offensive_damage) or _offensive_damage < 0.0:
		return &"invalid_offensive_damage"
	var expected := maxf(0.0, _effective_attack * _damage_multiplier + _fixed_damage_bonus)
	if not is_equal_approx(_offensive_damage, expected):
		return &"offensive_damage_mismatch"
	if not ElementIds.is_valid_payload_element(_element_id):
		return &"unknown_element_id"
	if _element_amount < 0 or _element_amount > 10:
		return &"invalid_element_amount"
	if not is_finite(_melee_query_multiplier) or _melee_query_multiplier < 1.0:
		return &"invalid_melee_query_multiplier"
	if _element_id == ElementIds.NONE and _element_amount != 0:
		return &"none_element_has_amount"
	return &""
