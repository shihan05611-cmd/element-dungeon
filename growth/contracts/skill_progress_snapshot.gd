class_name SkillProgressSnapshot
extends RefCounted

enum AcquisitionKind {
	INITIAL,
	PURCHASED,
	LEGACY_MIGRATED,
	SCRIPTED,
}

var skill_id: StringName:
	get:
		return _skill_id

var activation_kind: SkillDefinition.ActivationKind:
	get:
		return _activation_kind

var level: int:
	get:
		return _level

var cumulative_upgrade_spend: int:
	get:
		return _cumulative_upgrade_spend

var acquisition_kind: AcquisitionKind:
	get:
		return _acquisition_kind

var validation_error: StringName:
	get:
		return _validation_error

var _skill_id: StringName
var _activation_kind: SkillDefinition.ActivationKind
var _level: int
var _cumulative_upgrade_spend: int
var _acquisition_kind: AcquisitionKind
var _validation_error: StringName = &""


func _init(
		p_skill_id: StringName,
		p_activation_kind: SkillDefinition.ActivationKind = SkillDefinition.ActivationKind.ACTIVE,
		p_level: int = 1,
		p_cumulative_upgrade_spend: int = 0,
		p_acquisition_kind: AcquisitionKind = AcquisitionKind.LEGACY_MIGRATED
) -> void:
	_skill_id = p_skill_id
	_activation_kind = p_activation_kind
	_level = p_level
	_cumulative_upgrade_spend = p_cumulative_upgrade_spend
	_acquisition_kind = p_acquisition_kind
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func is_active() -> bool:
	return _activation_kind == SkillDefinition.ActivationKind.ACTIVE


func is_passive() -> bool:
	return _activation_kind == SkillDefinition.ActivationKind.PASSIVE


func _validate_values() -> StringName:
	if _skill_id.is_empty():
		return &"missing_skill_progress_id"
	if _activation_kind not in [
		SkillDefinition.ActivationKind.ACTIVE,
		SkillDefinition.ActivationKind.PASSIVE,
	]:
		return &"invalid_skill_progress_activation_kind"
	if _level < 1 or _cumulative_upgrade_spend < 0:
		return &"invalid_skill_progress_values"
	if is_passive() and (_level != 1 or _cumulative_upgrade_spend != 0):
		return &"passive_skill_has_progression"
	if _acquisition_kind not in [
		AcquisitionKind.INITIAL,
		AcquisitionKind.PURCHASED,
		AcquisitionKind.LEGACY_MIGRATED,
		AcquisitionKind.SCRIPTED,
	]:
		return &"invalid_skill_acquisition_kind"
	return &""
