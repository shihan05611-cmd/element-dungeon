extends SceneTree

const CHEST_SCENE: PackedScene = preload("res://scenes/run/interactables/run_reward_chest.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/run/interactables/run_transition_zone.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task88/screenshots"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080),
	])
	backdrop.color = Color("111827")
	backdrop.z_index = -10
	root.add_child(backdrop)
	var chest := CHEST_SCENE.instantiate() as RunWorldInteractable
	chest.position = Vector2(410, 350)
	root.add_child(chest)
	var transition := TRANSITION_SCENE.instantiate() as RunWorldInteractable
	transition.locked = false
	transition.position = Vector2(730, 350)
	root.add_child(transition)
	await _settle()
	_assert(chest.prompt.get_theme_font_size(&"font_size") == 14, "real window chest prompt uses 14px")
	_assert(transition.prompt.get_theme_font_size(&"font_size") == 12, "real window transition prompt remains 12px")
	_assert(chest.prompt.size == Vector2(232, 34), "real window chest prompt has unclipped 14px bounds")
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "real window has a framebuffer")
	if image != null and not image.is_empty():
		if image.get_size() != Vector2i(1920, 1080):
			image.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("task88_01_chest_14px_vs_transition_12px_1920x1080.png"))
		_assert(image.save_png(path) == OK, "saved real-window prompt comparison")
	for failure: String in _failures:
		printerr("TASK 88 VISUAL CAPTURE FAILED: " + failure)
	if _failures.is_empty():
		print("TASK 88 VISUAL CAPTURE PASSED: 1 screenshot")
	quit(0 if _failures.is_empty() else 1)


func _settle() -> void:
	for _frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)
