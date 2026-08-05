class_name EnemyKilledEvent
extends RunEvent

var enemy_id: StringName:
	get:
		return _enemy_id

var experience_reward: int:
	get:
		return _experience_reward

var dream_dust_reward: int:
	get:
		return _dream_dust_reward

var terminal_enemy: bool:
	get:
		return _terminal_enemy

var _enemy_id: StringName
var _experience_reward: int
var _dream_dust_reward: int
var _terminal_enemy: bool


func _init(
		p_event_id: StringName,
		p_room_id: StringName,
		p_enemy_id: StringName,
		p_experience_reward: int,
		p_dream_dust_reward: int = 0,
		p_terminal_enemy: bool = false
) -> void:
	super(p_event_id, Kind.ENEMY_KILLED, p_room_id)
	_enemy_id = p_enemy_id
	_experience_reward = p_experience_reward
	_dream_dust_reward = p_dream_dust_reward
	_terminal_enemy = p_terminal_enemy


func is_valid() -> bool:
	return (
		super()
		and not _enemy_id.is_empty()
		and _experience_reward >= 0
		and _dream_dust_reward >= 0
		and (not _terminal_enemy or _dream_dust_reward == 0)
	)
