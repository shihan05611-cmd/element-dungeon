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

var _phase: int = RunPhase.COMBAT
var _completed_combat_rooms: int = 0
var _current_room_id: StringName = &""
var _selected_reward_type: int = -1
var _next_options: Array[RouteOption] = []
var _completed_room_ids: Array[StringName] = []


func snapshot() -> RouteSnapshot:
	return RouteSnapshot.new(
		_phase,
		_completed_combat_rooms,
		_current_room_id,
		_selected_reward_type,
		_next_options
	)


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
