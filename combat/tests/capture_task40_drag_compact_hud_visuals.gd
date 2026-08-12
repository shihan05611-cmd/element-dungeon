extends SceneTree

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task40/viewport"
const DRAG_KIND := &"formal_shop_loadout"

var _assertions: int = 0
var _failures: Array[String] = []
var _images: Dictionary[String, Image] = {}
var _hit_sequence: int = 4090000
var _coordinator: RunFlowCoordinator
var _hud: CombatHUD
var _overlay: RunOverlayInterface


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	call_deferred(&"_run")


func _run() -> void:
	_expect(await _boot(), "Task40 capture boots formal RunGame")
	if _coordinator == null:
		_finish()
		return

	await _capture_combat("01_combat_hud_1920x1080.png", Vector2i(1920, 1080), &"combat_01_entry", false)
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "capture reaches first formal shop")
	await _capture_shop("02_shop_before_click_1920x1080.png", Vector2i(1920, 1080), &"element_bolt", SkillSlotIds.ACTIVE_1)

	var click_before := _coordinator.current_snapshot()
	_expect(_press(&"select:element_bolt"), "capture clicks the owned element-bolt card")
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, click_before.revision, "card click is still non-committing")
	_expect(_visible_text(_overlay).contains("待装配：元素弹"), "click selection is visibly recoverable")
	await _capture_shop("03_shop_after_click_before_drag_1920x1080.png", Vector2i(1920, 1080), &"element_bolt", SkillSlotIds.ACTIVE_1)

	var drag_before := _coordinator.current_snapshot()
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_bolt", &""), SkillSlotIds.ACTIVE_2)
	await process_frame
	var drag_after := _coordinator.current_snapshot()
	_expect_eq(drag_after.revision, drag_before.revision + 1, "one card drop advances authority exactly once")
	_expect(drag_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1).is_empty(), "card drag clears the prior authoritative slot")
	_expect_eq(drag_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"element_bolt", "card drag fills A2 authoritatively")
	_expect(_visible_text(_overlay).contains("拖拽装配已由权威"), "card drag success feedback is visible")
	await _capture_shop("04_shop_after_card_drag_1920x1080.png", Vector2i(1920, 1080), &"element_bolt", SkillSlotIds.ACTIVE_2)

	_expect(_press(&"purchase:element_reclaim"), "capture purchases reclaim through visible control")
	await process_frame
	_expect(_coordinator.current_snapshot().skills.owns(&"element_reclaim"), "reclaim ownership is authoritative before slot drag")
	var equip_before := _coordinator.current_snapshot()
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_reclaim", &""), SkillSlotIds.ACTIVE_1)
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, equip_before.revision + 1, "reclaim card drop advances once")
	var swap_before := _coordinator.current_snapshot()
	_overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_reclaim", SkillSlotIds.ACTIVE_1), SkillSlotIds.ACTIVE_2)
	await process_frame
	var swap_after := _coordinator.current_snapshot()
	_expect_eq(swap_after.revision, swap_before.revision + 1, "one slot-to-slot drop advances once")
	_expect_eq(swap_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1), &"element_bolt", "slot swap moves target content back to A1")
	_expect_eq(swap_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"element_reclaim", "slot swap moves dragged content into A2")
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(swap_after.loadout), "slot swap keeps RuntimeLoadout aligned")
	await _capture_shop("05_shop_after_slot_swap_2560x1440.png", Vector2i(2560, 1440), &"element_reclaim", SkillSlotIds.ACTIVE_2)

	_expect(_press(&"leave_shop"), "capture leaves first shop")
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "capture reaches route one")
	await _select_route(&"route_01_pressure", &"combat_02_pressure")
	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_03_layer_elite"), "capture reaches combat three")
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "capture reaches middle shop")
	_expect(_press(&"leave_shop"), "capture leaves middle shop")
	_expect(await _wait_for_room(&"combat_04_validation"), "capture reaches combat four")
	await _capture_combat("06_combat_hud_1366x768.png", Vector2i(1366, 768), &"combat_04_validation", false)
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "capture reaches route two")
	await _select_route(&"route_02_risk", &"combat_05_risk")
	await _capture_combat("07_corridor_title_2560x1440.png", Vector2i(2560, 1440), &"combat_05_risk", true)

	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Task40 viewport directory is writable")
		for file_name: String in _images:
			var image: Image = _images[file_name]
			_expect(image != null, "%s retains a gated Viewport image" % file_name)
			if image == null:
				continue
			var review_image := image.duplicate()
			review_image.convert(Image.FORMAT_RGB8)
			var png_path := directory.path_join(file_name)
			_expect(review_image.save_png(png_path) == OK, "%s saves only after all gates" % file_name)
			var decoded := Image.load_from_file(png_path)
			_expect(decoded != null and decoded.get_size() == review_image.get_size(), "%s round-trips at actual size" % file_name)
			if decoded != null:
				decoded.convert(Image.FORMAT_RGB8)
				_expect(decoded.get_data() == review_image.get_data(), "%s decoded pixels match the gated Viewport" % file_name)
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _boot() -> bool:
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	if _coordinator == null:
		return false
	root.add_child(_coordinator)
	current_scene = _coordinator
	var booted := await _wait_for_room(&"combat_01_entry")
	if booted:
		_hud = _coordinator.combat_hud
		_overlay = _hud.run_overlay as RunOverlayInterface
	return booted


func _capture_combat(file_name: String, size: Vector2i, room_id: StringName, assert_title_clear: bool) -> void:
	await _set_size(size)
	_expect(await _wait_for_feedback_clear(), "%s clears transition feedback" % file_name)
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.phase, RunPhase.COMBAT, "%s authority phase is combat" % file_name)
	_expect(_coordinator.active_room != null and _coordinator.active_room.configured, "%s uses a configured real room" % file_name)
	_expect_eq(_coordinator.active_room.room_id, room_id, "%s room identity is exact" % file_name)
	_expect_eq(snapshot.loadout.entries.size(), 7, "%s keeps the exact seven-slot snapshot" % file_name)
	_expect(not _overlay.visible and _overlay.formal_kind() == &"combat", "%s has no covering formal overlay" % file_name)
	_expect(_inside(_hud.status_panel.get_global_rect(), size), "%s status capsule is in bounds" % file_name)
	_expect(_inside(_hud.skill_panel.get_global_rect(), size), "%s active belt is in bounds" % file_name)
	_expect(_inside(_hud.passive_panel.get_global_rect(), size), "%s passive belt is in bounds" % file_name)
	_expect(_hud.get_node_or_null("Root/SkillPanel/BusyOverlay/BusyStrip") == null, "%s has no purple BusyStrip" % file_name)
	var state := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1).get_node("Margin/Body/State") as Label
	_expect(state.text.is_empty() and not state.visible, "%s has no persistent ready copy" % file_name)
	if assert_title_clear:
		var title := _coordinator.active_room.get_node_or_null("RoomTitle") as Label
		_expect(title != null and title.visible and not title.text.is_empty(), "%s has a visible authoritative room title" % file_name)
		if title != null:
			var status_rect := _hud.status_panel.get_global_rect()
			var title_rect := title.get_global_rect()
			_expect(
				not status_rect.intersects(title_rect),
				"%s HP capsule no longer overlaps the room title (status=%s title=%s)" % [file_name, str(status_rect), str(title_rect)]
			)
	await _store_capture(file_name, size)


func _capture_shop(file_name: String, size: Vector2i, expected_skill_id: StringName, expected_slot_id: StringName) -> void:
	await _set_size(size)
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.phase, RunPhase.SHOP, "%s authority phase is shop" % file_name)
	_expect(_overlay.visible and _overlay.formal_kind() == &"shop", "%s shows the formal shop" % file_name)
	_expect_eq(snapshot.loadout.entries.size(), 7, "%s keeps seven authoritative slots" % file_name)
	_expect_eq(snapshot.loadout.get_skill_id(expected_slot_id), expected_skill_id, "%s has the expected authoritative mapping" % file_name)
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(snapshot.loadout), "%s RuntimeLoadout matches snapshot" % file_name)
	_expect(_inside((_overlay.get("_panel") as Control).get_global_rect(), size), "%s shop panel is in bounds" % file_name)
	await _store_capture(file_name, size)


func _select_route(option_id: StringName, room_id: StringName) -> void:
	var cards := _overlay.formal_route_cards()
	var focused := false
	var options := _coordinator.current_snapshot().route.next_options
	for index: int in options.size():
		if options[index].option_id == option_id and index < cards.size():
			cards[index].pressed.emit()
			focused = true
			break
	await process_frame
	_expect(focused and _overlay.formal_selected_route_id() == option_id, "route %s is focused without submitting" % String(option_id))
	_expect(_overlay.formal_route_confirm_button() != null and not _overlay.formal_route_confirm_button().disabled, "focused route enables independent confirm")
	_overlay.formal_route_confirm_button().pressed.emit()
	_expect(await _wait_for_room(room_id), "route confirmation loads %s" % String(room_id))


func _payload(skill_id: StringName, source_slot_id: StringName) -> Dictionary:
	return {
		"kind": DRAG_KIND,
		"skill_id": skill_id,
		"source_slot_id": source_slot_id,
	}


func _press(control_id: StringName) -> bool:
	var button := _overlay.formal_control(control_id) as Button
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


func _defeat_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "capture active room is configured")
	if room == null:
		return
	for enemy: CombatEnemy in room.enemies:
		_hit_sequence += 1
		var cast := CastSnapshot.new(
			_hit_sequence,
			&"task40_capture_finisher",
			_coordinator.player.get_instance_id(),
			_coordinator.player.get_instance_id(),
			&"player",
			ElementIds.NONE,
			CombatStatSnapshot.new()
		)
		var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
		var request := HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var result := enemy.combat_receiver.receive_hit(request)
		_expect(result.accepted and enemy.defeated, "capture enemy is defeated through CombatReceiver")
	await process_frame


func _wait_for_room(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.active_room != null
			and _coordinator.active_room.room_id == room_id
			and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
		)
	, 600)


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator != null and _coordinator.current_snapshot().route.phase == phase
	, 600)


func _wait_for_feedback_clear() -> bool:
	var deadline := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		var feedback := _hud.get_node("Root/FeedbackPanel") as Control
		if not feedback.is_visible_in_tree():
			return true
		await process_frame
	return not (_hud.get_node("Root/FeedbackPanel") as Control).is_visible_in_tree()


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _set_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for _frame: int in 5:
		await process_frame
	_expect_eq(DisplayServer.window_get_size(), size, "window reaches requested %s" % str(size))


func _store_capture(file_name: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image != null and image.get_size() == expected_size, "%s is an actual %s Viewport" % [file_name, str(expected_size)])
	if image != null:
		_images[file_name] = image


func _visible_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_visible_text(node, lines)
	return "\n".join(PackedStringArray(lines))


func _collect_visible_text(node: Node, lines: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_visible_text(child, lines)


func _inside(rect: Rect2, size: Vector2i) -> bool:
	return (
		rect.position.x >= -0.2
		and rect.position.y >= -0.2
		and rect.end.x <= size.x + 0.2
		and rect.end.y <= size.y + 0.2
	)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 40 DRAG COMPACT HUD VISUAL CAPTURE PASSED: 1 tests, %d assertions, %d screenshots" % [_assertions, _images.size()])
		quit(0)
	else:
		printerr("TASK 40 DRAG COMPACT HUD VISUAL CAPTURE FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
