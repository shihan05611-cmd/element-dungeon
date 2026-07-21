class_name GrowthEffectPort
extends RefCounted

## Integration-owned narrow effect sink. Implementations may adapt these calls
## to Player components, but the growth domain never stores or queries Nodes.

func restore_energy(_amount: int, _source_relic_id: StringName, _event_id: StringName) -> bool:
	return false


func restore_health(_amount: int, _source_relic_id: StringName, _event_id: StringName) -> bool:
	return false


func apply_temporary_attack_multiplier(
		_multiplier: float,
		_duration_seconds: float,
		_source_relic_id: StringName,
		_event_id: StringName
) -> bool:
	return false


func increase_maximum_health(_amount: int, _source_relic_id: StringName) -> bool:
	return false


func increase_maximum_energy(_amount: int, _source_relic_id: StringName) -> bool:
	return false
