class_name AllEnergyBurstExecution
extends SkillExecutionDefinition

@export_range(1, 1000000, 1, "or_greater") var minimum_energy: int = 20
@export_range(0.0, 100.0, 0.001, "or_greater") var damage_multiplier_per_energy: float = 0.08
@export_range(1, 1000000, 1, "or_greater") var energy_per_element_amount: int = 20
@export_range(1, 1000, 1, "or_greater") var radius_step_count: int = 10
@export_range(0.0, 10.0, 0.01, "or_greater") var radius_step_scale: float = 0.10
@export_range(0.0, 60.0, 0.001, "or_greater") var active_time: float = 0.0
@export var presentation_tags: PackedStringArray = PackedStringArray()


func validation_error() -> StringName:
	var base_error := super()
	if not base_error.is_empty():
		return base_error
	if minimum_energy <= 0:
		return &"invalid_minimum_energy"
	if not is_finite(damage_multiplier_per_energy) or damage_multiplier_per_energy <= 0.0:
		return &"invalid_damage_multiplier_per_energy"
	if energy_per_element_amount <= 0:
		return &"invalid_energy_per_element_amount"
	if radius_step_count <= 0:
		return &"invalid_radius_step_count"
	if not is_finite(radius_step_scale) or radius_step_scale < 0.0:
		return &"invalid_radius_step_scale"
	if not is_finite(active_time) or active_time < 0.0:
		return &"invalid_active_time"
	return &""


func minimum_energy_required() -> int:
	return minimum_energy


func element_policy_validation_error(
		policy: SkillDefinition.ElementPolicy,
		_required_element_id: StringName
) -> StringName:
	return (
		&""
		if policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT
		else &"all_energy_burst_requires_current_element"
	)


func prepare(
		context: SkillExecutionContext,
		_services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	if context == null or not context.is_valid() or context.maximum_energy <= 0:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_execution_context"
		)
	if context.energy_before < minimum_energy:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY
		)
	var multiplier := float(context.energy_before) * damage_multiplier_per_energy
	var amount := mini(
		10,
		floori(float(context.energy_before) / float(energy_per_element_amount))
	)
	var radius_steps := floori(
		float(context.energy_before) / float(context.maximum_energy) * float(radius_step_count)
	)
	var radius_scale := 1.0 + float(radius_steps) * radius_step_scale
	var runtime_payload := RuntimeAttackPayload.from_locked_stats(
		context.cast_snapshot.stat_snapshot,
		multiplier,
		context.cast_snapshot.cast_element_id,
		amount,
		presentation_tags
	)
	if not runtime_payload.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			runtime_payload.validation_error
		)
	var snapshot := AllEnergyBurstExecutionSnapshot.new(
		context.cast_snapshot,
		context.energy_before,
		context.maximum_energy,
		movement_policy,
		runtime_payload,
		radius_scale
	)
	if not snapshot.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			snapshot.validation_error
		)
	return SkillExecutionPrepareResult.success(
		snapshot,
		SkillExecutionRuntime.new(snapshot, active_time)
	)
