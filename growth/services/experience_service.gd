class_name ExperienceService
extends RefCounted

## Deterministic first-version curve: 100 XP at level 1, +50 per level.

const BASE_REQUIREMENT: int = 100
const REQUIREMENT_STEP: int = 50


static func requirement_for_level(level: int) -> int:
	return BASE_REQUIREMENT + maxi(0, level - 1) * REQUIREMENT_STEP


static func plan_gain(current: ProgressionSnapshot, amount: int) -> ExperienceGainPlan:
	if current == null:
		return ExperienceGainPlan.rejected(&"missing_progression_snapshot", 1, 0)
	if amount < 0:
		return ExperienceGainPlan.rejected(&"negative_experience", current.level, current.experience)
	var next_level := current.level
	var remaining := current.experience + amount
	while remaining >= requirement_for_level(next_level):
		remaining -= requirement_for_level(next_level)
		next_level += 1
	return ExperienceGainPlan.new(true, &"", current.level, next_level, remaining)
