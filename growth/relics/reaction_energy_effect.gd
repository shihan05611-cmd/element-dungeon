class_name ReactionEnergyEffect
extends RelicEffect


func try_apply(definition: RelicDefinition, event: RunEvent, port: GrowthEffectPort) -> bool:
	if not event is CombatCommittedEvent or port == null:
		return false
	var combat_event := event as CombatCommittedEvent
	if combat_event.reaction_consumed < definition.reaction_threshold:
		return false
	return port.restore_energy(definition.amount, definition.relic_id, event.event_id)
