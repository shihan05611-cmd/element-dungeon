class_name RuntimeAttackPayload
extends RefCounted

## Immutable attack values locked at cast acceptance. Delivery passes this
## object through unchanged for every target/hit index.

var base_damage: float:
	get:
		return _base_damage

var offensive_damage: float:
	get:
		return _offensive_damage

var element_id: StringName:
	get:
		return _element_id

var element_amount: int:
	get:
		return _element_amount

var presentation_tags: PackedStringArray:
	get:
		return _presentation_tags.duplicate()

var validation_error: StringName:
	get:
		return _validation_error

var _base_damage: float
var _offensive_damage: float
var _element_id: StringName
var _element_amount: int
var _presentation_tags: PackedStringArray
var _validation_error: StringName = &""


func _init(
		p_base_damage: float,
		p_offensive_damage: float,
		p_element_id: StringName,
		p_element_amount: int,
		p_presentation_tags: PackedStringArray = PackedStringArray(),
		p_validation_error: StringName = &""
) -> void:
	_base_damage = p_base_damage
	_offensive_damage = p_offensive_damage
	_element_id = p_element_id
	_element_amount = p_element_amount
	_presentation_tags = p_presentation_tags.duplicate()
	_validation_error = p_validation_error
	if _validation_error.is_empty():
		_validation_error = _validate_values()


static func invalid(error: StringName) -> RuntimeAttackPayload:
	return RuntimeAttackPayload.new(0.0, 0.0, ElementIds.NONE, 0, PackedStringArray(), error)


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values() -> StringName:
	if not is_finite(_base_damage) or _base_damage < 0.0:
		return &"invalid_base_damage"
	if not is_finite(_offensive_damage) or _offensive_damage < 0.0:
		return &"invalid_offensive_damage"
	if not ElementIds.is_valid_payload_element(_element_id):
		return &"unknown_element_id"
	if _element_amount < 0 or _element_amount > 10:
		return &"invalid_element_amount"
	if _element_id == ElementIds.NONE and _element_amount != 0:
		return &"none_element_has_amount"
	return &""
