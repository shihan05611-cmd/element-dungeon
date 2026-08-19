extends SceneTree

const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var room := BOSS_ROOM.room_scene.instantiate() as RunRoomInstance
	world.add_child(room)
	var configured := room.configure(BOSS_ROOM)
	room.activate()
	var boss := room.enemies[0] as BossTideEmber

	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = Vector2(500.0, 660.0)
	world.add_child(player)
	boss.player = player
	boss.ai_enabled = false

	for _frame: int in 20:
		await physics_frame

	print("configured=%s boss_class=%s pos_y=%.3f terminal_enemy=%s is_physics_processing=%s" % [
		configured,
		boss.get_class(),
		boss.global_position.y,
		boss.terminal_enemy,
		boss.is_physics_processing(),
	])
	print("max_health=%d defense=%.1f form=%s water=%d fire=%d" % [
		boss.damage_receiver.maximum_health,
		boss.damage_receiver.defense_flat,
		String(boss.current_form_id),
		boss.element_carrier.get_amount(&"water"),
		boss.element_carrier.get_amount(&"fire"),
	])
	boss.set("_boss_projectile_cooldown", 0.0)
	boss.call("_spawn_boss_projectile")
	await physics_frame
	print("boss_projectiles_fired=%d" % boss.boss_projectiles_fired)
	print("PASS")
	quit(0)
