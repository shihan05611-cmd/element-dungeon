class_name PassiveTargetSnapshot
extends RefCounted

var target_id: StringName
var elements: ElementSnapshot


func _init(p_target_id: StringName, p_elements: ElementSnapshot) -> void:
	target_id = p_target_id
	elements = p_elements


func is_valid() -> bool:
	return not target_id.is_empty() and elements != null and elements.is_valid()
