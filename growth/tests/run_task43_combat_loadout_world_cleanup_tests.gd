extends SceneTree

const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const RUN_GAME: PackedScene = preload("res://scenes/run/run_game.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BATTLE_01_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_04_validation.tres")
const BATTLE_02_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_02_swarm.tres")
const TestHarness := preload("res://combat/tests/test_harness.gd")

var _harness := TestHarness.new()
var _hit_sequence := 43_000_000


class RecordingLoadoutPort:
	extends RuntimeLoadoutPort

	var current: RuntimeLoadoutSnapshot
	var catalog: RunContentCatalog

	func _init(initial: RuntimeLoadoutSnapshot, content_catalog: RunContentCatalog) -> void:
		current = initial
		catalog = content_catalog

	func snapshot() -> RuntimeLoadoutSnapshot:
		return RuntimeLoadoutSnapshot.new(current.entries, current.revision)

	func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		if candidate == null or not candidate.is_valid() or candidate.revision != current.revision:
			return RuntimeLoadoutChangeResult.rejected(&"invalid_or_stale_candidate", snapshot())
		for entry: RuntimeLoadoutSlotSnapshot in candidate.entries:
			if entry.skill_id.is_empty():
				continue
			var skill := catalog.gameplay_for(entry.skill_id)
			if skill == null:
				return RuntimeLoadoutChangeResult.rejected(&"unknown_skill", snapshot())
			if SkillSlotIds.is_active(entry.slot_id) != skill.is_active_skill():
				return RuntimeLoadoutChangeResult.rejected(&"wrong_slot_type", snapshot())
		return RuntimeLoadoutChangeResult.success(candidate)

	func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		var validation := validate_snapshot(candidate)
		if not validation.accepted:
			return validation
		if not current.same_mapping(candidate):
			current = RuntimeLoadoutSnapshot.new(candidate.entries, current.revision + 1)
		return RuntimeLoadoutChangeResult.success(snapshot())


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_test("formal_acquisition_auto_equip_atomicity", _test_formal_acquisition_auto_equip_atomicity)
	await _run_async_test("combat_loadout_gate_and_formal_cleanup", _test_combat_loadout_gate_and_formal_cleanup)
	await _run_async_test("boss_release_and_projectile_stop", _test_boss_release_and_projectile_stop)
	await _run_async_test("shared_platform_real_jump_reachability", _test_shared_platform_real_jump_reachability)
	_finish()


func _test_formal_acquisition_auto_equip_atomicity() -> void:
	var runtime := RecordingLoadoutPort.new(CATALOG.default_loadout_snapshot(), CATALOG)
	var session := RunSession.new(
		CATALOG.reward_definitions(), CATALOG.relic_definitions, CATALOG.initial_owned_skill_ids(),
		[ElementIds.WATER, ElementIds.FIRE], runtime, null,
		RunRulesSnapshot.formal_disabled(), CATALOG, 5000, FLOW, &"task40_drag_flow"
	)
	_expect(session.start_formal_run(&"start", 0).accepted, "formal auto-equip fixture starts through RunSession")
	var sequence := 0
	for room_index: int in 2:
		var pending := session.snapshot().route.pending_node_id
		var room := FLOW.combat_room_for(pending)
		sequence += 1
		_expect(session.accept_room_transition(StringName("accept_%d" % sequence), session.snapshot().revision, pending, 4300 + sequence, room.room_scene.resource_path).accepted, "formal room %d accepts" % (room_index + 1))
		var before := session.snapshot()
		var claim_id := StringName("claim_%d" % sequence)
		var claimed := session.claim_formal_room_chest(claim_id, before.revision, pending)
		_expect(claimed.accepted and claimed.chest_reward != null, "formal chest %d commits a typed reward" % (room_index + 1))
		_expect_eq(claimed.run_snapshot.revision, before.revision + 1, "chest acquisition advances run revision exactly once")
		if claimed.chest_reward.kind == RunChestRewardSnapshot.Kind.SKILL:
			var gained := claimed.chest_reward.skill_id
			var content := CATALOG.content_for(gained)
			var slots := SkillSlotIds.passive() if content.gameplay_definition.is_passive_skill() else SkillSlotIds.active()
			var first_empty := _first_empty(before.loadout, slots)
			if not first_empty.is_empty():
				_expect_eq(claimed.run_snapshot.loadout.get_skill_id(first_empty), gained, "chest skill fills the literal first empty same-type slot")
				_expect_eq(claimed.run_snapshot.loadout.revision, before.loadout.revision + 1, "chest auto-equip advances loadout revision exactly once")
			else:
				_expect(claimed.run_snapshot.loadout.same_mapping(before.loadout), "full same-type chest acquisition overwrites no slot")
				_expect_eq(claimed.run_snapshot.loadout.revision, before.loadout.revision, "full same-type chest acquisition changes no loadout revision")
		else:
			_expect(claimed.run_snapshot.loadout.same_mapping(before.loadout), "dust chest changes no mapping")
			_expect_eq(claimed.run_snapshot.loadout.revision, before.loadout.revision, "dust chest changes no loadout revision")
		var replay := session.claim_formal_room_chest(claim_id, before.revision, pending)
		_expect(replay == claimed, "identical chest command replays the exact result")
		_expect_eq(session.snapshot().revision, claimed.run_snapshot.revision, "chest replay advances no revision")
		_expect_eq(session.snapshot().loadout.revision, claimed.run_snapshot.loadout.revision, "chest replay advances no loadout revision")
		var definition := FLOW.combat_room_for(pending)
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("complete_%d" % sequence), pending, 0, 0,
			definition.completion_dream_dust, definition.final_boss
		)).accepted, "formal room %d completes" % (room_index + 1))
	_expect(session.snapshot().route.phase == RunPhase.SHOP and session.snapshot().shop != null, "two formal rooms reach the demo shop")
	_expect_eq(session.snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_1), &"element_bolt", "fixed cohort retains bolt in A1")
	_expect(not session.snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty(), "guaranteed first active chest auto-equips into literal A2")

	var purchased_burning := _purchase(session, &"burning", &"buy_burning")
	_expect_eq(purchased_burning.loadout.get_skill_id(SkillSlotIds.PASSIVE_1), &"burning", "shop passive purchase auto-equips into literal P1")
	var replay_before := session.snapshot()
	var burning_offer := _offer_for_skill(replay_before.shop, &"burning")
	var replay_purchase := session.purchase_skill(&"buy_burning", replay_before.revision - 1, replay_before.shop.session_id, burning_offer.offer_id)
	_expect(replay_purchase.accepted, "identical shop purchase command replays successfully")
	_expect_eq(session.snapshot().revision, replay_before.revision, "purchase replay changes no run revision")
	_expect_eq(session.snapshot().loadout.revision, replay_before.loadout.revision, "purchase replay changes no loadout revision")

	_purchase(session, &"unending", &"buy_unending")
	_purchase(session, &"passive_vitality", &"buy_vitality")
	_purchase(session, &"passive_energy", &"buy_energy")
	var full_passives := session.snapshot()
	_expect_eq(_slot_values(full_passives.loadout, SkillSlotIds.passive()), [&"burning", &"unending", &"passive_vitality", &"passive_energy"], "four passive purchases fill P1-P4 in literal order")
	var overflow_passive := _purchase(session, &"passive_reaction_energy", &"buy_reaction")
	_expect(overflow_passive.skills.owns(&"passive_reaction_energy"), "fifth passive purchase still grants ownership")
	_expect_eq(_slot_values(overflow_passive.loadout, SkillSlotIds.passive()), [&"burning", &"unending", &"passive_vitality", &"passive_energy"], "full passive slots are never overwritten")
	_expect_eq(overflow_passive.loadout.revision, full_passives.loadout.revision, "full passive purchase changes no loadout revision")

	var active_candidates: Array[StringName] = [&"elemental_laser", &"elemental_fury"]
	for skill_id: StringName in active_candidates:
		if session.snapshot().skills.owns(skill_id):
			continue
		var before_active := session.snapshot()
		var first_empty := _first_empty(before_active.loadout, SkillSlotIds.active())
		var after_active := _purchase(session, skill_id, StringName("buy_%s" % String(skill_id)))
		if first_empty.is_empty():
			_expect(after_active.loadout.same_mapping(before_active.loadout), "%s owned-only acquisition does not overwrite full active slots" % String(skill_id))
			_expect_eq(after_active.loadout.revision, before_active.loadout.revision, "%s full active acquisition changes no loadout revision" % String(skill_id))
		else:
			_expect_eq(after_active.loadout.get_skill_id(first_empty), skill_id, "%s fills literal first empty active slot" % String(skill_id))
			_expect_eq(after_active.loadout.revision, before_active.loadout.revision + 1, "%s auto-equip advances loadout once" % String(skill_id))
	_expect_eq(session.snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_1), &"element_bolt", "active A1 identity remains literal and frozen")
	_expect(not session.snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty(), "active A2 retains the guaranteed first-chest acquisition")


func _test_combat_loadout_gate_and_formal_cleanup() -> void:
	root.size = Vector2i(1920, 1080)
	var coordinator := RUN_GAME.instantiate() as RunFlowCoordinator
	coordinator.run_id_override = &"task43_world_gate"
	root.add_child(coordinator)
	current_scene = coordinator
	_expect(await _wait_until(func() -> bool: return coordinator.active_room != null and coordinator.current_snapshot().route.phase == RunPhase.COMBAT, 240), "RunGame boots a formal combat room")
	var overlay := coordinator.combat_hud.run_overlay as RunOverlayInterface
	overlay.toggle_loadout()
	await process_frame
	_expect(overlay.visible and overlay.formal_kind() == &"combat_loadout", "L opens the combat loadout page while enemies live")
	_expect(overlay.formal_shop_draft_instance_id() == 0, "combat loadout creates no ShopDraft")
	_expect(not coordinator.combat_loadout_available(), "live room keeps combat authority gate closed")
	_expect(_visible_text(overlay).contains("清场后可调整"), "live page shows the short clear-gate copy")
	var commands: Array[StringName] = []
	coordinator.ui_command_result.connect(func(command: StringName, _result: RunCommandResult) -> void: commands.append(command))
	var live_before := _authority_signature(coordinator.current_snapshot())
	overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_bolt", SkillSlotIds.ACTIVE_1), SkillSlotIds.ACTIVE_2)
	overlay.set("_formal_selected_slot_id", SkillSlotIds.ACTIVE_1)
	overlay.call("_formal_clear_selected_slot")
	var live_slot := overlay.formal_control(&"slot:active_2") as Button
	if live_slot != null:
		live_slot.pressed.emit()
	await process_frame
	_expect_eq(_authority_signature(coordinator.current_snapshot()), live_before, "live click/drag/clear change zero authority")
	_expect(commands.is_empty(), "live click/drag/clear make zero authority calls")

	var room := coordinator.active_room
	var initial_refs: Array[WeakRef] = []
	for enemy: CombatEnemy in room.initial_enemies:
		initial_refs.append(weakref(enemy))
		_defeat(enemy)
	_expect(room.reinforcement_activated, "single-wave completion synchronously closes the reinforcement gate")
	await process_frame
	_expect(_all_refs_freed(initial_refs), "formal initial-wave enemy nodes are gone on the next frame")
	_expect(room.room_is_cleared, "first-room initial wave opens the clear gate immediately")
	var reinforcement_refs: Array[WeakRef] = []
	for enemy: CombatEnemy in room.reinforcement_enemies:
		reinforcement_refs.append(weakref(enemy))
		_defeat(enemy)
	await process_frame
	_expect(_all_refs_freed(reinforcement_refs), "formal reinforcement nodes are gone on the next frame")
	_expect(reinforcement_refs.is_empty(), "first room creates no reinforcement nodes")
	_expect(room.room_is_cleared and room.chest.visible, "single wave reveals exactly one chest")
	_expect(coordinator.combat_loadout_available(), "same room opens combat loadout authority only after true clear")
	_expect(overlay.visible and _visible_text(overlay).contains("可点击或拖拽调整"), "same open page refreshes to the clear state")
	_expect(_chest_bottom_is_grounded(room), "normal chest alpha-visible bottom matches the authored ground")
	_expect(_all_refs_freed(initial_refs) and _all_refs_freed(reinforcement_refs), "grounded chest presentation does not depend on enemy corpse nodes")

	var wallet_before := coordinator.current_snapshot().economy.balance
	var click_before := coordinator.current_snapshot()
	(overlay.formal_control(&"select:element_bolt") as Button).pressed.emit()
	await process_frame
	(overlay.formal_control(&"slot:active_2") as Button).pressed.emit()
	await process_frame
	var click_after := coordinator.current_snapshot()
	_expect_eq(click_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"element_bolt", "cleared-room click commits the owned active skill")
	_expect_eq(click_after.revision, click_before.revision + 1, "cleared-room click advances run revision once")
	_expect_eq(click_after.loadout.revision, click_before.loadout.revision + 1, "cleared-room click advances loadout revision once")
	var drag_before := click_after
	overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"element_bolt", SkillSlotIds.ACTIVE_2), SkillSlotIds.ACTIVE_3)
	await process_frame
	var drag_after := coordinator.current_snapshot()
	_expect_eq(drag_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_3), &"element_bolt", "cleared-room drag commits through authority")
	_expect_eq(drag_after.revision, drag_before.revision + 1, "cleared-room drag advances run revision once")
	var reject_before := drag_after
	overlay.call("_formal_slot_drop", Vector2.ZERO, _payload(&"passive_vitality", &""), SkillSlotIds.PASSIVE_1)
	await process_frame
	_expect_eq(_authority_signature(coordinator.current_snapshot()), _authority_signature(reject_before), "unowned cleared-room rejection restores exact authority")
	_expect_eq(coordinator.current_snapshot().economy.balance, wallet_before, "combat loadout actions never change the wallet")
	_expect_eq(commands.count(&"apply_combat_loadout"), 3, "two successes and one rejection each make exactly one authority call")
	coordinator.queue_free()
	await process_frame


func _test_boss_release_and_projectile_stop() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var definition := FLOW.combat_room_for(&"combat_06_final_boss")
	var room := definition.room_scene.instantiate() as RunRoomInstance
	stage.add_child(room)
	_expect(room.configure(definition), "formal Boss room configures")
	room.activate()
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	stage.add_child(player)
	player.global_position = room.player_spawn_global_position()
	var boss := room.enemies[0]
	boss.player = player
	var death_count := [0]
	boss.enemy_defeated.connect(func() -> void: death_count[0] += 1)
	var boss_direction: Vector2 = boss.call("_resolve_accurate_direction", boss.ranged_projectile_profile, boss.player.global_position)
	boss.call("_apply_facing", boss_direction)
	boss.call("_launch_ranged_projectile", boss.ranged_projectile_profile, boss_direction, &"boss_arc")
	var fired_at_death := boss.boss_projectiles_fired
	var projectile_count_at_death := _projectile_count(stage)
	var boss_ref: WeakRef = weakref(boss)
	_defeat(boss)
	_defeat(boss)
	_expect_eq(death_count[0], 1, "formal Boss death event settles exactly once")
	await process_frame
	_expect(not is_instance_valid(boss_ref.get_ref()), "formal Boss node is released on the next frame")
	await physics_frame
	await physics_frame
	_expect(_projectile_count(stage) <= projectile_count_at_death, "released Boss produces no new projectile")
	_expect(fired_at_death == 1 and room.room_is_cleared, "Boss firing freezes and settlement chest appears")
	_expect(_chest_bottom_is_grounded(room), "Boss settlement chest alpha-visible bottom matches the authored ground")
	stage.queue_free()
	await process_frame


func _test_shared_platform_real_jump_reachability() -> void:
	var platform_rooms: Array[Dictionary] = [
		{"definition": BATTLE_01_ROOM, "scene": "res://scenes/run/rooms/room_arena_flat.tscn", "target_y": 484.0, "target_min_x": 699.0, "target_max_x": 837.0},
		{"definition": BATTLE_02_ROOM, "scene": "res://scenes/run/rooms/room_arena_tidal_battle_02.tscn", "target_y": 528.0, "target_min_x": 1110.0, "target_max_x": 1252.0},
	]
	for case: Dictionary in platform_rooms:
		var definition: CombatRoomDefinition = case["definition"]
		var room_id := definition.room_id
		_expect_eq(definition.room_scene.resource_path, case["scene"], "%s uses its formal full-room platform template" % String(room_id))
		var stage := Node2D.new()
		root.add_child(stage)
		current_scene = stage
		var room := definition.room_scene.instantiate() as RunRoomInstance
		stage.add_child(room)
		_expect(room.configure(definition), "%s room configures" % String(room_id))
		room.activate()
		for enemy: CombatEnemy in room.enemies:
			enemy.ai_enabled = false
		var player := PLAYER_SCENE.instantiate() as PlayerCharacter
		stage.add_child(player)
		player.global_position = room.player_spawn_global_position()
		_expect(await _wait_until(func() -> bool: return player.is_on_floor(), 30), "%s player settles on ground before input" % String(room_id))
		var spawn_position := player.global_position
		_expect(spawn_position.y > float(case["target_y"]), "%s starts below the reachable platform" % String(room_id))
		Input.action_press(&"move_right")
		var jump := InputEventAction.new()
		jump.action = &"jump"
		jump.pressed = true
		Input.parse_input_event(jump)
		await process_frame
		_expect(player.jump_requested, "%s real jump event reaches Player input handler" % String(room_id))
		await physics_frame
		var release_jump := InputEventAction.new()
		release_jump.action = &"jump"
		release_jump.pressed = false
		Input.parse_input_event(release_jump)
		var left_ground := false
		var landed_on_lower := false
		for _frame: int in 150:
			await physics_frame
			left_ground = left_ground or not player.is_on_floor()
			if left_ground and player.is_on_floor() and absf(player.global_position.y - float(case["target_y"])) <= 3.0 and player.global_position.x >= float(case["target_min_x"]) and player.global_position.x <= float(case["target_max_x"]):
				landed_on_lower = true
				break
		Input.action_release(&"move_right")
		_expect(landed_on_lower, "%s reaches its first formal platform with real jump input and physics frames" % String(room_id))
		_expect(player.global_position.distance_to(spawn_position) > 80.0, "%s records physical movement from the ground spawn" % String(room_id))
		stage.queue_free()
		await process_frame


func _purchase(session: RunSession, skill_id: StringName, command_id: StringName) -> RunSnapshot:
	var before := session.snapshot()
	var offer := _offer_for_skill(before.shop, skill_id)
	_expect(offer != null, "%s has a literal formal shop offer" % String(skill_id))
	if offer == null:
		return before
	var first_empty := _first_empty(before.loadout, SkillSlotIds.passive() if CATALOG.content_for(skill_id).gameplay_definition.is_passive_skill() else SkillSlotIds.active())
	var result := session.purchase_skill(command_id, before.revision, before.shop.session_id, offer.offer_id)
	_expect(result.accepted, "%s purchase succeeds" % String(skill_id))
	var after := result.run_snapshot
	_expect_eq(after.revision, before.revision + 1, "%s purchase advances run revision once" % String(skill_id))
	_expect_eq(after.economy.balance, before.economy.balance - offer.purchase_price, "%s purchase charges its literal price once" % String(skill_id))
	_expect_eq(after.loadout.revision, before.loadout.revision + (0 if first_empty.is_empty() else 1), "%s purchase has the exact loadout revision delta" % String(skill_id))
	return after


func _offer_for_skill(shop: ShopSnapshot, skill_id: StringName) -> ShopOfferSnapshot:
	if shop == null:
		return null
	for offer: ShopOfferSnapshot in shop.offers:
		if offer.skill_id == skill_id:
			return offer
	return null


func _first_empty(loadout: RuntimeLoadoutSnapshot, slots: Array[StringName]) -> StringName:
	for slot_id: StringName in slots:
		if loadout.get_skill_id(slot_id).is_empty():
			return slot_id
	return &""


func _slot_values(loadout: RuntimeLoadoutSnapshot, slots: Array[StringName]) -> Array[StringName]:
	var values: Array[StringName] = []
	for slot_id: StringName in slots:
		values.append(loadout.get_skill_id(slot_id))
	return values


func _defeat(enemy: CombatEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.defeated:
		return
	_hit_sequence += 1
	var cast := CastSnapshot.new(_hit_sequence, &"task43_finisher", 43, 43, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var request := HitRequest.new(cast, RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0), _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	var result := enemy.combat_receiver.receive_hit(request)
	_expect(result.accepted and enemy.defeated, "formal enemy dies through CombatReceiver")


func _all_refs_freed(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()):
			return false
	return true


func _chest_bottom_is_grounded(room: RunRoomInstance) -> bool:
	var sprite := room.chest.get_node("Sprite2D") as Sprite2D
	var image := sprite.texture.get_image()
	var max_alpha_y := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				max_alpha_y = maxi(max_alpha_y, y)
	var bottom := (
		room.chest.global_position.y
		+ sprite.position.y
		+ (float(max_alpha_y + 1) - float(image.get_height()) * 0.5) * sprite.scale.y
	)
	var ground_shape := room.get_node("Ground/CollisionShape2D") as CollisionShape2D
	var rectangle := ground_shape.shape as RectangleShape2D
	var ground_top := ground_shape.global_position.y - rectangle.size.y * 0.5
	return absf(bottom - ground_top) <= 2.0


func _projectile_count(node: Node) -> int:
	var count := 1 if node is ProjectileDelivery else 0
	for child: Node in node.get_children():
		count += _projectile_count(child)
	return count


func _payload(skill_id: StringName, source_slot_id: StringName) -> Dictionary:
	return {"kind": &"formal_shop_loadout", "skill_id": skill_id, "source_slot_id": source_slot_id}


func _visible_text(node: Node) -> String:
	var result := ""
	if node is Label and node.visible:
		result += (node as Label).text + "\n"
	if node is Button and node.visible:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _visible_text(child)
	return result


func _authority_signature(snapshot: RunSnapshot) -> Array:
	return [snapshot.revision, snapshot.loadout.revision, _slot_values(snapshot.loadout, SkillSlotIds.all()), snapshot.economy.balance, snapshot.economy.total_spent_on_purchases]


func _wait_until(predicate: Callable, frame_limit: int) -> bool:
	for _frame: int in frame_limit:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _run_test(name: String, body: Callable) -> void:
	await _harness.run_test(name, body)


func _run_async_test(name: String, body: Callable) -> void:
	await _harness.run_test(name, body)


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)
	if not condition:
		push_error("FAIL: %s" % message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (actual=%s expected=%s)" % [message, str(actual), str(expected)])


func _finish() -> void:
	quit(_harness.report("TASK 43 COMBAT LOADOUT WORLD CLEANUP TESTS"))
