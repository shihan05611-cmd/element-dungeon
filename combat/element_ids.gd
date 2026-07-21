class_name ElementIds
extends RefCounted

## The only element identifiers accepted by the MVP combat domain.
## Gameplay code should use these constants instead of spelling StringNames.

const NONE: StringName = &"none"
const WATER: StringName = &"water"
const FIRE: StringName = &"fire"

const ALL: Array[StringName] = [WATER, FIRE]


static func is_combat_element(element_id: StringName) -> bool:
	return element_id == WATER or element_id == FIRE


static func is_valid_payload_element(element_id: StringName) -> bool:
	return element_id == NONE or is_combat_element(element_id)


static func opposite_of(element_id: StringName) -> StringName:
	match element_id:
		WATER:
			return FIRE
		FIRE:
			return WATER
		_:
			return NONE
