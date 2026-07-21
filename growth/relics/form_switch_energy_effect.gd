class_name FormSwitchEnergyEffect
extends RelicEffect


func try_apply(definition: RelicDefinition, event: RunEvent, port: GrowthEffectPort) -> bool:
	if not event is FormChangedEvent or port == null:
		return false
	return port.restore_energy(definition.amount, definition.relic_id, event.event_id)
