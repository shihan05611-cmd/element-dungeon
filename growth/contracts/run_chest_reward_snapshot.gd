class_name RunChestRewardSnapshot
extends RefCounted

enum Kind {
	SKILL,
	DREAM_DUST,
}

const DREAM_DUST_AMOUNT: int = 150

var kind: Kind:
	get:
		return _kind
var room_id: StringName:
	get:
		return _room_id
var skill_id: StringName:
	get:
		return _skill_id
var dream_dust: int:
	get:
		return _dream_dust

var _kind: Kind
var _room_id: StringName
var _skill_id: StringName
var _dream_dust: int


func _init(
		p_kind: Kind,
		p_room_id: StringName,
		p_skill_id: StringName = &"",
		p_dream_dust: int = 0
) -> void:
	_kind = p_kind
	_room_id = p_room_id
	_skill_id = p_skill_id
	_dream_dust = p_dream_dust


func is_valid() -> bool:
	if _room_id.is_empty():
		return false
	if _kind == Kind.SKILL:
		return not _skill_id.is_empty() and _dream_dust == 0
	if _kind == Kind.DREAM_DUST:
		return _skill_id.is_empty() and _dream_dust == DREAM_DUST_AMOUNT
	return false


static func skill(p_room_id: StringName, p_skill_id: StringName) -> RunChestRewardSnapshot:
	return RunChestRewardSnapshot.new(Kind.SKILL, p_room_id, p_skill_id)


static func dust(p_room_id: StringName) -> RunChestRewardSnapshot:
	return RunChestRewardSnapshot.new(Kind.DREAM_DUST, p_room_id, &"", DREAM_DUST_AMOUNT)
