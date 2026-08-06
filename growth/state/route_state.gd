class_name RouteState
extends RefCounted

var phase: int:
	get:
		return _phase

var completed_combat_rooms: int:
	get:
		return _completed_combat_rooms

var current_room_id: StringName:
	get:
		return _current_room_id

var selected_reward_type: int:
	get:
		return _selected_reward_type

var formal_flow: bool:
	get:
		return _formal_flow

var _phase: int = RunPhase.COMBAT
var _completed_combat_rooms: int = 0
var _current_room_id: StringName = &""
var _selected_reward_type: int = -1
var _next_options: Array[RouteOption] = []
var _completed_room_ids: Array[StringName] = []
var _formal_flow: bool = false
var _run_id: StringName = &""
var _current_node_id: StringName = &""
var _pending_node_id: StringName = &""
var _selected_option_id: StringName = &""
var _active_room_instance_id: int = 0
var _active_scene_path: String = ""
var _completed_node_ids: Array[StringName] = []
var _selected_route_option_ids: Array[StringName] = []
var _activated_scene_paths: Array[String] = []
var _activated_room_instance_ids: Array[int] = []
var _shop_visits: int = 0
var _route_choices: int = 0


func configure_formal(run_id: StringName, entry_node_id: StringName) -> RunCommandResult:
	if run_id.is_empty() or entry_node_id.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"missing_formal_route_identity"
		)
	_formal_flow = true
	_run_id = run_id
	_phase = RunPhase.ENTRY
	_current_node_id = entry_node_id
	_current_room_id = &""
	return RunCommandResult.success()


func snapshot() -> RouteSnapshot:
	return RouteSnapshot.new(
		_phase,
		_completed_combat_rooms,
		_current_room_id,
		_selected_reward_type,
		_next_options,
		_run_id,
		_current_node_id,
		_pending_node_id,
		_selected_option_id,
		_active_room_instance_id,
		_active_scene_path,
		_completed_node_ids,
		_selected_route_option_ids,
		_activated_scene_paths,
		_activated_room_instance_ids,
		_shop_visits,
		_route_choices
	)


func begin_formal_run(first_combat_node_id: StringName) -> RunCommandResult:
	if not _formal_flow or _phase != RunPhase.ENTRY:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"formal_run_not_at_entry"
		)
	if first_combat_node_id.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"formal_run_missing_first_combat"
		)
	_phase = RunPhase.ROOM_LOADING
	_pending_node_id = first_combat_node_id
	return RunCommandResult.success()


func accept_formal_room(
		node_id: StringName,
		room_instance_id: int,
		scene_path: String
) -> RunCommandResult:
	if not _formal_flow or _phase != RunPhase.ROOM_LOADING:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"room_activation_outside_loading"
		)
	if node_id.is_empty() or node_id != _pending_node_id:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"pending_room_identity_mismatch"
		)
	if room_instance_id <= 0 or scene_path.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			&"invalid_room_instance_identity"
		)
	if _activated_room_instance_ids.has(room_instance_id):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			&"room_instance_reused"
		)
	_phase = RunPhase.COMBAT
	_current_node_id = node_id
	_current_room_id = node_id
	_pending_node_id = &""
	_active_room_instance_id = room_instance_id
	_active_scene_path = scene_path
	_activated_room_instance_ids.append(room_instance_id)
	_activated_scene_paths.append(scene_path)
	return RunCommandResult.success()


func validate_formal_room_completion(room_id: StringName) -> RunCommandResult:
	if _completed_room_ids.has(room_id):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.DUPLICATE_ROOM,
			&"room_already_completed"
		)
	if not _formal_flow or _phase != RunPhase.COMBAT:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"room_completion_outside_combat"
		)
	if room_id.is_empty() or room_id != _current_room_id:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"room_identity_mismatch"
		)
	return RunCommandResult.success()


func commit_formal_room_completion(room_id: StringName) -> void:
	_completed_room_ids.append(room_id)
	_completed_node_ids.append(room_id)
	_completed_combat_rooms += 1
	_phase = RunPhase.ROOM_RESOLUTION


func advance_formal_to(
		node_id: StringName,
		node_kind: int,
		options: Array[RouteOption] = []
) -> RunCommandResult:
	if not _formal_flow or _phase != RunPhase.ROOM_RESOLUTION:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"formal_advance_outside_resolution"
		)
	return _commit_formal_destination(node_id, node_kind, options)


func choose_formal_route(option_id: StringName) -> RunCommandResult:
	if not _formal_flow or _phase != RunPhase.ROUTE_CHOICE:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"route_selection_outside_route_choice"
		)
	var option := find_route_option(option_id)
	if option == null or option.kind != RouteOption.Kind.COMBAT_ROOM:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.STALE_ROUTE_OPTION,
			&"stale_route_option"
		)
	_selected_option_id = option.option_id
	_selected_route_option_ids.append(option.option_id)
	_route_choices += 1
	_next_options.clear()
	_phase = RunPhase.ROOM_LOADING
	_pending_node_id = option.target_node_id
	return RunCommandResult.success()


func leave_formal_shop(
		node_id: StringName,
		node_kind: int,
		options: Array[RouteOption] = []
) -> RunCommandResult:
	if not _formal_flow or _phase != RunPhase.SHOP:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"shop_exit_outside_shop"
		)
	return _commit_formal_destination(node_id, node_kind, options)


func mark_formal_failed(result_node_id: StringName) -> RunCommandResult:
	if not _formal_flow:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"legacy_run_cannot_formal_fail"
		)
	if _phase == RunPhase.RUN_COMPLETE or _phase == RunPhase.RUN_FAILED:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.RUN_ALREADY_FINISHED,
			&"run_already_finished"
		)
	_phase = RunPhase.RUN_FAILED
	_current_node_id = result_node_id
	_pending_node_id = &""
	_next_options.clear()
	return RunCommandResult.success()


func _commit_formal_destination(
		node_id: StringName,
		node_kind: int,
		options: Array[RouteOption]
) -> RunCommandResult:
	if node_id.is_empty() or not RunNodeKind.is_valid(node_kind):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"invalid_formal_destination"
		)
	if node_kind == RunNodeKind.ROUTE and options.size() != 2:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"formal_route_requires_two_options"
		)
	_next_options.clear()
	_selected_option_id = &""
	match node_kind:
		RunNodeKind.COMBAT, RunNodeKind.BOSS:
			_phase = RunPhase.ROOM_LOADING
			_pending_node_id = node_id
		RunNodeKind.SHOP:
			_phase = RunPhase.SHOP
			_current_node_id = node_id
			_pending_node_id = &""
			_shop_visits += 1
		RunNodeKind.ROUTE:
			_phase = RunPhase.ROUTE_CHOICE
			_current_node_id = node_id
			_pending_node_id = &""
			_next_options = options.duplicate()
		RunNodeKind.RESULT:
			_phase = RunPhase.RUN_COMPLETE
			_current_node_id = node_id
			_pending_node_id = &""
		_:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.CONFIGURATION_ERROR,
				&"unsupported_formal_destination"
			)
	return RunCommandResult.success()


func set_current_room(room_id: StringName) -> RunCommandResult:
	if _phase != RunPhase.COMBAT:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"not_in_combat")
	if room_id.is_empty():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"missing_room_id")
	if _completed_room_ids.has(room_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.DUPLICATE_ROOM, &"room_already_completed")
	if not _current_room_id.is_empty() and _current_room_id != room_id:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"combat_room_already_active")
	_current_room_id = room_id
	return RunCommandResult.success()


func can_complete_room(room_id: StringName) -> RunCommandResult:
	if _phase != RunPhase.COMBAT:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"room_completion_outside_combat")
	if room_id.is_empty() or room_id != _current_room_id:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"room_identity_mismatch")
	if _completed_room_ids.has(room_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.DUPLICATE_ROOM, &"room_already_completed")
	return RunCommandResult.success()


func commit_room_completion(room_id: StringName) -> void:
	_completed_room_ids.append(room_id)
	_completed_combat_rooms += 1


func try_transition(next_phase: int) -> RunCommandResult:
	if not RunPhase.is_valid(next_phase):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"unknown_run_phase")
	if not _is_legal_transition(_phase, next_phase):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_TRANSITION, &"illegal_run_phase_transition")
	_phase = next_phase
	if next_phase != RunPhase.ROUTE_CHOICE:
		_next_options.clear()
	if next_phase == RunPhase.COMBAT:
		_current_room_id = &""
	return RunCommandResult.success()


func set_route_options(options: Array[RouteOption]) -> RunCommandResult:
	if _phase != RunPhase.ROUTE_CHOICE:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"route_options_outside_route_choice")
	var seen: Array[StringName] = []
	for option in options:
		if option == null or not option.is_valid() or seen.has(option.option_id):
			return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"invalid_route_options")
		seen.append(option.option_id)
	_next_options = options.duplicate()
	return RunCommandResult.success()


func find_route_option(option_id: StringName) -> RouteOption:
	for option in _next_options:
		if option.option_id == option_id:
			return option
	return null


func select_reward_type(reward_type: int) -> void:
	_selected_reward_type = reward_type


static func _is_legal_transition(from_phase: int, to_phase: int) -> bool:
	match from_phase:
		RunPhase.COMBAT:
			return to_phase == RunPhase.REWARD
		RunPhase.REWARD:
			return to_phase == RunPhase.ROUTE_CHOICE
		RunPhase.ROUTE_CHOICE:
			return to_phase == RunPhase.COMBAT or to_phase == RunPhase.SHOP
		RunPhase.SHOP:
			return to_phase == RunPhase.COMBAT or to_phase == RunPhase.RUN_COMPLETE
		_:
			return false
