extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task38/viewport"

var _assertions: int = 0
var _failures: Array[String] = []
var _images: Dictionary[String, Image] = {}
var _identity: int = 3_800_000


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	call_deferred(&"_run")


func _run() -> void:
	await _capture_reclaim(Vector2i(1920, 1080), "01_reclaim_visible_far_1920x1080.png")
	await _capture_reaction(Vector2i(1920, 1080), "02_reaction_energy_1920x1080.png")
	await _capture_reclaim(Vector2i(2560, 1440), "03_reclaim_visible_far_2560x1440.png")
	await _capture_reaction(Vector2i(2560, 1440), "04_reaction_energy_2560x1440.png")
	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Task38 viewport directory is writable")
		for file_name: String in _images:
			var image := _images[file_name]
			_expect(image != null and image.save_png(directory.path_join(file_name)) == OK, "%s saves after all authority gates pass" % file_name)
	_finish()


func _capture_reclaim(size: Vector2i, file_name: String) -> void:
	var rig := await _make_room(size)
	if rig.is_empty():
		return
	var room := rig.room as Node2D
	var player := rig.player as PlayerCharacter
	var enemy := rig.enemy as CombatEnemy
	var host := rig.host as RunSessionHost
	_expect(_equip(host.runtime_loadout, SkillSlotIds.ACTIVE_3, &"element_reclaim"), "%s equips reclaim" % file_name)
	player.global_position = Vector2(310.0, 470.0)
	enemy.global_position = Vector2(660.0, 470.0)
	player.current_element_controller.request_element(ElementIds.WATER)
	player.energy_component.set_current(50)
	enemy.element_carrier.set_amounts_silent(3, 2)
	await physics_frame
	var screen_point := player.get_canvas_transform() * enemy.global_position
	_expect(root.get_visible_rect().has_point(screen_point), "%s target anchor is inside the current Viewport" % file_name)
	_expect(player.global_position.distance_to(enemy.global_position) > 160.0, "%s target exceeds the legacy radius" % file_name)
	var attempt := player.try_cast_slot(SkillSlotIds.ACTIVE_3)
	_expect(attempt != null and attempt.accepted and attempt.skill_id == &"element_reclaim", "%s commits through the formal reclaim skill" % file_name)
	_expect_eq(player.energy_component.current_energy, 65, "%s restores three layers times five SP" % file_name)
	_expect_eq(enemy.element_carrier.get_amount(ElementIds.WATER), 0, "%s consumes all matching layers" % file_name)
	_add_panel(room, "Task38  屏内远距回收\nViewport 世界矩形 / 无 LOS\n距离 350 > 旧半径 160\nSP 50 → 65  水层 3 → 0")
	await _store(file_name, size)
	room.queue_free()
	await process_frame


func _capture_reaction(size: Vector2i, file_name: String) -> void:
	var rig := await _make_room(size)
	if rig.is_empty():
		return
	var room := rig.room as Node2D
	var player := rig.player as PlayerCharacter
	var enemy := rig.enemy as CombatEnemy
	var host := rig.host as RunSessionHost
	var content := host.content_catalog.content_for(&"passive_reaction_energy")
	_expect(content != null and content.icon != null and content.icon.resource_path == "res://assets/generated/vfx/passive_reaction_energy/icon.png", "%s uses the frozen Task39 icon" % file_name)
	_expect(_equip(host.runtime_loadout, SkillSlotIds.PASSIVE_1, &"passive_reaction_energy"), "%s equips element echo" % file_name)
	_expect_eq(host.runtime_loadout.registered_passive_skill_ids, [&"passive_reaction_energy"], "%s has one typed element echo runtime" % file_name)
	player.global_position = Vector2(310.0, 470.0)
	enemy.global_position = Vector2(560.0, 470.0)
	player.energy_component.set_current(40)
	enemy.element_carrier.set_amounts_silent(1, 0)
	var result := enemy.combat_receiver.receive_hit(_fire_request(player))
	_expect(result != null and result.accepted and result.reaction_triggered, "%s uses an accepted player reaction settlement" % file_name)
	_expect_eq(player.energy_component.current_energy, 50, "%s restores exactly ten SP" % file_name)
	_add_panel(room, "Task38  元素回响\nP1 passive_reaction_energy / Runtime×1\n玩家反应结算 accepted=true\nSP 40 → 50  单次 +10")
	await _store(file_name, size)
	room.queue_free()
	await process_frame


func _make_room(size: Vector2i) -> Dictionary:
	await _set_size(size)
	var room := ROOM_SCENE.instantiate() as Node2D
	_expect(room != null, "real TestRoom instantiates")
	if room == null:
		return {}
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	var host := room.get_node("RunSessionHost") as RunSessionHost
	_expect(player != null and enemy != null and host != null, "real TestRoom authority chain resolves")
	if player == null or enemy == null or host == null:
		room.queue_free()
		await process_frame
		return {}
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	host.set_process(false)
	return {"room": room, "player": player, "enemy": enemy, "host": host}


func _equip(runtime: RuntimeSkillLoadout, slot_id: StringName, skill_id: StringName) -> bool:
	var current := runtime.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in current.entries:
		entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, skill_id if entry.slot_id == slot_id else entry.skill_id))
	return runtime.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision)).accepted


func _fire_request(player: PlayerCharacter) -> HitRequest:
	_identity += 1
	var cast := CastSnapshot.new(_identity, &"task38_visual_reaction", player.get_instance_id(), player.get_instance_id(), &"player", ElementIds.FIRE, CombatStatSnapshot.new())
	return HitRequest.new(cast, RuntimeAttackPayload.from_locked_stats(cast.stat_snapshot, 0.0, ElementIds.FIRE, 1), _identity + 1000, 0, Vector2(560.0, 470.0), Vector2.RIGHT)


func _add_panel(room: Node, text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	room.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(735.0, 28.0)
	panel.size = Vector2(390.0, 132.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.94)
	style.border_color = Color(0.95, 0.75, 0.28, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.91))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)


func _set_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for _frame: int in 8:
		await process_frame
	_expect_eq(DisplayServer.window_get_size(), size, "window reaches requested %s" % str(size))


func _store(file_name: String, size: Vector2i) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image != null and image.get_size() == size, "%s captures the actual %s Viewport" % [file_name, str(size)])
	if image != null:
		_images[file_name] = image


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 38 VISUAL CAPTURE PASSED: 1 test, %d assertions, %d screenshots" % [_assertions, _images.size()])
		quit(0)
	else:
		printerr("TASK 38 VISUAL CAPTURE FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
