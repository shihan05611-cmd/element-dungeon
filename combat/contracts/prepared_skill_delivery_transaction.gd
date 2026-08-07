class_name PreparedSkillDeliveryTransaction
extends SkillExecutionCommitTransaction

## Owns a fully initialized off-tree Delivery until the synchronous commit.
## commit_silent only performs the already-validated attachment; activation is
## intentionally delayed until all accepted execution events are published.

var prepared_delivery: DeliveryBase:
	get:
		return _delivery

var _delivery: DeliveryBase
var _parent_ref: WeakRef
var _attached_callback: Callable
var _discarded_callback: Callable
var _committed: bool = false
var _published: bool = false
var _activated: bool = false


func _init(
		p_delivery: DeliveryBase,
		p_parent: Node,
		p_attached_callback: Callable = Callable(),
		p_discarded_callback: Callable = Callable()
) -> void:
	_delivery = p_delivery
	_parent_ref = weakref(p_parent) if p_parent != null else null
	_attached_callback = p_attached_callback
	_discarded_callback = p_discarded_callback


func validation_error() -> StringName:
	if _committed:
		return &"" if _delivery_is_attached() else &"prepared_delivery_commit_lost"
	if (
		_delivery == null
		or not is_instance_valid(_delivery)
		or _delivery.is_queued_for_deletion()
	):
		return &"prepared_delivery_unavailable"
	if not _delivery.is_initialized or not _delivery.validation_error.is_empty():
		return &"prepared_delivery_not_initialized"
	if _delivery.is_inside_tree() or _delivery.get_parent() != null:
		return &"prepared_delivery_already_attached"
	var parent := _parent()
	if (
		parent == null
		or not is_instance_valid(parent)
		or parent.is_queued_for_deletion()
		or not parent.is_inside_tree()
	):
		return &"prepared_delivery_parent_unavailable"
	return &""


func commit_silent() -> void:
	assert(not _committed, "prepared delivery transaction commits once")
	assert(validation_error().is_empty(), "prepared delivery commit must match validation")
	var parent := _parent()
	parent.add_child(_delivery)
	assert(_delivery_is_attached(), "validated prepared delivery attachment is infallible")
	_committed = true
	if _attached_callback.is_valid():
		_attached_callback.call()


func publish_committed() -> void:
	assert(_committed and not _published, "prepared delivery publishes exactly once after commit")
	_published = true


func owns_prepared_delivery() -> bool:
	return true


func requires_immediate_activation() -> bool:
	return true


func activate_prepared_delivery() -> bool:
	if not _committed or not _published or _activated or not _delivery_is_attached():
		return false
	if not _delivery.has_method(&"trigger_prepared_delivery"):
		return false
	var result: Variant = _delivery.call(&"trigger_prepared_delivery")
	_activated = bool(result)
	return _activated


func discard_uncommitted() -> void:
	if _committed:
		return
	if _delivery != null and is_instance_valid(_delivery):
		_delivery.free()
	_delivery = null
	if _discarded_callback.is_valid():
		_discarded_callback.call()


func _parent() -> Node:
	return _parent_ref.get_ref() as Node if _parent_ref != null else null


func _delivery_is_attached() -> bool:
	return (
		_delivery != null
		and is_instance_valid(_delivery)
		and not _delivery.is_queued_for_deletion()
		and _delivery.is_inside_tree()
		and _delivery.get_parent() == _parent()
	)
