class_name RunRoomInstance
extends Node2D

signal room_cleared(room_id: StringName, room_instance_id: int)

@export var template_id: StringName = &""
@export var template_display_name: String = ""

var room_id: StringName:
	get:
		return _definition.room_id if _definition != null else StringName()

var room_definition: CombatRoomDefinition:
	get:
		return _definition

var enemies: Array[CombatEnemy]:
	get:
		return _enemies.duplicate()

var configured: bool:
	get:
		return _configured

var configuration_error: StringName:
	get:
		return _configuration_error

var scene_path: String:
	get:
		return scene_file_path

var _definition: CombatRoomDefinition
var _enemies: Array[CombatEnemy] = []
var _configured: bool = false
var _configuration_error: StringName = &""
var _clear_emitted: bool = false


func configure(definition: CombatRoomDefinition) -> bool:
	if _configured:
		return _fail(&"room_instance_already_configured")
	if definition == null:
		return _fail(&"missing_combat_room_definition")
	var definition_error := definition.validation_error()
	if not definition_error.is_empty():
		return _fail(definition_error)
	if template_id.is_empty() or get_node_or_null("PlayerSpawn") == null:
		return _fail(&"room_template_missing_spawn_or_identity")
	if scene_file_path.is_empty() or scene_file_path != definition.room_scene.resource_path:
		return _fail(&"room_template_scene_mismatch")
	var enemy_container := get_node_or_null("EnemyContainer")
	if enemy_container == null:
		return _fail(&"room_template_missing_enemy_container")
	_definition = definition
	for spawn: EnemySpawnDefinition in definition.enemy_spawns:
		var enemy := spawn.enemy_scene.instantiate() as CombatEnemy
		if enemy == null:
			return _fail(&"enemy_scene_protocol_mismatch")
		enemy.name = String(spawn.enemy_id)
		enemy.position = spawn.local_position
		enemy_container.add_child(enemy)
		if not enemy.configure_run_spawn(spawn, definition.final_boss):
			enemy.queue_free()
			return _fail(&"enemy_spawn_runtime_configuration_failed")
		var defeated_callback := Callable(self, "_on_enemy_defeated")
		if not enemy.enemy_defeated.is_connected(defeated_callback):
			enemy.enemy_defeated.connect(defeated_callback)
		_enemies.append(enemy)
	if _enemies.size() != definition.enemy_spawns.size():
		return _fail(&"enemy_spawn_count_mismatch")
	var title := get_node_or_null("RoomTitle") as Label
	if title != null:
		title.text = "%s · %s" % [definition.display_name, definition.template_label]
	_configured = true
	return true


func player_spawn_global_position() -> Vector2:
	var marker := get_node_or_null("PlayerSpawn") as Marker2D
	return marker.global_position if marker != null else Vector2.ZERO


func all_enemies_defeated() -> bool:
	if _enemies.is_empty():
		return false
	for enemy: CombatEnemy in _enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.defeated:
			return false
	return true


func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true


func deactivate() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false


func _on_enemy_defeated() -> void:
	if _clear_emitted or not all_enemies_defeated():
		return
	_clear_emitted = true
	room_cleared.emit(room_id, get_instance_id())


func _fail(detail: StringName) -> bool:
	_configuration_error = detail
	return false
