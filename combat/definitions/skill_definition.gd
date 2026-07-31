class_name SkillDefinition
extends Resource

## Immutable skill identity and common cast policy. Strategy-specific energy,
## payload, delivery, channel, and functional rules live in the polymorphic
## execution definition. Passive rules live in a typed passive definition.

enum ActivationKind {
	ACTIVE,
	PASSIVE,
}

enum ElementPolicy {
	EXCLUSIVE_ELEMENT,
	CURRENT_ELEMENT,
	NEUTRAL,
}

enum EnergyRefundPolicy {
	NEVER,
	BEFORE_DELIVERY,
}

@export var skill_id: StringName = &""
@export var activation_kind: ActivationKind = ActivationKind.ACTIVE
@export var element_policy: ElementPolicy = ElementPolicy.CURRENT_ELEMENT
@export var required_element_id: StringName = ElementIds.NONE
@export var energy_refund_policy: EnergyRefundPolicy = EnergyRefundPolicy.NEVER
@export_range(0.0, 60.0, 0.001, "or_greater") var startup_time: float = 0.0
@export_range(0.0, 60.0, 0.001, "or_greater") var recovery_time: float = 0.0
@export_range(0.0, 3600.0, 0.001, "or_greater") var cooldown: float = 0.0
@export var execution_definition: SkillExecutionDefinition
@export var passive_effect_definition: PassiveEffectDefinition

## Read-only availability preview for existing HUD integration. Resource and
## Executor authority belongs to execution_definition, not this facade.
var energy_cost: int:
	get:
		return execution_definition.minimum_energy_required() if execution_definition != null else 0


func validation_error() -> StringName:
	if skill_id.is_empty():
		return &"missing_skill_id"
	var policy_error := _element_policy_error()
	if not policy_error.is_empty():
		return policy_error
	match activation_kind:
		ActivationKind.ACTIVE:
			return _active_validation_error()
		ActivationKind.PASSIVE:
			return _passive_validation_error()
		_:
			return &"unknown_activation_kind"


func is_valid() -> bool:
	return validation_error().is_empty()


func is_active_skill() -> bool:
	return activation_kind == ActivationKind.ACTIVE


func is_passive_skill() -> bool:
	return activation_kind == ActivationKind.PASSIVE


func is_element_available(available_element_ids: Array[StringName]) -> bool:
	if element_policy != ElementPolicy.EXCLUSIVE_ELEMENT:
		return true
	return available_element_ids.has(required_element_id)


func resolve_cast_element(current_element_id: StringName) -> StringName:
	match element_policy:
		ElementPolicy.EXCLUSIVE_ELEMENT:
			return required_element_id
		ElementPolicy.CURRENT_ELEMENT:
			return current_element_id
		ElementPolicy.NEUTRAL:
			return ElementIds.NONE
		_:
			return &""


func _active_validation_error() -> StringName:
	if passive_effect_definition != null:
		return &"active_skill_has_passive_effect"
	if not _is_valid_duration(startup_time):
		return &"invalid_startup_time"
	if not _is_valid_duration(recovery_time):
		return &"invalid_recovery_time"
	if not _is_valid_duration(cooldown):
		return &"invalid_cooldown"
	if execution_definition == null:
		return &"missing_execution_definition"
	var execution_error := execution_definition.validation_error()
	if not execution_error.is_empty():
		return execution_error
	return execution_definition.element_policy_validation_error(
		element_policy,
		required_element_id
	)


func _passive_validation_error() -> StringName:
	if passive_effect_definition == null:
		return &"passive_skill_missing_effect_definition"
	if not passive_effect_definition.validation_error().is_empty():
		return passive_effect_definition.validation_error()
	if execution_definition != null:
		return &"passive_skill_has_execution_definition"
	if not is_zero_approx(startup_time) or not is_zero_approx(recovery_time):
		return &"passive_skill_has_cast_timing"
	if not is_zero_approx(cooldown):
		return &"passive_skill_has_cooldown"
	if energy_refund_policy != EnergyRefundPolicy.NEVER:
		return &"passive_skill_has_refund_policy"
	return &""


func _element_policy_error() -> StringName:
	match element_policy:
		ElementPolicy.EXCLUSIVE_ELEMENT:
			if required_element_id.is_empty() or required_element_id == ElementIds.NONE:
				return &"exclusive_skill_missing_element"
		ElementPolicy.CURRENT_ELEMENT, ElementPolicy.NEUTRAL:
			if required_element_id != ElementIds.NONE:
				return &"nonexclusive_skill_has_required_element"
		_:
			return &"unknown_element_policy"
	return &""


static func _is_valid_duration(value: float) -> bool:
	return is_finite(value) and value >= 0.0
