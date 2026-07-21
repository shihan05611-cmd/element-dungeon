class_name SkillDefinition
extends Resource

## Static skill configuration. Runtime energy, cooldowns, cast state and hit
## history deliberately live in per-actor components instead of this Resource.

enum FormPolicy {
	ANY_FORM,
	REQUIRED_FORM,
}

@export var skill_id: StringName = &""
@export var form_policy: FormPolicy = FormPolicy.ANY_FORM
@export var required_form_id: StringName = ElementIds.NONE
@export_range(0.0, 60.0, 0.001, "or_greater") var startup_time: float = 0.0
@export_range(0.0, 60.0, 0.001, "or_greater") var active_time: float = 0.0
@export_range(0.0, 60.0, 0.001, "or_greater") var recovery_time: float = 0.0
@export_range(0, 1000000, 1, "or_greater") var energy_cost: int = 0
@export_range(0.0, 3600.0, 0.001, "or_greater") var cooldown: float = 0.0
@export var delivery_scene: PackedScene
@export var payload: AttackPayloadDefinition


func validation_error() -> StringName:
	if skill_id.is_empty():
		return &"missing_skill_id"
	if not _is_valid_duration(startup_time):
		return &"invalid_startup_time"
	if not _is_valid_duration(active_time):
		return &"invalid_active_time"
	if not _is_valid_duration(recovery_time):
		return &"invalid_recovery_time"
	if energy_cost < 0:
		return &"invalid_energy_cost"
	if not _is_valid_duration(cooldown):
		return &"invalid_cooldown"
	if delivery_scene == null:
		return &"missing_delivery_scene"
	if payload == null or not payload.is_valid():
		return &"invalid_payload_definition"

	match form_policy:
		FormPolicy.ANY_FORM:
			if required_form_id != ElementIds.NONE:
				return &"universal_skill_has_required_form"
			if (
				payload.element_mode != AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
				and payload.element_mode != AttackPayloadDefinition.ElementMode.NONE
			):
				return &"universal_skill_must_follow_cast_form_or_be_neutral"
		FormPolicy.REQUIRED_FORM:
			if not ElementIds.is_combat_element(required_form_id):
				return &"invalid_required_form"
			if payload.element_mode == AttackPayloadDefinition.ElementMode.NONE:
				return &"exclusive_skill_missing_element"
			if (
				payload.element_mode == AttackPayloadDefinition.ElementMode.FIXED_ELEMENT
				and payload.fixed_element_id != required_form_id
			):
				return &"exclusive_skill_element_mismatch"
		_:
			return &"unknown_form_policy"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func is_form_allowed(form_id: StringName) -> bool:
	if not ElementIds.is_combat_element(form_id):
		return false
	return form_policy == FormPolicy.ANY_FORM or required_form_id == form_id


static func _is_valid_duration(value: float) -> bool:
	return is_finite(value) and value >= 0.0
