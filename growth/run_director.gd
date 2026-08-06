class_name RunDirector
extends RefCounted

const SHOP_INTERVAL: int = 3
const PROTOTYPE_ROOM_COUNT: int = 6
const SKILL_ROUTE_ID: StringName = &"route_skill_reward"
const RELIC_ROUTE_ID: StringName = &"route_relic_reward"
const SHOP_ROUTE_ID: StringName = &"route_shop"

var _route_state := RouteState.new()
var _flow_definition: RunFlowDefinition
var _configuration_error: StringName = &""


var formal_flow: bool:
	get:
		return _flow_definition != null

var configuration_error: StringName:
	get:
		return _configuration_error


func _init(
		flow_definition: RunFlowDefinition = null,
		run_id: StringName = &""
) -> void:
	if flow_definition == null:
		return
	var flow_error := flow_definition.validation_error()
	if not flow_error.is_empty():
		_configuration_error = flow_error
		return
	_flow_definition = flow_definition
	var configured := _route_state.configure_formal(run_id, flow_definition.entry_node_id)
	if not configured.accepted:
		_configuration_error = configured.detail


func snapshot() -> RouteSnapshot:
	return _route_state.snapshot()


func begin_combat_room(room_id: StringName) -> RunCommandResult:
	if formal_flow:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"formal_room_requires_transition_identity"
		)
	return _route_state.set_current_room(room_id)


func start_formal_run() -> RunCommandResult:
	if not formal_flow or not _configuration_error.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			_configuration_error if not _configuration_error.is_empty() else &"missing_run_flow"
		)
	var entry := _flow_definition.node_for(_flow_definition.entry_node_id)
	var first := _flow_definition.node_for(entry.next_node_id) if entry != null else null
	if first == null or not RunNodeKind.is_combat(first.kind):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"run_entry_does_not_target_combat"
		)
	return _route_state.begin_formal_run(first.node_id)


func accept_formal_room(
		node_id: StringName,
		room_instance_id: int,
		scene_path: String
) -> RunCommandResult:
	if not formal_flow:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"legacy_run_has_no_room_transition"
		)
	var pending := _flow_definition.node_for(node_id)
	if pending == null or not RunNodeKind.is_combat(pending.kind) or pending.combat_room == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			&"unknown_pending_combat_node"
		)
	if pending.combat_room.room_scene.resource_path != scene_path:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			&"room_scene_path_mismatch"
		)
	return _route_state.accept_formal_room(node_id, room_instance_id, scene_path)


func validate_room_completion(room_id: StringName) -> RunCommandResult:
	if formal_flow:
		return _route_state.validate_formal_room_completion(room_id)
	return _route_state.can_complete_room(room_id)


func commit_room_completion(room_id: StringName) -> RunCommandResult:
	if formal_flow:
		var formal_validation := _route_state.validate_formal_room_completion(room_id)
		if not formal_validation.accepted:
			return formal_validation
		var completed := _flow_definition.node_for(room_id)
		if completed == null or not RunNodeKind.is_combat(completed.kind):
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.CONFIGURATION_ERROR,
				&"completed_room_missing_from_flow"
			)
		var target := _flow_definition.node_for(completed.next_node_id)
		if target == null:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.CONFIGURATION_ERROR,
				&"completed_room_missing_successor"
			)
		var options := _options_for(target)
		_route_state.commit_formal_room_completion(room_id)
		return _route_state.advance_formal_to(target.node_id, target.kind, options)
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
	if formal_flow:
		return _route_state.choose_formal_route(option_id)
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
	if formal_flow:
		if complete_run:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.INVALID_TRANSITION,
				&"formal_shop_cannot_complete_run"
			)
		if _route_state.snapshot().phase != RunPhase.SHOP:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.INVALID_STATE,
				&"shop_confirm_outside_shop"
			)
		return RunCommandResult.success()
	if _route_state.phase != RunPhase.SHOP:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_confirm_outside_shop")
	if complete_run and _route_state.completed_combat_rooms < PROTOTYPE_ROOM_COUNT:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_TRANSITION, &"run_cannot_complete_before_room_six")
	return RunCommandResult.success()


func commit_shop_exit(complete_run: bool) -> RunCommandResult:
	if formal_flow:
		var formal_validation := validate_shop_exit(complete_run)
		if not formal_validation.accepted:
			return formal_validation
		var shop_node := _flow_definition.node_for(_route_state.snapshot().current_node_id)
		var target := (
			_flow_definition.node_for(shop_node.next_node_id)
			if shop_node != null
			else null
		)
		if target == null:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.CONFIGURATION_ERROR,
				&"formal_shop_missing_successor"
			)
		return _route_state.leave_formal_shop(
			target.node_id,
			target.kind,
			_options_for(target)
		)
	var validation := validate_shop_exit(complete_run)
	if not validation.accepted:
		return validation
	return _route_state.try_transition(RunPhase.RUN_COMPLETE if complete_run else RunPhase.COMBAT)


func _is_shop_due() -> bool:
	return (
		_route_state.completed_combat_rooms > 0
		and _route_state.completed_combat_rooms % SHOP_INTERVAL == 0
	)


func fail_formal_run() -> RunCommandResult:
	if not formal_flow:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"legacy_run_has_no_formal_result"
		)
	return _route_state.mark_formal_failed(_flow_definition.result_node_id)


func current_node_snapshot() -> RunNodeSnapshot:
	if not formal_flow:
		return null
	var route := snapshot()
	var node_id := route.pending_node_id if route.phase == RunPhase.ROOM_LOADING else route.current_node_id
	return RunNodeSnapshot.from_definition(_flow_definition.node_for(node_id))


func combat_room_for(node_id: StringName) -> CombatRoomDefinition:
	return _flow_definition.combat_room_for(node_id) if formal_flow else null


func _options_for(node: RunNodeDefinition) -> Array[RouteOption]:
	var result: Array[RouteOption] = []
	if node == null or node.kind != RunNodeKind.ROUTE:
		return result
	for branch: RouteBranchDefinition in node.route_branches:
		result.append(branch.to_option())
	return result
