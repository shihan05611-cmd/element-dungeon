extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const BOSS_PROJECTILE: PackedScene = preload("res://scenes/run/boss_arc_projectile.tscn")

var _harness := TestHarness.new()
var _hit_sequence: int = 41_000_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("single_shop_flow_graph", _test_single_shop_flow_graph)
	await _run_async_test("dormant_reinforcement_and_clear_gate", _test_dormant_reinforcement_and_clear_gate)
	_run_test("typed_chest_transaction_atomicity", _test_typed_chest_transaction_atomicity)
	await _run_async_test("physical_safe_path_and_boss_settlement", _test_physical_safe_path_and_boss_settlement)
	_finish()


func _test_single_shop_flow_graph() -> void:
	_expect(FLOW.is_valid(), "Task41 flow validates")
	var shops := 0
	var routes := 0
	var boss := 0
	for node: RunNodeDefinition in FLOW.nodes:
		shops += 1 if node.kind == RunNodeKind.SHOP else 0
		routes += 1 if node.kind == RunNodeKind.ROUTE else 0
		boss += 1 if node.kind == RunNodeKind.BOSS else 0
	_expect_eq(shops, 1, "flow contains one shop")
	_expect_eq(routes, 0, "demo flow contains no route choices")
	_expect_eq(boss, 1, "flow contains one boss")
	_expect_eq(FLOW.node_for(&"combat_01_entry").next_node_id, &"combat_02_swarm", "C1 portal reaches C2 directly")
	_expect_eq(FLOW.node_for(&"combat_02_swarm").next_node_id, &"shop_demo_mid", "C2 portal reaches the physical shop")
	_expect_eq(FLOW.node_for(&"combat_04_validation").next_node_id, &"combat_06_final_boss", "C3 reaches boss directly")
	var first := FLOW.combat_room_for(&"combat_01_entry")
	_expect(first.single_wave and first.enemy_spawns.size() == 2 and first.reinforcement_spawns.is_empty(), "C1 is the explicit two-enemy single-wave exception")
	for room_id: StringName in [&"combat_02_swarm", &"combat_04_validation"]:
		var room := FLOW.combat_room_for(room_id)
		_expect(room.enemy_spawns.size() >= 3 and room.enemy_spawns.size() <= 5, "%s initial wave is 3-5" % String(room_id))
		_expect(room.reinforcement_spawns.size() >= 2 and room.reinforcement_spawns.size() <= 3, "%s reinforcement wave is 2-3" % String(room_id))
		_expect(is_equal_approx(room.reinforcement_delay_seconds, 12.0), "%s reinforcement delay is 12 seconds" % String(room_id))


func _test_dormant_reinforcement_and_clear_gate() -> void:
	var definition := FLOW.combat_room_for(&"combat_02_swarm")
	var room := definition.room_scene.instantiate() as RunRoomInstance
	root.add_child(room)
	_expect(room.configure(definition), "room configures both waves")
	_expect_eq(room.initial_enemies.size(), 3, "room preinstantiates three initial enemies")
	_expect_eq(room.reinforcement_enemies.size(), 2, "room preinstantiates two reinforcements")
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_expect(enemy.reinforcement_dormant and not enemy.visible, "reinforcement starts invisible and dormant")
		_expect(not enemy.combat_receiver.accepting_hits and enemy.collision_layer == 0, "dormant reinforcement cannot collide or receive hits")
		var health_before := enemy.damage_receiver.current_health
		_defeat(enemy)
		_expect(not enemy.defeated and enemy.damage_receiver.current_health == health_before, "dormant reinforcement rejects real hit delivery")
	room.activate()
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat(enemy)
	await process_frame
	_expect(room.reinforcement_activated, "initial wave death activates reinforcement immediately")
	_expect(not room.room_is_cleared, "initial wave alone does not clear room")
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_expect(enemy.visible and enemy.combat_receiver.accepting_hits, "activated reinforcement is visible and hittable")
		_defeat(enemy)
	await process_frame
	_expect(room.room_is_cleared and room.chest.visible, "both waves defeated reveal chest once")
	_expect(room.portal.visible and room.portal.locked, "clear reveals a portal locked by chest")
	room.queue_free()
	await process_frame
	var timer_room := definition.room_scene.instantiate() as RunRoomInstance
	root.add_child(timer_room)
	_expect(timer_room.configure(definition), "timer room configures")
	timer_room.activate()
	var reinforcement_ids: Array[int] = []
	for enemy: CombatEnemy in timer_room.reinforcement_enemies:
		reinforcement_ids.append(enemy.get_instance_id())
	timer_room.call("_process", 12.0)
	_expect(timer_room.reinforcement_activated, "12 seconds activates the dormant reinforcement wave")
	timer_room.call("_process", 12.0)
	for enemy: CombatEnemy in timer_room.initial_enemies:
		_defeat(enemy)
	await process_frame
	var after_ids: Array[int] = []
	for enemy: CombatEnemy in timer_room.reinforcement_enemies:
		after_ids.append(enemy.get_instance_id())
	_expect_eq(after_ids, reinforcement_ids, "timer/death race activates the same reinforcement instances only once")
	timer_room.queue_free()
	await process_frame


func _test_typed_chest_transaction_atomicity() -> void:
	var reward_ids: Array[StringName] = []
	for content: SkillContentDefinition in CATALOG.skill_contents:
		if content.reward_pool:
			reward_ids.append(content.skill_id)
	var session := RunSession.new(
		CATALOG.reward_definitions(), CATALOG.relic_definitions, reward_ids,
		[ElementIds.WATER, ElementIds.FIRE], null, null,
		RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, &"empty_pool_run"
	)
	_expect(session.start_formal_run(&"start", 0).accepted, "domain run starts")
	var pending := session.snapshot().route.pending_node_id
	_expect(session.accept_room_transition(&"activate", 1, pending, 4101, FLOW.combat_room_for(pending).room_scene.resource_path).accepted, "first room activates")
	var before := session.snapshot()
	var stale := session.claim_formal_room_chest(&"stale", before.revision - 1, pending)
	_expect(not stale.accepted and stale.reject_reason == RunCommandResult.RejectReason.STALE_RUN_REVISION, "stale chest command is rejected")
	_expect_eq(session.snapshot().revision, before.revision, "stale chest changes no revision")
	var claimed := session.claim_formal_room_chest(&"claim", before.revision, pending)
	_expect(claimed.accepted and claimed.chest_reward != null and claimed.chest_reward.is_valid(), "chest returns a typed valid reward")
	_expect_eq(claimed.chest_reward.kind, RunChestRewardSnapshot.Kind.DREAM_DUST, "empty skill pool falls back to dust")
	_expect_eq(claimed.run_snapshot.economy.balance, before.economy.balance + 150, "dust fallback commits exactly 150")
	var replay := session.claim_formal_room_chest(&"claim", before.revision, pending)
	_expect(replay == claimed and session.snapshot().revision == claimed.run_snapshot.revision, "identical command replays without another mutation")
	var duplicate := session.claim_formal_room_chest(&"duplicate", session.snapshot().revision, pending)
	_expect(not duplicate.accepted and duplicate.reject_reason == RunCommandResult.RejectReason.ALREADY_CLAIMED, "new duplicate command is rejected once per room")


func _test_physical_safe_path_and_boss_settlement() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task41_safe_flow"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_combat(coordinator, &"combat_01_entry"), "RunGame starts in C1")
	await _clear_claim_and_portal(coordinator, &"combat_01_entry")
	_expect(await _wait_combat(coordinator, &"combat_02_swarm"), "safe C2 room loads")
	await _clear_claim_and_portal(coordinator, &"combat_02_swarm")
	_expect(await _wait_phase(coordinator, RunPhase.SHOP), "C2 portal reaches one shop")
	_expect(await _wait_until(func() -> bool: return coordinator.active_shop_room != null, 180), "physical shop replaces C2")
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	var shop_before := _authority_signature(coordinator.current_snapshot())
	var shop_session_id := coordinator.current_snapshot().shop.session_id
	var shop_commands: Array[StringName] = []
	coordinator.ui_command_result.connect(func(command: StringName, _result: RunCommandResult) -> void: shop_commands.append(command))
	_expect(not overlay.visible and overlay.formal_kind() != &"shop", "SHOP starts hidden without merchant content")
	_expect_eq(overlay.formal_shop_draft_instance_id(), 0, "SHOP snapshot creates no ShopDraft before crown F")
	await _press_physical_loadout(coordinator)
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "physical L opens the existing global loadout content in SHOP")
	_expect(overlay.formal_control(&"leave_shop") == null and overlay.formal_control(&"purchase:burning") == null and overlay.formal_control(&"upgrade:element_bolt") == null, "physical L exposes no merchant, purchase, or upgrade controls")
	_expect_eq(overlay.formal_shop_draft_instance_id(), 0, "physical L creates no ShopDraft")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), shop_before, "physical L mutates no shop/economy authority")
	_expect(shop_commands.is_empty(), "physical L submits no purchase, upgrade, loadout, or leave command")
	await _press_physical_loadout(coordinator)
	_expect(not overlay.visible, "second physical L closes the global loadout content")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), shop_before, "global loadout close preserves complete authority")
	var shop_room := coordinator.active_shop_room
	coordinator.player.global_position = shop_room.wishing_crown.global_position
	await _press_interact()
	_expect(overlay.visible and overlay.formal_kind() == &"shop", "nearby crown F is the merchant content entry")
	var draft_id := overlay.formal_shop_draft_instance_id()
	_expect(draft_id != 0, "crown F creates the unique ShopDraft")
	var close_button := overlay.formal_control(&"close_shop_panel") as Button
	_expect(close_button != null and close_button.visible and not close_button.disabled, "formal shop exposes an enabled visible close-to-world button")
	_expect(close_button.focus_mode == Control.FOCUS_ALL and close_button.text.contains("返回世界") and close_button.text.contains("L"), "shop close button is keyboard focusable with explicit world/L copy")
	var leave_button := overlay.formal_control(&"leave_shop") as Button
	_expect(leave_button != null and leave_button.disabled, "shop UI cannot bypass the world exit")
	close_button.pressed.emit()
	await process_frame
	_expect(not overlay.visible, "shop close button reveals the physical world")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), shop_before, "closing the shop panel mutates no authority")
	await _press_physical_loadout(coordinator)
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "physical L after merchant close still opens only global loadout content")
	_expect(overlay.formal_control(&"leave_shop") == null and overlay.formal_control(&"purchase:burning") == null, "reopened global loadout still contains no merchant controls")
	_expect_eq(overlay.formal_shop_draft_instance_id(), draft_id, "physical L creates no replacement ShopDraft")
	_expect_eq(coordinator.current_snapshot().shop.session_id, shop_session_id, "physical L retains the same authority shop session")
	await _press_physical_loadout(coordinator)
	_expect(not overlay.visible, "second physical L returns to the physical shop world")
	_expect_eq(_authority_signature(coordinator.current_snapshot()), shop_before, "close/reopen/close preserves the complete authority signature")
	var start_x := coordinator.player.global_position.x
	Input.action_press(&"move_right")
	var reached_portal := false
	for _frame: int in 360:
		await physics_frame
		if shop_room.exit_portal.can_interact(coordinator.player.global_position):
			reached_portal = true
			break
	Input.action_release(&"move_right")
	_expect(reached_portal and coordinator.player.global_position.x > start_x + 300.0, "real move_right physics carries the player from spawn to the exit portal")
	_expect(shop_room.visible and coordinator.player.visible and shop_room.exit_portal.visible and shop_room.exit_portal.prompt.visible, "hidden overlay reveals shop room, player, portal, and F prompt")
	_expect(shop_room.exit_portal.prompt.text == "F · 离开商店", "world exit shows the exact F leave-shop prompt")
	await _press_interact()
	_expect(await _wait_combat(coordinator, &"combat_04_validation"), "shop exit portal calls existing leave transaction")
	await _clear_claim_and_portal(coordinator, &"combat_04_validation")
	_expect(await _wait_combat(coordinator, &"combat_06_final_boss"), "C3 portal loads boss directly")
	var boss := coordinator.active_room.enemies[0]
	# Task 61 retires the placeholder CombatEnemy + runtime 1.7x scale/purple
	# outline hack in favor of a dedicated BossTideEmber with real, larger
	# (200x200 at 2x) art -- the old placeholder-specific assertion here no
	# longer applies to any real Boss room instance.
	_expect(boss is BossTideEmber, "the formal Boss room spawns the dedicated BossTideEmber class")
	_expect(boss.terminal_enemy, "the Boss keeps terminal_enemy=true as the pure data flag growth/flow reward and kill-event logic depends on")
	boss.player = coordinator.player
	coordinator.player.global_position = boss.global_position + Vector2(-320.0, 0.0)
	var fired_before := boss.boss_projectiles_fired
	var boss_direction: Vector2 = boss.call("_resolve_accurate_direction", boss.ranged_projectile_profile, boss.player.global_position)
	boss.call("_apply_facing", boss_direction)
	boss.call("_launch_ranged_projectile", boss.ranged_projectile_profile, boss_direction, &"boss_arc")
	await process_frame
	var projectile := BOSS_PROJECTILE.instantiate() as ProjectileDelivery
	_expect(boss.boss_projectiles_fired == fired_before + 1 and projectile != null, "boss fires the existing ProjectileDelivery scene")
	if projectile != null:
		_expect(projectile.speed <= 260.0 and projectile.hurtbox_collision_mask == 16 and projectile.blocking_collision_mask == 4, "boss projectile is slow, targets player hurtbox, and is wall-blocked")
		projectile.free()
	var boss_reference: WeakRef = weakref(boss)
	for enemy: CombatEnemy in coordinator.active_room.enemies:
		_defeat(enemy)
	var fired_at_death := boss.boss_projectiles_fired
	var projectiles_at_death := _projectile_count(coordinator)
	await process_frame
	_expect(not is_instance_valid(boss_reference.get_ref()), "defeated formal boss node is released on the next frame")
	await physics_frame
	await physics_frame
	_expect(_projectile_count(coordinator) <= projectiles_at_death, "released boss creates no new projectile after death")
	_expect_eq(fired_at_death, fired_before + 1, "boss projectile counter freezes at the death boundary")
	_expect(coordinator.active_room.room_is_cleared and coordinator.active_room.portal == null, "boss clear reveals settlement chest without portal")
	var before_boss_chest := coordinator.current_snapshot()
	coordinator.player.global_position = coordinator.active_room.chest.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	var final := coordinator.current_snapshot()
	_expect(final.route.phase == RunPhase.RUN_COMPLETE and final.result != null and final.result.is_complete(), "settlement chest enters Results")
	_expect_eq(final.economy.balance, before_boss_chest.economy.balance, "boss settlement chest grants zero reward")
	_expect_eq(final.route.shop_visits, 1, "complete run visits one shop")
	_expect_eq(final.route.completed_combat_rooms, 4, "complete run finishes four battles")
	coordinator.queue_free()
	await process_frame


func _clear_claim_and_portal(coordinator: RunFlowCoordinator, expected_room: StringName) -> void:
	var room := coordinator.active_room
	_expect(room != null and room.room_id == expected_room, "%s is the active physical room" % String(expected_room))
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat(enemy)
	await process_frame
	_expect(room.room_is_cleared, "%s clears after all configured enemies" % String(expected_room))
	_expect_eq(coordinator.current_snapshot().route.current_room_id, expected_room, "kills do not auto-complete the room")
	coordinator.player.global_position = room.chest.global_position
	coordinator.player.interact_requested.emit()
	await process_frame
	_expect(room.chest.consumed and not room.portal.locked, "chest opens once and unlocks portal")
	coordinator.player.global_position = room.portal.global_position
	coordinator.player.interact_requested.emit()
	await process_frame


func _defeat(enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task41_finisher", 41, 41, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT))


func _first_projectile(node: Node) -> ProjectileDelivery:
	for child: Node in node.get_children():
		if child is ProjectileDelivery:
			return child as ProjectileDelivery
	return null


func _projectile_count(node: Node) -> int:
	var count := 1 if node is ProjectileDelivery else 0
	for child: Node in node.get_children():
		count += _projectile_count(child)
	return count


func _wait_combat(coordinator: RunFlowCoordinator, room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.active_room != null and coordinator.active_room.room_id == room_id and coordinator.current_snapshot().route.phase == RunPhase.COMBAT
	, 360)


func _wait_phase(coordinator: RunFlowCoordinator, phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return coordinator.host.run_session != null and coordinator.current_snapshot().route.phase == phase
	, 360)


func _wait_until(predicate: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _press_interact() -> void:
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _press_physical_loadout(coordinator: RunFlowCoordinator) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_L
	coordinator.combat_hud._unhandled_input(event)
	await process_frame


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [
		snapshot.revision,
		snapshot.route.phase,
		snapshot.route.run_id,
		snapshot.route.current_room_id,
		snapshot.economy.balance,
		snapshot.shop.session_id if snapshot.shop != null else &"",
	]


func _run_test(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _run_async_test(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _finish() -> void:
	quit(_harness.report("TASK 41 PHYSICAL FLOW WAVES BOSS TESTS"))
