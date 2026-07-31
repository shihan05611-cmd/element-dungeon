class_name ReclaimVfxEvent
extends RefCounted

## Immutable presentation-only summary published after the authoritative
## reclaim transaction has committed and published all gameplay notifications.

var cast_id: int:
	get:
		return _cast_id

var element_id: StringName:
	get:
		return _element_id

var target_positions: Array[Vector2]:
	get:
		return _target_positions.duplicate()

var _cast_id: int
var _element_id: StringName
var _target_positions: Array[Vector2] = []


func _init(
		p_cast_id: int,
		p_element_id: StringName,
		p_target_positions: Array[Vector2]
) -> void:
	_cast_id = p_cast_id
	_element_id = p_element_id
	_target_positions = p_target_positions.duplicate()


func is_valid() -> bool:
	return (
		_cast_id > 0
		and ElementIds.is_combat_element(_element_id)
		and not _target_positions.is_empty()
	)

