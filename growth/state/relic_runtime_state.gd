class_name RelicRuntimeState
extends RefCounted

## Per-session state paired with a shared immutable RelicDefinition.

var cooldown_remaining: float:
	get:
		return _cooldown_remaining

var triggers_this_room: int:
	get:
		return _triggers_this_room

var current_room_id: StringName:
	get:
		return _current_room_id

var _cooldown_remaining: float = 0.0
var _triggers_this_room: int = 0
var _current_room_id: StringName = &""


func prepare_room(room_id: StringName) -> void:
	if room_id != _current_room_id:
		_current_room_id = room_id
		_triggers_this_room = 0


func can_trigger(definition: RelicDefinition) -> bool:
	if definition == null or not definition.is_valid() or _cooldown_remaining > 0.0:
		return false
	return definition.per_room_limit <= 0 or _triggers_this_room < definition.per_room_limit


func record_trigger(definition: RelicDefinition) -> void:
	_triggers_this_room += 1
	_cooldown_remaining = maxf(0.0, definition.internal_cooldown_seconds)


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0 or _cooldown_remaining <= 0.0:
		return false
	var previous := _cooldown_remaining
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	return not is_equal_approx(previous, _cooldown_remaining)
