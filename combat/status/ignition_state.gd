class_name IgnitionState
extends Node

## Player-owned temporary combat state. The multiplier is captured into a
## basic attack at acceptance; later expiry never mutates an in-flight payload.

signal activated(absorbed_fire_layers: int, multiplier: float)
signal cleared(reason: StringName)

const DURATION_SECONDS := 8.0

var active: bool:
	get:
		return _remaining_seconds > 0.0

var multiplier: float:
	get:
		return _multiplier if active else 1.0

var remaining_seconds: float:
	get:
		return _remaining_seconds

var absorbed_fire_layers: int:
	get:
		return _absorbed_fire_layers if active else 0

var _remaining_seconds: float = 0.0
var _multiplier: float = 1.0
var _absorbed_fire_layers: int = 0


func activate_silent(fire_layers: int) -> bool:
	if fire_layers <= 0:
		return false
	_absorbed_fire_layers = fire_layers
	_multiplier = 1.0 + 0.05 * float(fire_layers)
	_remaining_seconds = DURATION_SECONDS
	return true


func publish_activated() -> void:
	if active:
		activated.emit(_absorbed_fire_layers, _multiplier)


func clear(reason: StringName = &"cleared") -> void:
	var was_active := active
	_remaining_seconds = 0.0
	_multiplier = 1.0
	_absorbed_fire_layers = 0
	if was_active:
		cleared.emit(reason)


func _process(delta: float) -> void:
	if not active:
		return
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	if _remaining_seconds <= 0.0:
		clear(&"expired")
