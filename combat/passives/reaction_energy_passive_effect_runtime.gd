class_name ReactionEnergyPassiveEffectRuntime
extends PassiveEffectRuntime

var _last_event_id: StringName = &""


func on_combat_result(
		result: CombatResult,
		target_id: StringName,
		target_is_player: bool,
		owner_root_id: int
) -> bool:
	if (
		result == null
		or not result.accepted
		or not result.reaction_triggered
		or target_is_player
		or target_id.is_empty()
		or owner_root_id <= 0
		or result.root_owner_id != owner_root_id
		or not is_valid()
	):
		return false
	var reaction_energy := _definition as ReactionEnergyPassiveEffectDefinition
	if reaction_energy == null or _context == null or _context.owner_port == null:
		return false
	var event_id := StringName("reaction_energy:%d:%d:%d:%s" % [
		result.cast_id,
		result.delivery_id,
		result.hit_index,
		String(target_id),
	])
	if event_id == _last_event_id:
		return false
	var restored := _context.owner_port.restore_energy(
		reaction_energy.energy_restore,
		_skill_id,
		event_id
	)
	if restored:
		_last_event_id = event_id
	return restored
