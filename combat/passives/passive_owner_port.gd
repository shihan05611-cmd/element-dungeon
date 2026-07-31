class_name PassiveOwnerPort
extends RefCounted

func capture_attack_stats() -> CombatStatSnapshot:
	return null


func restore_health(
		_amount: int,
		_source_skill_id: StringName,
		_event_id: StringName
) -> bool:
	return false
