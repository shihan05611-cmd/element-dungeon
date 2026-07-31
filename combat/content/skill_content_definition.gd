class_name SkillContentDefinition
extends Resource

## Immutable-by-contract static content metadata. Runtime energy, cooldown,
## ownership, equipment, targets and timers never belong to this Resource.

@export var skill_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var presentation_scene: PackedScene
@export var gameplay_definition: SkillDefinition
@export var runtime_delivery_scene: PackedScene

@export_group("Acquisition")
@export var fixed_basic_attack: bool = false
@export var initially_owned: bool = false
@export var reward_pool: bool = false
@export var initial_reward_pool: bool = false
@export var future_unlock_condition: StringName = &""

@export_group("Loadout")
@export var equippable: bool = true
@export var default_slot_id: StringName = &""

@export_group("Growth Projection")
@export var allowed_form_ids: Array[StringName] = []


func validation_error() -> StringName:
	if skill_id.is_empty():
		return &"missing_skill_content_id"
	if display_name.strip_edges().is_empty():
		return &"missing_skill_display_name"
	if description.strip_edges().is_empty():
		return &"missing_skill_description"
	if gameplay_definition == null:
		return &"missing_gameplay_definition"
	if gameplay_definition.skill_id != skill_id:
		return &"content_gameplay_id_mismatch"
	var gameplay_error := gameplay_definition.validation_error()
	if not gameplay_error.is_empty():
		return gameplay_error
	if allowed_form_ids.is_empty():
		return &"missing_allowed_forms"
	var seen_forms: Array[StringName] = []
	for form_id: StringName in allowed_form_ids:
		if form_id.is_empty():
			return &"empty_allowed_form"
		if seen_forms.has(form_id):
			return &"duplicate_allowed_form"
		seen_forms.append(form_id)
	if initial_reward_pool and not reward_pool:
		return &"initial_reward_requires_reward_pool"
	if fixed_basic_attack:
		if initially_owned or reward_pool or equippable or not default_slot_id.is_empty():
			return &"fixed_basic_attack_has_shared_progression"
		if not gameplay_definition.is_active_skill():
			return &"fixed_basic_attack_must_be_active"
		if gameplay_definition.element_policy != SkillDefinition.ElementPolicy.NEUTRAL:
			return &"fixed_basic_attack_must_be_neutral"
	if not equippable and not default_slot_id.is_empty():
		return &"nonequippable_skill_has_default_slot"
	if not default_slot_id.is_empty():
		if not SkillSlotIds.is_known(default_slot_id):
			return &"unknown_default_slot"
		if not initially_owned:
			return &"default_equipment_must_be_initially_owned"
		if (
			default_slot_id == SkillSlotIds.PASSIVE_1
			and not gameplay_definition.is_passive_skill()
		):
			return &"active_skill_in_passive_default_slot"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func project_reward_definition() -> SkillRewardDefinition:
	if not reward_pool or not is_valid():
		return null
	var projection := SkillRewardDefinition.new()
	projection.skill_id = skill_id
	projection.display_name = display_name
	projection.description = description
	projection.initial_pool = initial_reward_pool
	projection.allowed_form_ids = allowed_form_ids.duplicate()
	return projection
