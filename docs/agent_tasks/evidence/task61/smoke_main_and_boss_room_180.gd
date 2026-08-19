extends SceneTree

## Task 61 双 180 帧 smoke: (1) the formal main scene run_game.tscn for 180
## physics frames with a live Player; (2) the formal Boss room
## combat_06_final_boss.tres for 180 physics frames with a live
## BossTideEmber, confirming its natural cooldown -> telegraph -> fire cycle
## completes at least once and the boss stays alive/physics-processing.

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _smoke_main_scene()
	await _smoke_boss_room()
	print("SMOKE PASS")
	quit(0)


func _smoke_main_scene() -> void:
	var game := RUN_GAME.instantiate()
	root.add_child(game)
	current_scene = game
	for _frame: int in 180:
		await physics_frame
	var player := _first_node_in_group(&"player")
	print("main_scene: player_alive=%s frames=180" % [is_instance_valid(player)])
	game.queue_free()
	await process_frame


func _smoke_boss_room() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	room.configure(BOSS_ROOM)
	room.activate()
	var boss := room.enemies[0] as BossTideEmber
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = boss.global_position + Vector2(360.0, 0.0)
	world.add_child(player)
	boss.player = player

	var shots := {&"count": 0}
	boss.delivery_created.connect(func(_d: Node) -> void: shots[&"count"] += 1)

	for _frame: int in 180:
		await physics_frame

	print("boss_room: alive=%s is_physics_processing=%s form=%s deliveries_created=%d" % [
		not boss.defeated,
		boss.is_physics_processing(),
		String(boss.current_form_id),
		shots[&"count"],
	])
	world.queue_free()
	await process_frame


func _first_node_in_group(group_name: StringName) -> Node:
	var nodes := get_nodes_in_group(group_name)
	return nodes[0] if not nodes.is_empty() else null
