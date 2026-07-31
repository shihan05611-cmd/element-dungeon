class_name SkillExecutionDefinition
extends Resource

@export var movement_policy: SkillExecutionSnapshot.MovementPolicy = SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT


func validation_error() -> StringName:
	if movement_policy not in [
		SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT,
		SkillExecutionSnapshot.MovementPolicy.ALLOW_MOVEMENT,
	]:
		return &"invalid_movement_policy"
	return &""


func catalog_validation_error() -> StringName:
	return validation_error()


func minimum_energy_required() -> int:
	return 0


func requires_spawn_snapshot() -> bool:
	return false


func element_policy_validation_error(
		_policy: SkillDefinition.ElementPolicy,
		_required_element_id: StringName
) -> StringName:
	return &""


func prepare(
		_context: SkillExecutionContext,
		_services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	return SkillExecutionPrepareResult.rejected(
		CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
		&"abstract_execution_definition"
	)
