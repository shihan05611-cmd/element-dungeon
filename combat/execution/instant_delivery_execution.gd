class_name InstantDeliveryExecution
extends SkillExecutionDefinition

@export_range(0, 1000000, 1, "or_greater") var energy_cost: int = 0
@export_range(0.0, 60.0, 0.001, "or_greater") var active_time: float = 0.0
@export var delivery_scene: PackedScene
@export var payload: AttackPayloadDefinition


func validation_error() -> StringName:
	var base_error := super()
	if not base_error.is_empty():
		return base_error
	if energy_cost < 0:
		return &"invalid_energy_cost"
	if not is_finite(active_time) or active_time < 0.0:
		return &"invalid_active_time"
	if delivery_scene == null:
		return &"missing_delivery_scene"
	if payload == null or not payload.is_valid():
		return &"invalid_payload_definition"
	return &""


func catalog_validation_error() -> StringName:
	var base_error := validation_error()
	if not base_error.is_empty():
		return base_error
	if not delivery_scene.can_instantiate():
		return &"delivery_scene_unavailable"
	var root := delivery_scene.instantiate()
	if root == null:
		return &"delivery_instantiation_failed"
	var follows_protocol := root is DeliveryBase
	root.free()
	return &"" if follows_protocol else &"delivery_scene_root_must_extend_delivery_base"


func minimum_energy_required() -> int:
	return energy_cost


func requires_spawn_snapshot() -> bool:
	return true


func element_policy_validation_error(
		policy: SkillDefinition.ElementPolicy,
		required_element_id: StringName
) -> StringName:
	match policy:
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
			if payload.element_mode != AttackPayloadDefinition.ElementMode.FIXED_ELEMENT:
				return &"exclusive_skill_requires_fixed_payload"
			if payload.fixed_element_id != required_element_id:
				return &"exclusive_skill_element_mismatch"
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
			if payload.element_mode != AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM:
				return &"current_element_skill_must_follow_cast_element"
		SkillDefinition.ElementPolicy.NEUTRAL:
			if payload.element_mode != AttackPayloadDefinition.ElementMode.NONE:
				return &"neutral_skill_requires_neutral_payload"
	return &""


func prepare(
		context: SkillExecutionContext,
		_services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	if context == null or not context.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_execution_context"
		)
	var runtime_payload := payload.build_runtime(context.cast_snapshot)
	if runtime_payload == null or not runtime_payload.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			runtime_payload.validation_error if runtime_payload != null else &"missing_payload"
		)
	var snapshot := InstantDeliveryExecutionSnapshot.new(
		context.cast_snapshot,
		context.energy_before,
		context.maximum_energy,
		energy_cost,
		movement_policy,
		runtime_payload,
		context.spawn_snapshot
	)
	if not snapshot.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			snapshot.validation_error
		)
	var node := delivery_scene.instantiate()
	var delivery := node as DeliveryBase
	if delivery == null:
		if node != null:
			node.free()
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			&"delivery_instantiation_failed"
		)
	if not delivery.initialize_delivery(
		context.cast_snapshot,
		runtime_payload,
		1,
		context.spawn_snapshot.initial_transform,
		context.spawn_snapshot.direction
	):
		var error := delivery.validation_error
		delivery.free()
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			error if not error.is_empty() else &"delivery_initialization_rejected"
		)
	return SkillExecutionPrepareResult.success(
		snapshot,
		SkillExecutionRuntime.new(snapshot, active_time),
		delivery
	)
