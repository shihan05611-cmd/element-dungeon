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

@export_group("Run Economy")
@export_range(0, 1000000, 1, "or_greater") var purchase_price: int = 0
@export var active_progression: ActiveSkillProgressionDefinition


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
	if purchase_price < 0:
		return &"negative_skill_purchase_price"
	if fixed_basic_attack:
		if (
			initially_owned
			or reward_pool
			or equippable
			or not default_slot_id.is_empty()
			or purchase_price != 0
			or active_progression != null
		):
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
	if gameplay_definition.is_passive_skill():
		if active_progression != null:
			return &"passive_skill_has_level_data"
	elif active_progression != null:
		var progression_error := active_progression.validation_error()
		if not progression_error.is_empty():
			return progression_error
	elif purchase_price > 0:
		return &"purchasable_active_missing_level_data"
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


func is_shop_purchasable() -> bool:
	return (
		not fixed_basic_attack
		and equippable
		and purchase_price > 0
		and is_valid()
	)


func level_effect(level: int) -> ActiveSkillLevelEffectSnapshot:
	if (
		gameplay_definition == null
		or not gameplay_definition.is_active_skill()
		or active_progression == null
	):
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id, maxi(1, level))
	return active_progression.effect_snapshot(skill_id, level)
