class_name DamageResolver
extends RefCounted

## Minimal pure mitigation model for the MVP:
## offensive * reaction multiplier -> subtract current flat defense -> clamp ->
## round exactly once before health application.


static func resolve(
		offensive_damage: float,
		reaction_multiplier: float,
		defense_flat: float
) -> DamageResolution:
	if not is_finite(offensive_damage) or offensive_damage < 0.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_offensive_damage")
	if not is_finite(reaction_multiplier) or reaction_multiplier < 1.0 or reaction_multiplier > 4.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_reaction_multiplier")
	if not is_finite(defense_flat) or defense_flat < 0.0:
		return DamageResolution.new(0.0, 1.0, 0.0, 0.0, 0.0, 0, &"invalid_defense")

	var reacted_damage := offensive_damage * reaction_multiplier
	var mitigated_damage := maxf(0.0, reacted_damage - defense_flat)
	var final_damage := roundi(maxf(0.0, mitigated_damage))
	return DamageResolution.new(
		offensive_damage,
		reaction_multiplier,
		reacted_damage,
		defense_flat,
		mitigated_damage,
		final_damage
	)
