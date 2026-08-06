class_name RunPhase
extends RefCounted

## Frozen run-state identifiers shared by the growth core and integration UI.

enum {
	COMBAT,
	REWARD,
	ROUTE_CHOICE,
	SHOP,
	RUN_COMPLETE,
	ENTRY,
	ROOM_LOADING,
	ROOM_RESOLUTION,
	RUN_FAILED,
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
		ENTRY:
			return &"entry"
		ROOM_LOADING:
			return &"room_loading"
		ROOM_RESOLUTION:
			return &"room_resolution"
		RUN_FAILED:
			return &"run_failed"
		_:
			return &"unknown"
