class_name ElementLayerConsumePlan
extends RefCounted

## Immutable, target-local plan for consuming every layer of one locked
## element. The other element and capacity must remain byte-for-byte stable.

var element_id: StringName:
	get:
		return _element_id

var before: ElementSnapshot:
	get:
		return _before

var after: ElementSnapshot:
	get:
		return _after

var consumed_amount: int:
	get:
		return _consumed_amount

var validation_error: StringName:
	get:
		return _validation_error

var _element_id: StringName
var _before: ElementSnapshot
var _after: ElementSnapshot
var _consumed_amount: int = 0
var _validation_error: StringName = &""


func _init(
		p_element_id: StringName,
		p_before: ElementSnapshot,
		p_after: ElementSnapshot
) -> void:
	_element_id = p_element_id
	_before = p_before
	_after = p_after
	_validation_error = _validate_values()
	if _validation_error.is_empty():
		_consumed_amount = _before.get_amount(_element_id) - _after.get_amount(_element_id)


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values() -> StringName:
	if not ElementIds.is_combat_element(_element_id):
		return &"invalid_consumed_element"
	if _before == null or not _before.is_valid():
		return &"invalid_before_snapshot"
	if _after == null or not _after.is_valid():
		return &"invalid_after_snapshot"
	if _before.capacity != _after.capacity:
		return &"element_capacity_changed"
	if _before.get_amount(_element_id) <= 0:
		return &"missing_consumable_layers"
	if _after.get_amount(_element_id) != 0:
		return &"matching_layers_not_fully_consumed"
	var other_element := (
		ElementIds.FIRE
		if _element_id == ElementIds.WATER
		else ElementIds.WATER
	)
	if _before.get_amount(other_element) != _after.get_amount(other_element):
		return &"unmatched_element_changed"
	return &""
