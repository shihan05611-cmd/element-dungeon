class_name ReactionTemporaryAttackEffect
extends RelicEffect


func try_apply(definition: RelicDefinition, event: RunEvent, port: GrowthEffectPort) -> bool:
	if not event is CombatCommittedEvent or port == null:
		return false
	var combat_event := event as CombatCommittedEvent
	if combat_event.reaction_consumed < definition.reaction_threshold:
		return false
	return port.apply_temporary_attack_multiplier(
		definition.attack_multiplier,
		definition.duration_seconds,
		definition.relic_id,
		event.event_id
	)
