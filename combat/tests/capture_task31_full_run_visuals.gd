extends SceneTree

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task31/viewport"
const PASSIVE_IDS: Array[StringName] = [
	&"burning",
	&"unending",
	&"passive_vitality",
	&"passive_energy",
]

var _assertions: int = 0
var _failures: Array[String] = []
var _images: Dictionary[String, Image] = {}
var _hit_sequence: int = 3190000
var _coordinator: RunFlowCoordinator
var _hud: CombatHUD
var _overlay: RunOverlayInterface


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	call_deferred(&"_run")


func _run() -> void:
	var safe_run_id := _pre_shop_dust_run_id("task31_capture_safe")
	_expect(await _boot(safe_run_id), "capture boots the formal first RunGame")
	if _coordinator == null:
		_finish()
		return

	await _capture_combat("01_first_combat1_flat_1920x1080.png", Vector2i(1920, 1080), &"combat_01_entry", &"arena_flat", 0)
	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_02_swarm"), "first capture reaches fixed combat two")
	await _capture_combat("02_first_combat2_flat_1920x1080.png", Vector2i(1920, 1080), &"combat_02_swarm", &"arena_flat", 0)
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "first capture reaches the single shop")
	await _purchase_and_equip(&"burning", SkillSlotIds.PASSIVE_1)
	await _purchase_and_equip(&"unending", SkillSlotIds.PASSIVE_2)
	await _purchase_and_equip(&"passive_vitality", SkillSlotIds.PASSIVE_3)
	await _purchase_and_equip(&"passive_energy", SkillSlotIds.PASSIVE_4)
	await _capture_shop("03_first_single_shop_four_passives_1920x1080.png", Vector2i(1920, 1080), 70, 4)
	await _leave_physical_shop()
	_expect(await _wait_for_room(&"combat_04_validation"), "first capture reaches combat three")
	await _capture_combat("04_first_combat3_four_passives_1920x1080.png", Vector2i(1920, 1080), &"combat_04_validation", &"arena_flat", 4)
	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_06_final_boss"), "first capture reaches boss")
	await _capture_combat("05_first_boss_1920x1080.png", Vector2i(1920, 1080), &"combat_06_final_boss", &"arena_boss", 4)
	var first_boss_balance := _coordinator.current_snapshot().economy.balance
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.RUN_COMPLETE), "first capture reaches complete result")
	_assert_complete_result(495, 300, 0, 0, 195, first_boss_balance, [], "first")
	await _capture_result("06_first_result_1920x1080.png", Vector2i(1920, 1080), false)

	var first_session_id := _coordinator.host.run_session.get_instance_id()
	var first_authority_id := _coordinator.current_snapshot().route.run_id
	var second_run_id := _pre_shop_dust_run_id("task31_capture_second")
	var scene_changed_signal: Signal = scene_changed
	_expect(_press(&"new_run"), "first result starts the second run through formal UI")
	await scene_changed_signal
	_coordinator = current_scene as RunFlowCoordinator
	_expect(_coordinator != null, "second capture receives replacement RunGame")
	if _coordinator == null:
		_finish()
		return
	_coordinator.run_id_override = second_run_id
	_expect(await _wait_for_room(&"combat_01_entry"), "second capture boots combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface
	_expect(_coordinator.host.run_session.get_instance_id() != first_session_id, "second capture has a new RunSession")
	_expect(_coordinator.current_snapshot().route.run_id != first_authority_id, "second capture has a new run ID")
	_assert_fresh_authority("second new run")
	await _capture_combat("07_second_new_run_flat_2560x1440.png", Vector2i(2560, 1440), &"combat_01_entry", &"arena_flat", 0)
	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_02_swarm"), "second capture reaches fixed combat two")
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "second capture reaches the single shop")
	await _purchase_and_equip(&"burning", SkillSlotIds.PASSIVE_1)
	await _purchase_and_equip(&"unending", SkillSlotIds.PASSIVE_2)
	await _purchase_and_equip(&"passive_vitality", SkillSlotIds.PASSIVE_3)
	await _purchase_and_equip(&"passive_energy", SkillSlotIds.PASSIVE_4)
	await _capture_shop("08_second_single_shop_four_passives_2560x1440.png", Vector2i(2560, 1440), 70, 4)
	await _leave_physical_shop()
	_expect(await _wait_for_room(&"combat_04_validation"), "second capture reaches combat three")
	await _capture_combat("09_second_combat3_four_passives_2560x1440.png", Vector2i(2560, 1440), &"combat_04_validation", &"arena_flat", 4)
	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_06_final_boss"), "second capture reaches boss")
	await _capture_combat("10_second_boss_2560x1440.png", Vector2i(2560, 1440), &"combat_06_final_boss", &"arena_boss", 4)
	var second_boss_balance := _coordinator.current_snapshot().economy.balance
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.RUN_COMPLETE), "second capture reaches complete result")
	_assert_complete_result(495, 300, 0, 0, 195, second_boss_balance, [], "second")
	await _capture_result("11_second_result_2560x1440.png", Vector2i(2560, 1440), false)

	var second_session_id := _coordinator.host.run_session.get_instance_id()
	var second_authority_id := _coordinator.current_snapshot().route.run_id
	scene_changed_signal = scene_changed
	_expect(_press(&"new_run"), "second result starts a fresh authority")
	await scene_changed_signal
	_coordinator = current_scene as RunFlowCoordinator
	_expect(_coordinator != null, "post-second new run creates a coordinator")
	if _coordinator == null:
		_finish()
		return
	_expect(await _wait_for_room(&"combat_01_entry"), "post-second new run boots combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface
	_expect(_coordinator.host.run_session.get_instance_id() != second_session_id, "post-second new run replaces RunSession")
	_expect(_coordinator.current_snapshot().route.run_id != second_authority_id, "post-second new run replaces run ID")
	_assert_fresh_authority("post-second new run")
	await _capture_combat("12_new_run_reset_2560x1440.png", Vector2i(2560, 1440), &"combat_01_entry", &"arena_flat", 0)
	await _defeat_player()
	_expect(await _wait_for_phase(RunPhase.RUN_FAILED), "capture reaches failed result through real player receiver")
	await _capture_result("13_failed_result_2560x1440.png", Vector2i(2560, 1440), true)

	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Task31 viewport directory is writable")
		for file_name: String in _images:
			var image: Image = _images[file_name]
			_expect(image != null and image.detect_alpha() == Image.ALPHA_NONE, "%s is a fully opaque real Viewport" % file_name)
			if image == null:
				continue
			var review_image := image.duplicate()
			review_image.convert(Image.FORMAT_RGB8)
			var png_path := directory.path_join(file_name)
			_expect(_save_unfiltered_rgb_png(review_image, png_path) == OK, "%s saves after all authority gates" % file_name)
			var decoded := Image.load_from_file(png_path)
			_expect(decoded != null and decoded.get_size() == review_image.get_size(), "%s PNG round-trips at actual size" % file_name)
			if decoded != null:
				decoded.convert(Image.FORMAT_RGB8)
				_expect(decoded.get_data() == review_image.get_data(), "%s PNG is pixel-identical to gated Viewport" % file_name)
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _boot(run_id: StringName) -> bool:
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	if _coordinator == null:
		return false
	_coordinator.run_id_override = run_id
	root.add_child(_coordinator)
	current_scene = _coordinator
	var booted := await _wait_for_room(&"combat_01_entry")
	if booted:
		_hud = _coordinator.combat_hud
		_overlay = _hud.run_overlay as RunOverlayInterface
	return booted


func _purchase_and_equip(skill_id: StringName, slot_id: StringName) -> void:
	var before := _coordinator.current_snapshot()
	var content := _coordinator.content_catalog.content_for(skill_id)
	_expect(before.route.phase == RunPhase.SHOP and content != null, "%s purchase has formal shop/content" % String(skill_id))
	_expect(_press(StringName("purchase:%s" % String(skill_id))), "%s purchases through visible control" % String(skill_id))
	await process_frame
	var purchased := _coordinator.current_snapshot()
	_expect(purchased.skills.owns(skill_id), "%s authority ownership commits" % String(skill_id))
	_expect_eq(purchased.economy.balance, before.economy.balance - content.purchase_price, "%s charges exact price once" % String(skill_id))
	_expect(_press(StringName("select:%s" % String(skill_id))), "%s selects through formal inventory" % String(skill_id))
	await process_frame
	_expect(_press(StringName("slot:%s" % String(slot_id))), "%s equips through %s" % [String(skill_id), String(slot_id)])
	await process_frame
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(slot_id), skill_id, "%s slot mapping commits" % String(skill_id))
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(_coordinator.current_snapshot().loadout), "%s runtime mapping aligns" % String(skill_id))


func _capture_combat(file_name: String, size: Vector2i, room_id: StringName, template_id: StringName, passive_count: int) -> void:
	await _set_size(size)
	_expect(await _wait_for_combat_feedback_clear(), "%s clears transition feedback before capture" % file_name)
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.phase, RunPhase.COMBAT, "%s authority phase is combat" % file_name)
	_expect(_coordinator.active_room != null and _coordinator.active_room.configured, "%s has a configured real room" % file_name)
	_expect_eq(_coordinator.active_room.room_id, room_id, "%s room identity is exact" % file_name)
	_expect_eq(_coordinator.active_room.template_id, template_id, "%s template identity is exact" % file_name)
	_expect(_coordinator.active_room.get_instance_id() == snapshot.route.active_room_instance_id, "%s room instance matches authority" % file_name)
	_expect(not _overlay.visible and _overlay.formal_kind() == &"combat", "%s leaves combat unobscured" % file_name)
	_expect_eq(snapshot.loadout.entries.size(), 7, "%s has exact seven-slot mapping" % file_name)
	_expect_eq(_equipped_passive_count(snapshot), passive_count, "%s has expected equipped passive count" % file_name)
	if passive_count == 4:
		_assert_four_passives(file_name, true)
	_expect(_inside(_hud.status_panel.get_global_rect(), size), "%s status HUD is in bounds" % file_name)
	_expect(_inside(_hud.skill_panel.get_global_rect(), size), "%s active HUD is in bounds" % file_name)
	_expect(_inside(_hud.passive_panel.get_global_rect(), size), "%s passive HUD is in bounds" % file_name)
	_expect(not _hud.has_visible_target_attachment_text(), "%s has no target attachment text" % file_name)
	await _store_capture(file_name, size)


func _capture_shop(file_name: String, size: Vector2i, balance: int, passive_count: int) -> void:
	await _set_size(size)
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.phase, RunPhase.SHOP, "%s authority phase is shop" % file_name)
	_expect(_overlay.visible and _overlay.formal_kind() == &"shop", "%s shows formal shop" % file_name)
	_expect_eq(snapshot.economy.balance, balance, "%s wallet balance is exact" % file_name)
	_expect(snapshot.economy.is_valid() and snapshot.economy.balance == snapshot.economy.conserved_balance(), "%s wallet conserves" % file_name)
	_expect_eq(snapshot.loadout.entries.size(), 7, "%s shop has exact seven-slot mapping" % file_name)
	_expect_eq(_equipped_passive_count(snapshot), passive_count, "%s has expected passive build" % file_name)
	_expect(_inside((_overlay.get("_panel") as Control).get_global_rect(), size), "%s shop panel is in bounds" % file_name)
	if passive_count == 4:
		_assert_four_passives(file_name, true)
	await _store_capture(file_name, size)


func _capture_result(file_name: String, size: Vector2i, failed: bool) -> void:
	await _set_size(size)
	var snapshot := _coordinator.current_snapshot()
	_expect(snapshot.result != null, "%s has a frozen result" % file_name)
	_expect_eq(snapshot.route.phase, RunPhase.RUN_FAILED if failed else RunPhase.RUN_COMPLETE, "%s result phase is exact" % file_name)
	_expect(_overlay.visible and _overlay.formal_kind() == &"result", "%s shows formal result overlay" % file_name)
	_expect(_button(&"new_run") != null and not _button(&"new_run").disabled, "%s has enabled new-run action" % file_name)
	_expect(_button(&"return_entry") != null and _button(&"return_entry").disabled, "%s keeps unavailable return action disabled" % file_name)
	_expect(_inside((_overlay.get("_panel") as Control).get_global_rect(), size), "%s result panel is in bounds" % file_name)
	if failed:
		_expect(_visible_text(_overlay).contains("DEFEAT"), "%s is unmistakably failed" % file_name)
	else:
		_expect(_visible_text(_overlay).contains("VICTORY"), "%s is unmistakably complete" % file_name)
		_assert_four_passives(file_name, false)
	await _store_capture(file_name, size)


func _assert_four_passives(context: String, require_runtime: bool) -> void:
	var snapshot := _coordinator.current_snapshot()
	for index: int in PASSIVE_IDS.size():
		var slot_id := SkillSlotIds.passive()[index]
		_expect_eq(snapshot.loadout.get_skill_id(slot_id), PASSIVE_IDS[index], "%s P%d mapping is exact" % [context, index + 1])
		_expect(snapshot.skills.owns(PASSIVE_IDS[index]), "%s owns %s" % [context, String(PASSIVE_IDS[index])])
		var progress := snapshot.skills.progress_for(PASSIVE_IDS[index])
		_expect(progress != null and progress.is_passive() and progress.level == 1 and progress.cumulative_upgrade_spend == 0, "%s %s remains level-free" % [context, String(PASSIVE_IDS[index])])
	if require_runtime:
		_expect_eq(_coordinator.host.runtime_loadout.registered_passive_skill_ids, PASSIVE_IDS, "%s runtime has four passives in order" % context)
		_expect_eq(_coordinator.host.runtime_loadout.registered_passive_slot_ids, SkillSlotIds.passive(), "%s runtime covers P1-P4" % context)
		_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(snapshot.loadout), "%s runtime mapping matches authority" % context)


func _assert_complete_result(earned: int, purchases: int, upgrades: int, refunded: int, balance: int, boss_balance: int, routes: Array[StringName], label: String) -> void:
	var final := _coordinator.current_snapshot()
	_expect(final.result != null and final.result.is_complete(), "%s result is complete" % label)
	_expect_eq(final.route.completed_combat_rooms, 4, "%s completes four combat rooms" % label)
	_expect_eq(final.route.shop_visits, 1, "%s visits one shop" % label)
	_expect_eq(final.route.route_choices, 0, "%s confirms zero routes" % label)
	_expect_eq(final.route.selected_route_option_ids, routes, "%s route IDs are frozen" % label)
	_expect_eq(final.economy.total_earned, earned, "%s earned ledger is exact" % label)
	_expect_eq(final.economy.total_spent_on_purchases, purchases, "%s purchase ledger is exact" % label)
	_expect_eq(final.economy.total_spent_on_upgrades, upgrades, "%s upgrade ledger is exact" % label)
	_expect_eq(final.economy.total_refunded, refunded, "%s refund ledger is exact" % label)
	_expect_eq(final.economy.balance, balance, "%s final balance is exact" % label)
	_expect_eq(final.economy.balance, boss_balance, "%s boss awards zero dream dust" % label)
	_expect(final.shop == null and final.pending_reward == null, "%s result has no shop/reward" % label)
	_assert_four_passives(label + " result", false)


func _assert_fresh_authority(context: String) -> void:
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.completed_combat_rooms, 0, "%s resets combat progress" % context)
	_expect_eq(snapshot.route.shop_visits, 0, "%s resets shop progress" % context)
	_expect_eq(snapshot.route.route_choices, 0, "%s resets route progress" % context)
	_expect_eq(snapshot.economy.balance, 0, "%s resets wallet" % context)
	_expect_eq(snapshot.skills.owned_skill_ids, [&"element_bolt"], "%s resets owned skills" % context)
	_expect_eq(_equipped_passive_count(snapshot), 0, "%s resets all passive slots" % context)
	_expect(snapshot.result == null and snapshot.shop == null, "%s has no stale result/shop" % context)


func _equipped_passive_count(snapshot: RunSnapshot) -> int:
	var count := 0
	for slot_id: StringName in SkillSlotIds.passive():
		if not snapshot.loadout.get_skill_id(slot_id).is_empty():
			count += 1
	return count


func _defeat_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "capture advances a configured real room")
	if room == null:
		return
	var enemies: Array[CombatEnemy] = room.initial_enemies.duplicate()
	enemies.append_array(room.reinforcement_enemies)
	for enemy: CombatEnemy in enemies:
		if enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task31_capture_finisher", _coordinator.player.get_instance_id(), _coordinator.player.get_instance_id(), &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var hit := enemy.combat_receiver.receive_hit(request)
		_expect(hit.accepted and enemy.defeated, "capture defeats enemy through real CombatReceiver")
		await process_frame
	_expect(room.room_is_cleared, "capture clears the configured room")
	_coordinator.player.global_position = room.chest.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	if room.room_definition.final_boss:
		return
	_coordinator.player.global_position = room.portal.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame


func _leave_physical_shop() -> void:
	var shop := _coordinator.active_shop_room
	_expect(shop != null and shop.exit_portal != null, "single shop exposes its physical exit")
	if shop == null:
		return
	if _overlay.visible:
		_overlay.toggle_loadout()
		await process_frame
	_coordinator.player.global_position = shop.exit_portal.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame


func _pre_shop_dust_run_id(prefix: String) -> StringName:
	for index: int in 512:
		var run_id := StringName("%s_%03d" % [prefix, index])
		var session := RunSession.new(
			CATALOG.reward_definitions(), CATALOG.relic_definitions, CATALOG.initial_owned_skill_ids(),
			[ElementIds.WATER, ElementIds.FIRE], null, null, RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
		)
		if not session.start_formal_run(&"start", 0).accepted:
			continue
		var first := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_first", session.snapshot().revision, first.room_id, 31_000 + index * 2, first.room_scene.resource_path).accepted:
			continue
		if not session.claim_formal_room_chest(&"claim_first", session.snapshot().revision, first.room_id).accepted:
			continue
		if not session.handle_event(RoomCompletedEvent.new(&"complete_first", first.room_id, 0, 0, first.completion_dream_dust, false)).accepted:
			continue
		var second := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_second", session.snapshot().revision, second.room_id, 31_001 + index * 2, second.room_scene.resource_path).accepted:
			continue
		var claim := session.claim_formal_room_chest(&"claim_second", session.snapshot().revision, second.room_id)
		if claim.accepted and claim.chest_reward.kind == RunChestRewardSnapshot.Kind.DREAM_DUST:
			return run_id
	_expect(false, "%s finds a deterministic second-room dust cohort" % prefix)
	return StringName("%s_fallback" % prefix)


func _defeat_player() -> void:
	_hit_sequence += 1
	var enemy := _coordinator.active_enemies[0]
	var cast := CastSnapshot.new(_hit_sequence, &"task31_capture_player_defeat", enemy.get_instance_id(), enemy.get_instance_id(), &"enemy", ElementIds.NONE, CombatStatSnapshot.new())
	var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, _coordinator.player.global_position, Vector2.LEFT)
	_expect(_coordinator.player.combat_receiver.receive_hit(request).accepted, "capture player defeat uses real CombatReceiver")
	await process_frame


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button if _overlay != null else null


func _press(control_id: StringName) -> bool:
	var button := _button(control_id)
	if button == null or button.disabled:
		return false
	button.grab_focus()
	button.pressed.emit()
	return true


func _wait_for_room(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator != null and _coordinator.active_room != null and _coordinator.active_room.room_id == room_id and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 480)


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator != null and _coordinator.host != null and _coordinator.host.run_session != null and _coordinator.current_snapshot().route.phase == phase
	, 480)


func _wait_for_combat_feedback_clear() -> bool:
	var cleared := func() -> bool:
		var feedback := _hud.get("_feedback_panel") as Control
		if feedback != null and feedback.visible:
			return false
		for child: Node in _coordinator.feedback.find_children("FinalDamage", "Label", true, false):
			var label := child as Label
			if label != null and label.is_visible_in_tree():
				return false
		return true
	var deadline_msec := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline_msec:
		if cleared.call():
			return true
		await process_frame
	return bool(cleared.call())


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
	_expect(image != null and image.get_size() == expected_size, "%s is actual %s Viewport before save" % [file_name, str(expected_size)])
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
	return rect.position.x >= -0.2 and rect.position.y >= -0.2 and rect.end.x <= size.x + 0.2 and rect.end.y <= size.y + 0.2


func _save_unfiltered_rgb_png(image: Image, path: String) -> Error:
	if image == null or image.get_format() != Image.FORMAT_RGB8:
		return ERR_INVALID_PARAMETER
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return ERR_INVALID_PARAMETER
	var pixels := image.get_data()
	var stride := width * 3
	var raw := PackedByteArray()
	for y: int in height:
		var row := y * stride
		raw.append(0)
		raw.append_array(pixels.slice(row, row + stride))
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.is_empty():
		return ERR_CANT_CREATE
	var png := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	var header := PackedByteArray()
	_append_be32(header, width)
	_append_be32(header, height)
	header.append_array(PackedByteArray([8, 2, 0, 0, 0]))
	_append_png_chunk(png, "IHDR", header)
	_append_png_chunk(png, "IDAT", compressed)
	_append_png_chunk(png, "IEND", PackedByteArray())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(png)
	return OK


func _append_png_chunk(png: PackedByteArray, type_name: String, data: PackedByteArray) -> void:
	var type_bytes := type_name.to_ascii_buffer()
	_append_be32(png, data.size())
	png.append_array(type_bytes)
	png.append_array(data)
	var crc_input := type_bytes.duplicate()
	crc_input.append_array(data)
	_append_be32(png, _png_crc32(crc_input))


func _append_be32(buffer: PackedByteArray, value: int) -> void:
	buffer.append((value >> 24) & 0xff)
	buffer.append((value >> 16) & 0xff)
	buffer.append((value >> 8) & 0xff)
	buffer.append(value & 0xff)


func _png_crc32(data: PackedByteArray) -> int:
	var crc := 0xffffffff
	for byte: int in data:
		crc ^= byte
		for _bit: int in 8:
			crc = (crc >> 1) ^ (0xedb88320 if (crc & 1) != 0 else 0)
	return (~crc) & 0xffffffff


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
		print("TASK 31 FULL RUN VISUAL CAPTURE PASSED: 1 tests, %d assertions, %d screenshots" % [_assertions, _images.size()])
		quit(0)
	else:
		printerr("TASK 31 FULL RUN VISUAL CAPTURE FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
