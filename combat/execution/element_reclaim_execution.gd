class_name ElementReclaimExecution
extends SkillExecutionDefinition

@export_range(0.0, 60.0, 0.001, "or_greater") var active_time: float = 0.0


func validation_error() -> StringName:
	var base_error := super()
	if not base_error.is_empty():
		return base_error
	if not is_finite(active_time) or active_time < 0.0:
		return &"invalid_active_time"
	return &""


func element_policy_validation_error(
		policy: SkillDefinition.ElementPolicy,
		_required_element_id: StringName
) -> StringName:
	return (
		&""
		if policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT
		else &"element_reclaim_requires_current_element"
	)


func prepare(
		context: SkillExecutionContext,
		services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	if context == null or not context.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_execution_context"
		)
	if not is_equal_approx(context.skill.cooldown, 5.0):
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"element_reclaim_requires_five_second_cooldown"
		)
	if context.energy_before >= context.maximum_energy:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.NO_BENEFIT,
			&"energy_already_full"
		)
	if services == null or services.reclaim_port == null:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.MISSING_COMPONENT,
			&"missing_element_reclaim_port"
		)
	var request := ElementReclaimRequest.new(
		context.cast_snapshot,
		context.energy_before,
		context.maximum_energy
	)
	var prepared := services.reclaim_port.prepare(request)
	if prepared == null:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"missing_reclaim_prepare_result"
		)
	if not prepared.accepted:
		return SkillExecutionPrepareResult.rejected(prepared.reject_reason, prepared.detail)
	if prepared.transaction == null or not prepared.transaction.validation_error().is_empty():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_reclaim_transaction"
		)
	var snapshot := ElementReclaimExecutionSnapshot.new(
		context.cast_snapshot,
		context.energy_before,
		context.maximum_energy,
		movement_policy,
		prepared.matched_element_amount,
		prepared.theoretical_energy_restore
	)
	if not snapshot.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			snapshot.validation_error
		)
	return SkillExecutionPrepareResult.success(
		snapshot,
		SkillExecutionRuntime.new(snapshot, active_time),
		null,
		prepared.transaction
	)
