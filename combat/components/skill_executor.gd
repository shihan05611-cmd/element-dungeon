class_name SkillExecutor
extends Node

## Authoritative, animation-independent execution coordinator. Every fallible
## provider, strategy, delivery, and functional preparation completes before
## energy, cooldown, element, external transaction, and runtime state commit.

signal cast_started(cast_snapshot: CastSnapshot, payload: RuntimeAttackPayload)
signal phase_changed(cast_id: int, previous_phase: Phase, current_phase: Phase)
signal delivery_spawned(cast_id: int, delivery_id: int, delivery: Node)
signal cast_cancelled(cast_snapshot: CastSnapshot, reason: StringName)
signal cast_finished(cast_snapshot: CastSnapshot)
signal cooldown_started(skill_id: StringName, duration: float)
signal cooldown_finished(skill_id: StringName)
signal presentation_marker_received(cast_id: int, marker: StringName)
signal execution_started(snapshot: SkillExecutionSnapshot)
signal execution_activated(snapshot: SkillExecutionSnapshot)
signal execution_tick_generated(snapshot: ChannelTickSnapshot)
signal execution_ended(snapshot: SkillExecutionSnapshot, result: SkillExecutionEndResult)

enum Phase {
	IDLE,
	STARTUP,
	ACTIVE,
	RECOVERY,
	CANCELLED,
}

const MAX_BOUNDARIES_PER_ADVANCE: int = 4096
const TIME_EPSILON: float = 0.000001

@export var energy_component_path: NodePath
@export var current_element_controller_path: NodePath
@export var delivery_parent_path: NodePath
@export var root_owner_id: int = 0
@export var caster_id: int = 0
@export var team_id: StringName = &""

var current_phase: Phase:
	get:
		return _phase

var current_cast_id: int:
	get:
		return _current_cast_snapshot.cast_id if _current_cast_snapshot != null else 0

var current_cast_snapshot: CastSnapshot:
	get:
		return _current_cast_snapshot

var current_execution_snapshot: SkillExecutionSnapshot:
	get:
		return _current_execution_snapshot

var current_payload: RuntimeAttackPayload:
	get:
		return (
			_current_execution_snapshot.runtime_payload()
			if _current_execution_snapshot != null
			else null
		)

var current_movement_policy: SkillExecutionSnapshot.MovementPolicy:
	get:
		return (
			_current_execution_snapshot.movement_policy
			if _current_execution_snapshot != null
			else SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT
		)

var current_slot_id: StringName:
	get:
		return _current_slot_id

var phase_elapsed: float:
	get:
		return _phase_elapsed

static var _last_issued_cast_id: int = 0

var _phase: Phase = Phase.IDLE
var _phase_elapsed: float = 0.0
var _energy: EnergyComponent
var _current_element_controller: CurrentElementController
var _delivery_parent: Node
var _cooldowns := SkillCooldowns.new()
var _execution_services := SkillExecutionServices.new()
var _external_action_gate: Callable
var _stat_snapshot_provider: Callable
var _spawn_snapshot_provider: Callable
var _active_skill_level_effect_port: ActiveSkillLevelEffectPort

var _current_cast_snapshot: CastSnapshot
var _current_execution_snapshot: SkillExecutionSnapshot
var _current_execution_runtime: SkillExecutionRuntime
var _current_slot_id: StringName = &""
var _current_startup_time: float = 0.0
var _current_recovery_time: float = 0.0
var _prepared_delivery: DeliveryBase
var _prepared_commit_transaction: SkillExecutionCommitTransaction
var _current_refund_policy: SkillDefinition.EnergyRefundPolicy = SkillDefinition.EnergyRefundPolicy.NEVER
var _current_initial_energy_spent: int = 0
var _uses_delivery: bool = false
var _delivery_generated: bool = false
var _delivery_spawned_successfully: bool = false
var _execution_activated: bool = false
var _execution_end_published: bool = false
var _current_deliveries: Array[WeakRef] = []

var _cast_transaction_in_progress: bool = false
var _advance_in_progress: bool = false
var _transition_in_progress: bool = false
var _pending_cancel_reason: StringName = &""
var _pending_cancel_cast_id: int = 0


func _ready() -> void:
	_resolve_dependencies_from_paths()
	set_process(true)


func _process(delta: float) -> void:
	advance(delta)


func _exit_tree() -> void:
	if _phase != Phase.IDLE:
		cancel_current_cast(&"caster_left_tree", current_cast_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _phase != Phase.IDLE:
		cancel_current_cast(&"scene_tree_paused", current_cast_id)


func configure_dependencies(
		energy: EnergyComponent,
		current_element_controller: CurrentElementController,
		delivery_parent: Node
) -> bool:
	if energy == null or current_element_controller == null or delivery_parent == null:
		return false
	_energy = energy
	_current_element_controller = current_element_controller
	_delivery_parent = delivery_parent
	return true


func configure_cast_identity(p_root_owner_id: int, p_caster_id: int, p_team_id: StringName) -> bool:
	if p_root_owner_id <= 0 or p_caster_id <= 0 or p_team_id.is_empty():
		return false
	root_owner_id = p_root_owner_id
	caster_id = p_caster_id
	team_id = p_team_id
	return true


func set_execution_services(services: SkillExecutionServices) -> bool:
	if services == null:
		return false
	_execution_services = services
	return true


## Callable contract: gate.call(skill: SkillDefinition) -> bool.
func set_external_action_gate(gate: Callable) -> void:
	_external_action_gate = gate


func is_external_action_allowed(skill: SkillDefinition = null) -> bool:
	if not _external_action_gate.is_valid():
		return true
	var result: bool = _external_action_gate.call(skill)
	return result


## Callable contract: provider.call(skill: SkillDefinition) -> CombatStatSnapshot.
func set_stat_snapshot_provider(provider: Callable) -> void:
	_stat_snapshot_provider = provider


## Callable contract: provider.call(skill: SkillDefinition) -> DeliverySpawnSnapshot.
func set_spawn_snapshot_provider(provider: Callable) -> void:
	_spawn_snapshot_provider = provider


func set_active_skill_level_effect_port(port: ActiveSkillLevelEffectPort) -> void:
	_active_skill_level_effect_port = port


func set_delivery_parent(delivery_parent: Node) -> bool:
	if delivery_parent == null:
		return false
	_delivery_parent = delivery_parent
	return true


## Internal path for skills supplied by a validated RuntimeSkillLoadout catalog.
func _try_cast_configured(
		skill: SkillDefinition,
		slot_id: StringName = &""
) -> CastAttemptResult:
	var requested_skill_id := skill.skill_id if skill != null else StringName()
	if _cast_transaction_in_progress or _advance_in_progress or _transition_in_progress or _phase != Phase.IDLE:
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.BUSY,
			requested_skill_id,
			&"",
			0.0,
			slot_id
		)
	_cast_transaction_in_progress = true
	var result := _try_cast_locked(skill, slot_id)
	_cast_transaction_in_progress = false
	_apply_pending_cancel()
	return result


func _try_cast_locked(skill: SkillDefinition, slot_id: StringName) -> CastAttemptResult:
	var requested_skill_id := skill.skill_id if skill != null else StringName()
	if not slot_id.is_empty() and not SkillSlotIds.is_known(slot_id):
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			requested_skill_id,
			slot_id,
			&"unknown_shared_slot"
		)
	if skill == null or not skill.is_valid():
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			requested_skill_id,
			slot_id,
			&"missing_or_invalid_skill_definition"
		)
	if not skill.is_active_skill():
		return _reject(
			CastAttemptResult.RejectReason.NOT_CASTABLE,
			skill.skill_id,
			slot_id,
			&"passive_skill"
		)
	if _energy == null or _current_element_controller == null:
		return _reject(
			CastAttemptResult.RejectReason.MISSING_COMPONENT,
			skill.skill_id,
			slot_id,
			&"missing_energy_or_current_element_controller"
		)
	if root_owner_id <= 0 or caster_id <= 0 or team_id.is_empty():
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			&"invalid_cast_identity"
		)
	if _external_action_gate.is_valid():
		var gate_result: bool = _external_action_gate.call(skill)
		if not gate_result:
			return _reject(
				CastAttemptResult.RejectReason.EXTERNAL_GATE_REJECTED,
				skill.skill_id,
				slot_id
			)

	var stat_snapshot := _capture_stat_snapshot(skill)
	if stat_snapshot == null or not stat_snapshot.is_valid():
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			&"invalid_stat_snapshot"
		)
	var spawn_snapshot: DeliverySpawnSnapshot
	if skill.execution_definition.requires_spawn_snapshot():
		spawn_snapshot = _capture_spawn_snapshot(skill)
		if spawn_snapshot == null or not spawn_snapshot.is_valid():
			return _reject(
				CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
				skill.skill_id,
				slot_id,
				&"invalid_spawn_snapshot"
			)
		if not _delivery_parent_is_available():
			return _reject(
				CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
				skill.skill_id,
				slot_id,
				&"delivery_parent_unavailable"
			)

	var cast_element := skill.resolve_cast_element(_current_element_controller.current_element_id)
	if (
		skill.element_policy != SkillDefinition.ElementPolicy.NEUTRAL
		and not _current_element_controller.is_element_available(cast_element)
	):
		return _reject(
			CastAttemptResult.RejectReason.ELEMENT_UNAVAILABLE,
			skill.skill_id,
			slot_id,
			cast_element
		)
	if not _energy.can_spend(skill.execution_definition.minimum_energy_required()):
		return _reject(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY,
			skill.skill_id,
			slot_id
		)
	var remaining_cooldown := _cooldowns.get_remaining(skill.skill_id)
	if remaining_cooldown > 0.0:
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.COOLDOWN_ACTIVE,
			skill.skill_id,
			&"",
			remaining_cooldown,
			slot_id
		)

	var level_effect := _capture_active_skill_level_effect(skill.skill_id)
	stat_snapshot = _apply_damage_level_effect(stat_snapshot, level_effect)
	if stat_snapshot == null or not stat_snapshot.is_valid():
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			&"invalid_level_scaled_stat_snapshot"
		)
	var cast_id := _allocate_cast_id()
	var cast_snapshot := CastSnapshot.new(
		cast_id,
		skill.skill_id,
		root_owner_id,
		caster_id,
		team_id,
		cast_element,
		stat_snapshot,
		level_effect
	)
	if not cast_snapshot.is_valid():
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			cast_snapshot.validation_error
		)
	var context := SkillExecutionContext.new(
		skill,
		cast_snapshot,
		spawn_snapshot,
		_energy.current_energy,
		_energy.maximum
	)
	var prepared := skill.execution_definition.prepare(
		context,
		_execution_services_for_accepted_cast(level_effect)
	)
	if prepared == null:
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			&"missing_execution_prepare_result"
		)
	if not prepared.accepted:
		return _reject(prepared.reject_reason, skill.skill_id, slot_id, prepared.detail)
	if (
		prepared.snapshot == null
		or not prepared.snapshot.is_valid()
		or prepared.runtime == null
		or prepared.runtime.snapshot != prepared.snapshot
	):
		_free_prepared_delivery(prepared.prepared_delivery)
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			&"invalid_execution_preparation"
		)
	if not _energy.can_spend(prepared.snapshot.energy_spent):
		_free_prepared_delivery(prepared.prepared_delivery)
		return _reject(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY,
			skill.skill_id,
			slot_id
		)
	if (
		prepared.commit_transaction != null
		and not prepared.commit_transaction.validation_error().is_empty()
	):
		_free_prepared_delivery(prepared.prepared_delivery)
		return _reject(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			slot_id,
			prepared.commit_transaction.validation_error()
		)

	# COMMIT: every fallible operation and callback completed above.
	if prepared.commit_transaction != null:
		prepared.commit_transaction.commit_silent()
	_energy._spend_silent(prepared.snapshot.energy_spent)
	var cooldown_committed := _cooldowns.start(skill.skill_id, skill.cooldown)
	assert(cooldown_committed, "cooldown commit must match the synchronous precheck")
	var element_change := _current_element_controller._commit_element_silent(
		cast_element if skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT else _current_element_controller.current_element_id,
		FormChangedEvent.Source.SKILL_AUTO
	)
	assert(element_change.accepted, "element commit must match the synchronous availability precheck")
	_energy._commit_spend_regeneration_delay(prepared.snapshot.energy_spent)

	_current_cast_snapshot = cast_snapshot
	_current_execution_snapshot = prepared.snapshot
	_current_execution_runtime = prepared.runtime
	_current_slot_id = slot_id
	_current_startup_time = skill.startup_time
	_current_recovery_time = skill.recovery_time
	_prepared_delivery = prepared.prepared_delivery
	_prepared_commit_transaction = prepared.commit_transaction
	_current_initial_energy_spent = prepared.snapshot.energy_spent
	_current_refund_policy = skill.energy_refund_policy
	_uses_delivery = prepared.prepared_delivery != null
	_delivery_generated = false
	_delivery_spawned_successfully = false
	_execution_activated = false
	_execution_end_published = false
	_current_deliveries.clear()
	_phase_elapsed = 0.0
	var previous_phase := _phase
	_phase = Phase.STARTUP

	var result := CastAttemptResult.success(
		skill.skill_id,
		cast_snapshot,
		prepared.snapshot,
		slot_id
	)
	_current_element_controller._publish_committed_change(element_change)
	phase_changed.emit(cast_id, previous_phase, _phase)
	cast_started.emit(cast_snapshot, prepared.snapshot.runtime_payload())
	execution_started.emit(prepared.snapshot)
	if skill.cooldown > 0.0:
		cooldown_started.emit(skill.skill_id, skill.cooldown)
	_energy._emit_committed_delta(-prepared.snapshot.energy_spent)
	if prepared.commit_transaction != null:
		prepared.commit_transaction.publish_committed()
		_prepared_commit_transaction = null
	return result


## Deterministic clock. Startup/recovery are fixed durations; ACTIVE delegates
## each boundary to the prepared runtime, so Channel can emit any number of
## exact ticks without SkillExecutor knowing its concrete type.
func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0 or _advance_in_progress:
		return false
	_advance_in_progress = true
	var finished_cooldowns: Array[StringName] = _cooldowns.advance(delta)
	var succeeded := true
	var remaining := delta
	var boundaries := 0
	while _phase != Phase.IDLE and _phase != Phase.CANCELLED:
		boundaries += 1
		if boundaries > MAX_BOUNDARIES_PER_ADVANCE:
			_queue_cancel(&"execution_boundary_guard", current_cast_id)
			succeeded = false
			break
		var cast_id := current_cast_id
		match _phase:
			Phase.STARTUP, Phase.RECOVERY:
				var duration := _current_startup_time if _phase == Phase.STARTUP else _current_recovery_time
				var to_boundary := maxf(0.0, duration - _phase_elapsed)
				if to_boundary - remaining > TIME_EPSILON:
					_phase_elapsed += remaining
					remaining = 0.0
					break
				remaining = maxf(0.0, remaining - to_boundary)
				_phase_elapsed = duration
				if _phase == Phase.STARTUP:
					_enter_phase(Phase.ACTIVE)
				else:
					_finish_current_cast()
			Phase.ACTIVE:
				if _current_execution_runtime == null:
					_queue_cancel(&"missing_execution_runtime", cast_id)
					succeeded = false
					break
				if _current_execution_runtime.is_complete:
					_end_active_runtime(_current_execution_runtime.end_result)
					continue
				var to_boundary := _current_execution_runtime.time_to_boundary()
				if to_boundary - remaining > TIME_EPSILON:
					_current_execution_runtime.advance_time(remaining)
					_phase_elapsed += remaining
					remaining = 0.0
					break
				_current_execution_runtime.advance_time(to_boundary)
				_phase_elapsed += to_boundary
				remaining = maxf(0.0, remaining - to_boundary)
				var boundary := _current_execution_runtime.reach_boundary(_energy)
				if boundary == null:
					_queue_cancel(&"missing_execution_boundary_result", cast_id)
					succeeded = false
					break
				if boundary.energy_spent > 0:
					_energy._emit_committed_delta(-boundary.energy_spent)
				if boundary.tick_snapshot != null:
					execution_tick_generated.emit(boundary.tick_snapshot)
				_apply_pending_cancel()
				if current_cast_id != cast_id or _phase != Phase.ACTIVE:
					continue
				if boundary.completed:
					_end_active_runtime(boundary.end_result)
			_:
				break
		_apply_pending_cancel()
		if remaining <= 0.0 and _phase != Phase.IDLE:
			if _phase == Phase.ACTIVE and _current_execution_runtime != null:
				if _current_execution_runtime.is_complete or is_zero_approx(_current_execution_runtime.time_to_boundary()):
					continue
			elif is_zero_approx(_get_fixed_phase_remaining()):
				continue
			break
	_advance_in_progress = false
	_apply_pending_cancel()
	for finished_skill_id: StringName in finished_cooldowns:
		cooldown_finished.emit(finished_skill_id)
	return succeeded


func request_channel_release(expected_cast_id: int = 0) -> bool:
	if _current_execution_runtime == null or not _current_execution_runtime.supports_release():
		return false
	if expected_cast_id > 0 and expected_cast_id != current_cast_id:
		return false
	if not _current_execution_runtime.request_release():
		return false
	if _phase == Phase.ACTIVE and not _advance_in_progress and not _transition_in_progress:
		_end_active_runtime(_current_execution_runtime.end_result)
	return true


func cancel_current_cast(reason: StringName, expected_cast_id: int = 0) -> bool:
	if _phase == Phase.IDLE or _current_cast_snapshot == null:
		return false
	if expected_cast_id > 0 and expected_cast_id != current_cast_id:
		return false
	var resolved_reason := reason if not reason.is_empty() else &"explicit_cancel"
	if _cast_transaction_in_progress or _advance_in_progress or _transition_in_progress:
		_queue_cancel(resolved_reason, current_cast_id)
		return true
	_cancel_now(resolved_reason)
	return true


func notify_presentation_marker(expected_cast_id: int, marker: StringName) -> bool:
	if expected_cast_id <= 0 or expected_cast_id != current_cast_id or marker.is_empty():
		return false
	presentation_marker_received.emit(expected_cast_id, marker)
	return true


func is_current_cast(expected_cast_id: int) -> bool:
	return expected_cast_id > 0 and expected_cast_id == current_cast_id


func get_cooldown_remaining(skill_id: StringName) -> float:
	return _cooldowns.get_remaining(skill_id)


func is_skill_on_cooldown(skill_id: StringName) -> bool:
	return _cooldowns.is_on_cooldown(skill_id)


func get_phase_name() -> StringName:
	match _phase:
		Phase.IDLE:
			return &"idle"
		Phase.STARTUP:
			return &"startup"
		Phase.ACTIVE:
			return &"active"
		Phase.RECOVERY:
			return &"recovery"
		Phase.CANCELLED:
			return &"cancelled"
		_:
			return &"unknown"


func handle_pause() -> bool:
	return cancel_current_cast(&"scene_tree_paused", current_cast_id)


func _enter_phase(next_phase: Phase) -> void:
	if _current_cast_snapshot == null:
		return
	_transition_in_progress = true
	var previous := _phase
	var cast_id := current_cast_id
	_phase = next_phase
	_phase_elapsed = 0.0
	phase_changed.emit(cast_id, previous, next_phase)
	if next_phase == Phase.ACTIVE and current_cast_id == cast_id:
		_execution_activated = true
		if _uses_delivery:
			_spawn_current_delivery()
		if current_cast_id == cast_id:
			execution_activated.emit(_current_execution_snapshot)
	_transition_in_progress = false
	_apply_pending_cancel()


func _end_active_runtime(result: SkillExecutionEndResult) -> void:
	if _phase != Phase.ACTIVE or _current_execution_snapshot == null:
		return
	var snapshot := _current_execution_snapshot
	var resolved := result if result != null else SkillExecutionEndResult.new(
		SkillExecutionEndResult.Reason.INTERNAL_FAILURE,
		&"missing_execution_end_result"
	)
	_close_active_hit_windows()
	_enter_phase(Phase.RECOVERY)
	if _current_execution_snapshot == snapshot and not _execution_end_published:
		_execution_end_published = true
		execution_ended.emit(snapshot, resolved)


func _spawn_current_delivery() -> bool:
	if _delivery_generated or _phase != Phase.ACTIVE or _current_cast_snapshot == null:
		return false
	_delivery_generated = true
	var delivery := _prepared_delivery
	_prepared_delivery = null
	if delivery == null or not is_instance_valid(delivery):
		_queue_cancel(&"delivery_instance_unavailable", current_cast_id)
		return false
	if not _delivery_parent_is_available():
		delivery.free()
		_queue_cancel(&"delivery_parent_unavailable", current_cast_id)
		return false
	_delivery_parent.add_child(delivery)
	_delivery_spawned_successfully = true
	_current_deliveries.append(weakref(delivery))
	delivery_spawned.emit(current_cast_id, delivery.delivery_id, delivery)
	return true


func _close_active_hit_windows() -> void:
	for delivery_reference: WeakRef in _current_deliveries:
		var delivery := delivery_reference.get_ref() as DeliveryBase
		if is_instance_valid(delivery) and not delivery.is_queued_for_deletion():
			delivery.close_hit_window()


func _finish_current_cast() -> void:
	if _current_cast_snapshot == null:
		return
	_transition_in_progress = true
	var completed_snapshot := _current_cast_snapshot
	var completed_cast_id := completed_snapshot.cast_id
	var previous := _phase
	_phase = Phase.IDLE
	_phase_elapsed = 0.0
	_clear_current_cast_data()
	phase_changed.emit(completed_cast_id, previous, Phase.IDLE)
	cast_finished.emit(completed_snapshot)
	_transition_in_progress = false
	_clear_pending_cancel()


func _cancel_now(reason: StringName) -> void:
	if _current_cast_snapshot == null:
		return
	_transition_in_progress = true
	var cancelled_snapshot := _current_cast_snapshot
	var cancelled_execution := _current_execution_snapshot
	var cancelled_cast_id := cancelled_snapshot.cast_id
	var previous := _phase
	if _phase == Phase.ACTIVE:
		_close_active_hit_windows()
	var refunded_energy := _refund_current_energy_if_eligible()
	var end_result := SkillExecutionEndResult.from_cancel_reason(reason)
	if not _execution_end_published and cancelled_execution != null:
		_execution_end_published = true
		execution_ended.emit(cancelled_execution, end_result)
	_phase = Phase.CANCELLED
	_phase_elapsed = 0.0
	phase_changed.emit(cancelled_cast_id, previous, Phase.CANCELLED)
	cast_cancelled.emit(cancelled_snapshot, reason)
	previous = _phase
	_phase = Phase.IDLE
	_clear_current_cast_data()
	phase_changed.emit(cancelled_cast_id, previous, Phase.IDLE)
	_transition_in_progress = false
	_clear_pending_cancel()
	_energy._emit_committed_delta(refunded_energy)


func _refund_current_energy_if_eligible() -> int:
	var committed_effect := _delivery_spawned_successfully if _uses_delivery else _execution_activated
	if (
		_current_refund_policy != SkillDefinition.EnergyRefundPolicy.BEFORE_DELIVERY
		or committed_effect
		or _current_initial_energy_spent <= 0
		or _energy == null
	):
		return 0
	return _energy._restore_clamped_silent(_current_initial_energy_spent)


func _queue_cancel(reason: StringName, cast_id: int) -> void:
	_pending_cancel_reason = reason
	_pending_cancel_cast_id = cast_id


func _apply_pending_cancel() -> void:
	if _pending_cancel_reason.is_empty() or _transition_in_progress:
		return
	var reason := _pending_cancel_reason
	var cast_id := _pending_cancel_cast_id
	_clear_pending_cancel()
	if _phase != Phase.IDLE and cast_id == current_cast_id:
		_cancel_now(reason)


func _clear_pending_cancel() -> void:
	_pending_cancel_reason = &""
	_pending_cancel_cast_id = 0


func _clear_current_cast_data() -> void:
	_current_cast_snapshot = null
	_current_execution_snapshot = null
	_current_execution_runtime = null
	_current_slot_id = &""
	_current_startup_time = 0.0
	_current_recovery_time = 0.0
	if _prepared_delivery != null and is_instance_valid(_prepared_delivery):
		_prepared_delivery.free()
	_prepared_delivery = null
	_prepared_commit_transaction = null
	_current_refund_policy = SkillDefinition.EnergyRefundPolicy.NEVER
	_current_initial_energy_spent = 0
	_uses_delivery = false
	_delivery_generated = false
	_delivery_spawned_successfully = false
	_execution_activated = false
	_execution_end_published = false
	_current_deliveries.clear()


func _get_fixed_phase_remaining() -> float:
	match _phase:
		Phase.STARTUP:
			return maxf(0.0, _current_startup_time - _phase_elapsed)
		Phase.RECOVERY:
			return maxf(0.0, _current_recovery_time - _phase_elapsed)
		_:
			return 0.0


func _capture_stat_snapshot(skill: SkillDefinition) -> CombatStatSnapshot:
	if not _stat_snapshot_provider.is_valid():
		return CombatStatSnapshot.new()
	var result: Variant = _stat_snapshot_provider.call(skill)
	return result as CombatStatSnapshot


func _capture_active_skill_level_effect(
		skill_id: StringName
) -> ActiveSkillLevelEffectSnapshot:
	if _active_skill_level_effect_port == null:
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id)
	var effect := _active_skill_level_effect_port.effect_for(skill_id)
	if (
		effect == null
		or not effect.is_valid()
		or (not effect.skill_id.is_empty() and effect.skill_id != skill_id)
	):
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id)
	return effect


func _apply_damage_level_effect(
		stats: CombatStatSnapshot,
		effect: ActiveSkillLevelEffectSnapshot
) -> CombatStatSnapshot:
	if stats == null or effect == null or not effect.is_valid():
		return stats
	return CombatStatSnapshot.new(
		stats.attack_multiplier * effect.damage_scale,
		stats.flat_damage_bonus * effect.damage_scale
	)


func _execution_services_for_accepted_cast(
		effect: ActiveSkillLevelEffectSnapshot
) -> SkillExecutionServices:
	if (
		effect == null
		or not effect.is_valid()
		or is_equal_approx(effect.resource_gain_scale, 1.0)
		or _execution_services == null
		or _execution_services.reclaim_port == null
		or _execution_services.reclaim_port is ElementReclaimExecution.LevelScaledReclaimPort
	):
		return _execution_services
	return SkillExecutionServices.new(
		ElementReclaimExecution.LevelScaledReclaimPort.new(
			_execution_services.reclaim_port,
			_energy
		)
	)


func _capture_spawn_snapshot(skill: SkillDefinition) -> DeliverySpawnSnapshot:
	if _spawn_snapshot_provider.is_valid():
		var result: Variant = _spawn_snapshot_provider.call(skill)
		return result as DeliverySpawnSnapshot
	var host := get_parent() as Node2D
	if host != null:
		var fallback_direction := host.global_transform.x.normalized()
		if fallback_direction.is_zero_approx():
			fallback_direction = Vector2.RIGHT
		return DeliverySpawnSnapshot.new(host.global_transform, fallback_direction)
	return DeliverySpawnSnapshot.new()


func _delivery_parent_is_available() -> bool:
	return (
		is_instance_valid(_delivery_parent)
		and not _delivery_parent.is_queued_for_deletion()
		and _delivery_parent.is_inside_tree()
	)


func _resolve_dependencies_from_paths() -> void:
	if _energy == null and not energy_component_path.is_empty():
		_energy = get_node_or_null(energy_component_path) as EnergyComponent
	if _current_element_controller == null and not current_element_controller_path.is_empty():
		_current_element_controller = get_node_or_null(current_element_controller_path) as CurrentElementController
	if _delivery_parent == null and not delivery_parent_path.is_empty():
		_delivery_parent = get_node_or_null(delivery_parent_path)


func _reject(
		reason: CastAttemptResult.RejectReason,
		skill_id: StringName,
		slot_id: StringName,
		detail: StringName = &""
) -> CastAttemptResult:
	return CastAttemptResult.rejected(reason, skill_id, detail, 0.0, slot_id)


static func _free_prepared_delivery(delivery: DeliveryBase) -> void:
	if delivery != null and is_instance_valid(delivery):
		delivery.free()


static func _allocate_cast_id() -> int:
	_last_issued_cast_id += 1
	if _last_issued_cast_id <= 0:
		_last_issued_cast_id = 1
	return _last_issued_cast_id
