class_name AcquireMaximumStatEffect
extends RelicEffect


func try_apply(definition: RelicDefinition, event: RunEvent, port: GrowthEffectPort) -> bool:
	if not event is RelicAcquiredEvent or port == null:
		return false
	var acquired_event := event as RelicAcquiredEvent
	if acquired_event.relic_id != definition.relic_id:
		return false
	match definition.effect_kind:
		RelicDefinition.EffectKind.ACQUIRE_MAXIMUM_HEALTH:
			return port.increase_maximum_health(definition.amount, definition.relic_id)
		RelicDefinition.EffectKind.ACQUIRE_MAXIMUM_ENERGY:
			return port.increase_maximum_energy(definition.amount, definition.relic_id)
		_:
			return false
