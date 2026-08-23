extends SceneTree

const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task84/screenshots"

var _coordinator: RunFlowCoordinator
var _hit_sequence := 84_500_000
var _saved := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	_coordinator = RUN_GAME.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = &"task84_visual_capture"
	root.add_child(_coordinator)
	current_scene = _coordinator
	if not await _reach_shop():
		quit(1)
		return
	var overlay := _coordinator.combat_hud.run_overlay as RunOverlayInterface
	_coordinator.player.global_position = _coordinator.active_shop_room.wishing_crown.global_position
	_coordinator.player.interact_requested.emit()
	await _settle()
	if not await _save("task84_01_purchase_two_columns_1920x1080.png"):
		quit(1)
		return
	var upgrade_tab := overlay.formal_control(&"shop_tab:upgrade") as Button
	if upgrade_tab == null:
		quit(1)
		return
	upgrade_tab.pressed.emit()
	await _settle()
	if not await _save("task84_02_upgrade_two_columns_1920x1080.png"):
		quit(1)
		return
	var purchase_tab := overlay.formal_control(&"shop_tab:purchase") as Button
	purchase_tab.pressed.emit()
	await _settle()
	var long_content := _coordinator.host.content_catalog.content_for(&"burning")
	if long_content != null:
		long_content.description = "长描述压力：元素燃烧状态持续叠加并在每次结算时按当前元素规则处理；此采集仅验证原卡片的两行截断与两列商店布局不会因中文长文本而溢出、遮挡或重排按钮。"
		overlay.call("_show_formal_shop", &"task84_long_description_capture")
		await _settle()
	if not await _save("task84_03_purchase_long_description_1920x1080.png"):
		quit(1)
		return
	# This is the genuine session's mixed empty-slot state: it records both rows
	# without manufacturing ownership, wallet, or loadout authority.
	if not await _save("task84_04_mixed_empty_slots_1920x1080.png"):
		quit(1)
		return
	print("TASK 84 VISUAL CAPTURE PASSED: %d screenshots" % _saved)
	quit(0)


func _reach_shop() -> bool:
	if not await _wait_until(func() -> bool: return _coordinator.active_room != null and _coordinator.active_room.room_id == &"combat_01_entry", 360):
		return false
	await _finish_room()
	if not await _wait_until(func() -> bool: return _coordinator.active_room != null and _coordinator.active_room.room_id == &"combat_02_swarm", 360):
		return false
	await _finish_room(false)
	return await _wait_until(func() -> bool: return _coordinator.current_snapshot().route.phase == RunPhase.SHOP and _coordinator.active_shop_room != null, 360)


func _finish_room(wait_after := true) -> void:
	var room := _coordinator.active_room
	for enemy: CombatEnemy in room.initial_enemies: _defeat(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies: _defeat(enemy)
	await process_frame
	_coordinator.player.global_position = room.chest.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	_coordinator.player.global_position = room.to_global(room.route_transition_zone.get_center())
	_coordinator.player.interact_requested.emit()
	if wait_after: await process_frame


func _defeat(enemy: CombatEnemy) -> void:
	if enemy == null or enemy.defeated: return
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task84_capture", 84, 84, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	enemy.combat_receiver.receive_hit(HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if predicate.call(): return true
		await process_frame
	return bool(predicate.call())


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(1920, 1080): return false
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))
	if result == OK: _saved += 1
	return result == OK
