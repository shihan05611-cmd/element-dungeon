class_name RoomCompleteHealEffect
extends RelicEffect


func try_apply(definition: RelicDefinition, event: RunEvent, port: GrowthEffectPort) -> bool:
	if not event is RoomCompletedEvent or port == null:
		return false
	return port.restore_health(definition.amount, definition.relic_id, event.event_id)
