class_name RunDirector
extends RefCounted

const SHOP_INTERVAL: int = 3
const PROTOTYPE_ROOM_COUNT: int = 6
const SKILL_ROUTE_ID: StringName = &"route_skill_reward"
const RELIC_ROUTE_ID: StringName = &"route_relic_reward"
const SHOP_ROUTE_ID: StringName = &"route_shop"

var _route_state := RouteState.new()


func snapshot() -> RouteSnapshot:
	return _route_state.snapshot()


func begin_combat_room(room_id: StringName) -> RunCommandResult:
	return _route_state.set_current_room(room_id)


func validate_room_completion(room_id: StringName) -> RunCommandResult:
	return _route_state.can_complete_room(room_id)


func commit_room_completion(room_id: StringName) -> RunCommandResult:
	var validation := _route_state.can_complete_room(room_id)
	if not validation.accepted:
		return validation
	_route_state.commit_room_completion(room_id)
	return _route_state.try_transition(RunPhase.REWARD)


func validate_reward_claim(skill_route_available: bool, relic_route_available: bool) -> RunCommandResult:
	if _route_state.phase != RunPhase.REWARD:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"reward_claim_outside_reward_phase")
	if _is_shop_due():
		return RunCommandResult.success()
	if not skill_route_available and not relic_route_available:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.CONFIGURATION_ERROR, &"no_legal_next_routes")
	return RunCommandResult.success()


func commit_reward_claim(skill_route_available: bool, relic_route_available: bool) -> RunCommandResult:
	var validation := validate_reward_claim(skill_route_available, relic_route_available)
	if not validation.accepted:
		return validation
	var options: Array[RouteOption] = []
	if _is_shop_due():
		options.append(RouteOption.new(SHOP_ROUTE_ID, RouteOption.Kind.SHOP))
	else:
		if skill_route_available:
			options.append(RouteOption.new(SKILL_ROUTE_ID, RouteOption.Kind.REWARD_ROOM, RewardType.SKILL))
		if relic_route_available:
			options.append(RouteOption.new(RELIC_ROUTE_ID, RouteOption.Kind.REWARD_ROOM, RewardType.RELIC))
	var transition := _route_state.try_transition(RunPhase.ROUTE_CHOICE)
	if not transition.accepted:
		return transition
	return _route_state.set_route_options(options)


func choose_route(option_id: StringName) -> RunCommandResult:
	if _route_state.phase != RunPhase.ROUTE_CHOICE:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"route_selection_outside_route_choice")
	var option := _route_state.find_route_option(option_id)
	if option == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"unknown_route_option")
	match option.kind:
		RouteOption.Kind.REWARD_ROOM:
			_route_state.select_reward_type(option.reward_type)
			return _route_state.try_transition(RunPhase.COMBAT)
		RouteOption.Kind.SHOP:
			return _route_state.try_transition(RunPhase.SHOP)
		_:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_TRANSITION, &"unsupported_route_kind")


func validate_shop_exit(complete_run: bool) -> RunCommandResult:
	if _route_state.phase != RunPhase.SHOP:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_confirm_outside_shop")
	if complete_run and _route_state.completed_combat_rooms < PROTOTYPE_ROOM_COUNT:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_TRANSITION, &"run_cannot_complete_before_room_six")
	return RunCommandResult.success()


func commit_shop_exit(complete_run: bool) -> RunCommandResult:
	var validation := validate_shop_exit(complete_run)
	if not validation.accepted:
		return validation
	return _route_state.try_transition(RunPhase.RUN_COMPLETE if complete_run else RunPhase.COMBAT)


func _is_shop_due() -> bool:
	return (
		_route_state.completed_combat_rooms > 0
		and _route_state.completed_combat_rooms % SHOP_INTERVAL == 0
	)
