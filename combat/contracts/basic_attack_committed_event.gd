class_name BasicAttackCommittedEvent
extends RefCounted

## The producer certifies that this came from the fixed basic attack after its
## CombatReceiver transaction succeeded. Consumers never infer that fact from
## animation, input, tags, or log strings.

var event_id: StringName
var root_owner_id: int
var target_id: StringName
var target_elements: ElementSnapshot
var combat_result: CombatResult
var validation_error: StringName = &""


func _init(
		p_event_id: StringName,
		p_root_owner_id: int,
		p_target_id: StringName,
		p_target_elements: ElementSnapshot,
		p_combat_result: CombatResult = null
) -> void:
	event_id = p_event_id
	root_owner_id = p_root_owner_id
	target_id = p_target_id
	target_elements = p_target_elements
	combat_result = p_combat_result
	validation_error = _validate_values()


func is_valid() -> bool:
	return validation_error.is_empty()


func _validate_values() -> StringName:
	if event_id.is_empty():
		return &"missing_event_id"
	if root_owner_id <= 0:
		return &"missing_root_owner_id"
	if target_id.is_empty():
		return &"missing_target_id"
	if target_elements == null or not target_elements.is_valid():
		return &"invalid_target_elements"
	if combat_result != null and not combat_result.accepted:
		return &"basic_attack_result_not_committed"
	return &""
