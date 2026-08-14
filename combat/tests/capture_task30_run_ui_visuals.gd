extends SceneTree

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task30/viewport"

var _assertions: int = 0
var _failures: Array[String] = []
var _hit_sequence: int = 3090000
var _images: Dictionary[String, Image] = {}
var _coordinator: RunFlowCoordinator
var _hud: CombatHUD
var _overlay: RunOverlayInterface


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	call_deferred(&"_run")


func _run() -> void:
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = _capture_run_id()
	_expect(_coordinator != null, "capture instantiates real RunGame")
	if _coordinator == null:
		_finish()
		return
	root.add_child(_coordinator)
	current_scene = _coordinator
	_expect(await _wait_for_room(&"combat_01_entry"), "capture boots combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface
	var persistent_ids := [
		_coordinator.host.get_instance_id(),
		_coordinator.host.run_session.get_instance_id(),
		_coordinator.player.get_instance_id(),
		_hud.get_instance_id(),
		_coordinator.host.runtime_loadout.get_instance_id(),
	]

	await _capture_combat("01_combat_hud_1920x1080.png", Vector2i(1920, 1080))
	await _capture_combat("02_combat_hud_2560x1440.png", Vector2i(2560, 1440))
	await _capture_combat("03_combat_hud_1366x768.png", Vector2i(1366, 768))
	_hud.set_colorblind_mode(true)
	_hud.set_reduced_motion(true)
	await _capture_combat("04_colorblind_reduced_motion_1920x1080.png", Vector2i(1920, 1080), true)
	await _capture_combat("04b_colorblind_reduced_motion_2560x1440.png", Vector2i(2560, 1440), true)
	await _capture_combat("04c_colorblind_reduced_motion_1366x768.png", Vector2i(1366, 768), true)
	_hud.set_colorblind_mode(false)
	_hud.set_reduced_motion(false)
	# The three accessibility captures above preserve and assert the real
	# feedback state.  Let its normal lifetime complete before unrelated combat
	# evidence so a stale accessibility message cannot cover live actors/VFX.
	_expect(await _wait_until(func() -> bool:
		var feedback := _hud.get("_feedback_panel") as Control
		return feedback == null or not feedback.visible
	, 180), "accessibility feedback completes its real display lifetime")

	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_02_swarm"), "capture reaches fixed combat two")
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "capture reaches the single shop after two combats")
	await _capture_overlay("05_early_shop_1920x1080.png", Vector2i(1920, 1080), &"shop")
	await _capture_overlay("06_early_shop_2560x1440.png", Vector2i(2560, 1440), &"shop")
	await _capture_overlay("07_early_shop_1366x768.png", Vector2i(1366, 768), &"shop")
	_expect(_press(&"purchase:elemental_laser"), "visible early shop purchases elemental laser")
	await process_frame
	_expect(_press(&"select:elemental_laser"), "visible early shop selects elemental laser")
	await process_frame
	_expect(_press(&"slot:active_2"), "visible early shop equips laser in A2")
	await process_frame
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"elemental_laser", "capture A2 laser mapping is authoritative")
	_expect(_press(&"purchase:element_reclaim"), "visible middle shop purchases element reclaim")
	await process_frame
	_expect(_press(&"select:element_reclaim"), "visible middle shop selects element reclaim")
	await process_frame
	_expect(_press(&"slot:active_3"), "visible middle shop equips reclaim in A3")
	await process_frame
	_expect(_coordinator.current_snapshot().skills.owns(&"burning"), "fixed second chest owns burning before the single shop")
	_expect(_press(&"select:burning"), "visible middle shop selects burning")
	await process_frame
	_expect(_press(&"slot:passive_1"), "visible middle shop equips burning in P1")
	await process_frame
	_expect(_press(&"select:elemental_fury"), "guaranteed first-chest fury remains selectable")
	await process_frame
	_expect(_press(&"slot:active_1"), "visible single shop equips fury in A1")
	await process_frame
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_3), &"element_reclaim", "capture A3 reclaim mapping is authoritative")
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.PASSIVE_1), &"burning", "capture P1 mapping is authoritative")
	await _capture_overlay("08_shop_seven_slot_zones_1920x1080.png", Vector2i(1920, 1080), &"shop")
	await _leave_physical_shop()
	_expect(await _wait_for_room(&"combat_04_validation"), "capture reaches combat four")
	await _capture_laser_state()
	await _capture_reclaim_state()
	await _capture_fury_state()

	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_06_final_boss"), "capture reaches final boss")
	var boss_balance := _coordinator.current_snapshot().economy.balance
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.RUN_COMPLETE), "capture reaches complete result")
	await _capture_overlay("13_complete_result_1920x1080.png", Vector2i(1920, 1080), &"result")
	await _capture_overlay("14_complete_result_2560x1440.png", Vector2i(2560, 1440), &"result")
	var final := _coordinator.current_snapshot()
	_expect(final.result != null and final.result.is_complete(), "capture final result is complete")
	_expect_eq(final.route.completed_combat_rooms, 4, "capture final has four combats")
	_expect_eq(final.route.shop_visits, 1, "capture final has one shop")
	_expect_eq(final.route.route_choices, 0, "capture final has zero routes")
	_expect_eq(final.economy.balance, boss_balance, "capture boss awards zero dream dust")
	_expect(final.shop == null and final.pending_reward == null, "capture result has no extra shop/reward")
	_expect_eq(_coordinator.host.get_instance_id(), persistent_ids[0], "capture Host persists")
	_expect_eq(_coordinator.host.run_session.get_instance_id(), persistent_ids[1], "capture Session persists")
	_expect_eq(_coordinator.player.get_instance_id(), persistent_ids[2], "capture Player persists")
	_expect_eq(_hud.get_instance_id(), persistent_ids[3], "capture HUD persists")
	_expect_eq(_coordinator.host.runtime_loadout.get_instance_id(), persistent_ids[4], "capture Runtime persists")

	_expect(_press(&"new_run"), "visible result starts a new run")
	await process_frame
	await process_frame
	_coordinator = current_scene as RunFlowCoordinator
	_expect(_coordinator != null, "capture new run creates replacement coordinator")
	if _coordinator == null:
		_finish()
		return
	_expect(await _wait_for_room(&"combat_01_entry"), "capture new run boots")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface
	await _defeat_player()
	_expect(await _wait_for_phase(RunPhase.RUN_FAILED), "capture reaches failed result")
	await _capture_overlay("15_failed_result_1920x1080.png", Vector2i(1920, 1080), &"result", true)

	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Task30 viewport evidence directory is writable")
		for file_name: String in _images:
			var image: Image = _images[file_name]
			_expect(image != null, "%s has an actual Viewport image" % file_name)
			if image != null:
				# Godot's filtered RGBA PNG is pixel-correct but the review image
				# decoder can misrender isolated Control rows in sparse combat frames.
				# Viewport captures are fully opaque, so emit the exact RGB pixels as
				# a standard filter-0 PNG and immediately prove a pixel-identical
				# round trip before accepting it as evidence.
				_expect(image.detect_alpha() == Image.ALPHA_NONE, "%s actual Viewport capture is fully opaque" % file_name)
				var review_image := image.duplicate()
				review_image.convert(Image.FORMAT_RGB8)
				var png_path := directory.path_join(file_name)
				_expect(_save_unfiltered_rgb_png(review_image, png_path) == OK, "%s saves only after phase/control assertions" % file_name)
				var decoded := Image.load_from_file(png_path)
				_expect(decoded != null and decoded.get_size() == review_image.get_size(), "%s standard PNG round-trips at the actual Viewport size" % file_name)
				if decoded != null:
					decoded.convert(Image.FORMAT_RGB8)
					_expect(decoded.get_data() == review_image.get_data(), "%s standard PNG is pixel-identical to the gated Viewport image" % file_name)
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _capture_combat(file_name: String, size: Vector2i, accessibility: bool = false) -> void:
	await _set_size(size)
	_assert_combat_hud(file_name, size, accessibility)
	await _store_capture(file_name, size)


func _assert_combat_hud(file_name: String, size: Vector2i, accessibility: bool = false) -> void:
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.route.phase, RunPhase.COMBAT, "%s authority phase is combat" % file_name)
	_expect(not _overlay.visible and _overlay.formal_kind() == &"combat", "%s overlay leaves combat unobscured" % file_name)
	_expect(_hud.status_panel.is_visible_in_tree() and _hud.skill_panel.is_visible_in_tree() and _hud.passive_panel.is_visible_in_tree(), "%s shows all formal HUD zones" % file_name)
	_expect(_inside(_hud.status_panel.get_global_rect(), size), "%s status is in bounds" % file_name)
	_expect(_inside(_hud.skill_panel.get_global_rect(), size), "%s active belt is in bounds" % file_name)
	_expect(_inside(_hud.passive_panel.get_global_rect(), size), "%s passive belt is in bounds" % file_name)
	_expect(not _hud.has_visible_target_attachment_text(), "%s has no target attachment text" % file_name)
	if accessibility:
		_expect(_hud.colorblind_mode and _hud.reduced_motion, "%s accessibility flags are enabled" % file_name)
		_expect(not (_hud.element_pivot_panel().get_node("Body/ElementShape") as Label).text.is_empty(), "%s preserves element shape" % file_name)
		var feedback := _hud.get("_feedback_panel") as Control
		_expect(feedback != null and feedback.is_visible_in_tree(), "%s keeps the real accessibility feedback visible" % file_name)
		if feedback != null:
			var feedback_rect := feedback.get_global_rect()
			_expect(_inside(feedback_rect, size), "%s feedback is in bounds" % file_name)
			_expect(not feedback_rect.intersects(_hud.status_panel.get_global_rect()), "%s feedback does not overlap status" % file_name)
			_expect(not feedback_rect.intersects(_hud.skill_panel.get_global_rect()), "%s feedback does not overlap active belt" % file_name)
			_expect(not feedback_rect.intersects(_hud.passive_panel.get_global_rect()), "%s feedback does not overlap passive belt" % file_name)


func _capture_laser_state() -> void:
	const FILE_NAME := "16_laser_damage_1920x1080.png"
	const SIZE := Vector2i(1920, 1080)
	await _set_size(SIZE)
	_expect(await _wait_for_feedback_clear(), "%s lets the preceding route feedback complete normally" % FILE_NAME)
	var enemy := _primary_live_enemy()
	_expect(enemy != null, "%s has a real RunGame enemy" % FILE_NAME)
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"elemental_laser", "%s consumes the authority A2 mapping" % FILE_NAME)
	if enemy == null:
		return
	# Stage both live actors over the real lower platform so they settle on the
	# same beam plane before the first authoritative 0.5-second channel tick.
	_stage_live_combatants(enemy, 170.0, 250.0, 320.0)
	_expect(_request_element(ElementIds.WATER), "%s selects a real current element" % FILE_NAME)
	_expect(_coordinator.player.energy_component.set_current(_coordinator.player.energy_component.maximum), "%s prepares legal channel energy" % FILE_NAME)
	var tick_before := _coordinator.vfx.laser_tick_count
	var cast := _coordinator.player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(cast != null and cast.accepted and cast.skill_id == &"elemental_laser", "%s starts through Player.try_cast_slot(A2)" % FILE_NAME)
	_expect(await _wait_until(func() -> bool: return _coordinator.vfx.active_laser_count == 1, 90), "%s has one authority-created laser presentation" % FILE_NAME)
	_expect(await _wait_until(func() -> bool:
		return _coordinator.vfx.laser_tick_count > tick_before and not _damage_number_labels().is_empty()
	, 180), "%s observes a real laser tick and damage number" % FILE_NAME)
	var laser := _first_vfx_presentation("LaserVfxPresentation") as LaserVfxPresentation
	_expect(laser != null and laser.is_visible_in_tree() and laser.pulse_count > 0, "%s keeps the ticking LaserVfxPresentation visible" % FILE_NAME)
	if laser != null:
		_expect_eq(laser.locked_element_id, ElementIds.WATER, "%s presentation keeps the cast-time water lock" % FILE_NAME)
		_expect_eq(laser.visual_size(), Vector2(320.0, 24.0), "%s uses the authoritative beam geometry" % FILE_NAME)
		_assert_rect_clear_of_hud(_canvas_rect(laser, Rect2(Vector2(0.0, -12.0), laser.visual_size())), "%s laser beam" % FILE_NAME)
	_assert_live_combat_geometry(FILE_NAME, SIZE, enemy)
	_assert_damage_numbers_clear(FILE_NAME, SIZE)
	_assert_combat_hud(FILE_NAME, SIZE)
	await _store_live_skill_capture(FILE_NAME, SIZE, laser, "Laser")
	_expect(_coordinator.player.release_channel_for_slot(SkillSlotIds.ACTIVE_2), "%s releases through the real A2 channel path" % FILE_NAME)
	_expect(await _wait_until(func() -> bool: return _coordinator.vfx.active_laser_count == 0, 120), "%s authority release removes the channel presentation" % FILE_NAME)


func _capture_reclaim_state() -> void:
	const FILE_NAME := "17_reclaim_authority_1920x1080.png"
	const SIZE := Vector2i(1920, 1080)
	await _set_size(SIZE)
	_expect(await _wait_for_feedback_clear(), "%s lets the preceding shop feedback complete normally" % FILE_NAME)
	var enemy := _primary_live_enemy()
	_expect(enemy != null, "%s has a real RunGame enemy" % FILE_NAME)
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"elemental_laser", "%s retains the authority laser setup" % FILE_NAME)
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_3), &"element_reclaim", "%s consumes the authority A3 mapping" % FILE_NAME)
	if enemy == null:
		return
	_stage_live_combatants(enemy, 150.0, 150.0)
	_expect(_request_element(ElementIds.WATER), "%s selects water through the player controller" % FILE_NAME)
	_expect(_coordinator.player.energy_component.set_current(_coordinator.player.energy_component.maximum), "%s prepares legal laser energy" % FILE_NAME)
	var tick_before := _coordinator.vfx.laser_tick_count
	var prime_cast := _coordinator.player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(prime_cast != null and prime_cast.accepted and prime_cast.skill_id == &"elemental_laser", "%s primes attachment through the real equipped laser" % FILE_NAME)
	_expect(await _wait_until(func() -> bool:
		return _coordinator.vfx.laser_tick_count > tick_before and enemy.element_carrier.snapshot().water_amount > 0
	, 180), "%s receives a real water attachment from the laser tick" % FILE_NAME)
	_expect(_coordinator.player.release_channel_for_slot(SkillSlotIds.ACTIVE_2), "%s releases the priming channel through A2" % FILE_NAME)
	_expect(await _wait_until(func() -> bool:
		return _coordinator.vfx.active_laser_count == 0 and _coordinator.player.skill_executor.current_phase == SkillExecutor.Phase.IDLE
	, 180), "%s waits for the real channel transaction to settle" % FILE_NAME)
	_stage_live_combatants(enemy, 120.0)
	var water_before := enemy.element_carrier.snapshot().water_amount
	var energy_before := _coordinator.player.energy_component.current_energy
	var playback_before := _coordinator.vfx.reclaim_playback_count
	var reclaim_cast := _coordinator.player.try_cast_slot(SkillSlotIds.ACTIVE_3)
	_expect(reclaim_cast != null and reclaim_cast.accepted and reclaim_cast.skill_id == &"element_reclaim", "%s commits through Player.try_cast_slot(A3)" % FILE_NAME)
	_expect(await _wait_until(func() -> bool: return _coordinator.vfx.reclaim_playback_count > playback_before, 90), "%s observes the committed reclaim event" % FILE_NAME)
	var reclaim := _first_vfx_presentation("ReclaimVfxPresentation") as ReclaimVfxPresentation
	_expect(reclaim != null and reclaim.is_visible_in_tree(), "%s keeps ReclaimVfxPresentation visible" % FILE_NAME)
	if reclaim != null:
		_expect(reclaim.locked_element_id == ElementIds.WATER and reclaim.target_count >= 1 and reclaim.particle_count >= 3, "%s shows particles from the authority target set" % FILE_NAME)
		_assert_reclaim_visuals_clear(FILE_NAME, reclaim)
	_expect(water_before > 0 and enemy.element_carrier.snapshot().water_amount < water_before, "%s consumes the real carrier layers" % FILE_NAME)
	_expect(_coordinator.player.energy_component.current_energy > energy_before, "%s restores real player energy" % FILE_NAME)
	_assert_live_combat_geometry(FILE_NAME, SIZE, enemy)
	_assert_combat_hud(FILE_NAME, SIZE)
	await _store_live_skill_capture(FILE_NAME, SIZE, reclaim, "Reclaim")


func _capture_fury_state() -> void:
	const FILE_NAME := "18_fury_damage_1920x1080.png"
	const SIZE := Vector2i(1920, 1080)
	await _set_size(SIZE)
	_expect(await _wait_for_feedback_clear(), "%s lets the preceding shop feedback complete normally" % FILE_NAME)
	var enemy := _primary_live_enemy()
	_expect(enemy != null, "%s has the real RunGame final boss" % FILE_NAME)
	_expect_eq(_coordinator.current_snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_1), &"elemental_fury", "%s consumes the authority A1 mapping" % FILE_NAME)
	if enemy == null:
		return
	var capture_platform := _coordinator.active_room.get_node_or_null("Task30CapturePlatform") as StaticBody2D
	if capture_platform != null:
		capture_platform.collision_layer = 0
		await physics_frame
	_stage_live_combatants(enemy, 92.0)
	await physics_frame
	_expect(_request_element(ElementIds.FIRE), "%s selects fire through the player controller" % FILE_NAME)
	_expect(_coordinator.player.energy_component.set_current(20), "%s prepares the legal minimum Fury energy" % FILE_NAME)
	_expect(await _wait_until(func() -> bool: return _coordinator.player.skill_executor.current_phase == SkillExecutor.Phase.IDLE, 180), "%s waits for the prior skill transaction to become idle" % FILE_NAME)
	var playback_before := _coordinator.vfx.fury_playback_count
	var cast := _coordinator.player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(cast != null and cast.accepted and cast.skill_id == &"elemental_fury", "%s commits through Player.try_cast_slot(A1): %s/%s" % [FILE_NAME, String(cast.reason_name()) if cast != null else "null", String(cast.detail) if cast != null else "null"])
	_expect(await _wait_until(func() -> bool:
		return _coordinator.vfx.fury_playback_count > playback_before and not _damage_number_labels().is_empty()
	, 90), "%s observes the real Fury burst and damage number" % FILE_NAME)
	var fury := _first_vfx_presentation("FuryVfxPresentation") as FuryVfxPresentation
	_expect(fury != null and fury.is_visible_in_tree() and fury.playback_count == 1, "%s keeps FuryVfxPresentation visible" % FILE_NAME)
	if fury != null:
		_expect(fury.locked_element_id == ElementIds.FIRE and is_equal_approx(fury.authoritative_radius, 115.2), "%s shows the locked 20-SP authority radius" % FILE_NAME)
		_assert_rect_clear_of_hud(_canvas_rect(fury.sprite, _sprite_local_rect(fury.sprite)), "%s Fury burst" % FILE_NAME)
	_assert_live_combat_geometry(FILE_NAME, SIZE, enemy)
	_assert_damage_numbers_clear(FILE_NAME, SIZE)
	_assert_combat_hud(FILE_NAME, SIZE)
	await _store_live_skill_capture(FILE_NAME, SIZE, fury, "Fury")


func _capture_overlay(file_name: String, size: Vector2i, kind: StringName, failed: bool = false) -> void:
	await _set_size(size)
	var snapshot := _coordinator.current_snapshot()
	_expect(_overlay.visible and _overlay.formal_kind() == kind, "%s shows formal %s" % [file_name, String(kind)])
	var panel_rect := (_overlay.get("_panel") as Control).get_global_rect()
	_expect(_inside(panel_rect, size), "%s formal panel is in bounds: rect=%s viewport=%s" % [file_name, str(panel_rect), str(size)])
	if kind == &"shop":
		_expect_eq(snapshot.route.phase, RunPhase.SHOP, "%s authority phase is shop" % file_name)
		_expect(_button(&"leave_shop") != null and _button(&"leave_shop").disabled, "%s cannot bypass the physical shop exit" % file_name)
		_expect(_button(&"close_shop_panel") != null and _button(&"close_shop_panel").text.contains("返回世界"), "%s has the precise close-to-world action" % file_name)
		_expect(_button(&"slot:active_1") != null and _button(&"slot:passive_4") != null, "%s shows A1-A3/P1-P4 endpoints" % file_name)
	elif kind == &"result":
		_expect(snapshot.result != null, "%s has frozen result" % file_name)
		_expect(snapshot.route.phase == (RunPhase.RUN_FAILED if failed else RunPhase.RUN_COMPLETE), "%s result outcome matches authority" % file_name)
		_expect(_button(&"new_run") != null and not _button(&"new_run").disabled, "%s has enabled new-run action" % file_name)
		_expect(_button(&"return_entry") != null and _button(&"return_entry").disabled, "%s has honest unavailable return action" % file_name)
	await _store_capture(file_name, size)


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


func _store_live_skill_capture(
		file_name: String,
		expected_size: Vector2i,
		presentation: Node,
		presentation_name: String
) -> void:
	# Live skill commits update executor state, cooldown text, VFX and damage
	# feedback in the same rendered interval.  A single OpenGL readback can
	# occasionally contain complete panel backgrounds but an incomplete Control
	# draw list.  Prove that the formal HUD has identical child geometry across
	# two completed draws while the real presentation/damage remain alive, then
	# inspect the exact physical pixels that will be saved.
	var before := _assert_live_skill_hud_subcontent(file_name, expected_size)
	await RenderingServer.frame_post_draw
	_expect(presentation != null and presentation.is_visible_in_tree(), "%s keeps real %s alive across the first synchronized draw" % [file_name, presentation_name])
	_expect(not _damage_number_labels().is_empty(), "%s keeps a real damage number across the first synchronized draw" % file_name)
	var after := _assert_live_skill_hud_subcontent(file_name, expected_size)
	_assert_rect_snapshots_stable(file_name, before, after)
	await RenderingServer.frame_post_draw
	_expect(presentation != null and presentation.is_visible_in_tree(), "%s still shows real %s on the saved draw" % [file_name, presentation_name])
	_expect(not _damage_number_labels().is_empty(), "%s still shows a real damage number on the saved draw" % file_name)
	var final_rects := _assert_live_skill_hud_subcontent(file_name, expected_size)
	_assert_rect_snapshots_stable(file_name, after, final_rects)
	var image := root.get_texture().get_image()
	_expect(image != null and image.get_size() == expected_size, "%s is actual %s Viewport before live-skill pixel gates" % [file_name, str(expected_size)])
	if image == null:
		return
	_assert_live_skill_hud_pixels(file_name, image, final_rects)
	_images[file_name] = image


func _assert_live_skill_hud_subcontent(file_name: String, size: Vector2i) -> Dictionary:
	var health_row := _hud.status_panel.get_node("Margin/Status/HealthRow") as Control
	var element_panel := _hud.element_pivot_panel()
	var specs := {
		"hp_label": {
			"control": health_row.get_node("Label") as Control,
			"owner": _hud.status_panel,
			"text": true,
			"minimum_pixels": 5,
		},
		"hp_bar": {
			"control": _hud.health_bar as Control,
			"owner": _hud.status_panel,
			"text": false,
			"minimum_pixels": 200,
		},
		"hp_value": {
			"control": _hud.health_value as Control,
			"owner": _hud.status_panel,
			"text": true,
			"minimum_pixels": 20,
		},
		"element_swatch": {
			"control": element_panel.get_node("Body/ElementSwatch") as Control,
			"owner": element_panel,
			"text": false,
			"minimum_pixels": 40,
		},
		"element_shape": {
			"control": element_panel.get_node("Body/ElementShape") as Control,
			"owner": element_panel,
			"text": true,
			"minimum_pixels": 12,
		},
		"element_text": {
			"control": element_panel.get_node("Body/ElementText") as Control,
			"owner": element_panel,
			"text": true,
			"minimum_pixels": 12,
		},
	}
	var visible_state_count := 0
	for slot_id: StringName in SkillSlotIds.active():
		var slot := _hud.visual_slot_panel(slot_id)
		var prefix := String(slot_id)
		specs[prefix + "_name"] = {
			"control": slot.get_node("Margin/Body/Name") as Control,
			"owner": slot,
			"text": true,
			"minimum_pixels": 12,
		}
		var state := slot.get_node("Margin/Body/State") as Label
		if state != null and state.is_visible_in_tree() and not state.text.strip_edges().is_empty():
			visible_state_count += 1
			specs[prefix + "_state"] = {
				"control": state,
				"owner": slot.get_node("Margin/Body") as Control,
				"text": true,
				"minimum_pixels": 8,
			}
	_expect(visible_state_count >= 1, "%s exposes at least one real cooldown/busy state while the skill presentation is live" % file_name)
	var rects: Dictionary = {}
	for key: String in specs:
		var spec: Dictionary = specs[key]
		var control := spec["control"] as Control
		var owner := spec["owner"] as Control
		_expect(control != null and owner != null, "%s %s resolves formal HUD control and owner" % [file_name, key])
		if control == null or owner == null:
			continue
		_expect(control.is_visible_in_tree(), "%s %s is visible in the real Reclaim frame" % [file_name, key])
		_expect(control.modulate.a > 0.95 and control.self_modulate.a > 0.95, "%s %s is not faded by a Control transform" % [file_name, key])
		if bool(spec["text"]):
			var label := control as Label
			_expect(label != null and not label.text.strip_edges().is_empty(), "%s %s has non-empty readable text" % [file_name, key])
		var rect := control.get_global_rect()
		var owner_rect := owner.get_global_rect()
		_expect(_inside(rect, size), "%s %s actual global rect is in the Viewport: %s" % [file_name, key, str(rect)])
		if not key.ends_with("_state"):
			_expect(_contains_rect(owner_rect, rect), "%s %s actual global rect stays inside owner %s" % [file_name, key, str(owner_rect)])
		rects[key] = rect
		rects[key + "_minimum_pixels"] = int(spec["minimum_pixels"])
	var swatch := element_panel.get_node("Body/ElementSwatch") as ColorRect
	var shape := element_panel.get_node("Body/ElementShape") as Label
	_expect(swatch != null and swatch.color.a > 0.95 and maxf(swatch.color.r, maxf(swatch.color.g, swatch.color.b)) > 0.55, "%s CurrentElement keeps a visible semantic color swatch" % file_name)
	_expect(shape != null and shape.get_theme_color(&"font_color").a > 0.95, "%s CurrentElement shape keeps its semantic color" % file_name)
	_expect(_hud.layer >= 10 and _hud.transform.is_equal_approx(Transform2D.IDENTITY), "%s combat CanvasLayer keeps its formal layer and identity transform" % file_name)
	return rects


func _assert_rect_snapshots_stable(file_name: String, before: Dictionary, after: Dictionary) -> void:
	for key: String in before:
		if key.ends_with("_minimum_pixels") or not after.has(key):
			continue
		var a: Rect2 = before[key]
		var b: Rect2 = after[key]
		_expect(
			a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size),
			"%s %s global rect is stable across completed draws: %s -> %s" % [file_name, key, str(a), str(b)]
		)


func _assert_live_skill_hud_pixels(file_name: String, image: Image, rects: Dictionary) -> void:
	for key: String in rects:
		if key.ends_with("_minimum_pixels"):
			continue
		var minimum := int(rects.get(key + "_minimum_pixels", 1))
		var logical_rect: Rect2 = rects[key]
		var pixel_rect := _logical_rect_to_physical_pixels(logical_rect, image.get_size())
		var count := _count_bright_pixels(image, pixel_rect)
		_expect(count >= minimum, "%s %s has %d bright rendered pixels (minimum %d) in the exact saved image" % [file_name, key, count, minimum])


func _logical_rect_to_physical_pixels(logical_rect: Rect2, image_size: Vector2i) -> Rect2:
	# CanvasItem transforms remain in the project's authoritative logical canvas
	# (1152x648 here), while Window Viewport readback returns physical pixels.
	# Apply Godot's keep-aspect uniform stretch plus its centered letterbox offset.
	var logical_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", image_size.x)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", image_size.y))
	)
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return logical_rect
	var uniform_scale := minf(float(image_size.x) / logical_size.x, float(image_size.y) / logical_size.y)
	var offset := (Vector2(image_size) - logical_size * uniform_scale) * 0.5
	return Rect2(logical_rect.position * uniform_scale + offset, logical_rect.size * uniform_scale)


func _count_bright_pixels(image: Image, rect: Rect2) -> int:
	var start_x := clampi(floori(rect.position.x), 0, image.get_width())
	var start_y := clampi(floori(rect.position.y), 0, image.get_height())
	var end_x := clampi(ceili(rect.end.x), 0, image.get_width())
	var end_y := clampi(ceili(rect.end.y), 0, image.get_height())
	var count := 0
	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and maxf(pixel.r, maxf(pixel.g, pixel.b)) >= 0.55:
				count += 1
	return count


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
		var pixel_row := y * stride
		raw.append(0)
		raw.append_array(pixels.slice(pixel_row, pixel_row + stride))
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


func _contains_rect(owner: Rect2, child: Rect2, tolerance: float = 0.5) -> bool:
	return (
		child.position.x >= owner.position.x - tolerance
		and child.position.y >= owner.position.y - tolerance
		and child.end.x <= owner.end.x + tolerance
		and child.end.y <= owner.end.y + tolerance
	)


func _press(control_id: StringName) -> bool:
	var button := _button(control_id)
	if button == null or button.disabled or not button.is_visible_in_tree():
		return false
	button.grab_focus()
	button.pressed.emit()
	return true


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button


func _primary_live_enemy() -> CombatEnemy:
	for enemy: CombatEnemy in _coordinator.active_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.defeated:
			return enemy
	return null


func _stage_live_combatants(
		enemy: CombatEnemy,
		horizontal_distance: float,
		vertical_position: float = 360.0,
		player_x: float = 480.0
) -> void:
	# Capture-only geometry staging keeps the real room, actors, authority,
	# physics and delivery paths intact while placing key pixels in the gameplay
	# safe zone.  No AI, receiver, executor or VFX process is disabled.
	_ensure_capture_platform()
	player_x = 600.0
	vertical_position = 330.0
	_coordinator.player.global_position = Vector2(player_x, vertical_position)
	_coordinator.player.velocity = Vector2.ZERO
	_coordinator.player.facing = 1.0
	_coordinator.player.sprite.flip_h = true
	enemy.global_position = Vector2(player_x + horizontal_distance, vertical_position)
	enemy.velocity = Vector2.ZERO
	enemy.facing = -1.0
	enemy.sprite.flip_h = false


func _ensure_capture_platform() -> void:
	if _coordinator.active_room.get_node_or_null("Task30CapturePlatform") != null:
		return
	var platform := StaticBody2D.new()
	platform.name = "Task30CapturePlatform"
	platform.collision_layer = 4
	platform.global_position = Vector2(600.0, 440.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(800.0, 20.0)
	collision.shape = shape
	platform.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-400.0, -10.0), Vector2(400.0, -10.0), Vector2(400.0, 10.0), Vector2(-400.0, 10.0)])
	visual.color = Color("4bb5be")
	platform.add_child(visual)
	_coordinator.active_room.add_child(platform)


func _request_element(element_id: StringName) -> bool:
	if _coordinator.player.current_element_controller.current_element_id == element_id:
		return true
	var result := _coordinator.player.request_element(element_id)
	return (
		result != null
		and result.accepted
		and not result.buffered
		and _coordinator.player.current_element_controller.current_element_id == element_id
	)


func _wait_for_feedback_clear() -> bool:
	return await _wait_until(func() -> bool:
		var feedback := _hud.get("_feedback_panel") as Control
		return feedback == null or not feedback.visible
	, 180)


func _first_vfx_presentation(type_name: String) -> Node:
	for child: Node in _coordinator.vfx.find_children("*", type_name, true, false):
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			return child
	return null


func _damage_number_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in _coordinator.feedback.find_children("FinalDamage", "Label", true, false):
		var label := child as Label
		if label != null and label.is_visible_in_tree():
			labels.append(label)
	return labels


func _assert_live_combat_geometry(file_name: String, size: Vector2i, enemy: CombatEnemy) -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured and room.is_inside_tree(), "%s keeps the configured real room visible" % file_name)
	_expect(current_scene == _coordinator, "%s remains in the real RunGame scene" % file_name)
	var player_rect := _canvas_rect(_coordinator.player.sprite, _sprite_local_rect(_coordinator.player.sprite))
	var enemy_rect := _canvas_rect(enemy.sprite, _sprite_local_rect(enemy.sprite))
	_expect(_inside(player_rect, size), "%s keeps the player inside the viewport" % file_name)
	_expect(_inside(enemy_rect, size), "%s keeps the enemy inside the viewport" % file_name)
	_assert_rect_clear_of_hud(player_rect, "%s player" % file_name)
	_assert_rect_clear_of_hud(enemy_rect, "%s enemy" % file_name)
	if room != null:
		var title := room.get_node_or_null("RoomTitle") as Label
		_expect(title != null and title.is_visible_in_tree(), "%s keeps the room title/key geometry visible" % file_name)
		if title != null:
			var title_rect := _canvas_rect(title, Rect2(Vector2.ZERO, title.size))
			_expect(_inside(title_rect, size), "%s room title is in bounds" % file_name)
			_assert_rect_clear_of_hud(title_rect, "%s room title" % file_name)


func _assert_damage_numbers_clear(file_name: String, size: Vector2i) -> void:
	var labels := _damage_number_labels()
	_expect(not labels.is_empty(), "%s has a visible FinalDamage control" % file_name)
	for label: Label in labels:
		var group := label.get_parent() as Control
		var rect := (
			_canvas_rect(group, Rect2(Vector2.ZERO, group.size))
			if group != null
			else _canvas_rect(label, Rect2(Vector2.ZERO, label.size))
		)
		_expect(_inside(rect, size), "%s damage number is in bounds" % file_name)
		_assert_rect_clear_of_hud(rect, "%s damage number" % file_name)


func _assert_reclaim_visuals_clear(file_name: String, reclaim: ReclaimVfxPresentation) -> void:
	var visible_count := 0
	for child: Node in reclaim.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := child as AnimatedSprite2D
		if sprite == null or not sprite.is_visible_in_tree():
			continue
		visible_count += 1
		_assert_rect_clear_of_hud(_canvas_rect(sprite, _sprite_local_rect(sprite)), "%s reclaim particle %d" % [file_name, visible_count])
	_expect(visible_count >= 3, "%s renders the real reclaim particle set" % file_name)


func _assert_rect_clear_of_hud(rect: Rect2, description: String) -> void:
	for obstacle: Rect2 in _hud_obstacle_rects():
		_expect(not rect.intersects(obstacle), "%s rect %s does not intersect formal HUD rect %s" % [description, str(rect), str(obstacle)])


func _hud_obstacle_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var controls: Array[Control] = [_hud.status_panel, _hud.skill_panel, _hud.passive_panel]
	var feedback := _hud.get("_feedback_panel") as Control
	if feedback != null:
		controls.append(feedback)
	for control: Control in controls:
		if control != null and control.is_visible_in_tree():
			rects.append(_canvas_rect(control, Rect2(Vector2.ZERO, control.size)))
	return rects


func _sprite_local_rect(sprite: AnimatedSprite2D) -> Rect2:
	if sprite == null or sprite.sprite_frames == null:
		return Rect2(Vector2(-16.0, -24.0), Vector2(32.0, 48.0))
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2(Vector2(-16.0, -24.0), Vector2(32.0, 48.0))
	var texture_size := Vector2(texture.get_size())
	return Rect2(-texture_size * 0.5, texture_size)


func _canvas_rect(item: CanvasItem, local_rect: Rect2) -> Rect2:
	var transform := item.get_global_transform_with_canvas()
	var points := [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _defeat_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "capture active room is configured")
	if room == null:
		return
	var enemies: Array[CombatEnemy] = room.initial_enemies.duplicate()
	enemies.append_array(room.reinforcement_enemies)
	for enemy: CombatEnemy in enemies:
		if not is_instance_valid(enemy) or enemy.defeated:
			continue
		_hit_sequence += 1
		var cast := CastSnapshot.new(_hit_sequence, &"task30_capture_finisher", _coordinator.player.get_instance_id(), _coordinator.player.get_instance_id(), &"player", ElementIds.NONE, CombatStatSnapshot.new())
		var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var result := enemy.combat_receiver.receive_hit(request)
		_expect(result.accepted and enemy.defeated, "capture defeats enemy through real CombatReceiver")
		await process_frame
	_expect(room.room_is_cleared, "capture clears every configured enemy")
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


func _capture_run_id() -> StringName:
	for index: int in 2048:
		var run_id := StringName("task30_capture_%04d" % index)
		var session := RunSession.new(
			CATALOG.reward_definitions(), CATALOG.relic_definitions, CATALOG.initial_owned_skill_ids(),
			[ElementIds.WATER, ElementIds.FIRE], null, null, RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
		)
		if not session.start_formal_run(&"start", 0).accepted:
			continue
		var first := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_first", session.snapshot().revision, first.room_id, 30_000 + index * 2, first.room_scene.resource_path).accepted:
			continue
		var first_claim := session.claim_formal_room_chest(&"claim_first", session.snapshot().revision, first.room_id)
		if not first_claim.accepted or first_claim.chest_reward.skill_id != &"elemental_fury":
			continue
		if not session.handle_event(RoomCompletedEvent.new(&"complete_first", first.room_id, 0, 0, first.completion_dream_dust, false)).accepted:
			continue
		var second := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_second", session.snapshot().revision, second.room_id, 30_001 + index * 2, second.room_scene.resource_path).accepted:
			continue
		var second_claim := session.claim_formal_room_chest(&"claim_second", session.snapshot().revision, second.room_id)
		if second_claim.accepted and second_claim.chest_reward.kind == RunChestRewardSnapshot.Kind.SKILL and second_claim.chest_reward.skill_id == &"burning":
			return run_id
	_expect(false, "Task30 capture finds fury then burning deterministic rewards")
	return &"task30_capture_fallback"


func _defeat_player() -> void:
	_hit_sequence += 1
	var enemy := _coordinator.active_enemies[0]
	var cast := CastSnapshot.new(_hit_sequence, &"task30_capture_player_defeat", enemy.get_instance_id(), enemy.get_instance_id(), &"enemy", ElementIds.NONE, CombatStatSnapshot.new())
	var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, _coordinator.player.global_position, Vector2.LEFT)
	_expect(_coordinator.player.combat_receiver.receive_hit(request).accepted, "capture player defeat uses real CombatReceiver")
	await process_frame


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator != null and _coordinator.host != null and _coordinator.host.run_session != null and _coordinator.current_snapshot().route.phase == phase
	, 480)


func _wait_for_room(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return _coordinator != null and _coordinator.active_room != null and _coordinator.active_room.room_id == room_id and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 480)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _inside(rect: Rect2, size: Vector2i) -> bool:
	return rect.position.x >= -0.2 and rect.position.y >= -0.2 and rect.end.x <= size.x + 0.2 and rect.end.y <= size.y + 0.2


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
		print("TASK 30 RUN UI VISUAL CAPTURE PASSED: 1 tests, %d assertions, %d screenshots" % [_assertions, _images.size()])
		quit(0)
	else:
		printerr("TASK 30 RUN UI VISUAL CAPTURE FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
