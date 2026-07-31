class_name ReclaimVfxPort
extends ElementReclaimPort

## Presentation decorator for the formal task-15 reclaim port. It delegates
## validation and mutation unchanged, then publishes read-only target positions
## only after the wrapped transaction has successfully published.

class ReclaimVfxTransaction:
	extends SkillExecutionCommitTransaction

	var _inner: SkillExecutionCommitTransaction
	var _cast_id: int
	var _element_id: StringName
	var _target_refs: Array[WeakRef] = []
	var _published_callback: Callable
	var _committed: bool = false
	var _published: bool = false

	func _init(
			inner: SkillExecutionCommitTransaction,
			cast_id: int,
			element_id: StringName,
			target_refs: Array[WeakRef],
			published_callback: Callable
	) -> void:
		_inner = inner
		_cast_id = cast_id
		_element_id = element_id
		_target_refs = target_refs.duplicate()
		_published_callback = published_callback

	func validation_error() -> StringName:
		if _inner == null:
			return &"missing_reclaim_vfx_inner_transaction"
		return _inner.validation_error()

	func commit_silent() -> void:
		assert(not _committed, "reclaim VFX transaction commits once")
		assert(validation_error().is_empty(), "wrapped reclaim transaction must validate")
		_inner.commit_silent()
		_committed = true

	func publish_committed() -> void:
		assert(_committed, "reclaim VFX publishes only after commit")
		assert(not _published, "reclaim VFX transaction publishes once")
		_inner.publish_committed()
		_published = true
		var positions: Array[Vector2] = []
		for target_ref: WeakRef in _target_refs:
			var target := target_ref.get_ref() as Node2D
			if _is_live_node(target):
				positions.append(target.global_position)
		if positions.is_empty() or not _published_callback.is_valid():
			return
		var event := ReclaimVfxEvent.new(_cast_id, _element_id, positions)
		if event.is_valid():
			_published_callback.call(event)

	static func _is_live_node(node: Node) -> bool:
		return (
			node != null
			and is_instance_valid(node)
			and not node.is_queued_for_deletion()
			and node.is_inside_tree()
		)


var _inner_port: ElementReclaimPort
var _published_callback: Callable


func _init(
		inner_port: ElementReclaimPort = null,
		published_callback: Callable = Callable()
) -> void:
	_inner_port = inner_port
	_published_callback = published_callback


func prepare(request: ElementReclaimRequest) -> ElementReclaimPrepareResult:
	if _inner_port == null:
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.MISSING_COMPONENT,
			&"missing_reclaim_vfx_inner_port"
		)
	var prepared := _inner_port.prepare(request)
	if prepared == null or not prepared.accepted:
		return prepared
	if prepared.transaction == null:
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"missing_reclaim_vfx_inner_transaction"
		)
	var target_refs := _capture_transaction_targets(prepared.transaction)
	if target_refs.is_empty():
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"missing_reclaim_vfx_targets"
		)
	var wrapped := ReclaimVfxTransaction.new(
		prepared.transaction,
		request.cast_snapshot.cast_id,
		request.cast_snapshot.cast_element_id,
		target_refs,
		_published_callback
	)
	return ElementReclaimPrepareResult.success(
		prepared.matched_element_amount,
		prepared.theoretical_energy_restore,
		wrapped
	)


func _capture_transaction_targets(
		transaction: SkillExecutionCommitTransaction
) -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	if not transaction is RangeElementReclaimTransaction:
		return result
	var plans_value: Variant = transaction.get("_target_plans")
	if not plans_value is Array:
		return result
	for plan_value: Variant in plans_value:
		var plan := plan_value as ElementReclaimTargetPlan
		if plan == null:
			continue
		var receiver_ref := plan.get("_receiver_ref") as WeakRef
		var receiver := (
			receiver_ref.get_ref() as CombatReceiver
			if receiver_ref != null
			else null
		)
		var target := receiver.get_parent() as Node2D if receiver != null else null
		if target != null and is_instance_valid(target) and not target.is_queued_for_deletion():
			result.append(weakref(target))
	return result

