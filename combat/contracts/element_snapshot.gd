class_name ElementSnapshot
extends RefCounted

## Immutable target element state used by the pure resolver.

var water_amount: int:
	get:
		return _water_amount

var fire_amount: int:
	get:
		return _fire_amount

var capacity: int:
	get:
		return _capacity

var validation_error: StringName:
	get:
		return _validation_error

var _water_amount: int
var _fire_amount: int
var _capacity: int
var _validation_error: StringName = &""


func _init(p_water_amount: int = 0, p_fire_amount: int = 0, p_capacity: int = 10) -> void:
	_water_amount = p_water_amount
	_fire_amount = p_fire_amount
	_capacity = p_capacity
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func get_amount(element_id: StringName) -> int:
	match element_id:
		ElementIds.WATER:
			return _water_amount
		ElementIds.FIRE:
			return _fire_amount
		_:
			return 0


func to_dictionary() -> Dictionary:
	return {
		ElementIds.WATER: _water_amount,
		ElementIds.FIRE: _fire_amount,
	}.duplicate(true)


func equals(other: ElementSnapshot) -> bool:
	return (
		other != null
		and _water_amount == other.water_amount
		and _fire_amount == other.fire_amount
		and _capacity == other.capacity
	)


func _validate_values() -> StringName:
	if _capacity <= 0 or _capacity > 10:
		return &"invalid_capacity"
	if _water_amount < 0 or _water_amount > _capacity:
		return &"invalid_water_amount"
	if _fire_amount < 0 or _fire_amount > _capacity:
		return &"invalid_fire_amount"
	return &""
