class_name SkillController
extends Node

## Shared-loadout facade. Runtime loadout creation and legacy migration belong
## to the run entry; this component only consumes the established runtime.

signal cast_attempted(slot_id: StringName, result: CastAttemptResult)
signal element_change_attempted(result: ElementChangeResult)

@export var current_element_controller_path: NodePath
@export var executor_path: NodePath
@export var shared_loadout: SkillLoadout

var runtime_loadout: RuntimeSkillLoadout:
	get:
		return _runtime_loadout

var _current_element_controller: CurrentElementController
var _executor: SkillExecutor
var _runtime_loadout: RuntimeSkillLoadout
var _manual_element_gate: Callable
var _buffered_element_id: StringName = &""
var _buffered_request_sequence: int = 0


func _ready() -> void:
	_resolve_dependencies_from_paths()
	_connect_executor_phase()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		clear_buffered_element_request()


func _process(_delta: float) -> void:
	_flush_buffered_element_if_allowed()


func configure_runtime(
		current_element_controller: CurrentElementController,
		executor: SkillExecutor,
		loadout: RuntimeSkillLoadout
) -> bool:
	if current_element_controller == null or executor == null or loadout == null:
		return false
	if _runtime_loadout != null:
		return (
			_current_element_controller == current_element_controller
			and _executor == executor
			and _runtime_loadout == loadout
		)
	_current_element_controller = current_element_controller
	_executor = executor
	_runtime_loadout = loadout
	_connect_executor_phase()
	return true


func try_cast_slot(slot_id: StringName) -> CastAttemptResult:
	var canonical_slot := SkillSlotIds.canonicalize_input(slot_id)
	if _current_element_controller == null or _executor == null or _runtime_loadout == null:
		return _publish_attempt(
			canonical_slot,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.MISSING_COMPONENT,
				&"",
				&"missing_shared_loadout_or_controller",
				0.0,
				canonical_slot
			)
		)
	if not SkillSlotIds.is_known(canonical_slot):
		return _publish_attempt(
			canonical_slot,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.SLOT_UNASSIGNED,
				&"",
				&"unknown_shared_slot",
				0.0,
				canonical_slot
			)
		)
	var skill := _runtime_loadout.get_skill_for_slot(canonical_slot)
	if skill == null:
		return _publish_attempt(
			canonical_slot,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.SLOT_UNASSIGNED,
				&"",
				&"",
				0.0,
				canonical_slot
			)
		)
	if not skill.is_active_skill():
		return _publish_attempt(
			canonical_slot,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.NOT_CASTABLE,
				skill.skill_id,
				&"passive_skill",
				0.0,
				canonical_slot
			)
		)
	return _publish_attempt(canonical_slot, _executor._try_cast_configured(skill, canonical_slot))


func request_element(
		element_id: StringName,
		request_sequence: int = 0
) -> ElementChangeResult:
	if _current_element_controller == null:
		return _publish_element_attempt(ElementChangeResult.rejected(
			&"missing_current_element_controller",
			&"",
			FormChangedEvent.Source.MANUAL
		))
	if not _current_element_controller.is_element_available(element_id):
		return _publish_element_attempt(ElementChangeResult.rejected(
			&"element_unavailable",
			_current_element_controller.current_element_id,
			FormChangedEvent.Source.MANUAL
		))
	if not _can_apply_manual_change_now():
		if element_id == _current_element_controller.current_element_id:
			# The latest intent is to remain on the committed element. This
			# explicitly cancels an earlier buffered change.
			clear_buffered_element_request()
			return _publish_element_attempt(_current_element_controller.request_element(
				element_id,
				FormChangedEvent.Source.MANUAL,
				request_sequence
			))
		_buffered_element_id = element_id
		_buffered_request_sequence = request_sequence
		return _publish_element_attempt(ElementChangeResult.queued(
			_current_element_controller.current_element_id,
			element_id
		))
	return _publish_element_attempt(_current_element_controller.request_element(
		element_id,
		FormChangedEvent.Source.MANUAL,
		request_sequence
	))


func cycle_next(request_sequence: int = 0) -> ElementChangeResult:
	if _current_element_controller == null or _current_element_controller.ordered_available_elements.is_empty():
		return _publish_element_attempt(ElementChangeResult.rejected(
			&"missing_current_element_controller",
			&"",
			FormChangedEvent.Source.MANUAL
		))
	var elements := _current_element_controller.ordered_available_elements
	var cycle_base := (
		_buffered_element_id
		if not _buffered_element_id.is_empty()
		else _current_element_controller.current_element_id
	)
	var index := elements.find(cycle_base)
	if index < 0:
		return _publish_element_attempt(ElementChangeResult.rejected(
			&"current_element_unavailable",
			_current_element_controller.current_element_id,
			FormChangedEvent.Source.MANUAL
		))
	return request_element(elements[(index + 1) % elements.size()], request_sequence)


func set_external_manual_element_gate(gate: Callable) -> void:
	_manual_element_gate = gate
	_flush_buffered_element_if_allowed()


func clear_buffered_element_request() -> void:
	_buffered_element_id = &""
	_buffered_request_sequence = 0


func on_owner_died() -> void:
	clear_buffered_element_request()
	if _runtime_loadout != null:
		_runtime_loadout.on_owner_died()


func on_owner_respawned() -> void:
	clear_buffered_element_request()
	if _runtime_loadout != null:
		_runtime_loadout.on_owner_respawned()


func on_floor_changed() -> void:
	clear_buffered_element_request()
	if _runtime_loadout != null:
		_runtime_loadout.on_floor_changed()


func on_run_reloaded() -> void:
	clear_buffered_element_request()
	if _runtime_loadout != null:
		_runtime_loadout.on_run_reloaded()
	if _current_element_controller != null:
		_current_element_controller.reset_request_deduplication()


func handle_pause_exit() -> void:
	clear_buffered_element_request()


func cancel_current_cast(reason: StringName, expected_cast_id: int = 0) -> bool:
	return _executor != null and _executor.cancel_current_cast(reason, expected_cast_id)


func get_skill_for_slot(slot_id: StringName) -> SkillDefinition:
	if _runtime_loadout == null:
		return null
	return _runtime_loadout.get_skill_for_slot(SkillSlotIds.canonicalize_input(slot_id))


func _publish_attempt(slot_id: StringName, result: CastAttemptResult) -> CastAttemptResult:
	cast_attempted.emit(slot_id, result)
	return result


func _publish_element_attempt(result: ElementChangeResult) -> ElementChangeResult:
	element_change_attempted.emit(result)
	return result


func _can_apply_manual_change_now() -> bool:
	if _executor != null:
		if (
			_executor.current_phase != SkillExecutor.Phase.IDLE
			and _executor.current_phase != SkillExecutor.Phase.RECOVERY
		):
			return false
	if _executor != null and not _executor.is_external_action_allowed(_manual_gate_probe_skill()):
		return false
	if _manual_element_gate.is_valid():
		var gate_result: Variant = _manual_element_gate.call()
		return gate_result is bool and gate_result
	return true


func _manual_gate_probe_skill() -> SkillDefinition:
	if _runtime_loadout == null:
		return null
	for slot_id: StringName in SkillSlotIds.active():
		var skill := _runtime_loadout.get_skill_for_slot(slot_id)
		if skill != null and skill.is_active_skill():
			return skill
	return null


func _flush_buffered_element_if_allowed() -> void:
	if _buffered_element_id.is_empty() or not _can_apply_manual_change_now():
		return
	var element_id := _buffered_element_id
	var request_sequence := _buffered_request_sequence
	clear_buffered_element_request()
	_publish_element_attempt(_current_element_controller.request_element(
		element_id,
		FormChangedEvent.Source.MANUAL,
		request_sequence
	))


func _on_executor_phase_changed(
		_cast_id: int,
		_previous_phase: SkillExecutor.Phase,
		current_phase: SkillExecutor.Phase
) -> void:
	if current_phase == SkillExecutor.Phase.RECOVERY or current_phase == SkillExecutor.Phase.IDLE:
		_flush_buffered_element_if_allowed()


func _connect_executor_phase() -> void:
	if _executor == null:
		return
	var callback := Callable(self, "_on_executor_phase_changed")
	if not _executor.phase_changed.is_connected(callback):
		_executor.phase_changed.connect(callback)


func _resolve_dependencies_from_paths() -> void:
	if _current_element_controller == null and not current_element_controller_path.is_empty():
		_current_element_controller = get_node_or_null(current_element_controller_path) as CurrentElementController
	if _executor == null and not executor_path.is_empty():
		_executor = get_node_or_null(executor_path) as SkillExecutor
	_connect_executor_phase()

