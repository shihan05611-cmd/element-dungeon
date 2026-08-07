class_name CombatSkillDeliveryAdapter
extends SkillDeliveryPreparePort

## Player-scoped adapter that prepares Fury Delivery nodes completely off-tree.

var _source_ref: WeakRef
var _catalog: RunContentCatalog
var _metrics: Dictionary = {}


func _init(source: Node2D, catalog: RunContentCatalog) -> void:
	_source_ref = weakref(source) if source != null else null
	_catalog = catalog
	reset_metrics()


func prepare(
		snapshot: SkillExecutionSnapshot,
		spawn_snapshot: DeliverySpawnSnapshot
) -> PreparedSkillDeliveryTransaction:
	_metrics[&"prepare_calls"] += 1
	if not snapshot is AllEnergyBurstExecutionSnapshot:
		return _reject_prepare()
	var burst_snapshot := snapshot as AllEnergyBurstExecutionSnapshot
	if not burst_snapshot.is_valid() or spawn_snapshot == null or not spawn_snapshot.is_valid():
		return _reject_prepare()
	var source := _source()
	if not _is_live_source(source) or _catalog == null:
		return _reject_prepare()
	var parent := _resolve_delivery_parent(source)
	if not _is_live_parent(parent):
		return _reject_prepare()
	var delivery_scene := _catalog.runtime_delivery_scene_for(snapshot.skill_id)
	if delivery_scene == null:
		return _reject_prepare()
	var node := delivery_scene.instantiate()
	_metrics[&"node_instantiate_count"] += 1
	var rage := node as ElementRageDelivery
	if rage == null:
		_discard_node(node)
		return _reject_prepare()
	rage.trigger_on_ready = false
	if not rage.initialize_burst(
		burst_snapshot,
		1,
		spawn_snapshot.initial_transform,
		spawn_snapshot.direction
	):
		_discard_node(rage)
		return _reject_prepare()
	var delivery_error := rage.preparation_validation_error()
	if not delivery_error.is_empty():
		_discard_node(rage)
		return _reject_prepare()
	rage.tree_exited.connect(_on_attached_delivery_tree_exited, CONNECT_ONE_SHOT)
	var transaction := PreparedSkillDeliveryTransaction.new(
		rage,
		parent,
		Callable(self, &"_on_delivery_attached"),
		Callable(self, &"_on_uncommitted_delivery_discarded")
	)
	if not transaction.validation_error().is_empty():
		transaction.discard_uncommitted()
		return _reject_prepare()
	_metrics[&"prepared_delivery_count"] += 1
	return transaction


func metrics_snapshot() -> Dictionary:
	return _metrics.duplicate(true)


func reset_metrics() -> void:
	_metrics = {
		&"prepare_calls": 0,
		&"prepare_reject_count": 0,
		&"prepared_delivery_count": 0,
		&"node_instantiate_count": 0,
		&"node_add_count": 0,
		&"node_free_count": 0,
	}


func _source() -> Node2D:
	return _source_ref.get_ref() as Node2D if _source_ref != null else null


func _resolve_delivery_parent(source: Node2D) -> Node:
	var tree := source.get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return source.get_parent()


func _reject_prepare() -> PreparedSkillDeliveryTransaction:
	_metrics[&"prepare_reject_count"] += 1
	return null


func _discard_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()
		_metrics[&"node_free_count"] += 1


func _on_delivery_attached() -> void:
	_metrics[&"node_add_count"] += 1


func _on_uncommitted_delivery_discarded() -> void:
	_metrics[&"node_free_count"] += 1


func _on_attached_delivery_tree_exited() -> void:
	_metrics[&"node_free_count"] += 1


static func _is_live_source(source: Node2D) -> bool:
	return (
		source != null
		and is_instance_valid(source)
		and not source.is_queued_for_deletion()
		and source.is_inside_tree()
		and source.get_world_2d() != null
	)


static func _is_live_parent(parent: Node) -> bool:
	return (
		parent != null
		and is_instance_valid(parent)
		and not parent.is_queued_for_deletion()
		and parent.is_inside_tree()
	)
