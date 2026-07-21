class_name EnemyKilledEvent
extends RunEvent

var enemy_id: StringName:
	get:
		return _enemy_id

var experience_reward: int:
	get:
		return _experience_reward

var _enemy_id: StringName
var _experience_reward: int


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_enemy_id: StringName,
		p_experience_reward: int
) -> void:
	super(p_event_id, Kind.ENEMY_KILLED, p_room_id)
	_enemy_id = p_enemy_id
	_experience_reward = p_experience_reward


func is_valid() -> bool:
	return super() and not _enemy_id.is_empty() and _experience_reward >= 0
