class_name UnendingPassiveEffectRuntime
extends PassiveEffectRuntime

func on_basic_attack_committed(event: BasicAttackCommittedEvent) -> bool:
	if event == null or not event.is_valid() or not is_valid():
		return false
	var unending := _definition as UnendingPassiveEffectDefinition
	if unending == null or _context == null or _context.owner_port == null:
		return false
	var layers := event.target_elements.get_amount(unending.observed_element_id)
	if layers <= 0:
		return false
	return _context.owner_port.restore_health(
		layers * unending.health_per_layer,
		_skill_id,
		event.event_id
	)
