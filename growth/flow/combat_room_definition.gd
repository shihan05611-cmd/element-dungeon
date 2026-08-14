class_name CombatRoomDefinition
extends Resource

@export var room_id: StringName = &""
@export var display_name: String = ""
@export var template_label: String = ""
@export var encounter_label: String = ""
@export var environment_label: String = ""
@export var room_scene: PackedScene
@export var enemy_spawns: Array[EnemySpawnDefinition] = []
@export var reinforcement_spawns: Array[EnemySpawnDefinition] = []
@export_range(0.1, 60.0, 0.1, "or_greater") var reinforcement_delay_seconds: float = 12.0
@export_range(0, 1000000, 1, "or_greater") var completion_dream_dust: int = 0
@export var single_wave: bool = false
@export var guaranteed_active_skill_reward: bool = false
@export var final_boss: bool = false


func validation_error() -> StringName:
	if room_id.is_empty():
		return &"missing_combat_room_id"
	if display_name.is_empty() or template_label.is_empty():
		return &"missing_combat_room_copy"
	if encounter_label.is_empty() or environment_label.is_empty():
		return &"missing_combat_room_disclosure"
	if room_scene == null or not room_scene.can_instantiate():
		return &"missing_combat_room_scene"
	if enemy_spawns.is_empty():
		return &"combat_room_has_no_enemies"
	if final_boss:
		if enemy_spawns.size() != 1 or not reinforcement_spawns.is_empty():
			return &"boss_room_requires_one_enemy_and_no_reinforcements"
		if single_wave or guaranteed_active_skill_reward:
			return &"boss_room_rejects_normal_reward_policy"
	elif single_wave:
		if enemy_spawns.size() != 2 or not reinforcement_spawns.is_empty():
			return &"single_wave_room_requires_two_enemies_and_no_reinforcements"
	elif enemy_spawns.size() < 3 or enemy_spawns.size() > 5:
		return &"normal_room_initial_wave_out_of_range"
	elif reinforcement_spawns.size() < 2 or reinforcement_spawns.size() > 3:
		return &"normal_room_reinforcement_wave_out_of_range"
	if guaranteed_active_skill_reward and not single_wave:
		return &"guaranteed_active_skill_reward_requires_single_wave"
	if not is_finite(reinforcement_delay_seconds) or reinforcement_delay_seconds <= 0.0:
		return &"invalid_reinforcement_delay"
	if completion_dream_dust < 0:
		return &"negative_room_dream_dust"
	if final_boss and completion_dream_dust != 0:
		return &"terminal_room_must_award_zero_dream_dust"
	var ids: Array[StringName] = []
	for spawn: EnemySpawnDefinition in enemy_spawns:
		if spawn == null:
			return &"null_enemy_spawn"
		var spawn_error := spawn.validation_error(final_boss)
		if not spawn_error.is_empty():
			return spawn_error
		if ids.has(spawn.enemy_id):
			return &"duplicate_enemy_spawn_id"
		ids.append(spawn.enemy_id)
	for spawn: EnemySpawnDefinition in reinforcement_spawns:
		if spawn == null:
			return &"null_reinforcement_spawn"
		var spawn_error := spawn.validation_error(false)
		if not spawn_error.is_empty():
			return spawn_error
		if ids.has(spawn.enemy_id):
			return &"duplicate_enemy_spawn_id"
		ids.append(spawn.enemy_id)
	return &""
