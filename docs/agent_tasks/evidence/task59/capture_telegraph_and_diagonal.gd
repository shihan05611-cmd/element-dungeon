extends SceneTree

## Task 59 evidence captures:
## 1) Yellow "!" telegraph, reduced-motion OFF vs ON (same live telegraph).
## 2) Diagonal shot hitting the player.
## 3) Diagonal shot blocked by a wall.
##
## Run with a real display driver (screenshots need frame_post_draw, which
## hangs under --headless):
##   Godot --display-driver windows --audio-driver Dummy --path <project>
##     --script res://docs/agent_tasks/evidence/task59/capture_telegraph_and_diagonal.gd
##     --resolution 1920x1080

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const COMBAT_HUD_SCENE: PackedScene = preload("res://scenes/combat_hud.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task59/screenshots"

var _failures: Array[String] = []
var _saved: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)

	await _capture_telegraph_reduced_motion()
	await _capture_diagonal_hit()
	await _capture_diagonal_blocked()

	if _failures.is_empty():
		print("TASK 59 CAPTURE PASSED: %d screenshots saved" % _saved.size())
		for path: String in _saved:
			print("  - " + path)
		quit(0)
	else:
		printerr("TASK 59 CAPTURE FAILED")
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _make_ground(world: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 4  # WorldBlocker
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.position = rect.size * 0.5
	shape.shape = rectangle
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.color = Color(0.16, 0.15, 0.2, 1.0)
	visual.size = rect.size
	body.add_child(visual)
	world.add_child(body)


func _make_backdrop(world: Node2D) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.07, 0.1, 1.0)
	backdrop.position = Vector2(-200, -400)
	backdrop.size = Vector2(2400, 1400)
	backdrop.z_index = -10
	world.add_child(backdrop)


func _make_camera(world: Node2D, center: Vector2) -> void:
	var camera := Camera2D.new()
	camera.position = center
	camera.zoom = Vector2(1.0, 1.0)
	camera.enabled = true
	world.add_child(camera)
	camera.make_current()


func _capture_telegraph_reduced_motion() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	_make_backdrop(world)
	_make_ground(world, Rect2(Vector2(300, 620), Vector2(1200, 80)))

	# The real production CombatHUD, added BEFORE the enemy so the enemy's own
	# _ready()/_connect_reduced_motion_source() finds it via find_child and
	# subscribes to its real reduced_motion_changed signal — this exercises
	# the actual toggle_reduced_motion production path end to end, not just
	# the indicator's own API.
	var hud := COMBAT_HUD_SCENE.instantiate() as CombatHUD
	world.add_child(hud)
	_assert(not hud.reduced_motion, "capture starts with reduced motion off, matching the default HUD state")

	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	for _frame: int in 10:
		await physics_frame

	boss.global_position = Vector2(700.0, 570.0)
	player.global_position = Vector2(1000.0, 570.0)
	boss.player = player
	player.set_physics_process(false)
	_make_camera(world, Vector2(850.0, 480.0))

	boss.set("_boss_projectile_cooldown", 0.0)
	await physics_frame
	await physics_frame
	_assert(bool(boss.get("_telegraph_active")), "telegraph is active for the capture")

	# Let the pulse animation run a bit so the "off" shot is mid-pulse, then
	# flip reduced-motion on for the same still-active telegraph through the
	# real HUD entry point (CombatHUD.set_reduced_motion — the same method
	# combat_hud.gd:163 calls when the player presses toggle_reduced_motion).
	for _frame: int in 6:
		await physics_frame
	await _settle()
	await _save("task59_telegraph_reduced_motion_off_1920x1080.png")

	hud.set_reduced_motion(true)
	await physics_frame
	_assert(boss.telegraph_indicator != null and boss.telegraph_indicator.reduced_motion, "the real HUD toggle propagated to the boss's telegraph indicator")
	await _settle()
	await _save("task59_telegraph_reduced_motion_on_1920x1080.png")

	world.queue_free()
	await process_frame


func _capture_diagonal_hit() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	_make_backdrop(world)
	_make_ground(world, Rect2(Vector2(300, 620), Vector2(1200, 80)))

	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	var profile := EnemyProjectileProfile.new()
	profile.projectile_scene = preload("res://scenes/run/boss_arc_projectile.tscn")
	profile.speed = 220.0
	profile.max_distance = 980.0
	profile.damage = 8.0
	profile.element_id = ElementIds.NONE
	profile.hurtbox_collision_mask = 16
	profile.blocking_collision_mask = 4
	profile.telegraph_duration = 0.0
	profile.aim_mode = EnemyProjectileProfile.AimMode.AIM_AT_PLAYER
	profile.aim_angle_limit_degrees = 60.0
	boss.ranged_projectile_profile = profile
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	for _frame: int in 10:
		await physics_frame

	boss.global_position = Vector2(650.0, 590.0)
	player.global_position = Vector2(950.0, 460.0)
	boss.player = player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	_make_camera(world, Vector2(800.0, 500.0))

	var created: Array[Node] = []
	boss.delivery_created.connect(func(node: Node) -> void: created.append(node), CONNECT_ONE_SHOT)
	boss.call("_spawn_boss_projectile")
	_assert(created.size() == 1, "diagonal hit capture fires one delivery")
	if not created.is_empty():
		var projectile := created[0] as ProjectileDelivery
		var outcome := {&"hit": false, &"reason": StringName()}
		projectile.delivery_finished.connect(func(reason: StringName) -> void:
			outcome[&"reason"] = reason
			if reason == DeliveryBase.FINISH_HIT:
				outcome[&"hit"] = true
		)
		var target_travel := boss.global_position.distance_to(player.global_position) * 0.55
		for _frame: int in 60:
			await physics_frame
			if not is_instance_valid(projectile):
				break
			if projectile.distance_travelled >= target_travel:
				break
		await _settle()
		await _save("task59_diagonal_shot_hits_player_1920x1080.png")
		for _frame: int in 120:
			if bool(outcome[&"hit"]) or not is_instance_valid(projectile):
				break
			await physics_frame
		_assert(bool(outcome[&"hit"]), "diagonal shot capture confirms a real hit")

	world.queue_free()
	await process_frame


func _capture_diagonal_blocked() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	_make_backdrop(world)
	_make_ground(world, Rect2(Vector2(300, 620), Vector2(1200, 80)))
	# A WorldBlocker wall sitting directly in the diagonal flight path.
	_make_ground(world, Rect2(Vector2(870, 420), Vector2(24, 200)))

	var boss := ENEMY_SCENE.instantiate() as CombatEnemy
	boss.terminal_enemy = true
	boss.ai_enabled = false
	var profile := EnemyProjectileProfile.new()
	profile.projectile_scene = preload("res://scenes/run/boss_arc_projectile.tscn")
	profile.speed = 220.0
	profile.max_distance = 980.0
	profile.damage = 8.0
	profile.element_id = ElementIds.NONE
	profile.hurtbox_collision_mask = 16
	profile.blocking_collision_mask = 4
	profile.telegraph_duration = 0.0
	profile.aim_mode = EnemyProjectileProfile.AimMode.AIM_AT_PLAYER
	profile.aim_angle_limit_degrees = 60.0
	boss.ranged_projectile_profile = profile
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	for _frame: int in 10:
		await physics_frame

	boss.global_position = Vector2(650.0, 590.0)
	# Player sits behind the wall; the diagonal aim points straight at the
	# blocker between boss and player.
	player.global_position = Vector2(1050.0, 440.0)
	boss.player = player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	_make_camera(world, Vector2(830.0, 500.0))

	var created: Array[Node] = []
	boss.delivery_created.connect(func(node: Node) -> void: created.append(node), CONNECT_ONE_SHOT)
	boss.call("_spawn_boss_projectile")
	_assert(created.size() == 1, "diagonal blocked capture fires one delivery")
	if not created.is_empty():
		var projectile := created[0] as ProjectileDelivery
		projectile.queue_free_on_finish = false
		var outcome := {&"blocked": false}
		projectile.blocker_contact.connect(func(_pos: Vector2) -> void: outcome[&"blocked"] = true)
		for _frame: int in 120:
			await physics_frame
			if bool(outcome[&"blocked"]):
				break
			if not is_instance_valid(projectile):
				break
		await _settle()
		await _save("task59_diagonal_shot_blocked_by_wall_1920x1080.png")
		projectile.free()
		_assert(bool(outcome[&"blocked"]), "diagonal blocked capture confirms a real WorldBlocker contact")

	world.queue_free()
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "%s captures a non-empty image" % file_name)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	_assert(image.save_png(ProjectSettings.globalize_path(path)) == OK, "%s saves successfully" % file_name)
	_saved.append(path)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
