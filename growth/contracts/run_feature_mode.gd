class_name RunFeatureMode
extends RefCounted

## Frozen per-run feature policy. Modes are deliberately values rather than
## mutable toggles so a session cannot change product rules halfway through.

enum Value {
	DISABLED,
	OBSERVE_ONLY,
	ENABLED,
}


static func is_valid(value: int) -> bool:
	return value in [Value.DISABLED, Value.OBSERVE_ONLY, Value.ENABLED]


static func is_effect_enabled(value: int) -> bool:
	return value == Value.ENABLED


static func is_observation_enabled(value: int) -> bool:
	return value == Value.OBSERVE_ONLY
