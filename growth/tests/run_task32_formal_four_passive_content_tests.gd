extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_five_stage_demo.tres")
const PASSIVE_IDS: Array[StringName] = [
	&"burning",
	&"unending",
	&"passive_vitality",
	&"passive_energy",
]

var _harness := TestHarness.new()
var _hit_sequence: int = 3200000
var _coordinator: RunFlowCoordinator
var _overlay: RunOverlayInterface
var _runtime_before_rebuild: Array[PassiveEffectRuntime] = []
var _registration_before_rebuild: int = 0
var _unregistration_before_rebuild: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	_run_test("formal_catalog_has_four_active_and_five_passive_contents", _test_catalog_shape)
	_run_test("new_stat_passives_are_purchase_only_static_content", _test_new_content_contract)

	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	_coordinator.run_id_override = _pre_shop_dust_run_id()
	_expect(_coordinator != null, "real RunGame instantiates for Task32")
	if _coordinator == null:
		_finish()
		return
	root.add_child(_coordinator)
	current_scene = _coordinator
	_expect(await _wait_for_room(&"combat_01_entry"), "real RunGame boots combat one")
	_overlay = _coordinator.combat_hud.run_overlay as RunOverlayInterface

	await _run_async_test("formal_shop_rejections_and_first_passive_are_atomic", _test_first_shop)
	await _run_async_test("real_run_purchases_and_equips_four_unique_passives", _test_second_shop)
	await _run_async_test("real_room_rebuild_preserves_four_unique_passive_runtimes", _test_room_rebuild)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _test_catalog_shape() -> void:
	_expect(CATALOG != null and CATALOG.is_valid(), "formal catalog validates")
	_expect_eq(CATALOG.gameplay_definitions().size(), 10, "catalog has fixed basic plus nine purchasable definitions")
	_expect_eq(CATALOG.shop_contents().size(), 9, "catalog has nine purchasable contents")
	_expect_eq(CATALOG.reward_definitions().size(), 5, "historical reward projection remains five")
	var active_count := 0
	var passive_count := 0
	for content: SkillContentDefinition in CATALOG.shop_contents():
		if content.gameplay_definition.is_active_skill():
			active_count += 1
		else:
			passive_count += 1
	_expect_eq(active_count, 4, "shop catalog has four active contents")
	_expect_eq(passive_count, 5, "shop catalog has five passive contents")
	var reaction_energy := CATALOG.content_for(&"passive_reaction_energy")
	_expect(reaction_energy != null and reaction_energy.purchase_price == 75, "element echo joins the formal shop catalog")
	_expect(reaction_energy.gameplay_definition.passive_effect_definition is ReactionEnergyPassiveEffectDefinition, "element echo uses the typed reaction-energy runtime")
	_expect(not reaction_energy.reward_pool and reaction_energy.active_progression == null, "element echo adds neither free reward nor passive levels")
	_expect_eq(CATALOG.initial_owned_skill_ids(), [&"element_bolt"], "new passives are not initially owned")
	for legacy_id: StringName in [&"water_lance", &"fire_lance", &"passive_focus", &"passive_balance"]:
		_expect(CATALOG.content_for(legacy_id) == null, "excluded legacy content remains unregistered: %s" % String(legacy_id))


func _test_new_content_contract() -> void:
	var specs := {
		&"passive_vitality": {
			"name": "坚韧体魄",
			"icon": "res://assets/generated/vfx/passive_vitality/icon.png",
			"gameplay": "res://resources/skills/passive_vitality.tres",
			"health": 20,
			"energy": 0,
		},
		&"passive_energy": {
			"name": "元素储备",
			"icon": "res://assets/generated/vfx/passive_energy/icon.png",
			"gameplay": "res://resources/skills/passive_energy.tres",
			"health": 0,
			"energy": 10,
		},
	}
	var icon_paths: Array[String] = []
	for skill_id: StringName in specs:
		var spec: Dictionary = specs[skill_id]
		var content := CATALOG.content_for(skill_id)
		_expect(content != null and content.is_valid(), "%s is valid formal content" % String(skill_id))
		if content == null:
			continue
		_expect_eq(content.display_name, spec["name"], "%s has frozen product name" % String(skill_id))
		_expect(content.gameplay_definition.is_passive_skill(), "%s remains a strict passive" % String(skill_id))
		_expect(content.is_shop_purchasable() and content.purchase_price == 75, "%s is purchasable for 75 dream dust" % String(skill_id))
		_expect(not content.initially_owned and content.default_slot_id.is_empty(), "%s has no initial ownership or default slot" % String(skill_id))
		_expect(not content.reward_pool and not content.initial_reward_pool, "%s does not enter free rewards" % String(skill_id))
		_expect(content.active_progression == null, "%s has no active level curve" % String(skill_id))
		_expect(content.presentation_scene == null and content.runtime_delivery_scene == null, "%s adds no world presentation or delivery" % String(skill_id))
		_expect(content.icon != null and content.icon.resource_path == spec["icon"], "%s has its independent formal icon" % String(skill_id))
		_expect_eq(content.gameplay_definition.resource_path, spec["gameplay"], "%s reuses the frozen gameplay resource" % String(skill_id))
		var effect := content.gameplay_definition.passive_effect_definition as StatModifierPassiveEffectDefinition
		_expect(effect != null, "%s uses typed stat-modifier runtime data" % String(skill_id))
		if effect != null:
			_expect_eq(effect.maximum_health_bonus, spec["health"], "%s preserves maximum-health bonus" % String(skill_id))
			_expect_eq(effect.maximum_energy_bonus, spec["energy"], "%s preserves maximum-SP bonus" % String(skill_id))
		icon_paths.append(content.icon.resource_path)
	_expect_eq(icon_paths.size(), 2, "both new passives expose icons")
	_expect(icon_paths[0] != icon_paths[1], "new passives use distinct icon resources")


func _test_first_shop() -> void:
	await _finish_current_room()
	_expect(await _wait_for_room(&"combat_02_swarm"), "combat one reaches the fixed second combat")
	await _finish_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "combat two opens the single formal shop")
	_expect(_overlay.visible and _overlay.formal_kind() == &"shop", "formal shop UI is live")
	var before := _coordinator.current_snapshot()
	_expect(before.economy.balance >= 220 and before.economy.balance == before.economy.total_earned, "single shop balance exactly reflects two rooms plus typed chest rewards")
	_expect_eq(before.shop.offers.size(), _unowned_shop_offer_count(before), "single shop offers every and only unowned purchasable content")
	var burning_offer := _offer_for_skill(before.shop, &"burning")
	_expect(burning_offer != null, "first shop has formal burning offer")
	if burning_offer == null:
		return

	var signature_before := _signature(before)
	var stale := _coordinator.purchase_shop_skill(
		burning_offer.offer_id,
		before.revision - 1,
		before.shop.session_id
	)
	_expect(not stale.accepted and stale.reject_reason == RunCommandResult.RejectReason.STALE_RUN_REVISION, "stale purchase rejects with typed reason")
	_expect_eq(_signature(_coordinator.current_snapshot()), signature_before, "stale purchase changes no authority state")

	_expect(_emit_button(&"purchase:burning"), "visible formal control purchases burning")
	await process_frame
	var purchased := _coordinator.current_snapshot()
	_expect(purchased.skills.owns(&"burning"), "burning ownership commits")
	_expect_eq(purchased.economy.balance, before.economy.balance - 75, "burning charges exactly 75 dream dust")
	_expect_eq(purchased.economy.total_spent_on_purchases, 75, "purchase ledger charges once")
	_expect_eq(purchased.revision, before.revision + 1, "successful purchase advances authority once")
	_expect_eq(purchased.loadout.revision, before.loadout.revision + 1, "burning automatic P1 loadout advances exactly once")
	var duplicate_signature := _signature(purchased)
	var duplicate := _coordinator.purchase_shop_skill(
		burning_offer.offer_id,
		purchased.revision,
		purchased.shop.session_id
	)
	_expect(not duplicate.accepted and duplicate.reject_reason == RunCommandResult.RejectReason.ALREADY_OWNED, "duplicate purchase rejects before a second charge")
	_expect_eq(_signature(_coordinator.current_snapshot()), duplicate_signature, "duplicate purchase changes no authority state")

	var unending_offer := _offer_for_skill(purchased.shop, &"unending")
	_expect(unending_offer != null, "unending remains an unowned formal offer")
	_expect(purchased.economy.balance >= 225, "single-shop budget preserves three remaining exact passive purchases")

	var passive_upgrade := _coordinator.upgrade_shop_skill(
		&"burning",
		purchased.revision,
		purchased.shop.session_id
	)
	_expect(not passive_upgrade.accepted and passive_upgrade.reject_reason == RunCommandResult.RejectReason.PASSIVE_HAS_NO_LEVELS, "formal passive rejects active progression")
	_expect_eq(_signature(_coordinator.current_snapshot()), duplicate_signature, "passive upgrade rejection changes nothing")

	_expect_eq(purchased.loadout.get_skill_id(SkillSlotIds.PASSIVE_1), &"burning", "purchase atomically maps burning to P1")
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(purchased.loadout), "P1 RuntimeLoadout matches RunSnapshot immediately")
	_expect_eq(_coordinator.host.runtime_loadout.registered_passive_skill_ids, [&"burning"], "burning Runtime registers exactly once")

	_expect(_button(&"leave_shop").disabled, "formal UI cannot bypass the physical shop exit")


func _test_second_shop() -> void:
	_expect(await _wait_for_phase(RunPhase.SHOP), "all four passives are handled in the one formal shop")
	var second_shop := _coordinator.current_snapshot()
	_expect(second_shop.economy.total_earned >= 220, "first two combats plus typed chests fund the single shop")
	_expect_eq(second_shop.economy.balance, second_shop.economy.total_earned - 75, "single shop balance reflects the first passive purchase")

	var purchases := [
		[&"unending", SkillSlotIds.PASSIVE_2],
		[&"passive_vitality", SkillSlotIds.PASSIVE_3],
		[&"passive_energy", SkillSlotIds.PASSIVE_4],
	]
	for purchase_spec: Array in purchases:
		var skill_id: StringName = purchase_spec[0]
		var slot_id: StringName = purchase_spec[1]
		var before := _coordinator.current_snapshot()
		_expect(_button(StringName("purchase:%s" % String(skill_id))) != null, "%s has a real visible purchase control" % String(skill_id))
		_expect(_emit_button(StringName("purchase:%s" % String(skill_id))), "%s purchases through formal UI" % String(skill_id))
		await process_frame
		var purchased := _coordinator.current_snapshot()
		_expect(purchased.skills.owns(skill_id), "%s commits purchased ownership" % String(skill_id))
		_expect_eq(purchased.economy.balance, before.economy.balance - 75, "%s charges exactly 75" % String(skill_id))
		_expect_eq(purchased.revision, before.revision + 1, "%s purchase advances authority once" % String(skill_id))
		_expect_eq(purchased.loadout.revision, before.loadout.revision + 1, "%s automatic loadout advances exactly once" % String(skill_id))
		var progress := purchased.skills.progress_for(skill_id)
		_expect(progress != null and progress.is_passive() and progress.level == 1 and progress.cumulative_upgrade_spend == 0, "%s is frozen level-free passive progress" % String(skill_id))
		_expect_eq(purchased.loadout.get_skill_id(slot_id), skill_id, "%s purchase atomically maps to its literal passive endpoint" % String(skill_id))

	var final_shop := _coordinator.current_snapshot()
	_expect_eq(final_shop.economy.total_spent_on_purchases, 300, "four formal passive purchases spend exactly 300")
	_expect_eq(final_shop.economy.balance, final_shop.economy.total_earned - 300, "wallet exactly conserves typed rewards minus four purchases")
	_expect(final_shop.economy.is_valid() and final_shop.economy.balance == final_shop.economy.conserved_balance(), "final shop wallet is conserved")
	_expect_eq(final_shop.loadout.entries.size(), 7, "authority loadout remains exactly seven slots")
	for index: int in PASSIVE_IDS.size():
		var slot_id := SkillSlotIds.passive()[index]
		_expect_eq(final_shop.loadout.get_skill_id(slot_id), PASSIVE_IDS[index], "P%d contains the intended unique passive" % (index + 1))
		_expect(final_shop.skills.owns(PASSIVE_IDS[index]), "%s is authority-owned" % String(PASSIVE_IDS[index]))
	_expect_eq(_unique_count(_coordinator.host.runtime_loadout.registered_passive_skill_ids), 4, "four Runtime passives are unique")
	_expect_eq(_coordinator.host.runtime_loadout.registered_passive_skill_ids, PASSIVE_IDS, "Runtime passives register once in P1-P4 order")
	_expect_eq(_coordinator.host.runtime_loadout.registered_passive_slot_ids, SkillSlotIds.passive(), "Runtime audit covers P1-P4")
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(final_shop.loadout), "runtime and authority mappings align before evidence")
	for skill_id: StringName in PASSIVE_IDS:
		var content := CATALOG.content_for(skill_id)
		_expect(content != null and content.icon != null, "%s has a real catalog icon before evidence" % String(skill_id))

	_runtime_before_rebuild = _runtime_instances(_coordinator.host.runtime_loadout)
	_registration_before_rebuild = _coordinator.host.runtime_loadout.passive_registration_commit_count
	_unregistration_before_rebuild = _coordinator.host.runtime_loadout.passive_unregistration_commit_count
	_expect_eq(_runtime_before_rebuild.size(), 4, "four concrete passive runtime instances exist before room rebuild")
	_expect_eq(_unique_object_count(_runtime_before_rebuild), 4, "each P1-P4 slot has a distinct runtime object")


func _test_room_rebuild() -> void:
	_expect(await _wait_until(func() -> bool: return _coordinator.active_shop_room != null, 360), "physical shop room is active")
	_coordinator.player.global_position = _coordinator.active_shop_room.exit_portal.global_position
	_coordinator.player.interact_requested.emit()
	_expect(await _wait_for_room(&"combat_04_validation"), "formal RunGame activates combat four")
	var runtime := _coordinator.host.runtime_loadout
	var combat_snapshot := _coordinator.current_snapshot()
	_expect_eq(combat_snapshot.route.phase, RunPhase.COMBAT, "authority is in real combat after rebuild")
	_expect_eq(runtime.registered_passive_skill_ids, PASSIVE_IDS, "room rebuild retains P1-P4 skill identities")
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "room rebuild has no duplicate passive registration")
	_expect_eq(runtime.registered_passive_slot_ids, SkillSlotIds.passive(), "room rebuild retains P1-P4 slot audit")
	_expect_eq(runtime.passive_registration_commit_count, _registration_before_rebuild + 1, "room rebuild registers one batch")
	_expect_eq(runtime.passive_unregistration_commit_count, _unregistration_before_rebuild + 1, "room rebuild unregisters one prior batch")
	var rebuilt := _runtime_instances(runtime)
	_expect_eq(rebuilt.size(), 4, "room rebuild creates four runtime instances")
	_expect_eq(_unique_object_count(rebuilt), 4, "rebuilt runtime instances remain distinct")
	_expect(not _same_instances(_runtime_before_rebuild, rebuilt), "room rebuild replaces every prior runtime instance")
	_expect(runtime.snapshot().same_mapping(combat_snapshot.loadout), "rebuilt RuntimeLoadout still matches authority")
	for index: int in PASSIVE_IDS.size():
		var slot_id := SkillSlotIds.passive()[index]
		var slot := _coordinator.combat_hud.visual_slot_panel(slot_id)
		var icon := slot.get_node("Margin/Body/Icon") as TextureRect
		var name_label := slot.get_node("Margin/Body/Name") as Label
		var content := CATALOG.content_for(PASSIVE_IDS[index])
		_expect(slot != null and slot.is_visible_in_tree(), "combat HUD P%d is visible" % (index + 1))
		_expect(icon != null and icon.texture == content.icon, "combat HUD P%d consumes the formal icon" % (index + 1))
		_expect(name_label != null and name_label.text == content.display_name, "combat HUD P%d consumes the formal name" % (index + 1))
		_expect(not (slot.get_node("Margin/Body/Key") as Control).visible, "combat HUD P%d has no fake key" % (index + 1))
		_expect(not (slot.get_node("Margin/Body/Level") as Control).visible, "combat HUD P%d has no fake level" % (index + 1))
		_expect(not (slot.get_node("Margin/Body/Cost") as Control).visible, "combat HUD P%d has no fake SP cost" % (index + 1))
		_expect(not (slot.get_node("Margin/Body/CooldownMask") as Control).visible, "combat HUD P%d has no fake cooldown" % (index + 1))


func _offer_for_skill(shop: ShopSnapshot, skill_id: StringName) -> ShopOfferSnapshot:
	if shop == null:
		return null
	for offer: ShopOfferSnapshot in shop.offers:
		if offer.skill_id == skill_id:
			return offer
	return null


func _pre_shop_dust_run_id() -> StringName:
	for index: int in 256:
		var run_id := StringName("task32_passive_flow_%03d" % index)
		var session := RunSession.new(
			CATALOG.reward_definitions(), CATALOG.relic_definitions,
			CATALOG.initial_owned_skill_ids(), [ElementIds.WATER, ElementIds.FIRE],
			null, null, RunRulesSnapshot.formal_disabled(), CATALOG, 0, FLOW, run_id
		)
		if not session.start_formal_run(&"start", 0).accepted:
			continue
		var first := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_first", session.snapshot().revision, first.room_id, 32_000 + index * 2, first.room_scene.resource_path).accepted:
			continue
		if not session.claim_formal_room_chest(&"claim_first", session.snapshot().revision, first.room_id).accepted:
			continue
		if not session.handle_event(RoomCompletedEvent.new(&"complete_first", first.room_id, 0, 0, first.completion_dream_dust, false)).accepted:
			continue
		var second := FLOW.combat_room_for(session.snapshot().route.pending_node_id)
		if not session.accept_room_transition(&"accept_second", session.snapshot().revision, second.room_id, 32_001 + index * 2, second.room_scene.resource_path).accepted:
			continue
		var claim := session.claim_formal_room_chest(&"claim_second", session.snapshot().revision, second.room_id)
		if claim.accepted and claim.chest_reward.kind == RunChestRewardSnapshot.Kind.DREAM_DUST:
			return run_id
	_expect(false, "a deterministic second-room dust cohort exists for the four-passive budget")
	return &"task32_passive_flow_fallback"


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button


func _route_index(option_id: StringName) -> int:
	var options := _coordinator.current_snapshot().route.next_options
	for index: int in options.size():
		if options[index].option_id == option_id:
			return index
	return -1


func _emit_button(control_id: StringName) -> bool:
	var button := _button(control_id)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


func _finish_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "Task32 uses a configured real combat room")
	if room == null:
		return
	for enemy: CombatEnemy in room.initial_enemies:
		_defeat_enemy(enemy)
	await process_frame
	for enemy: CombatEnemy in room.reinforcement_enemies:
		_defeat_enemy(enemy)
	await process_frame
	_expect(room.room_is_cleared, "Task32 clears both waves before world interaction")
	_coordinator.player.global_position = room.chest.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame
	if room.room_definition.final_boss:
		return
	_coordinator.player.global_position = room.portal.global_position
	_coordinator.player.interact_requested.emit()
	await process_frame


func _defeat_enemy(enemy: CombatEnemy) -> void:
	_hit_sequence += 1
	var cast := CastSnapshot.new(
		_hit_sequence,
		&"task32_formal_finisher",
		_coordinator.player.get_instance_id(),
		_coordinator.player.get_instance_id(),
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
	var hit := enemy.combat_receiver.receive_hit(request)
	_expect(hit.accepted and enemy.defeated, "Task32 room enemy is defeated through real CombatReceiver")


func _unowned_shop_offer_count(snapshot: RunSnapshot) -> int:
	var count := 0
	for content: SkillContentDefinition in CATALOG.shop_contents():
		if not snapshot.skills.owns(content.skill_id):
			count += 1
	return count


func _wait_for_room(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
			and _coordinator.active_room != null
			and _coordinator.active_room.room_id == room_id
		)
	, 480)


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == phase
		)
	, 480)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _signature(snapshot: RunSnapshot) -> Array:
	return [
		snapshot.revision,
		snapshot.economy.balance,
		snapshot.economy.total_earned,
		snapshot.economy.total_spent_on_purchases,
		snapshot.skills.owned_skill_ids,
		_loadout_signature(snapshot.loadout),
		snapshot.shop.session_id if snapshot.shop != null else StringName(),
	]


func _loadout_signature(snapshot: RuntimeLoadoutSnapshot) -> Array[String]:
	var result: Array[String] = []
	for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
		result.append("%s=%s" % [String(entry.slot_id), String(entry.skill_id)])
	return result


func _runtime_instances(runtime: RuntimeSkillLoadout) -> Array[PassiveEffectRuntime]:
	var result: Array[PassiveEffectRuntime] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var instance := runtime.passive_runtime_for_slot(slot_id)
		if instance != null:
			result.append(instance)
	return result


func _same_instances(left: Array[PassiveEffectRuntime], right: Array[PassiveEffectRuntime]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true


func _unique_object_count(values: Array[PassiveEffectRuntime]) -> int:
	var unique: Array[PassiveEffectRuntime] = []
	for value: PassiveEffectRuntime in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _run_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _finish() -> void:
	quit(_harness.report("TASK 32 FORMAL FOUR PASSIVE CONTENT TESTS"))
