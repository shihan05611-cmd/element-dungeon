class_name DamageResolver
extends RefCounted

## Minimal pure mitigation model for the MVP:
## offensive * reaction multiplier -> subtract current flat defense -> apply
## element mitigation factor -> clamp -> round exactly once before health
## application.
##
## mitigation_factor (Task 61 §3.6) is a fixed, layer-count-independent
## multiplier applied strictly AFTER the flat-defense subtraction, on the
## unrounded intermediate value -- never before it and never on an
## already-rounded value. It defaults to 1.0 (no-op) for every caller that
## does not opt in (i.e. every non-Boss hit in the game is unaffected).


static func resolve(
		offensive_damage: float,
		reaction_multiplier: float,
		defense_flat: float,
		mitigation_factor: float = 1.0
) -> DamageResolution:
	if not is_finite(offensive_damage) or offensive_damage < 0.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_offensive_damage")
	if not is_finite(reaction_multiplier) or reaction_multiplier < 1.0 or reaction_multiplier > 4.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_reaction_multiplier")
	if not is_finite(defense_flat) or defense_flat < 0.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_defense")
	if not is_finite(mitigation_factor) or mitigation_factor <= 0.0 or mitigation_factor > 1.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_mitigation_factor")

	var reacted_damage := offensive_damage * reaction_multiplier
	var defended_damage := maxf(0.0, reacted_damage - defense_flat)
	var mitigated_damage := defended_damage * mitigation_factor
	var final_damage := roundi(maxf(0.0, mitigated_damage))
	return DamageResolution.new(
		offensive_damage,
		reaction_multiplier,
		reacted_damage,
		defense_flat,
		mitigated_damage,
		final_damage,
		&"",
		mitigation_factor
	)
