extends SceneTree

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task29"

var _assertions: int = 0
var _failures: Array[String] = []
var _hit_sequence: int = 880000
var _images: Dictionary[String, Image] = {}


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	call_deferred("_run")


func _run() -> void:
	var coordinator := RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	_expect(coordinator != null, "RunGame scene instantiates for capture")
	if coordinator == null:
		_finish()
		return
	get_root().add_child(coordinator)
	_expect(await _wait_for_room(coordinator, &"combat_01_entry"), "capture reaches combat one")
	var persistent_ids := [
		coordinator.host.get_instance_id(),
		coordinator.host.run_session.get_instance_id(),
		coordinator.player.get_instance_id(),
		coordinator.smoke_panel.get_instance_id(),
		coordinator.host.runtime_loadout.get_instance_id(),
		coordinator.host.passive_adapter.get_instance_id(),
	]
	_images["01_combat_01_entry_1920x1080.png"] = await _capture_current()

	await _defeat_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.SHOP), "capture reaches early shop")
	_expect(coordinator.purchase_first_affordable_skill().accepted, "capture purchases at early shop")
	_expect(coordinator.leave_shop().accepted, "capture leaves early shop")
	_expect(await _wait_for_phase(coordinator, RunPhase.ROUTE_CHOICE), "capture reaches first route")
	_images["02_route_01_choice_1920x1080.png"] = await _capture_current()

	_expect(coordinator.choose_route(&"route_01_pressure").accepted, "capture selects pressure branch")
	_expect(await _wait_for_room(coordinator, &"combat_02_pressure"), "capture loads platform branch")
	_images["03_platform_room_1920x1080.png"] = await _capture_current()
	await _defeat_current_room(coordinator)
	_expect(await _wait_for_room(coordinator, &"combat_03_layer_elite"), "capture reaches combat three")
	await _defeat_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.SHOP), "capture reaches middle shop")
	_expect(coordinator.purchase_first_affordable_skill().accepted, "capture purchases at middle shop")
	_expect(coordinator.leave_shop().accepted, "capture leaves middle shop")
	_expect(await _wait_for_room(coordinator, &"combat_04_validation"), "capture reaches combat four")
	await _defeat_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.ROUTE_CHOICE), "capture reaches second route")
	_expect(coordinator.choose_route(&"route_02_risk").accepted, "capture selects risk branch")
	_expect(await _wait_for_room(coordinator, &"combat_05_risk"), "capture loads corridor branch")
	await _defeat_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.SHOP), "capture reaches preboss shop")
	_expect(coordinator.purchase_first_affordable_skill().accepted, "capture purchases at preboss shop")
	_expect(coordinator.leave_shop().accepted, "capture leaves preboss shop")
	_expect(await _wait_for_room(coordinator, &"combat_06_final_boss"), "capture loads boss room")
	var boss_balance := coordinator.host.run_session.snapshot().economy.balance
	await _defeat_current_room(coordinator)
	_expect(await _wait_for_phase(coordinator, RunPhase.RUN_COMPLETE), "capture reaches boss result")
	_images["04_boss_result_1920x1080.png"] = await _capture_current()

	var final := coordinator.host.run_session.snapshot()
	_expect_eq(final.route.completed_combat_rooms, 6, "capture final assertion: six combat rooms")
	_expect_eq(final.route.shop_visits, 3, "capture final assertion: three shops")
	_expect_eq(final.route.route_choices, 2, "capture final assertion: two routes")
	_expect(final.result != null and final.result.is_complete(), "capture final assertion: complete result")
	_expect_eq(final.economy.balance, boss_balance, "capture final assertion: boss awards zero dust")
	_expect_eq(final.route.activated_room_instance_ids.size(), 6, "capture final assertion: six room activations")
	_expect_eq(_unique_int_count(final.route.activated_room_instance_ids), 6, "capture final assertion: room instances differ")
	_expect(_unique_string_count(final.route.activated_scene_paths) >= 4, "capture final assertion: PackedScene templates differ")
	_expect_eq(final.route.selected_route_option_ids, [&"route_01_pressure", &"route_02_risk"], "capture final assertion: route identities")
	_expect_eq(coordinator.host.get_instance_id(), persistent_ids[0], "capture final assertion: Host persists")
	_expect_eq(coordinator.host.run_session.get_instance_id(), persistent_ids[1], "capture final assertion: Session persists")
	_expect_eq(coordinator.player.get_instance_id(), persistent_ids[2], "capture final assertion: Player persists")
	_expect_eq(coordinator.smoke_panel.get_instance_id(), persistent_ids[3], "capture final assertion: HUD persists")
	_expect_eq(coordinator.host.runtime_loadout.get_instance_id(), persistent_ids[4], "capture final assertion: seven-slot Runtime persists")
	_expect_eq(coordinator.host.passive_adapter.get_instance_id(), persistent_ids[5], "capture final assertion: passive Runtime persists")

	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		var directory_error := DirAccess.make_dir_recursive_absolute(directory)
		_expect(directory_error == OK, "evidence directory is writable")
		for file_name: String in _images:
			var image: Image = _images[file_name]
			_expect(
				image != null and image.get_size() == Vector2i(1920, 1080),
				"%s is actual 1920x1080 Viewport (got %s)" % [
					file_name,
					str(image.get_size()) if image != null else "null",
				]
			)
			if image != null:
				var save_error := image.save_png(directory.path_join(file_name))
				_expect(save_error == OK, "%s saves after final assertions" % file_name)
	coordinator.queue_free()
	await process_frame
	_finish()


func _capture_current() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()


func _defeat_current_room(coordinator: RunFlowCoordinator) -> void:
	var room := coordinator.active_room
	_expect(room != null and room.configured, "capture room is configured")
	if room == null:
		return
	for enemy: CombatEnemy in room.enemies:
		_hit_sequence += 1
		var cast := CastSnapshot.new(
			_hit_sequence,
			&"task29_capture_finisher",
			coordinator.player.get_instance_id(),
			coordinator.player.get_instance_id(),
			&"player",
			ElementIds.NONE,
			CombatStatSnapshot.new()
		)
		var request := HitRequest.new(
			cast,
			RuntimeAttackPayload.new(9999.0, 9999.0, ElementIds.NONE, 0),
			_hit_sequence,
			0,
			enemy.global_position,
			Vector2.RIGHT
		)
		var result := enemy.combat_receiver.receive_hit(request)
		_expect(result.accepted and enemy.defeated, "capture defeats enemy through CombatReceiver")
	await process_frame


func _wait_for_phase(coordinator: RunFlowCoordinator, phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return (
			coordinator.host != null
			and coordinator.host.run_session != null
			and coordinator.host.run_session.snapshot().route.phase == phase
		)
	, 360)


func _wait_for_room(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			coordinator.active_room != null
			and coordinator.active_room.room_id == room_id
			and coordinator.host.run_session.snapshot().route.phase == RunPhase.COMBAT
		)
	, 360)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _unique_int_count(values: Array[int]) -> int:
	var unique: Array[int] = []
	for value: int in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_string_count(values: Array[String]) -> int:
	var unique: Array[String] = []
	for value: String in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 29 FULL RUN VISUAL CAPTURE PASSED: 1 tests, %d assertions, 4 screenshots" % _assertions)
		quit(0)
	else:
		printerr("TASK 29 FULL RUN VISUAL CAPTURE FAILED: %d failures / %d assertions" % [
			_failures.size(),
			_assertions,
		])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])
