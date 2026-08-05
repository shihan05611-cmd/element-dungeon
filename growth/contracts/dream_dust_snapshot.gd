class_name DreamDustSnapshot
extends RefCounted

## Immutable, auditable single-wallet view.

var balance: int:
	get:
		return _balance

var total_earned: int:
	get:
		return _total_earned

var total_spent_on_purchases: int:
	get:
		return _total_spent_on_purchases

var total_spent_on_upgrades: int:
	get:
		return _total_spent_on_upgrades

var total_refunded: int:
	get:
		return _total_refunded

var total_spent: int:
	get:
		return _total_spent_on_purchases + _total_spent_on_upgrades

var validation_error: StringName:
	get:
		return _validation_error

var _balance: int
var _total_earned: int
var _total_spent_on_purchases: int
var _total_spent_on_upgrades: int
var _total_refunded: int
var _validation_error: StringName = &""


func _init(
		p_balance: int = 0,
		p_total_earned: int = 0,
		p_total_spent_on_purchases: int = 0,
		p_total_spent_on_upgrades: int = 0,
		p_total_refunded: int = 0
) -> void:
	_balance = p_balance
	_total_earned = p_total_earned
	_total_spent_on_purchases = p_total_spent_on_purchases
	_total_spent_on_upgrades = p_total_spent_on_upgrades
	_total_refunded = p_total_refunded
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func conserved_balance() -> int:
	return (
		_total_earned
		+ _total_refunded
		- _total_spent_on_purchases
		- _total_spent_on_upgrades
	)


func _validate_values() -> StringName:
	if (
		_balance < 0
		or _total_earned < 0
		or _total_spent_on_purchases < 0
		or _total_spent_on_upgrades < 0
		or _total_refunded < 0
	):
		return &"negative_dream_dust_field"
	if _balance != conserved_balance():
		return &"dream_dust_conservation_failed"
	return &""
