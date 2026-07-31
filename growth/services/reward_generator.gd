class_name RewardGenerator
extends RefCounted

const MAX_OPTIONS: int = 3


static func generate(
		run_snapshot: RunSnapshot,
		context: RoomRewardContext,
		seed: int,
		skill_catalog: Array[SkillRewardDefinition],
		relic_catalog: Array[RelicDefinition]
) -> RewardOffer:
	if run_snapshot == null or context == null or not context.is_valid():
		return RewardOffer.configuration_failure(&"", -1, seed, &"invalid_reward_generation_input")
	var authority_error := _route_authority_error(run_snapshot.route, context)
	if not authority_error.is_empty():
		return RewardOffer.configuration_failure(context.room_id, context.reward_type, seed, authority_error)
	var first_combat_room := _is_first_combat_reward(run_snapshot.route)
	var catalog_error := _validate_catalogs(skill_catalog, relic_catalog)
	if not catalog_error.is_empty():
		return RewardOffer.configuration_failure(context.room_id, context.reward_type, seed, catalog_error)
	match context.reward_type:
		RewardType.SKILL:
			return _generate_skill_offer(run_snapshot, context, seed, skill_catalog, first_combat_room)
		RewardType.RELIC:
			return _generate_relic_offer(run_snapshot, context, seed, relic_catalog)
		_:
			return RewardOffer.configuration_failure(context.room_id, context.reward_type, seed, &"unknown_reward_type")


static func has_legal_skill_candidate(
		run_snapshot: RunSnapshot,
		skill_catalog: Array[SkillRewardDefinition],
		initial_only: bool = false
) -> bool:
	if run_snapshot == null:
		return false
	for definition in skill_catalog:
		if (
			definition != null
			and definition.validation_error().is_empty()
			and (not initial_only or definition.initial_pool)
			and not run_snapshot.skills.owns(definition.skill_id)
			and definition.is_available_for(run_snapshot.unlocked_form_ids)
		):
			return true
	return false


static func has_legal_relic_candidate(
		run_snapshot: RunSnapshot,
		relic_catalog: Array[RelicDefinition]
) -> bool:
	if run_snapshot == null:
		return false
	for definition in relic_catalog:
		if definition != null and definition.is_valid() and not run_snapshot.relics.owns(definition.relic_id):
			return true
	return false


static func _generate_skill_offer(
		run_snapshot: RunSnapshot,
		context: RoomRewardContext,
		seed: int,
		skill_catalog: Array[SkillRewardDefinition],
		first_combat_room: bool
) -> RewardOffer:
	var candidates: Array[SkillRewardDefinition] = []
	for definition in skill_catalog:
		if first_combat_room and not definition.initial_pool:
			continue
		if run_snapshot.skills.owns(definition.skill_id):
			continue
		if not definition.is_available_for(run_snapshot.unlocked_form_ids):
			continue
		candidates.append(definition)
	if first_combat_room and candidates.size() < MAX_OPTIONS:
		return RewardOffer.configuration_failure(
			context.room_id,
			RewardType.SKILL,
			seed,
			&"insufficient_initial_skill_candidates"
		)
	if candidates.is_empty():
		return RewardOffer.configuration_failure(
			context.room_id,
			RewardType.SKILL,
			seed,
			&"no_legal_skill_candidates"
		)
	candidates.sort_custom(_skill_before)
	_shuffle(candidates, seed)
	var option_count := mini(MAX_OPTIONS, candidates.size())
	var options: Array[RewardOption] = []
	for index in option_count:
		var definition := candidates[index]
		options.append(RewardOption.new(
			_option_id(RewardType.SKILL, definition.skill_id),
			RewardType.SKILL,
			definition.skill_id,
			definition.display_name,
			definition.description
		))
	return _valid_offer(context, seed, options)


static func _generate_relic_offer(
		run_snapshot: RunSnapshot,
		context: RoomRewardContext,
		seed: int,
		relic_catalog: Array[RelicDefinition]
) -> RewardOffer:
	var candidates: Array[RelicDefinition] = []
	for definition in relic_catalog:
		if not run_snapshot.relics.owns(definition.relic_id):
			candidates.append(definition)
	if candidates.is_empty():
		return RewardOffer.configuration_failure(
			context.room_id,
			RewardType.RELIC,
			seed,
			&"no_legal_relic_candidates"
		)
	candidates.sort_custom(_relic_before)
	_shuffle(candidates, seed)
	var options: Array[RewardOption] = []
	for index in mini(MAX_OPTIONS, candidates.size()):
		var definition := candidates[index]
		options.append(RewardOption.new(
			_option_id(RewardType.RELIC, definition.relic_id),
			RewardType.RELIC,
			definition.relic_id,
			definition.display_name,
			definition.description
		))
	return _valid_offer(context, seed, options)


static func _route_authority_error(route: RouteSnapshot, context: RoomRewardContext) -> StringName:
	if route == null:
		return &"missing_route_snapshot"
	# Detached snapshots are supported for pure candidate tests. Every real
	# RunSession request reaches the generator in REWARD and is checked below.
	if route.phase != RunPhase.REWARD:
		return &""
	if route.completed_combat_rooms <= 0:
		return &"invalid_reward_progress"
	if route.current_room_id != context.room_id:
		return &"reward_room_mismatch"
	var expected_type := RewardType.SKILL if route.completed_combat_rooms == 1 else route.selected_reward_type
	if not RewardType.is_valid(expected_type):
		return &"missing_route_reward_type"
	if context.reward_type != expected_type:
		return &"reward_type_route_mismatch"
	return &""


static func _is_first_combat_reward(route: RouteSnapshot) -> bool:
	if route == null:
		return false
	if route.phase == RunPhase.REWARD:
		return route.completed_combat_rooms == 1
	# Compatibility for detached pure-service tests only. No caller-provided
	# boolean is consulted.
	return route.completed_combat_rooms <= 1


static func _valid_offer(context: RoomRewardContext, seed: int, options: Array[RewardOption]) -> RewardOffer:
	var id_parts := PackedStringArray()
	for option in options:
		id_parts.append(String(option.content_id))
	var offer_id := StringName("offer:%s:%s:%d:%s" % [
		String(context.room_id),
		String(RewardType.name_of(context.reward_type)),
		seed,
		",".join(id_parts),
	])
	return RewardOffer.new(offer_id, context.room_id, context.reward_type, seed, options)


static func _option_id(type: int, content_id: StringName) -> StringName:
	return StringName("%s:%s" % [String(RewardType.name_of(type)), String(content_id)])


static func _shuffle(items: Array, seed: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	for index in range(items.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var temporary = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temporary


static func _validate_catalogs(
		skill_catalog: Array[SkillRewardDefinition],
		relic_catalog: Array[RelicDefinition]
) -> StringName:
	var skill_ids: Array[StringName] = []
	for definition in skill_catalog:
		if definition == null or not definition.validation_error().is_empty():
			return &"invalid_skill_reward_definition"
		if skill_ids.has(definition.skill_id):
			return &"duplicate_skill_reward_definition"
		skill_ids.append(definition.skill_id)
	var relic_ids: Array[StringName] = []
	for definition in relic_catalog:
		if definition == null or not definition.is_valid():
			return &"invalid_relic_definition"
		if relic_ids.has(definition.relic_id):
			return &"duplicate_relic_definition"
		relic_ids.append(definition.relic_id)
	return &""


static func _skill_before(left: SkillRewardDefinition, right: SkillRewardDefinition) -> bool:
	return String(left.skill_id) < String(right.skill_id)


static func _relic_before(left: RelicDefinition, right: RelicDefinition) -> bool:
	return String(left.relic_id) < String(right.relic_id)
