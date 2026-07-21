class_name RunPhase
extends RefCounted

## Frozen run-state identifiers shared by the growth core and integration UI.

enum {
	COMBAT,
	REWARD,
	ROUTE_CHOICE,
	SHOP,
	RUN_COMPLETE,
}


static func is_valid(value: int) -> bool:
	return value >= COMBAT and value <= RUN_COMPLETE


static func name_of(value: int) -> StringName:
	match value:
		COMBAT:
			return &"combat"
		REWARD:
			return &"reward"
		ROUTE_CHOICE:
			return &"route_choice"
		SHOP:
			return &"shop"
		RUN_COMPLETE:
			return &"run_complete"
		_:
			return &"unknown"
