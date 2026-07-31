class_name PassiveDamageRequest
extends RefCounted

var event_id: StringName
var source_skill_id: StringName
var target: PassiveTargetSnapshot
var payload: RuntimeAttackPayload


func _init(
		p_event_id: StringName,
		p_source_skill_id: StringName,
		p_target: PassiveTargetSnapshot,
		p_payload: RuntimeAttackPayload
) -> void:
	event_id = p_event_id
	source_skill_id = p_source_skill_id
	target = p_target
	payload = p_payload


func is_valid() -> bool:
	return (
		not event_id.is_empty()
		and not source_skill_id.is_empty()
		and target != null
		and target.is_valid()
		and payload != null
		and payload.is_valid()
	)
