class_name ElementReclaimExecution
extends SkillExecutionDefinition

## Decorates the existing spatial reclaim port without changing its query,
## collision, target order or element-consumption transaction. The additional
## resource yield is locked from CastSnapshot and committed silently beside the
## base transaction.
class LevelScaledReclaimTransaction:
	extends SkillExecutionCommitTransaction

	var _base_transaction: SkillExecutionCommitTransaction
	var _energy_ref: WeakRef
	var _energy_before: int
	var _maximum_energy: int
	var _base_theoretical_restore: int
	var _scaled_theoretical_restore: int
	var _extra_actual_restore: int = 0
	var _committed: bool = false
	var _published: bool = false

	func _init(
			base_transaction: SkillExecutionCommitTransaction,
			energy: EnergyComponent,
			energy_before: int,
			maximum_energy: int,
			base_theoretical_restore: int,
			scaled_theoretical_restore: int
	) -> void:
		_base_transaction = base_transaction
		_energy_ref = weakref(energy)
		_energy_before = energy_before
		_maximum_energy = maximum_energy
		_base_theoretical_restore = base_theoretical_restore
		_scaled_theoretical_restore = scaled_theoretical_restore

	func validation_error() -> StringName:
		if _committed:
			return &""
		if _base_transaction == null:
			return &"missing_base_reclaim_transaction"
		var base_error := _base_transaction.validation_error()
		if not base_error.is_empty():
			return base_error
		var energy := _energy_ref.get_ref() as EnergyComponent if _energy_ref != null else null
		if energy == null or not is_instance_valid(energy):
			return &"reclaim_energy_unavailable"
		if energy.current_energy != _energy_before or energy.maximum != _maximum_energy:
			return &"reclaim_energy_snapshot_changed"
		if (
			_base_theoretical_restore <= 0
			or _scaled_theoretical_restore < _base_theoretical_restore
		):
			return &"invalid_scaled_reclaim_restore"
		return &""

	func commit_silent() -> void:
		assert(not _committed, "scaled reclaim transaction commits once")
		assert(validation_error().is_empty(), "scaled reclaim transaction must validate")
		_base_transaction.commit_silent()
		var energy := _energy_ref.get_ref() as EnergyComponent
		var capacity := maxi(0, _maximum_energy - _energy_before)
		var base_actual := mini(_base_theoretical_restore, capacity)
		var total_actual := mini(_scaled_theoretical_restore, capacity)
		_extra_actual_restore = energy._restore_clamped_silent(
			maxi(0, total_actual - base_actual)
		)
		assert(
			_extra_actual_restore == maxi(0, total_actual - base_actual),
			"scaled reclaim delta must match the locked snapshot"
		)
		_committed = true

	func publish_committed() -> void:
		assert(_committed and not _published, "scaled reclaim publishes once after commit")
		_base_transaction.publish_committed()
		var energy := _energy_ref.get_ref() as EnergyComponent
		assert(energy != null and is_instance_valid(energy))
		energy._emit_committed_delta(_extra_actual_restore)
		_published = true


class LevelScaledReclaimPort:
	extends ElementReclaimPort

	var _base_port: ElementReclaimPort
	var _energy_ref: WeakRef

	func _init(base_port: ElementReclaimPort, energy: EnergyComponent) -> void:
		_base_port = base_port
		_energy_ref = weakref(energy) if energy != null else null

	func prepare(request: ElementReclaimRequest) -> ElementReclaimPrepareResult:
		if _base_port == null:
			return ElementReclaimPrepareResult.rejected(
				CastAttemptResult.RejectReason.MISSING_COMPONENT,
				&"missing_base_reclaim_port"
			)
		var prepared := _base_port.prepare(request)
		if prepared == null or not prepared.accepted:
			return prepared
		var effect := (
			request.cast_snapshot.level_effect
			if request != null and request.cast_snapshot != null
			else ActiveSkillLevelEffectSnapshot.neutral()
		)
		if effect == null or not effect.is_valid() or is_equal_approx(effect.resource_gain_scale, 1.0):
			return prepared
		var energy := _energy_ref.get_ref() as EnergyComponent if _energy_ref != null else null
		if energy == null or not is_instance_valid(energy):
			return ElementReclaimPrepareResult.rejected(
				CastAttemptResult.RejectReason.MISSING_COMPONENT,
				&"reclaim_energy_unavailable"
			)
		var scaled_restore := floori(
			float(prepared.theoretical_energy_restore) * effect.resource_gain_scale
		)
		var transaction := LevelScaledReclaimTransaction.new(
			prepared.transaction,
			energy,
			request.current_energy,
			request.maximum_energy,
			prepared.theoretical_energy_restore,
			scaled_restore
		)
		var transaction_error := transaction.validation_error()
		if not transaction_error.is_empty():
			return ElementReclaimPrepareResult.rejected(
				CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
				transaction_error
			)
		return ElementReclaimPrepareResult.success(
			prepared.matched_element_amount,
			scaled_restore,
			transaction
		)

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
