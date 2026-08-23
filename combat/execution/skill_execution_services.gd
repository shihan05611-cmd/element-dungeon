class_name SkillExecutionServices
extends RefCounted

var reclaim_port: ElementReclaimPort
var ignition_port: RangeIgnitionPort
var projectile_sweep_query_port: ProjectileSweepQueryPort2D
var skill_delivery_prepare_port: SkillDeliveryPreparePort
var _projectile_source_ref: WeakRef


func _init(
		p_reclaim_port: ElementReclaimPort = null,
		p_projectile_sweep_query_port: ProjectileSweepQueryPort2D = null,
		p_skill_delivery_prepare_port: SkillDeliveryPreparePort = null,
		p_projectile_source: Node2D = null
) -> void:
	reclaim_port = p_reclaim_port
	projectile_sweep_query_port = p_projectile_sweep_query_port
	skill_delivery_prepare_port = p_skill_delivery_prepare_port
	_projectile_source_ref = weakref(p_projectile_source) if p_projectile_source != null else null


func set_reclaim_port(port: ElementReclaimPort) -> void:
	reclaim_port = port


func set_ignition_port(port: RangeIgnitionPort) -> void:
	ignition_port = port


func clear_temporary_states(reason: StringName) -> void:
	if ignition_port != null:
		ignition_port.clear_status(reason)


func set_projectile_sweep_query_port(port: ProjectileSweepQueryPort2D) -> void:
	projectile_sweep_query_port = port


func set_skill_delivery_prepare_port(port: SkillDeliveryPreparePort) -> void:
	skill_delivery_prepare_port = port


func set_projectile_source(source: Node2D) -> void:
	_projectile_source_ref = weakref(source) if source != null else null


func projectile_source() -> Node2D:
	return (
		_projectile_source_ref.get_ref() as Node2D
		if _projectile_source_ref != null
		else null
	)


func copy_with_reclaim_port(port: ElementReclaimPort) -> SkillExecutionServices:
	var copied := SkillExecutionServices.new(
		port,
		projectile_sweep_query_port,
		skill_delivery_prepare_port,
		projectile_source()
	)
	copied.ignition_port = ignition_port
	return copied
