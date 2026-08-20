class_name BossTuning
extends Resource

## Global (form-independent) tunables for the Tide-Ember Sovereign Boss
## (Task 61 §3.1/§3.3/§3.8). Kept in one Resource, separate from the
## per-form BossFormDefinition list, so every cross-form numeric knob the
## task book requires to be "配置化到 Resource" can be balanced without
## touching code.

## Successful counter-element hits required to switch form (§3.1/§3.2).
@export_range(1, 999, 1) var counter_hit_threshold: int = 15
## Element layers granted immediately on a form switch (§3.3).
@export_range(0, 10, 1) var attach_layers_on_switch: int = 5
## Passive regeneration tick: +1 layer every this many seconds, independent
## of whether layers are being consumed by reactions (§3.3, "常驻回补").
@export_range(0.001, 3600.0, 0.001, "or_greater") var attach_layer_regen_interval: float = 3.0
## Must mirror ElementCarrier.per_element_capacity on the Boss scene.
@export_range(1, 10, 1) var attach_layer_cap: int = 10
## Number of water<->fire alternations allowed before the next switch is
## forced to the neutral (NONE) form instead (§3.1).
@export_range(1, 99, 1) var alternation_switch_cap: int = 2
## Fixed same-element mitigation factor consumed by damage_resolver.gd via
## ElementCarrier node metadata (Task 61 §3.6); NOT layer-dependent.
@export_range(0.001, 1.0, 0.001) var same_element_mitigation_factor: float = 0.25
## invulnerable duration during the form-switch presentation beat (§3.7).
@export_range(0.0, 5.0, 0.001, "or_greater") var form_transition_invulnerable_duration: float = 0.6
## Poise: number of hits absorbed before a long stagger opens (§3.8).
@export_range(1, 999999, 1) var poise_hit_threshold: int = 6
## Length of the stagger window once poise breaks (§3.8, "1.5~2.0s").
@export_range(0.1, 30.0, 0.001, "or_greater") var poise_break_stun_duration: float = 1.75
## Task 69 §2.2: 0-based index of the impact frame inside the Boss's attack
## animation, as declared by the Task 68 v2 sheet manifest
## (assets/world/enemies/tide_ember_sovereign/manifest_v2.md §2: frames 0..3
## are the windup, frame 4 is the impact, frames 5..7 the recovery). Global
## rather than per-form because all three forms share one attack sheet
## timing -- form differences ride on melee_damage / melee_range /
## attack_cooldown instead. BossTideEmber reads the windup and recovery
## segment lengths straight off the SpriteFrames using this index, so the
## number never appears as a literal in code.
@export_range(0, 63, 1) var melee_attack_impact_frame_index: int = 4
## Task 71 §2 C1: 0-based index of the launch frame inside the Boss's ranged
## cast animation, as declared by the Task 70 manifest
## (assets/world/enemies/tide_ember_sovereign/manifest_v2.md §9.5: frames 0..4
## are the windup, frame 5 is the launch, frames 6..7 the recovery). Global
## for the same reason melee_attack_impact_frame_index is: the three forms
## share one cast sheet timing, and the manifest proves the effect-pixel
## rhythm is identical across plain/ember/tide. BossTideEmber derives the
## windup and recovery segment lengths from the SpriteFrames using this
## index, so the number never appears as a literal in code.
@export_range(0, 63, 1) var ranged_cast_launch_frame_index: int = 5


func validation_error() -> StringName:
	if counter_hit_threshold <= 0:
		return &"invalid_counter_hit_threshold"
	if attach_layers_on_switch < 0 or attach_layers_on_switch > attach_layer_cap:
		return &"invalid_attach_layers_on_switch"
	if not is_finite(attach_layer_regen_interval) or attach_layer_regen_interval <= 0.0:
		return &"invalid_attach_layer_regen_interval"
	if attach_layer_cap <= 0:
		return &"invalid_attach_layer_cap"
	if alternation_switch_cap <= 0:
		return &"invalid_alternation_switch_cap"
	if not is_finite(same_element_mitigation_factor) or same_element_mitigation_factor <= 0.0 or same_element_mitigation_factor > 1.0:
		return &"invalid_same_element_mitigation_factor"
	if not is_finite(form_transition_invulnerable_duration) or form_transition_invulnerable_duration < 0.0:
		return &"invalid_form_transition_invulnerable_duration"
	if poise_hit_threshold <= 0:
		return &"invalid_poise_hit_threshold"
	if not is_finite(poise_break_stun_duration) or poise_break_stun_duration <= 0.0:
		return &"invalid_poise_break_stun_duration"
	if melee_attack_impact_frame_index < 0:
		return &"invalid_melee_attack_impact_frame_index"
	if ranged_cast_launch_frame_index < 0:
		return &"invalid_ranged_cast_launch_frame_index"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()
