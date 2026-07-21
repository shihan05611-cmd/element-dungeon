class_name SkillExecutor
extends Node

## Authoritative, animation-independent cast state machine.
##
## A cast is accepted by try_cast() as one synchronous transaction. Timings,
## form, stats, payload, spawn transform and direction are copied into runtime
## state before any notification is emitted.

signal cast_started(cast_snapshot: CastSnapshot, payload: RuntimeAttackPayload)
signal phase_changed(cast_id: int, previous_phase: Phase, current_phase: Phase)
signal delivery_spawned(cast_id: int, delivery_id: int, delivery: Node)
signal cast_cancelled(cast_snapshot: CastSnapshot, reason: StringName)
signal cast_finished(cast_snapshot: CastSnapshot)
signal cooldown_started(skill_id: StringName, duration: float)
signal cooldown_finished(skill_id: StringName)
signal presentation_marker_received(cast_id: int, marker: StringName)

enum Phase {
	IDLE,
	STARTUP,
	ACTIVE,
	RECOVERY,
	CANCELLED,
}

const MAX_PHASE_TRANSITIONS_PER_ADVANCE: int = 8

@export var energy_component_path: NodePath
@export var form_controller_path: NodePath
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

var current_payload: RuntimeAttackPayload:
	get:
		return _current_payload

var phase_elapsed: float:
	get:
		return _phase_elapsed

static var _last_issued_cast_id: int = 0

var _phase: Phase = Phase.IDLE
var _phase_elapsed: float = 0.0
var _energy: EnergyComponent
var _form_controller: ElementFormController
var _delivery_parent: Node
var _cooldowns := SkillCooldowns.new()
var _external_action_gate: Callable
var _stat_snapshot_provider: Callable
var _spawn_snapshot_provider: Callable

var _current_cast_snapshot: CastSnapshot
var _current_payload: RuntimeAttackPayload
var _current_skill_id: StringName = &""
var _current_startup_time: float = 0.0
var _current_active_time: float = 0.0
var _current_recovery_time: float = 0.0
var _current_delivery_scene: PackedScene
var _current_spawn_snapshot: DeliverySpawnSnapshot
var _next_delivery_id: int = 1
var _delivery_generated: bool = false
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
		form_controller: ElementFormController,
		delivery_parent: Node
) -> bool:
	if energy == null or form_controller == null or delivery_parent == null:
		return false
	_energy = energy
	_form_controller = form_controller
	_delivery_parent = delivery_parent
	return true


func configure_cast_identity(p_root_owner_id: int, p_caster_id: int, p_team_id: StringName) -> bool:
	if p_root_owner_id <= 0 or p_caster_id <= 0 or p_team_id.is_empty():
		return false
	root_owner_id = p_root_owner_id
	caster_id = p_caster_id
	team_id = p_team_id
	return true


## Callable contract: gate.call(skill: SkillDefinition) -> bool.
func set_external_action_gate(gate: Callable) -> void:
	_external_action_gate = gate


## Callable contract: provider.call(skill: SkillDefinition) -> CombatStatSnapshot.
func set_stat_snapshot_provider(provider: Callable) -> void:
	_stat_snapshot_provider = provider


## Callable contract:
## provider.call(skill: SkillDefinition) -> DeliverySpawnSnapshot.
func set_spawn_snapshot_provider(provider: Callable) -> void:
	_spawn_snapshot_provider = provider


func set_delivery_parent(delivery_parent: Node) -> bool:
	if delivery_parent == null:
		return false
	_delivery_parent = delivery_parent
	return true


func try_cast(skill: SkillDefinition) -> CastAttemptResult:
	var requested_skill_id := skill.skill_id if skill != null else StringName()
	if _cast_transaction_in_progress or _advance_in_progress or _transition_in_progress or _phase != Phase.IDLE:
		return CastAttemptResult.rejected(CastAttemptResult.RejectReason.BUSY, requested_skill_id)
	_cast_transaction_in_progress = true
	var result := _try_cast_locked(skill)
	_cast_transaction_in_progress = false
	_apply_pending_cancel()
	return result


func _try_cast_locked(skill: SkillDefinition) -> CastAttemptResult:
	var requested_skill_id := skill.skill_id if skill != null else StringName()
	if skill == null:
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			requested_skill_id,
			&"missing_skill_definition"
		)
	var skill_error := skill.validation_error()
	if not skill_error.is_empty():
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			skill_error
		)

	_resolve_dependencies_from_paths()
	if _energy == null or _form_controller == null:
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.MISSING_COMPONENT,
			skill.skill_id,
			&"missing_energy_or_form_controller"
		)
	if (
		not is_instance_valid(_delivery_parent)
		or _delivery_parent.is_queued_for_deletion()
		or not _delivery_parent.is_inside_tree()
	):
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE,
			skill.skill_id,
			&"delivery_parent_unavailable"
		)
	if root_owner_id <= 0 or caster_id <= 0 or team_id.is_empty():
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			&"invalid_cast_identity"
		)

	var cast_form := _form_controller.current_form_id
	if not skill.is_form_allowed(cast_form):
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.FORM_MISMATCH,
			skill.skill_id,
			cast_form
		)
	if not _energy.can_spend(skill.energy_cost):
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY,
			skill.skill_id
		)
	var remaining_cooldown := _cooldowns.get_remaining(skill.skill_id)
	if remaining_cooldown > 0.0:
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.COOLDOWN_ACTIVE,
			skill.skill_id,
			&"",
			remaining_cooldown
		)
	if _external_action_gate.is_valid():
		var gate_result: Variant = _external_action_gate.call(skill)
		if not (gate_result is bool):
			return CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
				skill.skill_id,
				&"invalid_action_gate_result"
			)
		if not gate_result:
			return CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.EXTERNAL_GATE_REJECTED,
				skill.skill_id
			)

	var stat_snapshot := _capture_stat_snapshot(skill)
	if stat_snapshot == null or not stat_snapshot.is_valid():
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			&"invalid_stat_snapshot"
		)
	var spawn_snapshot := _capture_spawn_snapshot(skill)
	if spawn_snapshot == null or not spawn_snapshot.is_valid():
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			&"invalid_spawn_snapshot"
		)

	var cast_id := _allocate_cast_id()
	var cast_snapshot := CastSnapshot.new(
		cast_id,
		skill.skill_id,
		root_owner_id,
		caster_id,
		team_id,
		cast_form,
		stat_snapshot
	)
	if not cast_snapshot.is_valid():
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			cast_snapshot.validation_error
		)
	var runtime_payload := skill.payload.build_runtime(cast_snapshot)
	if runtime_payload == null or not runtime_payload.is_valid():
		var payload_error := runtime_payload.validation_error if runtime_payload != null else &"missing_payload"
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			payload_error
		)

	if not _energy._try_spend_silent(skill.energy_cost):
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY,
			skill.skill_id
		)
	if not _cooldowns.start(skill.skill_id, skill.cooldown):
		# All inputs were prevalidated and no observer can run before this point.
		# This branch is defensive; restoring the silent energy change preserves
		# the all-or-nothing contract if the cooldown component is corrupted.
		_energy._restore_silent(skill.energy_cost)
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			skill.skill_id,
			&"cooldown_commit_failed"
		)
	_energy._commit_spend_regeneration_delay(skill.energy_cost)

	_current_cast_snapshot = cast_snapshot
	_current_payload = runtime_payload
	_current_skill_id = skill.skill_id
	_current_startup_time = skill.startup_time
	_current_active_time = skill.active_time
	_current_recovery_time = skill.recovery_time
	_current_delivery_scene = skill.delivery_scene
	_current_spawn_snapshot = spawn_snapshot
	_next_delivery_id = 1
	_delivery_generated = false
	_current_deliveries.clear()
	_phase_elapsed = 0.0
	var previous_phase := _phase
	_phase = Phase.STARTUP

	var result := CastAttemptResult.success(skill.skill_id, cast_snapshot, runtime_payload)
	# State, energy and cooldown are all committed before the first observer.
	phase_changed.emit(cast_id, previous_phase, _phase)
	cast_started.emit(cast_snapshot, runtime_payload)
	if skill.cooldown > 0.0:
		cooldown_started.emit(skill.skill_id, skill.cooldown)
	_energy._emit_committed_delta(-skill.energy_cost)
	return result


## Public deterministic clock for tests and integration. A large delta walks
## every crossed boundary in order and never skips ACTIVE delivery generation.
func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0 or _advance_in_progress:
		return false
	_advance_in_progress = true
	var finished_cooldowns: Array[StringName] = _cooldowns.advance(delta)
	var succeeded := true

	if _phase != Phase.IDLE and _phase != Phase.CANCELLED:
		var remaining := delta
		var transitions := 0
		while _phase != Phase.IDLE and _phase != Phase.CANCELLED:
			var duration := _get_current_phase_duration()
			var time_to_boundary := maxf(0.0, duration - _phase_elapsed)
			if time_to_boundary > remaining:
				_phase_elapsed += remaining
				break
			remaining = maxf(0.0, remaining - time_to_boundary)
			_phase_elapsed = duration
			transitions += 1
			if transitions > MAX_PHASE_TRANSITIONS_PER_ADVANCE:
				cancel_current_cast(&"phase_transition_guard", current_cast_id)
				succeeded = false
				break
			match _phase:
				Phase.STARTUP:
					_enter_phase(Phase.ACTIVE)
				Phase.ACTIVE:
					_close_active_hit_windows()
					_enter_phase(Phase.RECOVERY)
				Phase.RECOVERY:
					_finish_current_cast()
				_:
					break
			if remaining <= 0.0 and _phase != Phase.IDLE and _get_current_phase_duration() > 0.0:
				break

	_advance_in_progress = false
	# Publishing after time advancement prevents a cooldown callback from
	# creating a new cast that incorrectly receives this already-elapsed delta.
	for finished_skill_id: StringName in finished_cooldowns:
		cooldown_finished.emit(finished_skill_id)
	return succeeded


func cancel_current_cast(reason: StringName, expected_cast_id: int = 0) -> bool:
	if _phase == Phase.IDLE or _current_cast_snapshot == null:
		return false
	if expected_cast_id > 0 and expected_cast_id != current_cast_id:
		return false
	var resolved_reason := reason if not reason.is_empty() else &"explicit_cancel"
	if _cast_transaction_in_progress:
		_pending_cancel_reason = resolved_reason
		_pending_cancel_cast_id = current_cast_id
		return true
	if _transition_in_progress:
		_pending_cancel_reason = resolved_reason
		_pending_cancel_cast_id = current_cast_id
		return true
	_cancel_now(resolved_reason)
	return true


## Animation callbacks are presentation-only and token checked. They cannot
## spend resources, spawn deliveries or move the gameplay state machine.
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
		_spawn_current_delivery()
	_transition_in_progress = false
	_apply_pending_cancel()


func _spawn_current_delivery() -> bool:
	if _delivery_generated or _phase != Phase.ACTIVE or _current_cast_snapshot == null:
		return false
	_delivery_generated = true
	if _current_delivery_scene == null:
		_request_cancel_during_transition(&"delivery_scene_unavailable")
		return false
	if (
		not is_instance_valid(_delivery_parent)
		or _delivery_parent.is_queued_for_deletion()
		or not _delivery_parent.is_inside_tree()
	):
		_request_cancel_during_transition(&"delivery_parent_unavailable")
		return false

	var delivery := _current_delivery_scene.instantiate()
	if delivery == null:
		_request_cancel_during_transition(&"delivery_instantiation_failed")
		return false
	if not delivery.has_method(&"initialize_delivery"):
		delivery.free()
		_request_cancel_during_transition(&"delivery_protocol_missing")
		return false

	var delivery_id := _next_delivery_id
	_next_delivery_id += 1
	var initialize_result: Variant = delivery.call(
		&"initialize_delivery",
		_current_cast_snapshot,
		_current_payload,
		delivery_id,
		_current_spawn_snapshot.initial_transform,
		_current_spawn_snapshot.direction
	)
	if initialize_result is bool and not initialize_result:
		delivery.free()
		_request_cancel_during_transition(&"delivery_initialization_rejected")
		return false

	# Initialization is intentionally complete before this add_child call.
	_delivery_parent.add_child(delivery)
	_current_deliveries.append(weakref(delivery))
	delivery_spawned.emit(current_cast_id, delivery_id, delivery)
	return true


func _close_active_hit_windows() -> void:
	for delivery_reference: WeakRef in _current_deliveries:
		var delivery: Variant = delivery_reference.get_ref()
		if is_instance_valid(delivery) and not delivery.is_queued_for_deletion():
			if delivery.has_method(&"close_hit_window"):
				delivery.call(&"close_hit_window")


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
	var cancelled_cast_id := cancelled_snapshot.cast_id
	var previous := _phase
	if _phase == Phase.ACTIVE:
		_close_active_hit_windows()
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


func _request_cancel_during_transition(reason: StringName) -> void:
	_pending_cancel_reason = reason
	_pending_cancel_cast_id = current_cast_id


func _apply_pending_cancel() -> void:
	if _pending_cancel_reason.is_empty():
		return
	var reason := _pending_cancel_reason
	var cast_id := _pending_cancel_cast_id
	_clear_pending_cancel()
	cancel_current_cast(reason, cast_id)


func _clear_pending_cancel() -> void:
	_pending_cancel_reason = &""
	_pending_cancel_cast_id = 0


func _clear_current_cast_data() -> void:
	_current_cast_snapshot = null
	_current_payload = null
	_current_skill_id = &""
	_current_startup_time = 0.0
	_current_active_time = 0.0
	_current_recovery_time = 0.0
	_current_delivery_scene = null
	_current_spawn_snapshot = null
	_next_delivery_id = 1
	_delivery_generated = false
	_current_deliveries.clear()


func _get_current_phase_duration() -> float:
	match _phase:
		Phase.STARTUP:
			return _current_startup_time
		Phase.ACTIVE:
			return _current_active_time
		Phase.RECOVERY:
			return _current_recovery_time
		_:
			return 0.0


func _capture_stat_snapshot(skill: SkillDefinition) -> CombatStatSnapshot:
	if not _stat_snapshot_provider.is_valid():
		return CombatStatSnapshot.new()
	var result: Variant = _stat_snapshot_provider.call(skill)
	return result as CombatStatSnapshot


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


func _resolve_dependencies_from_paths() -> void:
	if _energy == null and not energy_component_path.is_empty():
		_energy = get_node_or_null(energy_component_path) as EnergyComponent
	if _form_controller == null and not form_controller_path.is_empty():
		_form_controller = get_node_or_null(form_controller_path) as ElementFormController
	if _delivery_parent == null and not delivery_parent_path.is_empty():
		_delivery_parent = get_node_or_null(delivery_parent_path)


static func _allocate_cast_id() -> int:
	_last_issued_cast_id += 1
	if _last_issued_cast_id <= 0:
		_last_issued_cast_id = 1
	return _last_issued_cast_id
