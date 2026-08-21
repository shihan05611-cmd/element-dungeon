extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/run/rooms/room_arena_boss.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/combat_hud.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task73/screenshots"

var _hud: CombatHUD
var _world: Node2D


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if directory_result not in [OK, ERR_ALREADY_EXISTS]:
		printerr("TASK 73 cannot create evidence directory")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	_world = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_world)
	current_scene = _world
	_hud = HUD_SCENE.instantiate() as CombatHUD
	root.add_child(_hud)
	await process_frame
	await process_frame
	_populate_readability_sample()

	await RenderingServer.frame_post_draw
	var native := root.get_texture().get_image()
	if not _save(native, "01_hud_1152x648.png"):
		quit(1)
		return
	var text_crop := native.get_region(Rect2i(12, 12, 420, 130))
	text_crop.resize(4200, 1300, Image.INTERPOLATE_NEAREST)
	if not _save(text_crop, "02_font_native_10x.png"):
		quit(1)
		return

	root.size = Vector2i(1920, 1080)
	await RenderingServer.frame_post_draw
	var full_hd := root.get_texture().get_image()
	if not _save(full_hd, "03_hud_1920x1080.png"):
		quit(1)
		return
	var loadout := full_hd.get_region(Rect2i(720, 820, 480, 240))
	loadout.resize(1920, 960, Image.INTERPOLATE_NEAREST)
	if not _save(loadout, "04_loadout_4x.png"):
		quit(1)
		return

	root.size = Vector2i(2560, 1440)
	await RenderingServer.frame_post_draw
	if not _save(root.get_texture().get_image(), "05_hud_2560x1440.png"):
		quit(1)
		return
	print("TASK 73 PIXEL FONT VISUALS COMPLETE")
	quit(0)


func _populate_readability_sample() -> void:
	_hud.set_room_title("熔汐王门 · Boss Gate")
	_hud.boss_panel.visible = true
	(_hud.get_node("Root/BossPanel/Margin/Box/TitleRow/Name") as Label).text = "熔汐之王 · Sovereign"
	(_hud.get_node("Root/BossPanel/Margin/Box/TitleRow/Form") as Label).text = "形态：熔炽"
	var boss_health_bar := _hud.get_node("Root/BossPanel/Margin/Box/HealthRow/HealthBar") as ProgressBar
	boss_health_bar.max_value = 280
	boss_health_bar.value = 210
	(_hud.get_node("Root/BossPanel/Margin/Box/HealthRow/HealthValue") as Label).text = "210 / 280"
	var counter_bar := _hud.get_node("Root/BossPanel/Margin/Box/CounterRow/CounterBar") as ProgressBar
	counter_bar.max_value = 15
	counter_bar.value = 6
	(_hud.get_node("Root/BossPanel/Margin/Box/CounterRow/CounterLabel") as Label).text = "克制进度 6 / 15"
	(_hud.get_node("Root/StatusPanel/Margin/Status/HealthRow/HealthBar/HealthValue") as Label).text = "76 / 100"
	(_hud.get_node("Root/StatusPanel/Margin/Status/EnergyRow/EnergyBar/EnergyValue") as Label).text = "42 / 60"


func _save(image: Image, file_name: String) -> bool:
	return image != null and not image.is_empty() and image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))) == OK
