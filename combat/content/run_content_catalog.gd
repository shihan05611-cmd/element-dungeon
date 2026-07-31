class_name RunContentCatalog
extends Resource

const ELEMENT_RAGE_DELIVERY_SCRIPT := preload(
	"res://combat/delivery/element_rage_delivery.gd"
)
const ELEMENT_BEAM_DELIVERY_SCRIPT := preload(
	"res://combat/delivery/element_beam_delivery.gd"
)

## The single static registration source for one run. Every downstream view is
## deterministically projected from skill_contents and relic_definitions.

@export var skill_contents: Array[SkillContentDefinition] = []
@export var fixed_basic_attack_id: StringName = &""
@export var relic_definitions: Array[RelicDefinition] = []


func validation_error() -> StringName:
	if skill_contents.is_empty():
		return &"empty_skill_content_catalog"
	if fixed_basic_attack_id.is_empty():
		return &"missing_fixed_basic_attack_id"

	var content_ids: Array[StringName] = []
	var gameplay_ids: Array[StringName] = []
	var default_slots: Array[StringName] = []
	var fixed_count := 0
	for content: SkillContentDefinition in skill_contents:
		if content == null:
			return &"null_skill_content"
		if content.skill_id.is_empty():
			return &"missing_skill_content_id"
		if content_ids.has(content.skill_id):
			return &"duplicate_skill_content_id"
		content_ids.append(content.skill_id)
		if content.gameplay_definition == null:
			return &"missing_gameplay_definition"
		var gameplay_id := content.gameplay_definition.skill_id
		if gameplay_id.is_empty():
			return &"missing_gameplay_skill_id"
		if gameplay_ids.has(gameplay_id):
			return &"duplicate_gameplay_skill_id"
		gameplay_ids.append(gameplay_id)
		if content.reward_pool and not gameplay_ids.has(content.skill_id):
			return &"reward_points_to_unknown_skill"
		var content_error := content.validation_error()
		if not content_error.is_empty():
			return content_error
		if content.fixed_basic_attack:
			fixed_count += 1
			if content.skill_id != fixed_basic_attack_id:
				return &"fixed_basic_attack_id_mismatch"
		if not content.default_slot_id.is_empty():
			if default_slots.has(content.default_slot_id):
				return &"duplicate_default_slot"
			default_slots.append(content.default_slot_id)
		var delivery_error := _runtime_delivery_validation_error(content)
		if not delivery_error.is_empty():
			return delivery_error
	if fixed_count != 1 or not content_ids.has(fixed_basic_attack_id):
		return &"fixed_basic_attack_not_registered_once"

	var reward_ids: Array[StringName] = []
	for reward: SkillRewardDefinition in reward_definitions():
		if reward == null or not reward.validation_error().is_empty():
			return &"invalid_reward_projection"
		if not content_ids.has(reward.skill_id):
			return &"reward_points_to_unknown_skill"
		if reward_ids.has(reward.skill_id):
			return &"duplicate_reward_projection"
		reward_ids.append(reward.skill_id)
	if reward_ids.has(fixed_basic_attack_id):
		return &"fixed_basic_attack_in_reward_pool"

	var relic_ids: Array[StringName] = []
	for relic: RelicDefinition in relic_definitions:
		if relic == null or not relic.is_valid():
			return &"invalid_relic_catalog_entry"
		if relic_ids.has(relic.relic_id):
			return &"duplicate_relic_catalog_id"
		relic_ids.append(relic.relic_id)
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


func content_for(skill_id: StringName) -> SkillContentDefinition:
	for content: SkillContentDefinition in skill_contents:
		if content != null and content.skill_id == skill_id:
			return content
	return null


func gameplay_for(skill_id: StringName) -> SkillDefinition:
	var content := content_for(skill_id)
	return content.gameplay_definition if content != null else null


func gameplay_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for content: SkillContentDefinition in skill_contents:
		if content != null and content.gameplay_definition != null:
			result.append(content.gameplay_definition)
	return result


func equippable_gameplay_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for content: SkillContentDefinition in skill_contents:
		if content != null and content.equippable and content.gameplay_definition != null:
			result.append(content.gameplay_definition)
	return result


func obtainable_contents() -> Array[SkillContentDefinition]:
	var result: Array[SkillContentDefinition] = []
	for content: SkillContentDefinition in skill_contents:
		if content != null and not content.fixed_basic_attack:
			result.append(content)
	return result


func initial_owned_skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for content: SkillContentDefinition in skill_contents:
		if content != null and content.initially_owned:
			result.append(content.skill_id)
	return result


func reward_definitions() -> Array[SkillRewardDefinition]:
	var result: Array[SkillRewardDefinition] = []
	for content: SkillContentDefinition in skill_contents:
		if content == null or not content.reward_pool:
			continue
		var projection := content.project_reward_definition()
		if projection != null:
			result.append(projection)
	return result


func fixed_basic_attack_definition() -> SkillDefinition:
	return gameplay_for(fixed_basic_attack_id)


func default_loadout_snapshot(revision: int = 0) -> RuntimeLoadoutSnapshot:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		var equipped_skill_id: StringName = &""
		for content: SkillContentDefinition in skill_contents:
			if content != null and content.default_slot_id == slot_id:
				equipped_skill_id = content.skill_id
				break
		entries.append(RuntimeLoadoutSlotSnapshot.new(slot_id, equipped_skill_id))
	return RuntimeLoadoutSnapshot.new(entries, revision)


func runtime_delivery_scene_for(skill_id: StringName) -> PackedScene:
	var content := content_for(skill_id)
	return content.runtime_delivery_scene if content != null else null


func _runtime_delivery_validation_error(content: SkillContentDefinition) -> StringName:
	var skill := content.gameplay_definition
	if skill == null:
		return &"missing_gameplay_definition"
	if skill.is_passive_skill():
		if content.runtime_delivery_scene != null:
			return &"passive_skill_has_runtime_delivery"
		var effect := skill.passive_effect_definition
		if effect is BurningPassiveEffectDefinition:
			if (
				skill.element_policy != SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
				or skill.required_element_id != ElementIds.FIRE
			):
				return &"burning_requires_fixed_fire_semantics"
		elif effect is UnendingPassiveEffectDefinition:
			if (
				skill.element_policy != SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
				or skill.required_element_id != ElementIds.WATER
			):
				return &"unending_requires_fixed_water_semantics"
		return &""

	var execution := skill.execution_definition
	if execution == null:
		return &"missing_execution_definition"
	var execution_error := execution.catalog_validation_error()
	if not execution_error.is_empty():
		return execution_error
	if execution is InstantDeliveryExecution:
		return (
			&""
			if content.runtime_delivery_scene == null
			else &"instant_skill_has_duplicate_runtime_delivery"
		)
	if execution is ElementReclaimExecution:
		return (
			&""
			if content.runtime_delivery_scene == null
			else &"reclaim_has_runtime_delivery"
		)
	if content.runtime_delivery_scene == null:
		return &"missing_runtime_delivery_scene"
	if not content.runtime_delivery_scene.can_instantiate():
		return &"runtime_delivery_scene_unavailable"
	var root := content.runtime_delivery_scene.instantiate()
	if root == null:
		return &"runtime_delivery_instantiation_failed"
	var error: StringName = &"unsupported_active_execution_definition"
	if execution is AllEnergyBurstExecution:
		var rage := root as ELEMENT_RAGE_DELIVERY_SCRIPT
		if rage == null:
			error = &"rage_delivery_protocol_mismatch"
		elif (
			not is_finite(rage.base_radius)
			or rage.base_radius <= 0.0
			or rage.hurtbox_collision_mask <= 0
			or not rage.walls_block_targets
			or rage.blocking_collision_mask <= 0
		):
			error = &"invalid_rage_delivery_configuration"
		else:
			error = &""
	elif execution is ChannelExecution:
		var beam := root as ELEMENT_BEAM_DELIVERY_SCRIPT
		if beam == null:
			error = &"beam_delivery_protocol_mismatch"
		elif (
			not is_finite(beam.beam_length)
			or beam.beam_length <= 0.0
			or not is_finite(beam.beam_width)
			or beam.beam_width <= 0.0
			or beam.hurtbox_collision_mask <= 0
		):
			error = &"invalid_beam_delivery_configuration"
		else:
			error = &""
	root.free()
	return error
