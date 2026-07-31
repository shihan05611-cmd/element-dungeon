class_name PlayerGrowthAdapter
extends GrowthEffectPort

signal stats_applied(maximum_health: int, maximum_energy: int, attack_multiplier: float)

var temporary_modifier_count: int:
	get:
		return _temporary_attack_modifiers.size()

var _player: PlayerCharacter
var _base_maximum_health: int = 100
var _base_maximum_energy: int = 100
var _base_attack_multiplier: float = 1.0
var _progression_attack_multiplier: float = 1.0
var _progression_health_bonus: int = 0
var _progression_energy_bonus: int = 0
var _passive_attack_multiplier: float = 1.0
var _passive_health_bonus: int = 0
var _passive_energy_bonus: int = 0
var _permanent_health_bonus: int = 0
var _permanent_energy_bonus: int = 0
var _permanent_health_sources: Dictionary[StringName, bool] = {}
var _permanent_energy_sources: Dictionary[StringName, bool] = {}
var _temporary_attack_modifiers: Dictionary[StringName, Dictionary] = {}


func _init(player: PlayerCharacter = null) -> void:
	if player != null:
		configure(player)


func configure(player: PlayerCharacter) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _player != null and _player != player:
		return false
	_player = player
	_base_maximum_health = player.damage_receiver.maximum_health
	_base_maximum_energy = player.energy_component.maximum
	_base_attack_multiplier = player.attack_multiplier
	_recompute_stats()
	return true


func apply_progression(snapshot: ProgressionSnapshot) -> bool:
	if snapshot == null or snapshot.allocated_stats == null:
		return false
	_progression_attack_multiplier = snapshot.allocated_stats.attack_multiplier
	_progression_health_bonus = snapshot.allocated_stats.maximum_health_bonus
	_progression_energy_bonus = snapshot.allocated_stats.maximum_energy_bonus
	_recompute_stats()
	return true


func set_passive_modifiers(
		health_bonus: int,
		energy_bonus: int,
		attack_multiplier_value: float
) -> bool:
	if (
		health_bonus < 0
		or energy_bonus < 0
		or not is_finite(attack_multiplier_value)
		or attack_multiplier_value < 1.0
	):
		return false
	_passive_health_bonus = health_bonus
	_passive_energy_bonus = energy_bonus
	_passive_attack_multiplier = attack_multiplier_value
	_recompute_stats()
	return true


func restore_energy(amount: int, _source_relic_id: StringName, _event_id: StringName) -> bool:
	return _player != null and amount >= 0 and _player.energy_component.restore(amount)


func restore_health(amount: int, _source_relic_id: StringName, _event_id: StringName) -> bool:
	if _player == null or amount < 0:
		return false
	var receiver := _player.damage_receiver
	var previous := receiver.current_health
	var next_health := mini(receiver.maximum_health, previous + amount)
	if not receiver.replace_health_silent(next_health):
		return false
	receiver.notify_health_changed(next_health - previous)
	return true


func apply_temporary_attack_multiplier(
		multiplier: float,
		duration_seconds: float,
		source_relic_id: StringName,
		event_id: StringName
) -> bool:
	var effect_key := StringName("%d:%s:%s" % [
		String(source_relic_id).length(),
		String(source_relic_id),
		String(event_id),
	])
	if (
		_player == null
		or source_relic_id.is_empty()
		or event_id.is_empty()
		or _temporary_attack_modifiers.has(effect_key)
		or not is_finite(multiplier)
		or multiplier <= 1.0
		or not is_finite(duration_seconds)
		or duration_seconds <= 0.0
	):
		return false
	_temporary_attack_modifiers[effect_key] = {
		"multiplier": multiplier,
		"remaining": duration_seconds,
	}
	_recompute_stats()
	return true


func increase_maximum_health(amount: int, source_relic_id: StringName) -> bool:
	if _player == null or amount <= 0 or source_relic_id.is_empty():
		return false
	if _permanent_health_sources.has(source_relic_id):
		return false
	_permanent_health_sources[source_relic_id] = true
	_permanent_health_bonus += amount
	_recompute_stats()
	return true


func increase_maximum_energy(amount: int, source_relic_id: StringName) -> bool:
	if _player == null or amount <= 0 or source_relic_id.is_empty():
		return false
	if _permanent_energy_sources.has(source_relic_id):
		return false
	_permanent_energy_sources[source_relic_id] = true
	_permanent_energy_bonus += amount
	_recompute_stats()
	return true


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0 or _temporary_attack_modifiers.is_empty():
		return false
	var changed := false
	for event_id: StringName in _temporary_attack_modifiers.keys():
		var state: Dictionary = _temporary_attack_modifiers[event_id]
		var remaining := maxf(0.0, float(state.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			_temporary_attack_modifiers.erase(event_id)
		else:
			state["remaining"] = remaining
			_temporary_attack_modifiers[event_id] = state
		changed = true
	if changed:
		_recompute_stats()
	return changed


func clear_temporary_modifiers() -> void:
	if _temporary_attack_modifiers.is_empty():
		return
	_temporary_attack_modifiers.clear()
	_recompute_stats()


func _recompute_stats() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var maximum_health := (
		_base_maximum_health
		+ _progression_health_bonus
		+ _passive_health_bonus
		+ _permanent_health_bonus
	)
	var maximum_energy := (
		_base_maximum_energy
		+ _progression_energy_bonus
		+ _passive_energy_bonus
		+ _permanent_energy_bonus
	)
	_apply_maximum_health(maximum_health)
	_apply_maximum_energy(maximum_energy)
	_player.attack_multiplier = (
		_base_attack_multiplier
		* _progression_attack_multiplier
		* _passive_attack_multiplier
		* _temporary_attack_product()
	)
	stats_applied.emit(maximum_health, maximum_energy, _player.attack_multiplier)


func _apply_maximum_health(maximum_health: int) -> void:
	var receiver := _player.damage_receiver
	var previous_maximum := receiver.maximum_health
	if previous_maximum == maximum_health:
		return
	var previous_health := receiver.current_health
	var missing_health := previous_maximum - previous_health
	var next_health := clampi(maximum_health - missing_health, 0, maximum_health)
	if receiver.configure_runtime(maximum_health, next_health, receiver.defense_flat):
		receiver.notify_health_changed(next_health - previous_health)


func _apply_maximum_energy(maximum_energy: int) -> void:
	var energy := _player.energy_component
	if energy.maximum == maximum_energy:
		return
	var missing_energy := energy.maximum - energy.current_energy
	var next_energy := clampi(maximum_energy - missing_energy, 0, maximum_energy)
	energy.configure_runtime(maximum_energy, next_energy)


func _temporary_attack_product() -> float:
	var result := 1.0
	for state_variant: Variant in _temporary_attack_modifiers.values():
		var state := state_variant as Dictionary
		result *= float(state.get("multiplier", 1.0))
	return result
