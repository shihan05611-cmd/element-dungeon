class_name RelicInventorySnapshot
extends RefCounted

## Immutable owned-relic set plus UI-safe display state.

var owned_relic_ids: Array[StringName]:
	get:
		return _owned_relic_ids.duplicate()

var display_states: Array[RelicDisplayState]:
	get:
		return _display_states.duplicate()

var _owned_relic_ids: Array[StringName] = []
var _display_states: Array[RelicDisplayState] = []


func _init(
		p_owned_relic_ids: Array[StringName] = [],
		p_display_states: Array[RelicDisplayState] = []
) -> void:
	for relic_id in p_owned_relic_ids:
		if not relic_id.is_empty() and not _owned_relic_ids.has(relic_id):
			_owned_relic_ids.append(relic_id)
	_owned_relic_ids.sort()
	_display_states = p_display_states.duplicate()


func owns(relic_id: StringName) -> bool:
	return _owned_relic_ids.has(relic_id)


func display_state_for(relic_id: StringName) -> RelicDisplayState:
	for state in _display_states:
		if state.relic_id == relic_id:
			return state
	return null
