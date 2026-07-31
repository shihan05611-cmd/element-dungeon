class_name StatModifierPassiveEffectRuntime
extends PassiveEffectRuntime

var _modifier: PassiveStatModifierSnapshot


func _init(
		p_skill_id: StringName,
		p_definition: PassiveEffectDefinition,
		p_context: PassiveRuntimeContext,
		p_modifier: PassiveStatModifierSnapshot
) -> void:
	super(p_skill_id, p_definition, p_context)
	_modifier = p_modifier


func is_valid() -> bool:
	return super() and _modifier != null and _modifier.is_valid()


func stat_modifier_snapshot() -> PassiveStatModifierSnapshot:
	return _modifier
