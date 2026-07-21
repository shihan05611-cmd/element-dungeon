class_name RewardType
extends RefCounted

## Reward categories supported by the first growth prototype.

enum {
	SKILL,
	RELIC,
}


static func is_valid(value: int) -> bool:
	return value == SKILL or value == RELIC


static func name_of(value: int) -> StringName:
	match value:
		SKILL:
			return &"skill"
		RELIC:
			return &"relic"
		_:
			return &"unknown"
