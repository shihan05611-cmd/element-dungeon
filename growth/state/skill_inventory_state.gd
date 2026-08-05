class_name SkillInventoryState
extends RefCounted

var _owned_skill_ids: Array[StringName] = []
var _activation_kinds: Dictionary = {}
var _levels: Dictionary = {}
var _upgrade_spend: Dictionary = {}
var _acquisition_kinds: Dictionary = {}


func _init(
		initial_skill_ids: Array[StringName] = [],
		content_definitions: Array[SkillContentDefinition] = []
) -> void:
	for skill_id in initial_skill_ids:
		if skill_id.is_empty() or _owned_skill_ids.has(skill_id):
			continue
		var content := _content_for(skill_id, content_definitions)
		var activation_kind := (
			content.gameplay_definition.activation_kind
			if content != null and content.gameplay_definition != null
			else SkillDefinition.ActivationKind.ACTIVE
		)
		_commit_add(
			skill_id,
			activation_kind,
			SkillProgressSnapshot.AcquisitionKind.INITIAL
		)


func snapshot() -> SkillInventorySnapshot:
	var progress_entries: Array[SkillProgressSnapshot] = []
	for skill_id: StringName in _owned_skill_ids:
		progress_entries.append(SkillProgressSnapshot.new(
			skill_id,
			_activation_kinds[skill_id],
			_levels[skill_id],
			_upgrade_spend[skill_id],
			_acquisition_kinds[skill_id]
		))
	return SkillInventorySnapshot.new(_owned_skill_ids, progress_entries)


func owns(skill_id: StringName) -> bool:
	return _owned_skill_ids.has(skill_id)


func try_add(skill_id: StringName) -> RunCommandResult:
	if skill_id.is_empty():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"missing_skill_id")
	if owns(skill_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_OWNED, &"skill_already_owned")
	_commit_add(
		skill_id,
		SkillDefinition.ActivationKind.ACTIVE,
		SkillProgressSnapshot.AcquisitionKind.LEGACY_MIGRATED
	)
	return RunCommandResult.success()


func validate_add_content(content: SkillContentDefinition) -> RunCommandResult:
	if (
		content == null
		or content.gameplay_definition == null
		or content.skill_id.is_empty()
	):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"invalid_skill_content"
		)
	if owns(content.skill_id):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.ALREADY_OWNED,
			&"skill_already_owned"
		)
	return RunCommandResult.success()


func commit_add_content(
		content: SkillContentDefinition,
		acquisition_kind: SkillProgressSnapshot.AcquisitionKind
) -> void:
	assert(validate_add_content(content).accepted, "skill content add must be validated")
	_commit_add(content.skill_id, content.gameplay_definition.activation_kind, acquisition_kind)


func activation_kind_for(skill_id: StringName) -> SkillDefinition.ActivationKind:
	return _activation_kinds.get(skill_id, SkillDefinition.ActivationKind.ACTIVE)


func level_for(skill_id: StringName) -> int:
	return int(_levels.get(skill_id, 0))


func cumulative_upgrade_spend_for(skill_id: StringName) -> int:
	return int(_upgrade_spend.get(skill_id, 0))


func commit_upgrade(skill_id: StringName, paid_price: int) -> void:
	assert(
		owns(skill_id)
		and activation_kind_for(skill_id) == SkillDefinition.ActivationKind.ACTIVE
		and paid_price > 0,
		"active skill upgrade must be validated"
	)
	_levels[skill_id] = level_for(skill_id) + 1
	_upgrade_spend[skill_id] = cumulative_upgrade_spend_for(skill_id) + paid_price


func commit_reset(skill_id: StringName) -> void:
	assert(
		owns(skill_id)
		and activation_kind_for(skill_id) == SkillDefinition.ActivationKind.ACTIVE
		and level_for(skill_id) > 1
		and cumulative_upgrade_spend_for(skill_id) > 0,
		"active skill reset must be validated"
	)
	_levels[skill_id] = 1
	_upgrade_spend[skill_id] = 0


func _commit_add(
		skill_id: StringName,
		activation_kind: SkillDefinition.ActivationKind,
		acquisition_kind: SkillProgressSnapshot.AcquisitionKind
) -> void:
	assert(not skill_id.is_empty() and not owns(skill_id), "skill add must be unique")
	_owned_skill_ids.append(skill_id)
	_activation_kinds[skill_id] = activation_kind
	_levels[skill_id] = 1
	_upgrade_spend[skill_id] = 0
	_acquisition_kinds[skill_id] = acquisition_kind


func _content_for(
		skill_id: StringName,
		content_definitions: Array[SkillContentDefinition]
) -> SkillContentDefinition:
	for content: SkillContentDefinition in content_definitions:
		if content != null and content.skill_id == skill_id:
			return content
	return null
