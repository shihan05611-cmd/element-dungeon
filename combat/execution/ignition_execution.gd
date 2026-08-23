class_name IgnitionExecution
extends SkillExecutionDefinition

## Functional active skill: no delivery and no energy cost. Its transaction
## clears all locked visible FIRE layers and activates the player status.

func element_policy_validation_error(
		policy: SkillDefinition.ElementPolicy,
		required_element_id: StringName
) -> StringName:
	return &"" if policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT and required_element_id == ElementIds.FIRE else &"ignition_requires_fixed_fire_semantics"


func prepare(
		context: SkillExecutionContext,
		services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	if context == null or not context.is_valid():
		return SkillExecutionPrepareResult.rejected(CastAttemptResult.RejectReason.INVALID_CONFIGURATION, &"invalid_execution_context")
	if not is_equal_approx(context.skill.cooldown, 8.0):
		return SkillExecutionPrepareResult.rejected(CastAttemptResult.RejectReason.INVALID_CONFIGURATION, &"ignition_requires_eight_second_cooldown")
	if services == null or services.ignition_port == null:
		return SkillExecutionPrepareResult.rejected(CastAttemptResult.RejectReason.MISSING_COMPONENT, &"missing_ignition_port")
	var prepared := services.ignition_port.prepare(context.cast_snapshot)
	if prepared == null or not prepared.accepted:
		return SkillExecutionPrepareResult.rejected(
			prepared.reject_reason if prepared != null else CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			prepared.detail if prepared != null else &"missing_ignition_prepare_result"
		)
	if prepared.transaction == null or not prepared.transaction.validation_error().is_empty():
		return SkillExecutionPrepareResult.rejected(CastAttemptResult.RejectReason.INVALID_CONFIGURATION, &"invalid_ignition_transaction")
	var snapshot := IgnitionExecutionSnapshot.new(
		context.cast_snapshot,
		context.energy_before,
		context.maximum_energy,
		movement_policy,
		prepared.matched_element_amount
	)
	if not snapshot.is_valid():
		return SkillExecutionPrepareResult.rejected(CastAttemptResult.RejectReason.INVALID_CONFIGURATION, snapshot.validation_error)
	return SkillExecutionPrepareResult.success(
		snapshot,
		SkillExecutionRuntime.new(snapshot),
		null,
		prepared.transaction
	)
