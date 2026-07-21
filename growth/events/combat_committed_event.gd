class_name CombatCommittedEvent
extends RunEvent

## Explicit projection of an already-accepted CombatResult. No combat object or
## target reference crosses into the growth domain.

var cast_id: int:
	get:
		return _cast_id

var delivery_id: int:
	get:
		return _delivery_id

var hit_index: int:
	get:
		return _hit_index

var target_id: StringName:
	get:
		return _target_id

var skill_id: StringName:
	get:
		return _skill_id

var source_element_id: StringName:
	get:
		return _source_element_id

var final_damage: int:
	get:
		return _final_damage

var reaction_consumed: int:
	get:
		return _reaction_consumed

var target_current_health: int:
	get:
		return _target_current_health

var _cast_id: int
var _delivery_id: int
var _hit_index: int
var _target_id: StringName
var _skill_id: StringName
var _source_element_id: StringName
var _final_damage: int
var _reaction_consumed: int
var _target_current_health: int


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_cast_id: int,
		p_delivery_id: int,
		p_hit_index: int,
		p_target_id: StringName,
		p_skill_id: StringName,
		p_source_element_id: StringName,
		p_final_damage: int,
		p_reaction_consumed: int,
		p_target_current_health: int
) -> void:
	super(p_event_id, Kind.COMBAT_COMMITTED, p_room_id)
	_cast_id = p_cast_id
	_delivery_id = p_delivery_id
	_hit_index = p_hit_index
	_target_id = p_target_id
	_skill_id = p_skill_id
	_source_element_id = p_source_element_id
	_final_damage = p_final_damage
	_reaction_consumed = p_reaction_consumed
	_target_current_health = p_target_current_health


func is_valid() -> bool:
	return (
		super()
		and _cast_id > 0
		and _delivery_id > 0
		and _hit_index >= 0
		and not _target_id.is_empty()
		and not _skill_id.is_empty()
		and not _source_element_id.is_empty()
		and _final_damage >= 0
		and _reaction_consumed >= 0
		and _target_current_health >= 0
	)
