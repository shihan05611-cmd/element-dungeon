class_name RelicEffect
extends RefCounted

## Small strategy interface; deliberately not a general-purpose rule DSL.

func try_apply(
		_definition: RelicDefinition,
		_event: RunEvent,
		_port: GrowthEffectPort
) -> bool:
	return false
