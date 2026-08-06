class_name RunFlowDefinition
extends Resource

const REQUIRED_COMBAT_ROOMS: int = 6
const REQUIRED_SHOPS: int = 3
const REQUIRED_ROUTES: int = 2

@export var flow_id: StringName = &""
@export var entry_node_id: StringName = &"run_entry"
@export var result_node_id: StringName = &"run_result"
@export var nodes: Array[RunNodeDefinition] = []


func validation_error() -> StringName:
	if flow_id.is_empty() or entry_node_id.is_empty() or result_node_id.is_empty():
		return &"missing_run_flow_identity"
	if nodes.is_empty():
		return &"empty_run_flow"
	var ids: Array[StringName] = []
	var boss_count := 0
	for node: RunNodeDefinition in nodes:
		if node == null:
			return &"null_run_node"
		var node_error := node.validation_error()
		if not node_error.is_empty():
			return node_error
		if ids.has(node.node_id):
			return &"duplicate_run_node_id"
		ids.append(node.node_id)
		if node.kind == RunNodeKind.BOSS:
			boss_count += 1
	if boss_count != 1:
		return &"run_flow_requires_one_boss"
	var entry := node_for(entry_node_id)
	var result := node_for(result_node_id)
	if entry == null or entry.kind != RunNodeKind.ENTRY:
		return &"invalid_run_entry_node"
	if result == null or result.kind != RunNodeKind.RESULT:
		return &"invalid_run_result_node"
	for node: RunNodeDefinition in nodes:
		if not node.next_node_id.is_empty() and node_for(node.next_node_id) == null:
			return &"unknown_run_node_successor"
		for branch: RouteBranchDefinition in node.route_branches:
			var target := node_for(branch.target_node_id)
			if target == null or not RunNodeKind.is_combat(target.kind):
				return &"route_target_is_not_combat"
	var path_error := _validate_path(entry_node_id, [], 0, 0, 0)
	if not path_error.is_empty():
		return path_error
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func node_for(node_id: StringName) -> RunNodeDefinition:
	for node: RunNodeDefinition in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func combat_room_for(node_id: StringName) -> CombatRoomDefinition:
	var node := node_for(node_id)
	return node.combat_room if node != null and RunNodeKind.is_combat(node.kind) else null


func _validate_path(
		node_id: StringName,
		seen: Array[StringName],
		combat_count: int,
		shop_count: int,
		route_count: int
) -> StringName:
	if seen.has(node_id):
		return &"run_flow_cycle_detected"
	var node := node_for(node_id)
	if node == null:
		return &"run_flow_path_missing_node"
	var next_seen := seen.duplicate()
	next_seen.append(node_id)
	var next_combat := combat_count + (1 if RunNodeKind.is_combat(node.kind) else 0)
	var next_shop := shop_count + (1 if node.kind == RunNodeKind.SHOP else 0)
	var next_route := route_count + (1 if node.kind == RunNodeKind.ROUTE else 0)
	if node.kind == RunNodeKind.RESULT:
		if (
			next_combat != REQUIRED_COMBAT_ROOMS
			or next_shop != REQUIRED_SHOPS
			or next_route != REQUIRED_ROUTES
		):
			return &"run_flow_path_count_mismatch"
		return &""
	if node.kind == RunNodeKind.ROUTE:
		for branch: RouteBranchDefinition in node.route_branches:
			var branch_error := _validate_path(
				branch.target_node_id,
				next_seen,
				next_combat,
				next_shop,
				next_route
			)
			if not branch_error.is_empty():
				return branch_error
		return &""
	return _validate_path(
		node.next_node_id,
		next_seen,
		next_combat,
		next_shop,
		next_route
	)
