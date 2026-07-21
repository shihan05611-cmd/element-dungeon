class_name ElementResolution
extends RefCounted

## Pure element calculation output. `before` and `after` are immutable and no
## target component is modified while this object is created.

var status: CombatStatus.SubResult:
	get:
		return _status

var before: ElementSnapshot:
	get:
		return _before

var after: ElementSnapshot:
	get:
		return _after

var incoming_element_id: StringName:
	get:
		return _incoming_element_id

var opposite_element_id: StringName:
	get:
		return _opposite_element_id

var incoming_amount: int:
	get:
		return _incoming_amount

var consumed_amount: int:
	get:
		return _consumed_amount

var remaining_incoming_amount: int:
	get:
		return _remaining_incoming_amount

var reaction_triggered: bool:
	get:
		return _consumed_amount > 0

var reaction_multiplier: float:
	get:
		return _reaction_multiplier

var water_delta: int:
	get:
		return _after.water_amount - _before.water_amount

var fire_delta: int:
	get:
		return _after.fire_amount - _before.fire_amount

var validation_error: StringName:
	get:
		return _validation_error

var _status: CombatStatus.SubResult
var _before: ElementSnapshot
var _after: ElementSnapshot
var _incoming_element_id: StringName
var _opposite_element_id: StringName
var _incoming_amount: int
var _consumed_amount: int
var _remaining_incoming_amount: int
var _reaction_multiplier: float
var _validation_error: StringName = &""


func _init(
		p_status: CombatStatus.SubResult,
		p_before: ElementSnapshot,
		p_after: ElementSnapshot,
		p_incoming_element_id: StringName,
		p_incoming_amount: int,
		p_consumed_amount: int,
		p_remaining_incoming_amount: int,
		p_reaction_multiplier: float,
		p_validation_error: StringName = &""
) -> void:
	_status = p_status
	_before = p_before
	_after = p_after
	_incoming_element_id = p_incoming_element_id
	_opposite_element_id = ElementIds.opposite_of(p_incoming_element_id)
	_incoming_amount = p_incoming_amount
	_consumed_amount = p_consumed_amount
	_remaining_incoming_amount = p_remaining_incoming_amount
	_reaction_multiplier = p_reaction_multiplier
	_validation_error = p_validation_error
	if _validation_error.is_empty():
		_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values() -> StringName:
	if _before == null or _after == null or not _before.is_valid() or not _after.is_valid():
		return &"invalid_element_snapshot"
	if not ElementIds.is_valid_payload_element(_incoming_element_id):
		return &"unknown_incoming_element"
	if _incoming_amount < 0 or _incoming_amount > 10:
		return &"invalid_incoming_amount"
	if _consumed_amount < 0 or _consumed_amount > _incoming_amount:
		return &"invalid_consumed_amount"
	if _remaining_incoming_amount < 0 or _remaining_incoming_amount > _incoming_amount:
		return &"invalid_remaining_amount"
	if not is_finite(_reaction_multiplier) or _reaction_multiplier < 1.0 or _reaction_multiplier > 4.0:
		return &"invalid_reaction_multiplier"
	return &""
