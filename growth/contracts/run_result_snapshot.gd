class_name RunResultSnapshot
extends RefCounted

enum Outcome {
	COMPLETE,
	FAILED,
}

var outcome: Outcome
var run_id: StringName
var completed_combat_rooms: int
var total_combat_rooms: int
var final_node_id: StringName
var failure_reason: StringName
var economy: DreamDustSnapshot
var skills: SkillInventorySnapshot
var loadout: RuntimeLoadoutSnapshot
var shop_visits: int
var route_choices: int
var final_run_revision: int


func _init(
		p_outcome: Outcome,
		p_run_id: StringName,
		p_completed_combat_rooms: int,
		p_total_combat_rooms: int,
		p_final_node_id: StringName,
		p_failure_reason: StringName,
		p_economy: DreamDustSnapshot,
		p_skills: SkillInventorySnapshot,
		p_loadout: RuntimeLoadoutSnapshot,
		p_shop_visits: int,
		p_route_choices: int,
		p_final_run_revision: int
) -> void:
	outcome = p_outcome
	run_id = p_run_id
	completed_combat_rooms = maxi(0, p_completed_combat_rooms)
	total_combat_rooms = maxi(0, p_total_combat_rooms)
	final_node_id = p_final_node_id
	failure_reason = p_failure_reason
	economy = p_economy
	skills = p_skills
	loadout = p_loadout
	shop_visits = maxi(0, p_shop_visits)
	route_choices = maxi(0, p_route_choices)
	final_run_revision = maxi(0, p_final_run_revision)


func is_complete() -> bool:
	return outcome == Outcome.COMPLETE
