extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task90/screenshots"

var _failures: Array[String] = []
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _feedback: CombatFeedback
var _host: RunSessionHost
var _capture_label: Label
var _delivery_serial: int = 90900
var _cast_serial: int = 90800


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
	_enemy.ai_enabled = false
	_host.set_process(false)
	_player.global_position = Vector2(365.0, 470.0)
	_add_capture_label()

	await _capture_knockback_sequence("right", Vector2(690.0, 470.0), Vector2.RIGHT, 1)
	await _capture_knockback_sequence("left", Vector2(925.0, 470.0), Vector2.LEFT, 4)
	await _capture_multiple_targets()
	await _capture_static_and_boss()
	await _capture_reduced_motion_follow()
	await _capture_tree_exit_freeze()

	_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 90 WINDOW CAPTURE PASSED: 13 same-camera screenshots")
		quit(0)
		return
	for failure: String in _failures:
		printerr("TASK 90 WINDOW CAPTURE FAILED: " + failure)
	quit(1)


func _capture_knockback_sequence(
		name: String,
		start_position: Vector2,
		direction: Vector2,
		file_index: int
) -> void:
	await _prepare_enemy(start_position, true, 1, 0)
	var hit_position := _enemy.global_position + Vector2(0.0, -34.0)
	var local_offset := _enemy.to_local(hit_position)
	var result := _submit_hit(_enemy, ElementIds.FIRE, 1, 8.0, hit_position, direction)
	var visual := _latest_visual()
	var damage_group := _latest_damage_group()
	var damage_x := damage_group.global_position.x
	var start_x := _enemy.global_position.x
	_expect(result.reaction_triggered, name + " capture uses a real accepted reaction")
	await _save("%02d_%s_spawn_1280x720.png" % [file_index, name], name + " knockback · spawn")
	_verify_anchor(visual, _enemy, local_offset, name + " spawn")
	await create_timer(0.11).timeout
	await _save("%02d_%s_mid_1280x720.png" % [file_index + 1, name], name + " knockback · middle")
	_verify_anchor(visual, _enemy, local_offset, name + " middle")
	_expect(is_instance_valid(damage_group) and absf(damage_group.global_position.x - damage_x) < 0.75, name + " damage number stays in the original horizontal hit region")
	await create_timer(0.15).timeout
	await _save("%02d_%s_late_1280x720.png" % [file_index + 2, name], name + " knockback · late")
	_verify_anchor(visual, _enemy, local_offset, name + " late")
	_expect(absf(_enemy.global_position.x - start_x) > 18.0, name + " target visibly moves during the continuous sequence")


func _capture_multiple_targets() -> void:
	await _prepare_enemy(Vector2(700.0, 470.0), true, 1, 0)
	var second := ENEMY_SCENE.instantiate() as CombatEnemy
	_room.add_child(second)
	await physics_frame
	second.ai_enabled = false
	second.global_position = Vector2(920.0, 470.0)
	_feedback.observe_receiver(second.combat_receiver)
	second.element_carrier.set_amounts_silent(0, 1)
	var first_hit := _enemy.global_position + Vector2(0.0, -34.0)
	var second_hit := second.global_position + Vector2(0.0, -34.0)
	var first_offset := _enemy.to_local(first_hit)
	var second_offset := second.to_local(second_hit)
	_submit_hit(_enemy, ElementIds.FIRE, 1, 6.0, first_hit, Vector2.LEFT)
	var first_visual := _latest_visual()
	_submit_hit(second, ElementIds.WATER, 1, 6.0, second_hit, Vector2.RIGHT)
	var second_visual := _latest_visual()
	await create_timer(0.12).timeout
	await _save("07_multiple_opposite_knockback_1280x720.png", "multiple targets · opposite knockback")
	_verify_anchor(first_visual, _enemy, first_offset, "multi left")
	_verify_anchor(second_visual, second, second_offset, "multi right")
	second.queue_free()
	await process_frame


func _capture_static_and_boss() -> void:
	await _prepare_enemy(Vector2(790.0, 470.0), false, 1, 0)
	var static_hit := _enemy.global_position + Vector2(0.0, -34.0)
	_submit_hit(_enemy, ElementIds.FIRE, 1, 6.0, static_hit, Vector2.RIGHT)
	await create_timer(0.12).timeout
	await _save("08_static_enemy_control_1280x720.png", "static ordinary enemy · control")
	_expect(_latest_visual().global_position.is_equal_approx(static_hit), "static control preserves Task87 hit position")

	await _clear_feedback()
	_enemy.visible = false
	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	_room.add_child(boss)
	await physics_frame
	boss.set_physics_process(false)
	boss.ai_enabled = false
	boss.global_position = Vector2(820.0, 520.0)
	_feedback.observe_receiver(boss.combat_receiver)
	boss.element_carrier.set_amounts_silent(0, 3)
	var boss_hit := boss.global_position + Vector2(-28.0, -112.0)
	_submit_hit(boss, ElementIds.WATER, 3, 8.0, boss_hit, Vector2.LEFT)
	await create_timer(0.12).timeout
	await _save("09_boss_static_control_1280x720.png", "Boss · static control")
	_expect(_latest_visual().global_position.is_equal_approx(boss_hit), "Boss control preserves Task87 hit position")
	boss.queue_free()
	_enemy.visible = true
	await process_frame


func _capture_reduced_motion_follow() -> void:
	await _prepare_enemy(Vector2(710.0, 470.0), true, 0, 3)
	_feedback.set_reduced_motion(true)
	var hit_position := _enemy.global_position + Vector2(0.0, -34.0)
	var offset := _enemy.to_local(hit_position)
	_submit_hit(_enemy, ElementIds.WATER, 3, 7.0, hit_position, Vector2.RIGHT)
	var visual := _latest_visual()
	await _save("10_reduced_motion_spawn_1280x720.png", "reduced motion · spawn")
	await create_timer(0.12).timeout
	await _save("11_reduced_motion_mid_1280x720.png", "reduced motion · anchored middle")
	_verify_anchor(visual, _enemy, offset, "reduced motion middle")
	_feedback.set_reduced_motion(false)


func _capture_tree_exit_freeze() -> void:
	await _clear_feedback()
	_enemy.visible = false
	var target := ENEMY_SCENE.instantiate() as CombatEnemy
	_room.add_child(target)
	await physics_frame
	target.set_physics_process(false)
	target.ai_enabled = false
	target.global_position = Vector2(805.0, 470.0)
	_feedback.observe_receiver(target.combat_receiver)
	target.element_carrier.set_amounts_silent(1, 0)
	var hit_position := target.global_position + Vector2(0.0, -34.0)
	_submit_hit(target, ElementIds.FIRE, 1, 6.0, hit_position, Vector2.RIGHT)
	var visual := _latest_visual()
	await _save("12_exit_before_1280x720.png", "target exit · before")
	var frozen_position := visual.global_position
	_room.remove_child(target)
	await process_frame
	await process_frame
	await _save("13_exit_frozen_1280x720.png", "target exit · effect frozen")
	_expect(is_instance_valid(visual) and visual.global_position.is_equal_approx(frozen_position), "tree exit freezes the last valid world position")
	target.queue_free()
	_enemy.visible = true


func _prepare_enemy(position: Vector2, physics_enabled: bool, water: int, fire: int) -> void:
	await _clear_feedback()
	_feedback.set_reduced_motion(false)
	_enemy.visible = true
	_enemy.set_physics_process(physics_enabled)
	_enemy.ai_enabled = false
	_enemy.scale = Vector2.ONE
	_enemy.global_position = position
	_enemy.velocity = Vector2.ZERO
	_enemy.defeated = false
	_enemy.hurt_time = 0.0
	_enemy.attack_time = 0.0
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


func _submit_hit(
		target: CombatEnemy,
		element_id: StringName,
		element_amount: int,
		offensive_damage: float,
		hit_position: Vector2,
		hit_direction: Vector2
) -> CombatResult:
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
		PackedStringArray(["task90_capture"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task90_capture",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	var request := HitRequest.new(snapshot, payload, _delivery_serial, 0, hit_position, hit_direction)
	return target.combat_receiver.receive_hit(request)


func _latest_visual() -> Node2D:
	var visuals := _feedback.find_children("ReactionComposition_*", "Node2D", false, false)
	return visuals.back() as Node2D if not visuals.is_empty() else null


func _latest_damage_group() -> Control:
	return _feedback.get_node("DamageFeedback_%d" % (_feedback.get("_spawn_serial") as int)) as Control


func _verify_anchor(visual: Node2D, target: Node2D, offset: Vector2, label: String) -> void:
	var expected := target.to_global(offset)
	var distance := visual.global_position.distance_to(expected) if is_instance_valid(visual) else INF
	print("TASK90 ANCHOR %s target=%s visual=%s distance=%.3f" % [label, expected, visual.global_position if is_instance_valid(visual) else Vector2.ZERO, distance])
	_expect(distance <= 1.0, label + " reaction composition stays on the same local body point")


func _add_capture_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_room.add_child(layer)
	_capture_label = Label.new()
	_capture_label.position = Vector2(28.0, 24.0)
	_capture_label.add_theme_font_size_override(&"font_size", 22)
	_capture_label.add_theme_constant_override(&"outline_size", 6)
	_capture_label.add_theme_color_override(&"font_outline_color", Color("10131c"))
	layer.add_child(_capture_label)


func _settle() -> void:
	for _frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String, label: String) -> void:
	_capture_label.text = "Task 90 · " + label
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
