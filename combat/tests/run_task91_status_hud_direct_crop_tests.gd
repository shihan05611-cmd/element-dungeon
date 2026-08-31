extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _hud: CombatHUD
var _player: PlayerCharacter


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_player = _room.get_node("Player") as PlayerCharacter
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)

	_run_test("direct_concept_crop_dimensions_and_transparent_runtime_slots", _test_crop_resources)
	_run_test("water_fire_swap_keeps_geometry_and_runtime_values", _test_element_swap_and_runtime_values)

	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 91 STATUS HUD DIRECT CROP TESTS"))


func _test_crop_resources() -> void:
	_expect(CombatHUD.STATUS_WATER_TEXTURE.get_size() == CombatHUD.STATUS_SIZE, "water crop uses the fixed 264x87 concept ratio")
	_expect(CombatHUD.STATUS_FIRE_TEXTURE.get_size() == CombatHUD.STATUS_SIZE, "fire crop uses the same fixed 264x87 concept ratio")
	for texture: Texture2D in [CombatHUD.STATUS_WATER_TEXTURE, CombatHUD.STATUS_FIRE_TEXTURE]:
		var image := texture.get_image()
		_expect(image.get_pixel(100, 24).a == 0.0 and image.get_pixel(100, 58).a == 0.0, "concept crop leaves both bar interiors transparent for runtime fills")


func _test_element_swap_and_runtime_values() -> void:
	var before := _hud.status_panel.get_global_rect()
	var caption := _hud.get_node("Root/StatusPanel/Margin/Status/HealthRow/Label") as Label
	_expect(caption != null and not caption.visible, "legacy HP label node is retained but does not double-render")
	var fire := _player.request_element(ElementIds.FIRE)
	_expect(fire.accepted, "fire element request is accepted")
	_expect(_hud.get_node("Root/StatusPanel/ElementSkin").texture == CombatHUD.STATUS_FIRE_TEXTURE, "fire selects the direct fire concept crop")
	_expect(_hud.status_panel.get_global_rect().is_equal_approx(before), "fire switch preserves status geometry")
	_player.energy_component.set_current(34)
	_expect(_hud.energy_value.text.contains("34 /"), "runtime SP text still refreshes")
	var receiver := _player.damage_receiver
	var original := receiver.current_health
	_expect(receiver.replace_health_silent(20), "non-full HP fixture applies")
	receiver.notify_health_changed(20 - original)
	_expect(_hud.health_value.text.contains("20 /") and _hud.low_health.visible, "runtime HP fill/value and low-health indicator still refresh")
	var water := _player.request_element(ElementIds.WATER)
	_expect(water.accepted, "water element request is accepted")
	_expect(_hud.get_node("Root/StatusPanel/ElementSkin").texture == CombatHUD.STATUS_WATER_TEXTURE, "water selects the direct water concept crop")
	_expect(_hud.status_panel.get_global_rect().is_equal_approx(before), "water switch preserves status geometry")


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
