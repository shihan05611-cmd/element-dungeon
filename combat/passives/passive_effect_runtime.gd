class_name PassiveEffectRuntime
extends RefCounted

var skill_id: StringName:
	get:
		return _skill_id

var definition: PassiveEffectDefinition:
	get:
		return _definition

var _skill_id: StringName
var _definition: PassiveEffectDefinition
var _context: PassiveRuntimeContext


func _init(
		p_skill_id: StringName,
		p_definition: PassiveEffectDefinition,
		p_context: PassiveRuntimeContext
) -> void:
	_skill_id = p_skill_id
	_definition = p_definition
	_context = p_context


func is_valid() -> bool:
	return (
		not _skill_id.is_empty()
		and _definition != null
		and _definition.validation_error().is_empty()
	)


func advance(_delta: float) -> bool:
	return false


func on_basic_attack_committed(_event: BasicAttackCommittedEvent) -> bool:
	return false


func stat_modifier_snapshot() -> PassiveStatModifierSnapshot:
	return PassiveStatModifierSnapshot.new()
