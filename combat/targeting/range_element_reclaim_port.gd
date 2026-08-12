class_name RangeElementReclaimPort
extends ElementReclaimPort

## Concrete spatial port. The current source Viewport and canvas transform are
## the only range authority; no live combat stats or current element are read.

var hurtbox_collision_mask: int = 8
var max_query_results: int = 256

var _source_ref: WeakRef
var _energy_ref: WeakRef


func _init(
		source: Node2D = null,
		energy: EnergyComponent = null,
		p_hurtbox_collision_mask: int = 8,
		p_max_query_results: int = 256
) -> void:
	hurtbox_collision_mask = p_hurtbox_collision_mask
	max_query_results = p_max_query_results
	if source != null and energy != null:
		configure(source, energy)


func configure(source: Node2D, energy: EnergyComponent) -> bool:
	if not _is_live_node(source) or not _is_live_node(energy):
		return false
	_source_ref = weakref(source)
	_energy_ref = weakref(energy)
	return true


func prepare(request: ElementReclaimRequest) -> ElementReclaimPrepareResult:
	if request == null:
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_reclaim_request"
		)
	var valid_full_request := (
		request.cast_snapshot != null
		and request.cast_snapshot.is_valid()
		and ElementIds.is_combat_element(request.cast_snapshot.cast_element_id)
		and request.maximum_energy > 0
		and request.current_energy == request.maximum_energy
	)
	if not request.is_valid() and not valid_full_request:
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_reclaim_request"
		)
	if (
		hurtbox_collision_mask <= 0
		or max_query_results <= 0
	):
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_reclaim_query_configuration"
		)
	var source := _source_ref.get_ref() as Node2D if _source_ref != null else null
	var energy := _energy_ref.get_ref() as EnergyComponent if _energy_ref != null else null
	if (
		not _is_live_node(source)
		or not source.is_inside_tree()
		or not _is_live_node(energy)
	):
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.MISSING_COMPONENT,
			&"reclaim_query_dependencies_unavailable"
		)
	if (
		energy.current_energy != request.current_energy
		or energy.maximum != request.maximum_energy
	):
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"reclaim_energy_snapshot_changed"
		)
	if energy.current_energy >= energy.maximum:
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.NO_BENEFIT,
			&"energy_already_full"
		)

	var candidates := CombatTargetQuery2D.query_visible_world_rect(
		source,
		hurtbox_collision_mask,
		max_query_results,
		request.cast_snapshot.team_id,
		true
	)
	if candidates.is_empty():
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.NO_LEGAL_TARGET,
			&"no_reclaim_targets"
		)
	var target_plans: Array[ElementReclaimTargetPlan] = []
	for candidate: CombatTargetCandidate2D in candidates:
		if not candidate.is_valid():
			continue
		var carrier := candidate.receiver.get_element_carrier()
		if not _is_live_node(carrier):
			continue
		var consume_plan := carrier.prepare_consume_all(request.cast_snapshot.cast_element_id)
		if consume_plan == null:
			continue
		target_plans.append(ElementReclaimTargetPlan.new(
			candidate.receiver,
			carrier,
			request.cast_snapshot.team_id,
			consume_plan
		))
	if target_plans.is_empty():
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.NO_LEGAL_TARGET,
			&"no_matching_element"
		)
	target_plans.sort_custom(func(a: ElementReclaimTargetPlan, b: ElementReclaimTargetPlan) -> bool:
		return a.stable_identity < b.stable_identity
	)
	var transaction := RangeElementReclaimTransaction.new(
		energy,
		request.current_energy,
		request.maximum_energy,
		target_plans
	)
	var transaction_error := transaction.validation_error()
	if not transaction_error.is_empty():
		return ElementReclaimPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			transaction_error
		)
	return ElementReclaimPrepareResult.success(
		transaction.matched_element_amount,
		transaction.theoretical_energy_restore,
		transaction
	)


static func _is_live_node(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and not node.is_queued_for_deletion()
	)
