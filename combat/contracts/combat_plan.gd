class_name CombatPlan
extends RefCounted

## Internal pre-commit plan. CombatReceiver validates the complete plan before
## mutating either target component.

var request: HitRequest
var element_status: CombatStatus.SubResult = CombatStatus.SubResult.NOT_AVAILABLE
var damage_status: CombatStatus.SubResult = CombatStatus.SubResult.NOT_AVAILABLE
var element_resolution: ElementResolution
var damage_resolution: DamageResolution
var health_before: int = 0
var health_after: int = 0
var maximum_health: int = 0
var validation_error: StringName = &""


func _init(p_request: HitRequest) -> void:
	request = p_request


func validate() -> StringName:
	if request == null or not request.is_valid():
		return &"invalid_request"
	if (
		element_status == CombatStatus.SubResult.NOT_AVAILABLE
		and damage_status == CombatStatus.SubResult.NOT_AVAILABLE
	):
		return &"no_receivers"
	if element_status != CombatStatus.SubResult.NOT_AVAILABLE:
		if element_resolution == null or not element_resolution.is_valid():
			return &"invalid_element_resolution"
	if damage_status != CombatStatus.SubResult.NOT_AVAILABLE:
		if damage_resolution == null or not damage_resolution.is_valid():
			return &"invalid_damage_resolution"
		if maximum_health <= 0:
			return &"invalid_maximum_health"
		if health_before < 0 or health_before > maximum_health:
			return &"invalid_health_before"
		if health_after < 0 or health_after > maximum_health:
			return &"invalid_health_after"
		if health_after > health_before:
			return &"damage_increased_health"
	return &""


func is_valid() -> bool:
	validation_error = validate()
	return validation_error.is_empty()


func health_delta() -> int:
	return health_after - health_before
