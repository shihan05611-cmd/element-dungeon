extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task85/screenshots"
const ICON_PATH := "res://assets/generated/vfx/ignition/icon.png"

var _failures: Array[String] = []
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _hud: CombatHUD


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await _settle()
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_player.global_position = Vector2(470, 470)
	_enemy.global_position = Vector2(720, 470)
	await physics_frame

	var icon := _ignition_icon()
	_expect(icon != null and icon.texture != null and icon.texture.resource_path == ICON_PATH, "real HUD binds the ignition icon")
	_expect(icon != null and icon.size == Vector2(32, 32), "real HUD displays ignition at 32x32")

	_expect(_player.request_element(ElementIds.FIRE).accepted, "normal icon fixture reaches fire form")
	_hide_feedback()
	_hud.call("_refresh_skill_status")
	_expect(is_zero_approx(_icon_disabled()), "available ignition icon is full color")
	await _save("01_ignition_icon_normal_1920x1080.png")

	_expect(_player.request_element(ElementIds.WATER).accepted, "disabled icon fixture reaches water form")
	_hide_feedback()
	_hud.call("_refresh_skill_status")
	_expect(is_equal_approx(_icon_disabled(), 1.0), "water mismatch uses the grayscale-disabled icon")
	await _save("02_ignition_icon_disabled_grayscale_1920x1080.png")

	_enemy.element_carrier.set_amounts_silent(0, 5)
	_hide_feedback()
	var ignition := _player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(ignition.accepted, "cooldown fixture casts real ignition")
	_player.skill_executor.advance(0.01)
	_hud.call("_refresh_skill_status")
	var slot := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_2)
	_expect((slot.get_node("Margin/Body/CooldownMask") as Control).visible, "ignition cooldown mask is visible")
	_expect((slot.get_node("Margin/Body/CooldownLabel") as Label).visible, "ignition cooldown seconds are visible")
	_expect(not (_hud.get_node("Root/FeedbackPanel") as Control).visible, "successful ignition casts no feedback banner")
	_expect(not (_hud.get("_slot_transients") as Dictionary).has(SkillSlotIds.ACTIVE_2), "successful ignition casts no slot transient")
	await _save("03_ignition_icon_cooldown_1920x1080.png")

	_hud.set_skill_hud_visible(false)
	_expect(not _hud.skill_panel.visible and not _hud.passive_panel.visible, "H-hidden state removes both skill belts")
	_expect(icon.texture != null and icon.texture.resource_path == ICON_PATH, "hidden icon retains its latest binding")
	await _save("04_skill_hud_hidden_1920x1080.png")
	_hud.set_skill_hud_visible(true)
	_expect(icon.is_visible_in_tree() and icon.texture.resource_path == ICON_PATH, "restored HUD shows the current ignition icon")

	var state := _player.get_node("IgnitionState") as IgnitionState
	state.clear(&"task85_normal_compare")
	_player.skill_executor.advance(20.0)
	_player.facing = 1.0
	_player.sprite.flip_h = true
	var normal := _player.try_basic_attack()
	_expect(normal.accepted, "normal FIRE comparison attack accepts")
	_player.sprite.set_frame_and_progress(PlayerCharacter.BASIC_ATTACK_CRITICAL_AIRFLOW_FRAME, 0.0)
	_player._sync_basic_attack_airflow()
	_expect(_player.basic_attack_airflow.scale.is_equal_approx(Vector2(2, 2)), "normal comparison keeps authored airflow scale")
	await _save("05_normal_fire_attack_critical_frame_1920x1080.png")

	_player.skill_executor.advance(1.0)
	state.activate_silent(5)
	var boosted := _player.try_basic_attack()
	_expect(boosted.accepted and is_equal_approx(boosted.payload.melee_query_multiplier, PlayerCharacter.IGNITION_MELEE_QUERY_MULTIPLIER), "ignition comparison attack locks the derived range")
	_player.sprite.set_frame_and_progress(PlayerCharacter.BASIC_ATTACK_CRITICAL_AIRFLOW_FRAME, 0.0)
	_player._sync_basic_attack_airflow()
	_expect(_player.basic_attack_airflow.scale.is_equal_approx(Vector2(3, 3)), "ignition comparison keeps exact 1.5x airflow scale")
	_expect(_player.basic_attack_airflow.modulate.is_equal_approx(Color("ff7a20")), "ignition comparison keeps orange airflow")
	await _save("06_ignition_fire_attack_critical_frame_1920x1080.png")

	var diagnostic := _add_boundary_diagnostic()
	await _save("07_ignition_boundary_formula_overlay_1920x1080.png")
	diagnostic.queue_free()
	state.clear(&"task85_capture_complete")
	_player.skill_executor.advance(1.0)
	_player._play_locomotion_animation()
	_player._sync_basic_attack_airflow()
	_expect(_player.basic_attack_airflow.scale.is_equal_approx(Vector2(2, 2)), "capture cleanup restores airflow scale")
	_expect(_player.basic_attack_airflow.position.is_equal_approx(Vector2(0, 1)), "capture cleanup leaves airflow position unchanged")

	_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 85 VISUAL CAPTURE PASSED: 7 screenshots")
		quit(0)
		return
	for failure: String in _failures:
		printerr("TASK 85 VISUAL CAPTURE FAILED: " + failure)
	quit(1)


func _ignition_icon() -> TextureRect:
	var slot := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_2)
	return slot.get_node("Margin/Body/Icon") as TextureRect


func _icon_disabled() -> float:
	var material := _ignition_icon().material as ShaderMaterial
	return float(material.get_shader_parameter(&"disabled"))


func _hide_feedback() -> void:
	var panel := _hud.get_node("Root/FeedbackPanel") as Control
	panel.visible = false


func _add_boundary_diagnostic() -> Node2D:
	var diagnostic := Node2D.new()
	diagnostic.name = "Task85BoundaryDiagnostic"
	_room.add_child(diagnostic)
	var entries := [
		{"distance": PlayerCharacter.BASIC_ATTACK_VISUAL_FRONT, "color": Color("67d8ff")},
		{"distance": PlayerCharacter.BASIC_ATTACK_QUERY_FRONT, "color": Color("257dff")},
		{"distance": PlayerCharacter.IGNITION_VISUAL_FRONT, "color": Color("ff7a20")},
		{"distance": PlayerCharacter.IGNITION_QUERY_FRONT, "color": Color("ffd45a")},
	]
	for entry: Dictionary in entries:
		var line := Line2D.new()
		var x := _player.global_position.x + float(entry.distance)
		line.points = PackedVector2Array([Vector2(x, 390), Vector2(x, 535)])
		line.width = 2.0
		line.default_color = entry.color
		line.z_index = 50
		diagnostic.add_child(line)
	var legend := Label.new()
	legend.position = Vector2(_player.global_position.x - 30, 370)
	legend.text = "V0 34  V1 51  Q0 108  Q1 125  P 74"
	legend.add_theme_font_size_override(&"font_size", 12)
	legend.add_theme_color_override(&"font_color", Color.WHITE)
	legend.z_index = 51
	diagnostic.add_child(legend)
	return diagnostic


func _settle() -> void:
	for _frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	await _settle()
	var image := root.get_texture().get_image()
	if image == null:
		_expect(false, file_name + " has a real Viewport image")
		return
	# Windows HiDPI can expose the backing framebuffer at 2x the requested
	# physical window. Normalize that exact framebuffer to the requested output
	# size so every same-camera artifact has stable 1920x1080 review geometry.
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	_expect(image.get_size() == Vector2i(1920, 1080), file_name + " normalizes the real window framebuffer to 1920x1080")
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	_expect(image.save_png(path) == OK, "saved " + file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
