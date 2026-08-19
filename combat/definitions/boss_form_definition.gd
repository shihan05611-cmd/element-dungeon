class_name BossFormDefinition
extends Resource

## Data-only description of one Tide-Ember Sovereign Boss form (Task 61
## §3.1/§3.7). The counter relationship is a data table read by
## BossTideEmber, never a hardcoded match on element_id.

@export var form_id: StringName = &""
@export var display_name: String = ""
@export var element_id: StringName = ElementIds.NONE

## Element that must land counter_hit_threshold (BossTuning) successful hits
## to switch this form away. Ignored when counts_any_combat_element is true.
@export var countered_by: StringName = ElementIds.NONE
## True only for the NONE (neutral) form: any combat element (water or fire)
## counts toward the switch-out threshold (Task 61 §3.1 "普通形态出口").
@export var counts_any_combat_element: bool = false

@export var ranged_projectile_profile: EnemyProjectileProfile
@export_range(0.0, 5.0, 0.001, "or_greater") var melee_telegraph_duration: float = 0.4
@export_range(0.0, 1000000.0, 0.001, "or_greater") var melee_damage: float = 14.0
@export_range(1.0, 1000000.0, 0.001, "or_greater") var melee_range: float = 84.0
@export_range(0.001, 60.0, 0.001, "or_greater") var attack_cooldown: float = 2.4

## Optional summon move (potentially recruits TidalSentry for the water
## form). summon_max_alive == 0 disables summoning for this form.
@export var summon_scene: PackedScene
@export_range(0, 8, 1) var summon_max_alive: int = 0
@export_range(1, 8, 1) var summon_count_per_cast: int = 1
@export_range(0.001, 120.0, 0.001, "or_greater") var summon_cooldown: float = 12.0


func validation_error() -> StringName:
	if form_id.is_empty():
		return &"missing_form_id"
	if not ElementIds.is_valid_payload_element(element_id):
		return &"invalid_element_id"
	if counts_any_combat_element:
		if countered_by != ElementIds.NONE:
			return &"any_form_must_not_set_countered_by"
	else:
		if not ElementIds.is_combat_element(countered_by):
			return &"invalid_countered_by"
	if ranged_projectile_profile != null and not ranged_projectile_profile.validation_error().is_empty():
		return &"invalid_ranged_projectile_profile"
	if not is_finite(melee_telegraph_duration) or melee_telegraph_duration < 0.0:
		return &"invalid_melee_telegraph_duration"
	if not is_finite(melee_damage) or melee_damage < 0.0:
		return &"invalid_melee_damage"
	if not is_finite(melee_range) or melee_range <= 0.0:
		return &"invalid_melee_range"
	if not is_finite(attack_cooldown) or attack_cooldown <= 0.0:
		return &"invalid_attack_cooldown"
	if summon_max_alive > 0 and summon_scene == null:
		return &"missing_summon_scene"
	if not is_finite(summon_cooldown) or summon_cooldown <= 0.0:
		return &"invalid_summon_cooldown"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


## Whether incoming_element counts toward this form's switch-out counter.
## Pure data lookup -- callers must never re-implement this as a match.
func counters(incoming_element: StringName) -> bool:
	if counts_any_combat_element:
		return ElementIds.is_combat_element(incoming_element)
	return incoming_element == countered_by
