class_name RunEconomyState
extends RefCounted

var _balance: int = 0
var _total_earned: int = 0
var _total_spent_on_purchases: int = 0
var _total_spent_on_upgrades: int = 0
var _total_refunded: int = 0


func _init(initial_dream_dust: int = 0) -> void:
	assert(initial_dream_dust >= 0, "initial dream dust must be non-negative")
	_balance = maxi(0, initial_dream_dust)
	_total_earned = _balance


func snapshot() -> DreamDustSnapshot:
	return DreamDustSnapshot.new(
		_balance,
		_total_earned,
		_total_spent_on_purchases,
		_total_spent_on_upgrades,
		_total_refunded
	)


func can_spend(amount: int) -> bool:
	return amount >= 0 and _balance >= amount


func commit_earned(amount: int) -> void:
	assert(amount >= 0, "earned dream dust must be validated")
	_balance += amount
	_total_earned += amount
	_assert_conserved()


func commit_purchase(amount: int) -> void:
	assert(amount > 0 and can_spend(amount), "purchase spend must be validated")
	_balance -= amount
	_total_spent_on_purchases += amount
	_assert_conserved()


func commit_upgrade(amount: int) -> void:
	assert(amount > 0 and can_spend(amount), "upgrade spend must be validated")
	_balance -= amount
	_total_spent_on_upgrades += amount
	_assert_conserved()


func commit_refund(amount: int) -> void:
	assert(amount >= 0, "refund must be validated")
	_balance += amount
	_total_refunded += amount
	_assert_conserved()


func _assert_conserved() -> void:
	assert(snapshot().is_valid(), "dream dust state must remain conserved")
