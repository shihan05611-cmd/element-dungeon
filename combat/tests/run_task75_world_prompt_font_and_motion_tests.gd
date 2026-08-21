extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const FONT: FontFile = preload("res://assets/ui/fonts/fusion_pixel_12px/fusion-pixel-12px-proportional-zh_hans.otf")
const CHEST_SCENE: PackedScene = preload("res://scenes/run/interactables/run_reward_chest.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/run/interactables/run_route_portal.tscn")
const CROWN_SCENE: PackedScene = preload("res://scenes/run/interactables/run_wishing_crown.tscn")

var _harness := TestHarness.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _harness.run_test("world_prompt_font_outline_and_motion_are_scoped", _test_world_prompt_font_outline_and_motion_are_scoped)
	quit(_harness.report("TASK 75 WORLD PROMPT FONT AND MOTION TESTS"))


func _test_world_prompt_font_outline_and_motion_are_scoped() -> void:
	var chest := CHEST_SCENE.instantiate() as RunWorldInteractable
	var portal := PORTAL_SCENE.instantiate() as RunWorldInteractable
	var crown := CROWN_SCENE.instantiate() as RunWorldInteractable
	root.add_child(chest)
	root.add_child(portal)
	root.add_child(crown)
	await process_frame

	for interactable: RunWorldInteractable in [chest, portal, crown]:
		var prompt := interactable.prompt
		_harness.expect(prompt.get_theme_font(&"font") == FONT, "%s prompt uses the shared Fusion Pixel font" % interactable.name)
		_harness.expect_eq(prompt.get_theme_font_size(&"font_size"), 12, "%s prompt uses the native 12px font rung" % interactable.name)
		_harness.expect(not prompt.has_theme_stylebox_override(&"normal"), "%s prompt has no normal StyleBox background" % interactable.name)
		_harness.expect_eq(prompt.get_theme_constant(&"outline_size"), 2, "%s prompt keeps a 2px hard readability outline" % interactable.name)

	_harness.expect(chest.get_node_or_null("PromptFloat") is AnimationPlayer, "only chest owns the prompt floating AnimationPlayer")
	_harness.expect(portal.get_node_or_null("PromptFloat") == null, "portal prompt remains static")
	_harness.expect(crown.get_node_or_null("PromptFloat") == null, "crown prompt remains static")
	var animation_player := chest.get_node("PromptFloat") as AnimationPlayer
	var animation := animation_player.get_animation(&"prompt_float")
	_harness.expect(animation != null and is_equal_approx(animation.length, 2.4), "chest prompt has a slow 2.4 second loop")
	_harness.expect(animation != null and animation.loop_mode == Animation.LOOP_LINEAR, "chest prompt loop is continuous")
	var chest_base_y := chest.prompt.position.y
	var portal_base_y := portal.prompt.position.y
	var crown_base_y := crown.prompt.position.y
	animation_player.seek(0.0, true)
	animation_player.advance(0.6)
	_harness.expect(is_equal_approx(chest.prompt.position.y, chest_base_y - 3.0), "chest prompt rises by the low 3px amplitude")
	animation_player.advance(1.8)
	_harness.expect(is_equal_approx(chest.prompt.position.y, chest_base_y), "one chest prompt cycle returns exactly to its baseline")
	_harness.expect(is_equal_approx(portal.prompt.position.y, portal_base_y), "portal prompt never moves")
	_harness.expect(is_equal_approx(crown.prompt.position.y, crown_base_y), "crown prompt never moves")

	chest.queue_free()
	portal.queue_free()
	crown.queue_free()
	await process_frame
