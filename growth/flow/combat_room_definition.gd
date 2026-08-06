class_name CombatRoomDefinition
extends Resource

@export var room_id: StringName = &""
@export var display_name: String = ""
@export var template_label: String = ""
@export var encounter_label: String = ""
@export var environment_label: String = ""
@export var room_scene: PackedScene
@export var enemy_spawns: Array[EnemySpawnDefinition] = []
@export_range(0, 1000000, 1, "or_greater") var completion_dream_dust: int = 0
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
	return &""
