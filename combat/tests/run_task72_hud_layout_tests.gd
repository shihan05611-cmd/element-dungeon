extends SceneTree

## Task 72: HUD layout skeleton convergence + room title relocation.
## Covers docs/agent_tasks/pending/72_hud_layout_skeleton_and_room_title.md
## §5.2 point 3 -- this file is the regression gate for task 73 (pixel font /
## HUD theme), which must not reopen any of these layout guarantees.

const TestHarness := preload("res://combat/tests/test_harness.gd")
const HUD_SCENE: PackedScene = preload("res://scenes/combat_hud.tscn")

const CANVAS_SIZE := Vector2(1152, 648)
const SAFE_MARGIN := 16.0

var _harness := TestHarness.new()
var _hud: CombatHUD


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(int(CANVAS_SIZE.x), int(CANVAS_SIZE.y))
	_hud = HUD_SCENE.instantiate() as CombatHUD
	_expect(_hud != null, "CombatHUD scene instantiates")
	root.add_child(_hud)
	current_scene = _hud
	await process_frame
	await process_frame

	_run_test("no_overlap_boss_hidden", _test_no_overlap_boss_hidden)
	_run_test("no_overlap_boss_visible", _test_no_overlap_boss_visible)
	_run_test("every_panel_keeps_16px_safe_margin", _test_safe_margin)
	_run_test("room_progress_removed_from_hud", _test_room_progress_removed_from_hud)
	_run_test("b5_passive_slot_downgrade", _test_b5_passive_downgrade)
	_run_test("active_slot_values_unchanged", _test_active_slot_unchanged)

	if is_instance_valid(_hud):
		_hud.queue_free()
	await process_frame
	quit(_harness.report("TASK 72 HUD LAYOUT TESTS"))


# ---------------------------------------------------------------------------
# B1 hard target 1: any two simultaneously visible top-level panels have an
# empty rect intersection. Covers both the Boss-hidden and Boss-visible
# states, per §5.2 point 3.
# ---------------------------------------------------------------------------
func _test_no_overlap_boss_hidden() -> void:
	_hud.boss_panel.visible = false
	_assert_no_overlap(_visible_top_level_rects(), "boss hidden")


func _test_no_overlap_boss_visible() -> void:
	_hud.boss_panel.visible = true
	_assert_no_overlap(_visible_top_level_rects(), "boss visible")
	_hud.boss_panel.visible = false


func _visible_top_level_rects() -> Dictionary:
	var rects: Dictionary = {}
	var root_control := _hud.get_node("Root") as Control
	for child: Node in root_control.get_children():
		var control := child as Control
		if control == null:
			continue
		if not control.visible:
			continue
		if control.size.x <= 0.0 or control.size.y <= 0.0:
			continue
		rects[control.name] = control.get_global_rect()
	return rects


func _assert_no_overlap(rects: Dictionary, state_label: String) -> void:
	var names: Array = rects.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			_expect(
				not a.intersects(b),
				"[%s] %s does not overlap %s (a=%s b=%s)" % [state_label, names[i], names[j], str(a), str(b)]
			)


# ---------------------------------------------------------------------------
# B1 hard target 2: every top-level panel stays >=16px from every canvas edge.
# ---------------------------------------------------------------------------
func _test_safe_margin() -> void:
	_hud.boss_panel.visible = true
	for entry in _visible_top_level_rects().values():
		var rect: Rect2 = entry
		_expect(rect.position.x >= SAFE_MARGIN - 0.1, "left margin >=16 for rect %s" % str(rect))
		_expect(rect.position.y >= SAFE_MARGIN - 0.1, "top margin >=16 for rect %s" % str(rect))
		_expect(CANVAS_SIZE.x - rect.end.x >= SAFE_MARGIN - 0.1, "right margin >=16 for rect %s" % str(rect))
		_expect(CANVAS_SIZE.y - rect.end.y >= SAFE_MARGIN - 0.1, "bottom margin >=16 for rect %s" % str(rect))
	_hud.boss_panel.visible = false


# ---------------------------------------------------------------------------
# B3 replacement: the room-progress/title band below the status capsule has
# been removed from the combat HUD.
# ---------------------------------------------------------------------------
func _test_room_progress_removed_from_hud() -> void:
	_expect(_hud.get_node_or_null("Root/RoomTitle") == null, "HUD no longer builds the room progress/title band")


# ---------------------------------------------------------------------------
# B5 / §0.1.2: the passive belt must read as visually subordinate to the
# active belt, not just spatially separated.
# ---------------------------------------------------------------------------
func _test_b5_passive_downgrade() -> void:
	_expect(
		CombatHUD.PASSIVE_SLOT_SIZE.x <= CombatHUD.ACTIVE_SLOT_SIZE.x * 0.8 + 0.01,
		"criterion 1: passive slot width (%s) <= 80%% of active slot width (%s)" % [CombatHUD.PASSIVE_SLOT_SIZE.x, CombatHUD.ACTIVE_SLOT_SIZE.x]
	)
	_expect(
		CombatHUD.PASSIVE_STRIP_SIZE.x <= CombatHUD.SKILL_STRIP_SIZE.x * 0.85 + 0.01,
		"criterion 2: passive strip width (%s) <= 85%% of skill strip width (%s)" % [CombatHUD.PASSIVE_STRIP_SIZE.x, CombatHUD.SKILL_STRIP_SIZE.x]
	)
	var passive_rect := _hud.passive_panel.get_global_rect()
	_expect(absf(CANVAS_SIZE.x - passive_rect.end.x - 51.0) <= 0.5, "criterion 3a: passive strip keeps Task95's fixed 51px right margin")
	_expect(absf(CANVAS_SIZE.y - passive_rect.end.y - 18.0) <= 0.5, "criterion 3b: passive strip keeps Task95's fixed 18px bottom margin")
	for slot_id: StringName in SkillSlotIds.passive():
		var panel := _hud.visual_slot_panel(slot_id)
		_expect(panel.custom_minimum_size == CombatHUD.PASSIVE_SLOT_SIZE, "criterion 4: %s uses the exact Task95 passive source footprint" % String(slot_id))


# ---------------------------------------------------------------------------
# Task95 intentional active source geometry: exact one-third shares of 324x85.
# ---------------------------------------------------------------------------
func _test_active_slot_unchanged() -> void:
	_expect(CombatHUD.ACTIVE_SLOT_SIZE == Vector2(108, 85), "ACTIVE_SLOT_SIZE is the exact Task95 frame division")
	for slot_id: StringName in SkillSlotIds.active():
		var panel := _hud.visual_slot_panel(slot_id)
		_expect(panel.custom_minimum_size == CombatHUD.ACTIVE_SLOT_SIZE, "%s uses the shared reduced active size" % String(slot_id))
		var body := panel.get_node("Margin/Body") as Control
		_expect(body.custom_minimum_size == CombatHUD.ACTIVE_SLOT_SIZE, "%s Body uses the Task95 active footprint" % String(slot_id))
		var icon := body.get_node("Icon") as Control
		_expect(icon.size == Vector2(48, 48), "%s Icon uses the Task95 readable 48px footprint" % String(slot_id))
		var fields := _hud.slot_visible_fields(slot_id)
		_expect(fields.has(&"icon") and fields.has(&"key") and fields.has(&"cost"), "%s retains the compact active affordances" % String(slot_id))


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
