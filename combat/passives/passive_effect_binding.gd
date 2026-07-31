class_name PassiveEffectBinding
extends RefCounted

var skill_id: StringName:
	get:
		return _skill_id

var definition: PassiveEffectDefinition:
	get:
		return _definition

var element_policy: SkillDefinition.ElementPolicy:
	get:
		return _element_policy

var required_element_id: StringName:
	get:
		return _required_element_id

var _skill_id: StringName
var _definition: PassiveEffectDefinition
var _element_policy: SkillDefinition.ElementPolicy
var _required_element_id: StringName


func _init(
		p_skill_id: StringName,
		p_definition: PassiveEffectDefinition,
		p_element_policy: SkillDefinition.ElementPolicy,
		p_required_element_id: StringName
) -> void:
	_skill_id = p_skill_id
	_definition = p_definition
	_element_policy = p_element_policy
	_required_element_id = p_required_element_id


func is_valid() -> bool:
	return (
		not _skill_id.is_empty()
		and _definition != null
		and _definition.validation_error().is_empty()
	)
