class_name RouteBranchDefinition
extends Resource

@export var option_id: StringName = &""
@export var target_node_id: StringName = &""
@export var title: String = ""
@export var encounter_label: String = ""
@export var environment_label: String = ""
@export var risk_label: String = ""
@export_range(0, 10, 1) var risk_tier: int = 0
@export var expected_dream_dust_label: String = ""


func validation_error() -> StringName:
	if option_id.is_empty() or target_node_id.is_empty():
		return &"missing_route_branch_identity"
	if (
		title.is_empty()
		or encounter_label.is_empty()
		or environment_label.is_empty()
		or risk_label.is_empty()
		or expected_dream_dust_label.is_empty()
	):
		return &"missing_route_branch_disclosure"
	return &""


func to_option() -> RouteOption:
	return RouteOption.new(
		option_id,
		RouteOption.Kind.COMBAT_ROOM,
		-1,
		target_node_id,
		title,
		encounter_label,
		environment_label,
		risk_label,
		risk_tier,
		expected_dream_dust_label
	)
