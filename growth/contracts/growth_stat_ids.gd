class_name GrowthStatIds
extends RefCounted

const ATTACK: StringName = &"attack"
const VITALITY: StringName = &"vitality"
const ENERGY: StringName = &"energy"


static func is_valid(stat_id: StringName) -> bool:
	return stat_id == ATTACK or stat_id == VITALITY or stat_id == ENERGY
