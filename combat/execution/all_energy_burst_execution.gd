class_name AllEnergyBurstExecution
extends SkillExecutionDefinition

@export_range(1, 1000000, 1, "or_greater") var minimum_energy: int = 20
@export_range(0.0, 100.0, 0.001, "or_greater") var damage_multiplier_per_energy: float = 0.08
@export_range(1, 1000000, 1, "or_greater") var energy_per_element_amount: int = 20
@export_range(1, 1000, 1, "or_greater") var radius_step_count: int = 10
@export_range(0.0, 10.0, 0.01, "or_greater") var radius_step_scale: float = 0.10
@export_range(0.0, 60.0, 0.001, "or_greater") var active_time: float = 0.0
@export var presentation_tags: PackedStringArray = PackedStringArray()
@export var projectile_sweep_profile: ProjectileSweepProfile2D


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
	if projectile_sweep_profile == null:
		return &"missing_projectile_sweep_profile"
	var profile_error := projectile_sweep_profile.validation_error()
	if not profile_error.is_empty():
		return profile_error
	if projectile_sweep_profile.hurtbox_collision_mask <= 0:
		return &"fury_requires_hurtbox_collision_mask"
	if projectile_sweep_profile.blocking_collision_mask <= 0:
		return &"fury_requires_blocking_collision_mask"
	return &""


func minimum_energy_required() -> int:
	return minimum_energy


func requires_spawn_snapshot() -> bool:
	return true


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
		services: SkillExecutionServices
) -> SkillExecutionPrepareResult:
	if (
		context == null
		or not context.is_valid()
		or context.maximum_energy <= 0
		or context.spawn_snapshot == null
		or not context.spawn_snapshot.is_valid()
	):
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_execution_context"
		)
	if context.energy_before < minimum_energy:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY
		)
	if (
		services == null
		or services.projectile_sweep_query_port == null
		or services.skill_delivery_prepare_port == null
	):
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			&"missing_projectile_cast_services"
		)
	var source := services.projectile_source()
	var world := source.get_world_2d() if _is_live_source(source) else null
	var request := ProjectileSweepRequest2D.new(
		source,
		world,
		context.spawn_snapshot.initial_transform,
		context.spawn_snapshot.direction,
		projectile_sweep_profile.max_distance,
		projectile_sweep_profile,
		context.cast_snapshot.team_id,
		true
	)
	var sweep_result := services.projectile_sweep_query_port.query_first_contact(request)
	if sweep_result == null:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			&"missing_projectile_sweep_result"
		)
	match sweep_result.status:
		ProjectileSweepResult2D.Status.BLOCKER_CONTACT:
			return SkillExecutionPrepareResult.rejected(
				CastAttemptResult.RejectReason.NO_LEGAL_TARGET,
				&"projectile_blocked"
			)
		ProjectileSweepResult2D.Status.NO_CONTACT:
			return SkillExecutionPrepareResult.rejected(
				CastAttemptResult.RejectReason.NO_LEGAL_TARGET,
				&"projectile_no_contact"
			)
		ProjectileSweepResult2D.Status.INVALID_CONTEXT:
			return SkillExecutionPrepareResult.rejected(
				CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
				sweep_result.detail if not sweep_result.detail.is_empty() else &"invalid_projectile_context"
			)
		ProjectileSweepResult2D.Status.QUERY_FAILED:
			return SkillExecutionPrepareResult.rejected(
				CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
				sweep_result.detail if not sweep_result.detail.is_empty() else &"projectile_query_failed"
			)
		ProjectileSweepResult2D.Status.ENEMY_CONTACT:
			pass
		_:
			return SkillExecutionPrepareResult.rejected(
				CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
				&"unknown_projectile_sweep_status"
			)
	if not _is_finite_vector(sweep_result.point):
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"invalid_projectile_impact_position"
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
		radius_scale,
		sweep_result.point
	)
	if not snapshot.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			snapshot.validation_error
		)
	var impact_transform := context.spawn_snapshot.initial_transform
	impact_transform.origin = sweep_result.point
	var impact_spawn := DeliverySpawnSnapshot.new(
		impact_transform,
		context.spawn_snapshot.direction
	)
	if not impact_spawn.is_valid():
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			impact_spawn.validation_error
		)
	var transaction := services.skill_delivery_prepare_port.prepare(snapshot, impact_spawn)
	if transaction == null:
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			&"delivery_prepare_failed"
		)
	var transaction_error := transaction.validation_error()
	if not transaction_error.is_empty():
		transaction.discard_uncommitted()
		return SkillExecutionPrepareResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			transaction_error
		)
	return SkillExecutionPrepareResult.success(
		snapshot,
		SkillExecutionRuntime.new(snapshot, active_time),
		transaction.prepared_delivery,
		transaction
	)


static func _is_live_source(source: Node2D) -> bool:
	return (
		source != null
		and is_instance_valid(source)
		and not source.is_queued_for_deletion()
		and source.is_inside_tree()
	)


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
