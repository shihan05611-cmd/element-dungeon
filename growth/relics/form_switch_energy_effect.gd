class_name FormSwitchEnergyEffect
extends RelicEffect


func try_apply(definition: RelicDefinition, event: RunEvent, port: GrowthEffectPort) -> bool:
	if not event is FormChangedEvent or port == null:
		return false
	var form_event := event as FormChangedEvent
	if definition is FormChangeRelicDefinition:
		var filtered_definition := definition as FormChangeRelicDefinition
		if not FormChangeResponsePolicy.matches(filtered_definition.response_policy, form_event.source):
			return false
	return port.restore_energy(definition.amount, definition.relic_id, event.event_id)
