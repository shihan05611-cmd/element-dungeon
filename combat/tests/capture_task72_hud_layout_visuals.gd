extends SceneTree

## Task 72 §5.3 (simplified per the amended acceptance flow): a single
## Boss-room verification screenshot for the HUD layout rework -- B1's
## overlap fix and B5's passive belt downgrade. Uses the real Boss room
## background and the real HUD
## builder (no mock nodes), populated with plausible Boss/status numbers
## directly through CombatHUD's own public surface, so the screenshot is
## purely about layout geometry -- it intentionally skips playing an entire
## run through to the Boss room, which is unnecessary for a layout capture
## and was observed to take a very long time in this headless environment.

const ROOM_SCENE: PackedScene = preload("res://scenes/run/rooms/room_arena_boss.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/combat_hud.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task72/screenshots"

var _assertions: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world := ROOM_SCENE.instantiate() as Node2D
	root.add_child(world)
	current_scene = world
	var hud := HUD_SCENE.instantiate() as CombatHUD
	root.add_child(hud)
	await process_frame
	await process_frame

	hud.boss_panel.visible = true
	(hud.get_node("Root/BossPanel/Margin/Box/TitleRow/Name") as Label).text = "熔汐王座"
	(hud.get_node("Root/BossPanel/Margin/Box/TitleRow/Form") as Label).text = "形态：熔炽"
	var boss_health_bar := hud.get_node("Root/BossPanel/Margin/Box/HealthRow/HealthBar") as ProgressBar
	boss_health_bar.max_value = 280
	boss_health_bar.value = 210
	(hud.get_node("Root/BossPanel/Margin/Box/HealthRow/HealthValue") as Label).text = "210 / 280"
	var counter_bar := hud.get_node("Root/BossPanel/Margin/Box/CounterRow/CounterBar") as ProgressBar
	counter_bar.max_value = 15
	counter_bar.value = 6
	(hud.get_node("Root/BossPanel/Margin/Box/CounterRow/CounterLabel") as Label).text = "克制进度 6 / 15"

	var status_health_bar := hud.get_node("Root/StatusPanel/Margin/Status/HealthRow/HealthBar") as ProgressBar
	status_health_bar.max_value = 100
	status_health_bar.value = 76
	(hud.get_node("Root/StatusPanel/Margin/Status/HealthRow/HealthValue") as Label).text = " 76 / 100"
	var status_energy_bar := hud.get_node("Root/StatusPanel/Margin/Status/EnergyRow/EnergyBar") as ProgressBar
	status_energy_bar.max_value = 60
	status_energy_bar.value = 42
	(hud.get_node("Root/StatusPanel/Margin/Status/EnergyRow/EnergyValue") as Label).text = "  42 / 60"

	_expect(hud.boss_panel != null and hud.boss_panel.visible, "Boss panel is visible")
	_expect(hud.get_node_or_null("Root/RoomTitle") == null, "room progress/title band is absent from the HUD")
	_expect(hud.status_panel != null and hud.status_panel.visible, "status panel is visible")
	_expect(hud.passive_panel != null and hud.passive_panel.visible, "passive belt is visible")
	_expect(hud.skill_panel != null and hud.skill_panel.visible, "skill belt is visible")

	await RenderingServer.frame_post_draw
	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "evidence directory is writable")
		var image := root.get_texture().get_image()
		var path := directory.path_join("task72_hud_boss_room_1920x1080.png")
		var result := image.save_png(path)
		_expect(result == OK, "%s saves to disk" % path)
		if result == OK:
			print("CAPTURED " + path)

	if is_instance_valid(world):
		world.queue_free()
	if is_instance_valid(hud):
		hud.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 72 HUD LAYOUT VISUAL CAPTURE PASSED: 1 tests, %d assertions" % _assertions)
		quit(0)
	else:
		printerr("TASK 72 HUD LAYOUT VISUAL CAPTURE FAILED: %d assertions, failures:" % _assertions)
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
