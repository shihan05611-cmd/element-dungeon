class_name PassiveTargetPort
extends RefCounted

func query_targets(_observed_element_id: StringName) -> Array[PassiveTargetSnapshot]:
	return []


func submit_damage(_request: PassiveDamageRequest) -> bool:
	return false
