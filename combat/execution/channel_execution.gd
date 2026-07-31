class_name ChannelExecution
extends SkillExecutionDefinition

@export_range(0.001, 60.0, 0.001, "or_greater") var tick_interval: float = 0.5
@export_range(1, 1000000, 1, "or_greater") var energy_per_tick: int = 5
@export_range(0.0, 100000.0, 0.01, "or_greater") var damage_multiplier: float = 0.5
@export_range(1, 10, 1) var element_amount: int = 1
@export var presentation_tags: PackedStringArray = PackedStringArray()


func _init() -> void:
	movement_policy = SkillExecutionSnapshot.MovementPolicy.ALLOW_MOVEMENT


func validation_error() -> StringName:
	var base_error := super()
	if not base_error.is_empty():
		return base_error
	if not is_finite(tick_interval) or tick_interval <= 0.0:
		return &"invalid_tick_interval"
	if energy_per_tick <= 0:
		return &"invalid_energy_per_tick"
	if not is_finite(damage_multiplier) or damage_multiplier < 0.0:
		return &"invalid_damage_multiplier"
	if element_amount <= 0 or element_amount > 10:
		return &"invalid_element_amount"
	return &""


func minimum_energy_required() -> int:
	return energy_per_tick


func element_policy_validation_error(
		policy: SkillDefinition.ElementPolicy,
		_required_element_id: StringName
) -> StringName:
	return (
		&""
		if policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT
		else &"channel_requires_current_element"
	)


func prepare(
		context: SkillExecutionContext,
		_services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	if context == null or not context.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_execution_context"
		)
	if context.energy_before < energy_per_tick:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY
		)
	var snapshot := ChannelExecutionSnapshot.new(
		context.cast_snapshot,
		context.energy_before,
		context.maximum_energy,
		movement_policy,
		tick_interval,
		energy_per_tick,
		damage_multiplier,
		element_amount,
		presentation_tags
	)
	if not snapshot.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			snapshot.validation_error
		)
	return SkillExecutionPrepareResult.success(
		snapshot,
		ChannelExecutionRuntime.new(snapshot)
	)
