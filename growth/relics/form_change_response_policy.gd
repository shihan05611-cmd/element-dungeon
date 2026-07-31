class_name FormChangeResponsePolicy
extends RefCounted

enum Value {
	ALL,
	MANUAL_ONLY,
	SKILL_AUTO_ONLY,
}


static func is_valid(policy: int) -> bool:
	return policy >= Value.ALL and policy <= Value.SKILL_AUTO_ONLY


static func matches(policy: int, source: FormChangedEvent.Source) -> bool:
	match policy:
		Value.ALL:
			return true
		Value.MANUAL_ONLY:
			return source == FormChangedEvent.Source.MANUAL
		Value.SKILL_AUTO_ONLY:
			return source == FormChangedEvent.Source.SKILL_AUTO
		_:
			return false
