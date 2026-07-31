class_name BurningPassiveEffectRuntime
extends PassiveEffectRuntime

const MAX_TICKS_PER_ADVANCE: int = 4096

var _accumulator: float = 0.0
var _tick_index: int = 0


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0 or not is_valid():
		return false
	var burning := _definition as BurningPassiveEffectDefinition
	if burning == null or _context == null:
		return false
	_accumulator += delta
	var triggered := false
	var ticks := 0
	while _accumulator + 0.000001 >= burning.tick_interval:
		_accumulator = maxf(0.0, _accumulator - burning.tick_interval)
		_tick_index += 1
		ticks += 1
		if ticks > MAX_TICKS_PER_ADVANCE:
			break
		triggered = _trigger_tick(burning) or triggered
	return triggered


func _trigger_tick(definition_value: BurningPassiveEffectDefinition) -> bool:
	var targets := _context.target_port.query_targets(definition_value.observed_element_id)
	targets.sort_custom(func(left: PassiveTargetSnapshot, right: PassiveTargetSnapshot) -> bool:
		return String(left.target_id) < String(right.target_id)
	)
	var stats: CombatStatSnapshot
	var submitted := false
	for target: PassiveTargetSnapshot in targets:
		if target == null or not target.is_valid():
			continue
		var layer_count := target.elements.get_amount(definition_value.observed_element_id)
		if layer_count <= 0:
			continue
		if stats == null:
			stats = _context.owner_port.capture_attack_stats()
			if stats == null or not stats.is_valid():
				return submitted
		var multiplier := float(layer_count) * definition_value.damage_multiplier_per_layer
		var payload := RuntimeAttackPayload.from_locked_stats(
			stats,
			multiplier,
			ElementIds.NONE,
			0,
			PackedStringArray(["burning", "passive"])
		)
		var event_id := StringName("%s:tick:%d:%s" % [
			String(_skill_id),
			_tick_index,
			String(target.target_id),
		])
		var request := PassiveDamageRequest.new(event_id, _skill_id, target, payload)
		if request.is_valid() and _context.target_port.submit_damage(request):
			submitted = true
	return submitted
