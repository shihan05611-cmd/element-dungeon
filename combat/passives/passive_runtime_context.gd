class_name PassiveRuntimeContext
extends RefCounted

var owner_port: PassiveOwnerPort
var target_port: PassiveTargetPort


func _init(
		p_owner_port: PassiveOwnerPort = null,
		p_target_port: PassiveTargetPort = null
) -> void:
	owner_port = p_owner_port
	target_port = p_target_port
