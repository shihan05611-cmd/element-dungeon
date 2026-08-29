class_name RangeIgnitionPort
extends RefCounted

## Fire-only sibling of the reclaim query. It deliberately has no Energy
## dependency or full-energy rejection: its whole transaction is target fire
## consumption plus a player-owned IgnitionState activation.

var hurtbox_collision_mask: int = 8
var max_query_results: int = 256

var _source_ref: WeakRef
var _state_ref: WeakRef
var _published_callback: Callable


func _init(
		source: Node2D = null,
		state: IgnitionState = null,
		p_hurtbox_collision_mask: int = 8,
		p_max_query_results: int = 256,
		published_callback: Callable = Callable()
) -> void:
	hurtbox_collision_mask = p_hurtbox_collision_mask
	max_query_results = p_max_query_results
	_published_callback = published_callback
	if source != null and state != null:
		configure(source, state)


func configure(source: Node2D, state: IgnitionState) -> bool:
	if not _is_live_node(source) or not _is_live_node(state):
		return false
	_source_ref = weakref(source)
	_state_ref = weakref(state)
	return true


func clear_status(reason: StringName) -> void:
	var state := _state_ref.get_ref() as IgnitionState if _state_ref != null else null
	if _is_live_node(state):
		state.clear(reason)


func prepare(cast_snapshot: CastSnapshot) -> IgnitionPrepareResult:
	if cast_snapshot == null or not cast_snapshot.is_valid():
		return IgnitionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_ignition_cast_snapshot"
		)
	if cast_snapshot.cast_element_id != ElementIds.FIRE:
		return IgnitionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"ignition_requires_fire_cast"
		)
	if hurtbox_collision_mask <= 0 or max_query_results <= 0:
		return IgnitionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_ignition_query_configuration"
		)
	var source := _source_ref.get_ref() as Node2D if _source_ref != null else null
	var state := _state_ref.get_ref() as IgnitionState if _state_ref != null else null
	if not _is_live_node(source) or not source.is_inside_tree() or not _is_live_node(state):
		return IgnitionPrepareResult.rejected(
			CastAttemptResult.RejectReason.MISSING_COMPONENT,
			&"ignition_query_dependencies_unavailable"
		)
	var candidates := CombatTargetQuery2D.query_visible_world_rect(
		source,
		hurtbox_collision_mask,
		max_query_results,
		cast_snapshot.team_id,
		true
	)
	var plans: Array[ElementReclaimTargetPlan] = []
	var positions: Array[Vector2] = []
	for candidate: CombatTargetCandidate2D in candidates:
		if not candidate.is_valid():
			continue
		var carrier := candidate.receiver.get_element_carrier()
		if not _is_live_node(carrier):
			continue
		var consume_plan := carrier.prepare_consume_all(ElementIds.FIRE)
		if consume_plan == null:
			continue
		plans.append(ElementReclaimTargetPlan.new(
			candidate.receiver,
			carrier,
			cast_snapshot.team_id,
			consume_plan
		))
		var target := candidate.receiver.get_parent() as Node2D
		if _is_live_node(target):
			positions.append(target.global_position)
	if plans.is_empty():
		return IgnitionPrepareResult.rejected(
			CastAttemptResult.RejectReason.NO_LEGAL_TARGET,
			&"no_ignition_fire_targets"
		)
	plans.sort_custom(func(a: ElementReclaimTargetPlan, b: ElementReclaimTargetPlan) -> bool:
		return a.stable_identity < b.stable_identity
	)
	var transaction := IgnitionTransaction.new(
		state,
		plans,
		positions,
		_published_callback,
		cast_snapshot.cast_id,
		cast_snapshot.level_effect.damage_scale
	)
	var error := transaction.validation_error()
	if not error.is_empty():
		return IgnitionPrepareResult.rejected(CastAttemptResult.RejectReason.INVALID_CONFIGURATION, error)
	return IgnitionPrepareResult.success(transaction.matched_element_amount, transaction)


static func _is_live_node(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


class IgnitionTransaction:
	extends SkillExecutionCommitTransaction

	var matched_element_amount: int = 0
	var _state_ref: WeakRef
	var _target_plans: Array[ElementReclaimTargetPlan] = []
	var _positions: Array[Vector2] = []
	var _published_callback: Callable
	var _cast_id: int
	var _damage_scale: float
	var _committed: bool = false
	var _published: bool = false

	func _init(
			state: IgnitionState,
			plans: Array[ElementReclaimTargetPlan],
			positions: Array[Vector2],
			published_callback: Callable,
			cast_id: int,
			damage_scale: float
	) -> void:
		_state_ref = weakref(state)
		_target_plans = plans.duplicate()
		_positions = positions.duplicate()
		_published_callback = published_callback
		_cast_id = cast_id
		_damage_scale = damage_scale
		for plan: ElementReclaimTargetPlan in _target_plans:
			if plan != null and plan.consume_plan != null:
				matched_element_amount += plan.consume_plan.consumed_amount

	func validation_error() -> StringName:
		if _committed:
			return &""
		var state := _state_ref.get_ref() as IgnitionState if _state_ref != null else null
		if not RangeIgnitionPort._is_live_node(state):
			return &"ignition_state_unavailable"
		if _target_plans.is_empty() or matched_element_amount <= 0:
			return &"missing_ignition_targets"
		var previous_identity := 0
		for plan: ElementReclaimTargetPlan in _target_plans:
			if plan == null or plan.stable_identity <= previous_identity:
				return &"unstable_ignition_target_order"
			previous_identity = plan.stable_identity
			var target_error := plan.validation_error()
			if not target_error.is_empty():
				return target_error
		return &""

	func commit_silent() -> void:
		assert(not _committed and validation_error().is_empty())
		for plan: ElementReclaimTargetPlan in _target_plans:
			plan.commit_silent()
		var state := _state_ref.get_ref() as IgnitionState
		assert(state.activate_silent(matched_element_amount, _damage_scale))
		_committed = true

	func publish_committed() -> void:
		assert(_committed and not _published)
		for plan: ElementReclaimTargetPlan in _target_plans:
			plan.publish_committed()
		var state := _state_ref.get_ref() as IgnitionState
		assert(state != null and is_instance_valid(state))
		state.publish_activated()
		_published = true
		if _published_callback.is_valid() and not _positions.is_empty():
			_published_callback.call(ReclaimVfxEvent.new(_cast_id, ElementIds.FIRE, _positions))
