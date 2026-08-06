class_name RunNodeKind
extends RefCounted

enum {
	ENTRY,
	COMBAT,
	SHOP,
	ROUTE,
	BOSS,
	RESULT,
}


static func is_valid(value: int) -> bool:
	return value >= ENTRY and value <= RESULT


static func is_combat(value: int) -> bool:
	return value == COMBAT or value == BOSS


static func name_of(value: int) -> StringName:
	match value:
		ENTRY:
			return &"entry"
		COMBAT:
			return &"combat"
		SHOP:
			return &"shop"
		ROUTE:
			return &"route"
		BOSS:
			return &"boss"
		RESULT:
			return &"result"
		_:
			return &"unknown"
