class_name SkillSlotIds
extends RefCounted

const ACTIVE_1: StringName = &"active_1"
const ACTIVE_2: StringName = &"active_2"
const ACTIVE_3: StringName = &"active_3"
const PASSIVE_1: StringName = &"passive_1"
const PASSIVE_2: StringName = &"passive_2"
const PASSIVE_3: StringName = &"passive_3"
const PASSIVE_4: StringName = &"passive_4"

const LEGACY_MELEE: StringName = &"melee"
const LEGACY_PRIMARY: StringName = &"primary"

enum SlotKind {
	UNKNOWN,
	ACTIVE,
	PASSIVE,
}


static func all() -> Array[StringName]:
	return [ACTIVE_1, ACTIVE_2, ACTIVE_3, PASSIVE_1, PASSIVE_2, PASSIVE_3, PASSIVE_4]


static func active() -> Array[StringName]:
	return [ACTIVE_1, ACTIVE_2, ACTIVE_3]


static func passive() -> Array[StringName]:
	return [PASSIVE_1, PASSIVE_2, PASSIVE_3, PASSIVE_4]


static func is_known(slot_id: StringName) -> bool:
	return all().has(slot_id)


static func is_active(slot_id: StringName) -> bool:
	return active().has(slot_id)


static func is_passive(slot_id: StringName) -> bool:
	return passive().has(slot_id)


static func kind_for(slot_id: StringName) -> SlotKind:
	if is_active(slot_id):
		return SlotKind.ACTIVE
	if is_passive(slot_id):
		return SlotKind.PASSIVE
	return SlotKind.UNKNOWN


static func canonicalize_input(slot_id: StringName) -> StringName:
	match slot_id:
		LEGACY_MELEE:
			return ACTIVE_1
		LEGACY_PRIMARY:
			return ACTIVE_2
		_:
			return slot_id
