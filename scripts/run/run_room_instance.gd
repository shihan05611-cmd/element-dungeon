class_name RunRoomInstance
extends Node2D

signal room_cleared(room_id: StringName, room_instance_id: int)

const CHEST_SCENE: PackedScene = preload("res://scenes/run/interactables/run_reward_chest.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/run/interactables/run_route_portal.tscn")
const CHEST_OPEN_TEXTURE: Texture2D = preload("res://assets/world/interactables/run_reward_chest/chest_open_v2.png")

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

var initial_enemies: Array[CombatEnemy]:
	get:
		return _initial_enemies.duplicate()

var reinforcement_enemies: Array[CombatEnemy]:
	get:
		return _reinforcement_enemies.duplicate()

var reinforcement_activated: bool:
	get:
		return _reinforcement_activated

var room_is_cleared: bool:
	get:
		return _clear_emitted

var chest: RunWorldInteractable:
	get:
		return _chest

var portal: RunWorldInteractable:
	get:
		return _portal

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
var _initial_enemies: Array[CombatEnemy] = []
var _reinforcement_enemies: Array[CombatEnemy] = []
var _configured: bool = false
var _configuration_error: StringName = &""
var _clear_emitted: bool = false
var _reinforcement_activated: bool = false
var _active_elapsed: float = 0.0
var _chest: RunWorldInteractable
var _portal: RunWorldInteractable


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
	if not _validate_authored_markers(definition):
		return false
	_definition = definition
	for index: int in definition.enemy_spawns.size():
		var spawn: EnemySpawnDefinition = definition.enemy_spawns[index]
		var enemy := spawn.enemy_scene.instantiate() as CombatEnemy
		if enemy == null:
			return _fail(&"enemy_scene_protocol_mismatch")
		enemy.name = String(spawn.enemy_id)
		enemy.position = _spawn_marker("InitialEnemySpawns", index).position
		enemy_container.add_child(enemy)
		if not enemy.configure_run_spawn(spawn, definition.final_boss):
			enemy.queue_free()
			return _fail(&"enemy_spawn_runtime_configuration_failed")
		var defeated_callback := Callable(self, "_on_enemy_defeated")
		if not enemy.enemy_defeated.is_connected(defeated_callback):
			enemy.enemy_defeated.connect(defeated_callback)
		_enemies.append(enemy)
		_initial_enemies.append(enemy)
	for index: int in definition.reinforcement_spawns.size():
		var spawn: EnemySpawnDefinition = definition.reinforcement_spawns[index]
		var enemy := spawn.enemy_scene.instantiate() as CombatEnemy
		if enemy == null:
			return _fail(&"enemy_scene_protocol_mismatch")
		enemy.name = String(spawn.enemy_id)
		enemy.position = _spawn_marker("ReinforcementSpawns", index).position
		enemy_container.add_child(enemy)
		if not enemy.configure_run_spawn(spawn, false):
			enemy.queue_free()
			return _fail(&"enemy_spawn_runtime_configuration_failed")
		enemy.set_reinforcement_dormant(true)
		var defeated_callback := Callable(self, "_on_enemy_defeated")
		if not enemy.enemy_defeated.is_connected(defeated_callback):
			enemy.enemy_defeated.connect(defeated_callback)
		_enemies.append(enemy)
		_reinforcement_enemies.append(enemy)
	if _enemies.size() != definition.enemy_spawns.size() + definition.reinforcement_spawns.size():
		return _fail(&"enemy_spawn_count_mismatch")
	_reinforcement_activated = definition.final_boss
	_create_interactables()
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


func interaction_target_at(player_position: Vector2) -> RunWorldInteractable:
	if _chest != null and _chest.can_interact(player_position):
		return _chest
	if _portal != null and _portal.can_interact(player_position):
		return _portal
	return null


func apply_chest_reward(reward_copy: String) -> void:
	if _chest == null or _chest.consumed:
		return
	_chest.open_chest(CHEST_OPEN_TEXTURE, reward_copy)
	if _portal != null:
		_portal.set_locked(false)


func open_settlement_chest() -> void:
	if _chest != null and not _chest.consumed:
		_chest.open_chest(CHEST_OPEN_TEXTURE, "结算已提交")


func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	_active_elapsed = 0.0


func deactivate() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false


func _process(delta: float) -> void:
	if not _configured or _definition.final_boss or _reinforcement_activated:
		return
	_active_elapsed += delta
	if _initial_wave_defeated() or _active_elapsed >= _definition.reinforcement_delay_seconds:
		_activate_reinforcements()


func _on_enemy_defeated() -> void:
	if _clear_emitted:
		return
	if not _reinforcement_activated and _initial_wave_defeated():
		_activate_reinforcements()
	if not _reinforcement_activated or not all_enemies_defeated():
		return
	_clear_emitted = true
	_reveal_clear_interactables()
	room_cleared.emit(room_id, get_instance_id())


func _initial_wave_defeated() -> bool:
	for enemy: CombatEnemy in _initial_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.defeated:
			return false
	return not _initial_enemies.is_empty()


func _activate_reinforcements() -> void:
	if _reinforcement_activated:
		return
	_reinforcement_activated = true
	for enemy: CombatEnemy in _reinforcement_enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.set_reinforcement_dormant(false)


func _create_interactables() -> void:
	var container := Node2D.new()
	container.name = "WorldInteractables"
	add_child(container)
	_chest = CHEST_SCENE.instantiate() as RunWorldInteractable
	_chest.name = "SettlementChest" if _definition.final_boss else "RewardChest"
	_chest.position = (get_node("RewardChestSpawn") as Marker2D).position
	_chest.visible = false
	_chest.set_enabled(false)
	container.add_child(_chest)
	if not _definition.final_boss:
		_portal = PORTAL_SCENE.instantiate() as RunWorldInteractable
		_portal.position = (get_node("RoutePortalSpawn") as Marker2D).position
		_portal.visible = false
		_portal.set_enabled(false)
		container.add_child(_portal)


func _validate_authored_markers(definition: CombatRoomDefinition) -> bool:
	var chest_marker := get_node_or_null("RewardChestSpawn") as Marker2D
	if chest_marker == null:
		return _fail(&"room_template_missing_reward_chest_spawn")
	var portal_marker := get_node_or_null("RoutePortalSpawn") as Marker2D
	if not definition.final_boss and portal_marker == null:
		return _fail(&"room_template_missing_route_portal_spawn")
	for index: int in definition.enemy_spawns.size():
		if _spawn_marker("InitialEnemySpawns", index) == null:
			return _fail(&"room_template_missing_initial_enemy_spawn")
	for index: int in definition.reinforcement_spawns.size():
		if _spawn_marker("ReinforcementSpawns", index) == null:
			return _fail(&"room_template_missing_reinforcement_spawn")
	return true


func _spawn_marker(group_name: String, index: int) -> Marker2D:
	return get_node_or_null("%s/Spawn%d" % [group_name, index + 1]) as Marker2D


func _reveal_clear_interactables() -> void:
	_chest.visible = true
	_chest.set_enabled(true)
	_chest.set_locked(false)
	if _definition.final_boss:
		_chest.prompt_text = "开启结算宝箱"
		_chest.call("_refresh_prompt")
	elif _portal != null:
		_portal.visible = true
		_portal.set_enabled(true)
		_portal.set_locked(true, "先开启宝箱")


func _fail(detail: StringName) -> bool:
	_configuration_error = detail
	return false
