class_name ElementReclaimRequest
extends RefCounted

var cast_snapshot: CastSnapshot
var current_energy: int
var maximum_energy: int


func _init(p_cast_snapshot: CastSnapshot, p_current_energy: int, p_maximum_energy: int) -> void:
	cast_snapshot = p_cast_snapshot
	current_energy = p_current_energy
	maximum_energy = p_maximum_energy


func is_valid() -> bool:
	return (
		cast_snapshot != null
		and cast_snapshot.is_valid()
		and ElementIds.is_combat_element(cast_snapshot.cast_element_id)
		and current_energy >= 0
		and maximum_energy > 0
		and current_energy < maximum_energy
	)
