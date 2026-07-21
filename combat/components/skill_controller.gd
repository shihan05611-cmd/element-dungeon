class_name SkillController
extends Node

## Input-agnostic facade that resolves the current form's independent loadout
## and delegates the atomic transaction to SkillExecutor.

signal cast_attempted(slot_id: StringName, result: CastAttemptResult)

@export var form_controller_path: NodePath
@export var executor_path: NodePath
@export var water_loadout: SkillLoadout
@export var fire_loadout: SkillLoadout

var _form_controller: ElementFormController
var _executor: SkillExecutor


func _ready() -> void:
	_resolve_dependencies_from_paths()


func configure_runtime(
		form_controller: ElementFormController,
		executor: SkillExecutor,
		p_water_loadout: SkillLoadout,
		p_fire_loadout: SkillLoadout
) -> bool:
	if form_controller == null or executor == null:
		return false
	_form_controller = form_controller
	_executor = executor
	water_loadout = p_water_loadout
	fire_loadout = p_fire_loadout
	return true


func try_cast_slot(slot_id: StringName) -> CastAttemptResult:
	_resolve_dependencies_from_paths()
	if _form_controller == null or _executor == null:
		return _publish_attempt(
			slot_id,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.MISSING_COMPONENT,
				&"",
				&"missing_form_controller_or_executor"
			)
		)
	var loadout := get_current_loadout()
	if loadout == null:
		return _publish_attempt(
			slot_id,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
				&"",
				&"missing_form_loadout"
			)
		)
	var loadout_error := loadout.validation_error()
	if not loadout_error.is_empty():
		return _publish_attempt(
			slot_id,
			CastAttemptResult.rejected(
				CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
				&"",
				loadout_error
			)
		)
	var skill := loadout.get_skill(slot_id)
	if skill == null:
		return _publish_attempt(
			slot_id,
			CastAttemptResult.rejected(CastAttemptResult.RejectReason.SLOT_UNASSIGNED)
		)
	return _publish_attempt(slot_id, _executor.try_cast(skill))


func request_form(form_id: StringName) -> bool:
	_resolve_dependencies_from_paths()
	return _form_controller != null and _form_controller.request_form(form_id)


func toggle_form() -> bool:
	_resolve_dependencies_from_paths()
	return _form_controller != null and _form_controller.toggle_form()


func cancel_current_cast(reason: StringName, expected_cast_id: int = 0) -> bool:
	_resolve_dependencies_from_paths()
	return _executor != null and _executor.cancel_current_cast(reason, expected_cast_id)


func get_current_loadout() -> SkillLoadout:
	if _form_controller == null:
		return null
	match _form_controller.current_form_id:
		ElementIds.WATER:
			return water_loadout
		ElementIds.FIRE:
			return fire_loadout
		_:
			return null


func get_skill_for_slot(slot_id: StringName) -> SkillDefinition:
	var loadout := get_current_loadout()
	return loadout.get_skill(slot_id) if loadout != null else null


func get_current_slot_ids() -> Array[StringName]:
	var loadout := get_current_loadout()
	return loadout.get_slot_ids() if loadout != null else []


func _publish_attempt(slot_id: StringName, result: CastAttemptResult) -> CastAttemptResult:
	cast_attempted.emit(slot_id, result)
	return result


func _resolve_dependencies_from_paths() -> void:
	if _form_controller == null and not form_controller_path.is_empty():
		_form_controller = get_node_or_null(form_controller_path) as ElementFormController
	if _executor == null and not executor_path.is_empty():
		_executor = get_node_or_null(executor_path) as SkillExecutor
