extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const WALL_LAYER: int = 4

var _output_dir: String = ""
var _captures: Array[Dictionary] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output_dir = argument.trim_prefix("--output=")
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("TASK34 VISUAL CAPTURE FAILED: non-headless DisplayServer required")
		quit(2)
		return
	if _output_dir.is_empty():
		printerr("TASK34 VISUAL CAPTURE FAILED: --output is required")
		quit(2)
		return
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if mkdir_error != OK:
		printerr("TASK34 VISUAL CAPTURE FAILED: cannot create output directory")
		quit(2)
		return

	for scenario: StringName in [&"enemy_contact", &"wall_first", &"empty_range"]:
		for size in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			await _capture_scenario(scenario, size)
	print("TASK34_VISUAL_JSON=" + JSON.stringify({
		"display_server": DisplayServer.get_name(),
		"captures": _captures,
	}))
	quit(0)


func _capture_scenario(scenario: StringName, size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await process_frame
	DisplayServer.window_set_size(size)
	await process_frame
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	var host := room.get_node("RunSessionHost") as RunSessionHost
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	host.set_process(false)
	player.global_position = Vector2(380.0, 700.0)
	player.facing = 1.0
	enemy.global_position = Vector2(760.0, 700.0)
	var wall_visual: Polygon2D
	if scenario == &"wall_first":
		_make_wall(room, Vector2(560.0, 700.0))
		wall_visual = Polygon2D.new()
		wall_visual.polygon = PackedVector2Array([
			Vector2(-8.0, -90.0), Vector2(8.0, -90.0),
			Vector2(8.0, 90.0), Vector2(-8.0, 90.0),
		])
		wall_visual.position = Vector2(560.0, 700.0)
		wall_visual.color = Color("76a6c9")
		wall_visual.z_index = 10
		room.add_child(wall_visual)
	elif scenario == &"empty_range":
		enemy.global_position = Vector2(1500.0, 700.0)
	await physics_frame
	_equip_fury(host)
	player.energy_component.set_current(20)
	var attempt := player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	var snapshot := attempt.execution_snapshot as AllEnergyBurstExecutionSnapshot
	var overlay := _make_overlay(
		scenario,
		size,
		attempt,
		snapshot,
		player.energy_component.current_energy
	)
	room.add_child(overlay)
	for _frame in 5:
		await process_frame
	await physics_frame
	var image := root.get_texture().get_image()
	var file_name := "task34_%s_%dx%d.png" % [scenario, size.x, size.y]
	var path := _output_dir.path_join(file_name)
	var save_error := image.save_png(path)
	_captures.append({
		"scenario": str(scenario),
		"width": image.get_width(),
		"height": image.get_height(),
		"accepted": attempt.accepted,
		"reason": str(attempt.reason_name()),
		"energy_after": player.energy_component.current_energy,
		"impact": str(snapshot.impact_position) if snapshot != null else "none",
		"path": path,
		"save_error": save_error,
	})
	for tween in get_processed_tweens():
		tween.kill()
	current_scene = null
	room.free()
	await process_frame


func _equip_fury(host: RunSessionHost) -> void:
	var current := host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(
			slot_id,
			&"elemental_fury" if slot_id == SkillSlotIds.ACTIVE_1 else &""
		))
	var result := host.runtime_loadout.try_replace_snapshot(
		RuntimeLoadoutSnapshot.new(entries, current.revision)
	)
	assert(result.accepted, "visual fixture equips Fury")


func _make_overlay(
		scenario: StringName,
		size: Vector2i,
		attempt: CastAttemptResult,
		snapshot: AllEnergyBurstExecutionSnapshot,
		energy_after: int
) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var panel := ColorRect.new()
	panel.position = Vector2(32.0, 28.0)
	panel.size = Vector2(720.0, 154.0)
	panel.color = Color(0.025, 0.04, 0.07, 0.92)
	layer.add_child(panel)
	var label := Label.new()
	label.position = Vector2(54.0, 46.0)
	label.size = Vector2(680.0, 120.0)
	label.add_theme_font_size_override("font_size", 26)
	label.text = (
		"TASK34  %s  |  %d×%d\naccepted=%s  reason=%s  SP=%d\nimpact=%s"
		% [
			str(scenario), size.x, size.y,
			str(attempt.accepted), str(attempt.reason_name()), energy_after,
			str(snapshot.impact_position) if snapshot != null else "none",
		]
	)
	layer.add_child(label)
	return layer


func _make_wall(parent: Node2D, position: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = WALL_LAYER
	wall.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16.0, 180.0)
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)
	parent.add_child(wall)
