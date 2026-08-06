class_name EnemySpawnDefinition
extends Resource

@export var enemy_scene: PackedScene
@export var enemy_id: StringName = &""
@export var local_position: Vector2 = Vector2.ZERO
@export_range(1, 1000000, 1, "or_greater") var maximum_health: int = 120
@export_range(0.0, 1000000.0, 0.01, "or_greater") var defense_flat: float = 0.0
@export_range(0, 1000000, 1, "or_greater") var dream_dust_reward: int = 0


func validation_error(terminal_room: bool = false) -> StringName:
	if enemy_scene == null or not enemy_scene.can_instantiate():
		return &"missing_enemy_scene"
	if enemy_id.is_empty():
		return &"missing_enemy_id"
	if not local_position.is_finite():
		return &"invalid_enemy_spawn_position"
	if maximum_health <= 0 or not is_finite(defense_flat) or defense_flat < 0.0:
		return &"invalid_enemy_combat_configuration"
	if dream_dust_reward < 0:
		return &"negative_enemy_dream_dust"
	if terminal_room and dream_dust_reward != 0:
		return &"terminal_enemy_must_award_zero_dream_dust"
	return &""
