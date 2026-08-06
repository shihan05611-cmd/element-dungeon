class_name RunNodeDefinition
extends Resource

@export var node_id: StringName = &""
@export_enum("Entry", "Combat", "Shop", "Route", "Boss", "Result") var kind: int = RunNodeKind.ENTRY
@export var next_node_id: StringName = &""
@export var combat_room: CombatRoomDefinition
@export var route_branches: Array[RouteBranchDefinition] = []


func validation_error() -> StringName:
	if node_id.is_empty() or not RunNodeKind.is_valid(kind):
		return &"invalid_run_node_identity"
	if RunNodeKind.is_combat(kind):
		if combat_room == null:
			return &"combat_node_missing_room"
		var room_error := combat_room.validation_error()
		if not room_error.is_empty():
			return room_error
		if combat_room.room_id != node_id:
			return &"combat_room_node_id_mismatch"
		if kind == RunNodeKind.BOSS and not combat_room.final_boss:
			return &"boss_node_missing_terminal_room"
		if kind == RunNodeKind.COMBAT and combat_room.final_boss:
			return &"normal_combat_marked_terminal"
		if next_node_id.is_empty():
			return &"combat_node_missing_successor"
		if not route_branches.is_empty():
			return &"combat_node_has_route_branches"
		return &""
	if kind == RunNodeKind.ROUTE:
		if route_branches.size() != 2:
			return &"route_node_requires_two_branches"
		if not next_node_id.is_empty() or combat_room != null:
			return &"route_node_has_invalid_payload"
		var option_ids: Array[StringName] = []
		var targets: Array[StringName] = []
		for branch: RouteBranchDefinition in route_branches:
			if branch == null:
				return &"null_route_branch"
			var branch_error := branch.validation_error()
			if not branch_error.is_empty():
				return branch_error
			if option_ids.has(branch.option_id) or targets.has(branch.target_node_id):
				return &"duplicate_route_branch"
			option_ids.append(branch.option_id)
			targets.append(branch.target_node_id)
		return &""
	if kind == RunNodeKind.RESULT:
		return (
			&""
			if next_node_id.is_empty() and combat_room == null and route_branches.is_empty()
			else &"result_node_has_successor"
		)
	if next_node_id.is_empty():
		return &"run_node_missing_successor"
	if combat_room != null or not route_branches.is_empty():
		return &"noncombat_node_has_invalid_payload"
	return &""
