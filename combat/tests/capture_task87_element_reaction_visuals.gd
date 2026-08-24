extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task87/screenshots"

var _failures: Array[String] = []
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _boss: BossTideEmber
var _feedback: CombatFeedback
var _host: RunSessionHost
var _delivery_serial: int = 87900
var _cast_serial: int = 87800


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await _settle()
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_feedback = _room.get_node("WorldFeedbackLayer") as CombatFeedback
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)
	_player.global_position = Vector2(390.0, 470.0)
	_enemy.global_position = Vector2(790.0, 470.0)

	await _prepare_enemy(1, 0)
	var fire_result := _submit_enemy_hit(ElementIds.FIRE, 1, 8.0, _enemy.global_position + Vector2(0.0, -34.0))
	_expect(fire_result.reaction_triggered, "fire-to-water capture uses a real accepted reaction")
	await _save("01_fire_into_water_inward_1280x720.png")
	await create_timer(0.12).timeout
	await _save("02_fire_into_water_burst_1280x720.png")

	await _prepare_enemy(0, 2)
	var water_result := _submit_enemy_hit(ElementIds.WATER, 2, 8.0, _enemy.global_position + Vector2(0.0, -34.0))
	_expect(water_result.reaction_triggered, "water-to-fire capture uses a real accepted reaction")
	await _save("03_water_into_fire_inward_1280x720.png")
	await create_timer(0.12).timeout
	await _save("04_water_into_fire_burst_1280x720.png")

	for entry: Dictionary in [
		{"layers": 1, "delay": 0.18, "file": "05_strength_weak_1280x720.png"},
		{"layers": 2, "delay": 0.155, "file": "06_strength_medium_1280x720.png"},
		{"layers": 4, "delay": 0.13, "file": "07_strength_strong_capped_1280x720.png"},
	]:
		var layers := entry["layers"] as int
		await _prepare_enemy(layers, 0)
		var result := _submit_enemy_hit(ElementIds.FIRE, layers, 7.0, _enemy.global_position + Vector2(0.0, -34.0))
		_expect(result.reaction_consumed == layers, "%d-layer capture retains exact result authority" % layers)
		await create_timer(entry["delay"] as float).timeout
		await _save(entry["file"] as String)

	await _prepare_enemy(0, 0)
	var ordinary := _submit_enemy_hit(ElementIds.NONE, 0, 7.0, _enemy.global_position + Vector2(0.0, -34.0))
	_expect(ordinary.accepted and not ordinary.reaction_triggered, "ordinary comparison is a real non-reaction hit")
	await create_timer(0.10).timeout
	await _save("08_ordinary_hit_control_1280x720.png")

	await _clear_feedback()
	_enemy.visible = false
	_boss = BOSS_SCENE.instantiate() as BossTideEmber
	_room.add_child(_boss)
	_boss.global_position = Vector2(805.0, 525.0)
	await physics_frame
	_boss.set_physics_process(false)
	_boss.ai_enabled = false
	_feedback.observe_receiver(_boss.combat_receiver)
	_boss.element_carrier.set_amounts_silent(0, 3)
	var boss_hit := _boss.global_position + Vector2(-28.0, -116.0)
	var boss_result := _submit_boss_hit(ElementIds.WATER, 3, 10.0, boss_hit)
	_expect(boss_result.accepted and boss_result.hit_position.is_equal_approx(boss_hit), "boss capture carries the authored hit position")
	await create_timer(0.13).timeout
	await _save("09_boss_hit_position_1280x720.png")

	await _clear_feedback()
	_boss.visible = false
	_enemy.visible = true
	_feedback.set_reduced_motion(true)
	_enemy.element_carrier.set_amounts_silent(0, 3)
	var reduced := _submit_enemy_hit(ElementIds.WATER, 3, 8.0, _enemy.global_position + Vector2(0.0, -34.0))
	_expect(reduced.reaction_triggered, "reduced-motion capture remains a real reaction")
	await create_timer(0.08).timeout
	await _save("10_reduced_motion_static_1280x720.png")

	_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 87 WINDOW CAPTURE PASSED: 10 same-camera screenshots")
		quit(0)
		return
	for failure: String in _failures:
		printerr("TASK 87 WINDOW CAPTURE FAILED: " + failure)
	quit(1)


func _prepare_enemy(water: int, fire: int) -> void:
	await _clear_feedback()
	_enemy.visible = true
	_enemy.scale = Vector2.ONE
	_enemy.defeated = false
	_enemy.combat_receiver.accepting_hits = true
	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	_enemy.element_carrier.set_amounts_silent(water, fire)


func _clear_feedback() -> void:
	for tween: Tween in get_processed_tweens():
		tween.kill()
	for child: Node in _feedback.get_children():
		child.queue_free()
	await process_frame
	_feedback.set("_active_labels", [])
	_feedback.set("_active_reaction_visuals", [])


func _submit_enemy_hit(
		element_id: StringName,
		element_amount: int,
		offensive_damage: float,
		hit_position: Vector2
) -> CombatResult:
	return _enemy.combat_receiver.receive_hit(_request(element_id, element_amount, offensive_damage, hit_position))


func _submit_boss_hit(
		element_id: StringName,
		element_amount: int,
		offensive_damage: float,
		hit_position: Vector2
) -> CombatResult:
	return _boss.combat_receiver.receive_hit(_request(element_id, element_amount, offensive_damage, hit_position))


func _request(
		element_id: StringName,
		element_amount: int,
		offensive_damage: float,
		hit_position: Vector2
) -> HitRequest:
	_delivery_serial += 1
	_cast_serial += 1
	var stats := CombatStatSnapshot.new(1.0, 0.0)
	var payload := RuntimeAttackPayload.from_locked_inputs(
		stats.effective_attack,
		offensive_damage / stats.effective_attack,
		0.0,
		offensive_damage,
		element_id,
		element_amount,
		PackedStringArray(["task87_capture"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task87_capture",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	return HitRequest.new(snapshot, payload, _delivery_serial, 0, hit_position, Vector2.RIGHT)


func _settle() -> void:
	for _frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		_expect(false, file_name + " has a real Viewport image")
		return
	if image.get_size() != Vector2i(1280, 720):
		image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	_expect(image.get_size() == Vector2i(1280, 720), file_name + " keeps same-camera output geometry")
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	_expect(image.save_png(path) == OK, "saved " + file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
