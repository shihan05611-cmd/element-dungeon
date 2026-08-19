extends SceneTree

## Task 59 evidence: two independent 180-frame smokes.
## 1) Formal RunGame main scene through Battle01.
## 2) The formal Boss room with the Boss actively telegraphing/firing.

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _smoke_main_scene()
	await _smoke_boss_room()
	print("TASK 59 SMOKE: both 180-frame smokes completed")
	quit(0)


func _smoke_main_scene() -> void:
	var coordinator := RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task59_smoke_main"
	root.add_child(coordinator)
	current_scene = coordinator
	for _frame: int in 180:
		await physics_frame
	print("SMOKE 1 (main scene) done: active_room=%s alive=%s" % [
		coordinator.active_room.room_id if coordinator.active_room != null else "none",
		is_instance_valid(coordinator.player)
	])
	coordinator.queue_free()
	await process_frame


func _smoke_boss_room() -> void:
	var world := Node2D.new()
	world.name = "Task59SmokeBossWorld"
	root.add_child(world)
	current_scene = world
	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	room.configure(BOSS_ROOM)
	room.activate()
	var boss := room.enemies[0] as CombatEnemy
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = Vector2(boss.global_position.x - 260.0, boss.global_position.y)
	world.add_child(player)
	boss.player = player
	boss.ai_enabled = false
	# A captured local int would be a per-call copy inside the lambda (GDScript
	# closures capture primitives by value, not by reference); use a Dictionary
	# so the mutation is visible after the loop, same as run_task59_*_tests.gd.
	var stats := {&"shots_fired": 0}
	boss.delivery_created.connect(func(_node: Node) -> void: stats[&"shots_fired"] = int(stats[&"shots_fired"]) + 1)
	for _frame: int in 180:
		await physics_frame
	print("SMOKE 2 (Boss room) done: shots_fired=%d boss_alive=%s" % [int(stats[&"shots_fired"]), is_instance_valid(boss)])
	world.queue_free()
	await process_frame
