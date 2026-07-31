class_name SkillLoadout
extends Resource

## Shared four-slot template. form_element_id and arbitrary legacy slot names
## are retained only so old resources can be read by the one-time migrator.

@export_storage var form_element_id: StringName = ElementIds.NONE
@export var slots: Dictionary[StringName, SkillDefinition] = {}


func validation_error() -> StringName:
	if _has_shared_shape():
		return shared_validation_error()
	return legacy_validation_error()


func shared_validation_error() -> StringName:
	var expected := SkillSlotIds.all()
	if slots.size() != expected.size():
		return &"expected_four_shared_slots"
	for slot_id: StringName in expected:
		if not slots.has(slot_id):
			return &"missing_shared_slot"
	var seen_skill_ids: Array[StringName] = []
	for slot_id: StringName in expected:
		var skill := slots.get(slot_id) as SkillDefinition
		if skill == null:
			continue
		var error := skill.validation_error()
		if not error.is_empty():
			return error
		if seen_skill_ids.has(skill.skill_id):
			return &"duplicate_equipped_skill"
		seen_skill_ids.append(skill.skill_id)
		if slot_id == SkillSlotIds.PASSIVE_1 and not skill.is_passive_skill():
			return &"active_skill_in_passive_slot"
	return &""


func legacy_validation_error() -> StringName:
	if not ElementIds.is_combat_element(form_element_id):
		return &"invalid_legacy_loadout_element"
	var seen_skill_ids: Array[StringName] = []
	for slot_id: StringName in slots:
		if slot_id.is_empty():
			return &"missing_slot_id"
		var skill := slots.get(slot_id) as SkillDefinition
		if skill == null:
			return &"invalid_slot_skill"
		var error := skill.validation_error()
		if not error.is_empty():
			return error
		if seen_skill_ids.has(skill.skill_id):
			return &"duplicate_equipped_skill"
		seen_skill_ids.append(skill.skill_id)
		if (
			skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
			and skill.required_element_id != form_element_id
		):
			return &"legacy_slot_skill_element_mismatch"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func is_shared() -> bool:
	return _has_shared_shape() and shared_validation_error().is_empty()


func get_skill(slot_id: StringName) -> SkillDefinition:
	return slots.get(slot_id) as SkillDefinition


func has_slot(slot_id: StringName) -> bool:
	return not slot_id.is_empty() and slots.has(slot_id) and get_skill(slot_id) != null


func get_slot_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for slot_id: StringName in slots:
		result.append(slot_id)
	result.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return result


func to_runtime_snapshot(revision: int = 0) -> RuntimeLoadoutSnapshot:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		var skill := get_skill(slot_id)
		entries.append(RuntimeLoadoutSlotSnapshot.new(
			slot_id,
			skill.skill_id if skill != null else &""
		))
	return RuntimeLoadoutSnapshot.new(entries, revision)


func _has_shared_shape() -> bool:
	if slots.size() != SkillSlotIds.all().size():
		return false
	for slot_id: StringName in SkillSlotIds.all():
		if not slots.has(slot_id):
			return false
	return true
