class_name RelicDefinition
extends Resource

## Static relic display/configuration. Per-run cooldowns and counters are held
## exclusively by RelicRuntimeState.

enum EffectKind {
	FORM_SWITCH_ENERGY_RESTORE,
	REACTION_ENERGY_RESTORE,
	ROOM_COMPLETE_HEAL,
	REACTION_TEMPORARY_ATTACK,
	ACQUIRE_MAXIMUM_HEALTH,
	ACQUIRE_MAXIMUM_ENERGY,
}

@export var relic_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect_kind: EffectKind = EffectKind.FORM_SWITCH_ENERGY_RESTORE
@export_range(0, 1000000, 1, "or_greater") var amount: int = 0
@export_range(0, 10, 1, "or_greater") var reaction_threshold: int = 0
@export_range(1.0, 100.0, 0.01, "or_greater") var attack_multiplier: float = 1.0
@export_range(0.0, 3600.0, 0.01, "or_greater") var duration_seconds: float = 0.0
@export_range(0.0, 3600.0, 0.01, "or_greater") var internal_cooldown_seconds: float = 0.0
@export_range(0, 1000000, 1, "or_greater") var per_room_limit: int = 0


func validation_error() -> StringName:
	if relic_id.is_empty():
		return &"missing_relic_id"
	if not is_finite(internal_cooldown_seconds) or internal_cooldown_seconds < 0.0:
		return &"invalid_internal_cooldown"
	if per_room_limit < 0:
		return &"invalid_per_room_limit"
	match effect_kind:
		EffectKind.FORM_SWITCH_ENERGY_RESTORE, EffectKind.ROOM_COMPLETE_HEAL:
			if amount <= 0:
				return &"invalid_effect_amount"
		EffectKind.REACTION_ENERGY_RESTORE:
			if amount <= 0 or reaction_threshold <= 0:
				return &"invalid_reaction_energy_configuration"
		EffectKind.REACTION_TEMPORARY_ATTACK:
			if (
				reaction_threshold <= 0
				or not is_finite(attack_multiplier)
				or attack_multiplier <= 1.0
				or not is_finite(duration_seconds)
				or duration_seconds <= 0.0
			):
				return &"invalid_temporary_attack_configuration"
		EffectKind.ACQUIRE_MAXIMUM_HEALTH, EffectKind.ACQUIRE_MAXIMUM_ENERGY:
			if amount <= 0:
				return &"invalid_maximum_stat_amount"
		_:
			return &"unknown_effect_kind"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()
