extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const HUD_SCENE: PackedScene = preload("res://scenes/combat_hud.tscn")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const THEME: Theme = preload("res://resources/ui/combat_hud.theme")
const FONT: FontFile = preload("res://assets/ui/fonts/fusion_pixel_12px/fusion-pixel-12px-proportional-zh_hans.otf")
const UI := preload("res://scripts/ui/combat_ui_tokens.gd")

var _harness := TestHarness.new()
var _hud: CombatHUD


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	_hud = HUD_SCENE.instantiate() as CombatHUD
	root.add_child(_hud)
	current_scene = _hud
	await process_frame
	await process_frame
	_run_test("font_import_keeps_pixel_edges", _test_font_import)
	_run_test("pixel_type_scale_is_tokenized", _test_type_scale)
	_run_test("static_hud_panels_use_theme_variations", _test_theme_variations)
	_run_test("task72_and_task74_geometry_is_preserved", _test_geometry)
	await _run_async_test("task12_compatibility_slots_keep_order_after_font_change", _test_compatibility_slot_order)
	if is_instance_valid(_hud):
		_hud.queue_free()
	await process_frame
	quit(_harness.report("TASK 73 PIXEL FONT AND HUD THEME TESTS"))


func _test_font_import() -> void:
	_expect(THEME.default_font == FONT, "combat HUD Theme uses Fusion Pixel proportional zh-Hans")
	_expect(THEME.default_font_size == UI.FONT_BODY, "Theme default size is the native 12px rung")
	_expect(int(FONT.get("antialiasing")) == 0, "font antialiasing is None")
	_expect(int(FONT.get("hinting")) == 0, "font hinting is None")
	_expect(int(FONT.get("subpixel_positioning")) == 0, "font subpixel positioning is Disabled")
	_expect(not bool(FONT.get("multichannel_signed_distance_field")), "font MSDF is disabled")


func _test_type_scale() -> void:
	_expect(UI.FONT_CAPTION == 12 and UI.FONT_BODY == 12 and UI.FONT_EMPHASIS == 12 and UI.FONT_TITLE == 24, "four semantic roles map to 12px and 24px integer multiple")


func _test_theme_variations() -> void:
	_expect(_hud.get_node("Root").theme == THEME, "HUD root owns the shared Theme resource")
	for entry: Dictionary in [
		{"path": "Root/StatusPanel", "variation": &"", "extracted": true},
		{"path": "Root/SkillPanel", "variation": &"HudPanelActive", "extracted": true},
		{"path": "Root/PassivePanel", "variation": &"HudPanelPassive", "extracted": true},
		{"path": "Root/BossPanel", "variation": &"HudPanelBoss", "extracted": false},
		{"path": "Root/SkillPanel/Margin/Skills/SlotRow/active_1", "variation": &"HudPanelSlot", "extracted": true},
		{"path": "Root/PassivePanel/Margin/SlotRow/passive_1", "variation": &"HudPanelPassiveSlot", "extracted": true},
	]:
		var panel := _hud.get_node(entry.path) as PanelContainer
		_expect(panel.theme_type_variation == entry.variation, "%s uses %s" % [entry.path, String(entry.variation)])
		if entry.extracted:
			_expect(panel.has_theme_stylebox_override(&"panel") and panel.get_theme_stylebox(&"panel") is StyleBoxEmpty, "%s delegates drawing to its approved extracted texture" % entry.path)
		else:
			_expect(not panel.has_theme_stylebox_override(&"panel"), "%s keeps its theme-owned panel" % entry.path)
	for variation: StringName in [&"HudPanel", &"HudPanelEmphasis", &"HudPanelBoss", &"HudPanelSlot", &"HudPanelPassiveSlot", &"HudPanelKey"]:
		var style := THEME.get_stylebox(&"panel", variation) as StyleBoxFlat
		_expect(style != null and style.corner_radius_top_left == 0 and style.corner_radius_top_right == 0 and style.corner_radius_bottom_left == 0 and style.corner_radius_bottom_right == 0, "%s is an integer hard-corner pixel panel" % String(variation))


func _test_geometry() -> void:
	_expect(CombatHUD.PASSIVE_SLOT_SIZE.x * CombatHUD.PASSIVE_SLOT_SIZE.y < CombatHUD.ACTIVE_SLOT_SIZE.x * CombatHUD.ACTIVE_SLOT_SIZE.y, "passive slots stay smaller than active slots")
	_expect(CombatHUD.PASSIVE_STRIP_SIZE.x < CombatHUD.SKILL_STRIP_SIZE.x, "passive strip stays narrower than the active strip")
	_expect(CombatHUD.STATUS_SIZE.x * CombatHUD.STATUS_SIZE.y + CombatHUD.SKILL_STRIP_SIZE.x * CombatHUD.SKILL_STRIP_SIZE.y + CombatHUD.PASSIVE_STRIP_SIZE.x * CombatHUD.PASSIVE_STRIP_SIZE.y <= 1152.0 * 648.0 * 0.125, "permanent HUD stays within the minimum-canvas density budget")


func _test_compatibility_slot_order() -> void:
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	await process_frame
	await physics_frame
	var room_hud := room.get_node("CombatHUD") as CombatHUD
	for viewport_size: Vector2i in [Vector2i(1152, 648), Vector2i(900, 540), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		var previous_end := -INF
		for slot_id: StringName in [SkillSlotIds.ACTIVE_1, SkillSlotIds.ACTIVE_2, SkillSlotIds.ACTIVE_3, SkillSlotIds.PASSIVE_1]:
			var slot := room_hud.slot_panel(slot_id)
			var rect := slot.get_global_rect()
			print("TASK73 COMPAT %s %s rect=%s minimum=%s" % [str(viewport_size), String(slot_id), str(rect), str(slot.get_combined_minimum_size())])
			_expect(rect.position.x >= previous_end, "%s does not overlap its preceding task12 adapter slot at %s" % [String(slot_id), str(viewport_size)])
			previous_end = rect.end.x
	root.size = Vector2i(1152, 648)
	room.queue_free()
	await process_frame


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _run_async_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
