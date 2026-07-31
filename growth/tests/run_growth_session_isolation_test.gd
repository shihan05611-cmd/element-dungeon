extends SceneTree

## Verifies the task-level requirement using two full RunSession aggregates.

class RecordingPort:
	extends GrowthEffectPort

	var restored: int = 0

	func restore_energy(amount: int, _source_relic_id: StringName, _event_id: StringName) -> bool:
		restored += amount
		return true


func _initialize() -> void:
	var skills: Array[SkillRewardDefinition] = []
	for index in 4:
		var skill := SkillRewardDefinition.new()
		skill.skill_id = StringName("shared_skill_%d" % index)
		skill.display_name = "Shared Skill %d" % index
		skill.initial_pool = true
		skill.allowed_form_ids = [&"water"]
		skills.append(skill)

	var relic := RelicDefinition.new()
	relic.relic_id = &"shared_relic"
	relic.display_name = "Shared Relic"
	relic.effect_kind = RelicDefinition.EffectKind.FORM_SWITCH_ENERGY_RESTORE
	relic.amount = 3
	relic.internal_cooldown_seconds = 5.0
	var relics: Array[RelicDefinition] = [relic]
	var forms: Array[StringName] = [&"water"]
	var first_port := RecordingPort.new()
	var second_port := RecordingPort.new()
	var first := RunSession.new(skills, relics, [], forms, null, first_port)
	var second := RunSession.new(skills, relics, [], forms, null, second_port)

	if not _acquire_shared_relic(first, &"first") or not _acquire_shared_relic(second, &"second"):
		printerr("GROWTH SESSION ISOLATION TEST FAILED: setup could not acquire shared relic")
		quit(1)
		return

	first.choose_route(RunDirector.SKILL_ROUTE_ID)
	second.choose_route(RunDirector.SKILL_ROUTE_ID)
	first.begin_combat_room(&"first_room_3")
	second.begin_combat_room(&"second_room_3")
	first.handle_event(FormChangedEvent.new(&"first_switch", &"first_room_3", &"water", &"fire", FormChangedEvent.Source.MANUAL, 1, 1000))

	var first_state := first.snapshot().relics.display_state_for(&"shared_relic")
	var second_state := second.snapshot().relics.display_state_for(&"shared_relic")
	var passed := (
		first_port.restored == 3
		and second_port.restored == 0
		and is_equal_approx(first_state.cooldown_remaining, 5.0)
		and is_equal_approx(second_state.cooldown_remaining, 0.0)
		and is_equal_approx(relic.internal_cooldown_seconds, 5.0)
	)
	if passed:
		print("GROWTH SESSION ISOLATION TEST PASSED: 1 test, 5 assertions")
		quit(0)
	else:
		printerr("GROWTH SESSION ISOLATION TEST FAILED: shared static Resource leaked runtime state")
		quit(1)


func _acquire_shared_relic(session: RunSession, prefix: StringName) -> bool:
	var first_room_id := StringName("%s_room_1" % String(prefix))
	if not session.begin_combat_room(first_room_id).accepted:
		return false
	if not session.handle_event(RoomCompletedEvent.new(
		StringName("%s_done_1" % String(prefix)),
		first_room_id,
		0
	)).accepted:
		return false
	var skill_offer := session.generate_reward(RoomRewardContext.new(first_room_id, RewardType.SKILL), 76)
	if not skill_offer.accepted:
		return false
	var skill_option := skill_offer.reward_offer.options[0]
	if not session.claim_reward(skill_offer.reward_offer.offer_id, skill_option.option_id).accepted:
		return false
	if not session.choose_route(RunDirector.RELIC_ROUTE_ID).accepted:
		return false

	var second_room_id := StringName("%s_room_2" % String(prefix))
	if not session.begin_combat_room(second_room_id).accepted:
		return false
	if not session.handle_event(RoomCompletedEvent.new(
		StringName("%s_done_2" % String(prefix)),
		second_room_id,
		0
	)).accepted:
		return false
	var relic_offer := session.generate_reward(RoomRewardContext.new(second_room_id, RewardType.RELIC), 77)
	if not relic_offer.accepted:
		return false
	var relic_option := relic_offer.reward_offer.options[0]
	return session.claim_reward(relic_offer.reward_offer.offer_id, relic_option.option_id).accepted

