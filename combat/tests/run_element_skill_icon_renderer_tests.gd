extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const IconRenderer := preload("res://scripts/ui/element_skill_icon_renderer.gd")

var _harness := TestHarness.new()
var _renderer = IconRenderer.new()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_test("supported_icon_set", _test_supported_icon_set)
	await _run_test("shared_grayscale_source", _test_shared_grayscale_source)
	await _run_test("water_fire_palette_mapping", _test_water_fire_palette_mapping)
	await _run_test("preview_export", _test_preview_export)
	quit(_harness.report("ELEMENT SKILL ICON RENDERER TESTS"))


func _test_supported_icon_set() -> void:
	_expect(_renderer.supports(&"element_bolt"), "element bolt uses the runtime icon renderer")
	_expect(_renderer.supports(&"elemental_laser"), "elemental laser uses the runtime icon renderer")
	_expect(not _renderer.supports(&"burning"), "fixed fire passive keeps its authored icon")


func _test_shared_grayscale_source() -> void:
	for skill_id: StringName in [&"element_bolt", &"elemental_laser"]:
		var image := _renderer.grayscale_image(skill_id)
		_expect(image != null and image.get_size() == Vector2i(16, 16), "%s has one 16x16 grayscale source" % String(skill_id))
		_expect(image.detect_alpha() != Image.ALPHA_NONE, "%s keeps transparent padding" % String(skill_id))
		var visible_count := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a <= 0.0:
					continue
				visible_count += 1
				_expect(
					is_equal_approx(pixel.r, pixel.g) and is_equal_approx(pixel.g, pixel.b),
					"%s source pixel is grayscale at %s" % [String(skill_id), str(Vector2i(x, y))]
				)
		_expect(visible_count > 0, "%s grayscale source contains a visible glyph" % String(skill_id))


func _test_water_fire_palette_mapping() -> void:
	for skill_id: StringName in [&"element_bolt", &"elemental_laser"]:
		var base := _renderer.grayscale_image(skill_id)
		var water_texture := _renderer.texture_for(skill_id, ElementIds.WATER)
		var fire_texture := _renderer.texture_for(skill_id, ElementIds.FIRE)
		var water := water_texture.get_image()
		var fire := fire_texture.get_image()
		_expect(water.get_size() == base.get_size() and fire.get_size() == base.get_size(), "%s tint keeps source dimensions" % String(skill_id))
		_expect(water_texture == _renderer.texture_for(skill_id, ElementIds.WATER), "%s water texture is cached" % String(skill_id))
		_expect(fire_texture == _renderer.texture_for(skill_id, ElementIds.FIRE), "%s fire texture is cached" % String(skill_id))
		var different_visible_pixels := 0
		for y: int in base.get_height():
			for x: int in base.get_width():
				var base_pixel := base.get_pixel(x, y)
				var water_pixel := water.get_pixel(x, y)
				var fire_pixel := fire.get_pixel(x, y)
				_expect(is_equal_approx(base_pixel.a, water_pixel.a), "%s water tint preserves alpha at %s" % [String(skill_id), str(Vector2i(x, y))])
				_expect(is_equal_approx(base_pixel.a, fire_pixel.a), "%s fire tint preserves alpha at %s" % [String(skill_id), str(Vector2i(x, y))])
				if base_pixel.a > 0.0 and not water_pixel.is_equal_approx(fire_pixel):
					different_visible_pixels += 1
		_expect(different_visible_pixels > 0, "%s water and fire variants use different palettes" % String(skill_id))


func _test_preview_export() -> void:
	const OUTPUT_DIR := "res://docs/agent_tasks/evidence/skill_icon_runtime"
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	_expect(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "preview output directory is available")
	var preview := Image.create(176, 176, false, Image.FORMAT_RGBA8)
	preview.fill(Color("080c12"))
	var entries: Array[Dictionary] = [
		{&"skill": &"element_bolt", &"element": ElementIds.WATER, &"position": Vector2i(12, 12), &"name": "element_bolt_water_16.png"},
		{&"skill": &"element_bolt", &"element": ElementIds.FIRE, &"position": Vector2i(96, 12), &"name": "element_bolt_fire_16.png"},
		{&"skill": &"elemental_laser", &"element": ElementIds.WATER, &"position": Vector2i(12, 96), &"name": "elemental_laser_water_16.png"},
		{&"skill": &"elemental_laser", &"element": ElementIds.FIRE, &"position": Vector2i(96, 96), &"name": "elemental_laser_fire_16.png"},
	]
	for entry: Dictionary in entries:
		var image := _renderer.texture_for(entry[&"skill"], entry[&"element"]).get_image()
		var save_path := "%s/%s" % [OUTPUT_DIR, String(entry[&"name"])]
		_expect(image.save_png(save_path) == OK, "exports %s" % String(entry[&"name"]))
		image.resize(68, 68, Image.INTERPOLATE_NEAREST)
		preview.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), entry[&"position"])
	_expect(
		preview.save_png("%s/element_skill_icons_water_fire_preview.png" % OUTPUT_DIR) == OK,
		"exports combined water/fire preview"
	)


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
