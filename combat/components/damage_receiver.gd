class_name DamageReceiver
extends Node

## Minimal target health/flat-defense implementation. Runtime health lives on
## the Node instance, never in a shared Resource.

signal health_changed(current_health: int, maximum_health: int, delta: int)

@export_range(1, 1000000, 1, "or_greater") var configured_maximum_health: int = 100
@export_range(0, 1000000, 1, "or_greater") var configured_starting_health: int = 100
@export_range(0.0, 1000000.0, 0.01, "or_greater") var defense_flat: float = 0.0

var current_health: int:
	get:
		_ensure_initialized()
		return _current_health

var maximum_health: int:
	get:
		_ensure_initialized()
		return _maximum_health

var _current_health: int = 100
var _maximum_health: int = 100
var _initialized: bool = false


func _ready() -> void:
	_ensure_initialized()


func configure_runtime(max_health: int, starting_health: int, p_defense_flat: float = 0.0) -> bool:
	if max_health <= 0 or starting_health < 0 or starting_health > max_health:
		return false
	if not is_finite(p_defense_flat) or p_defense_flat < 0.0:
		return false
	_maximum_health = max_health
	_current_health = starting_health
	defense_flat = p_defense_flat
	_initialized = true
	return true


func is_runtime_valid() -> bool:
	_ensure_initialized()
	return (
		_maximum_health > 0
		and _current_health >= 0
		and _current_health <= _maximum_health
		and is_finite(defense_flat)
		and defense_flat >= 0.0
	)


func preview_health_after_damage(final_damage: int) -> int:
	_ensure_initialized()
	if final_damage < 0:
		return -1
	return maxi(0, _current_health - final_damage)


func can_replace_health(next_health: int) -> bool:
	_ensure_initialized()
	return next_health >= 0 and next_health <= _maximum_health


func replace_health_silent(next_health: int) -> bool:
	if not can_replace_health(next_health):
		return false
	_current_health = next_health
	return true


func notify_health_changed(delta: int) -> void:
	_ensure_initialized()
	health_changed.emit(_current_health, _maximum_health, delta)


func restore_full(emit_notification: bool = true) -> void:
	_ensure_initialized()
	var previous := _current_health
	_current_health = _maximum_health
	if emit_notification and previous != _current_health:
		notify_health_changed(_current_health - previous)


func _ensure_initialized() -> void:
	if _initialized:
		return
	_maximum_health = maxi(1, configured_maximum_health)
	_current_health = clampi(configured_starting_health, 0, _maximum_health)
	_initialized = true
