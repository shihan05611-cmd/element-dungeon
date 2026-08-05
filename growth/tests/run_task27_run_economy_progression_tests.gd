extends SceneTree

const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")

class RejectingLoadoutPort:
	extends RuntimeLoadoutPort

	var current: RuntimeLoadoutSnapshot
	var commit_calls: int = 0

	func _init(initial: RuntimeLoadoutSnapshot) -> void:
		current = initial

	func snapshot() -> RuntimeLoadoutSnapshot:
		return RuntimeLoadoutSnapshot.new(current.entries, current.revision)

	func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		return RuntimeLoadoutChangeResult.success(candidate)

	func try_replace_snapshot(_candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		commit_calls += 1
		return RuntimeLoadoutChangeResult.rejected(&"task27_final_port_rejected", snapshot())


var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run_test("catalog_and_frozen_rules", _test_catalog_and_frozen_rules)
	_run_test("disabled_observe_enabled_modes", _test_disabled_observe_enabled_modes)
	_run_test("active_and_passive_purchase", _test_active_and_passive_purchase)
	_run_test("active_upgrade_curve_and_max", _test_active_upgrade_curve_and_max)
	_run_test("reset_floor_and_purchase_not_refunded", _test_reset_floor_and_purchase_not_refunded)
	_run_test("economy_rejections_are_atomic", _test_economy_rejections_are_atomic)
	_run_test("command_replay_and_id_reuse", _test_command_replay_and_id_reuse)
	_run_test("dream_dust_rewards_and_terminal_zero", _test_dream_dust_rewards_and_terminal_zero)
	_run_test("loadout_and_room_preserve_level", _test_loadout_and_room_preserve_level)
	_run_test("final_loadout_port_rejection_is_atomic", _test_final_loadout_port_rejection_is_atomic)
	_run_test("snapshot_collections_are_copies", _test_snapshot_collections_are_copies)

	if _failures.is_empty():
		print("TASK 27 RUN ECONOMY PROGRESSION TESTS PASSED: %d tests, %d assertions" % [
			_tests,
			_assertions,
		])
		quit(0)
	else:
		printerr("TASK 27 RUN ECONOMY PROGRESSION TESTS FAILED: %d failures / %d assertions" % [
			_failures.size(),
			_assertions,
		])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _test_catalog_and_frozen_rules() -> void:
	_expect(CATALOG != null and CATALOG.is_valid(), "production catalog remains loadable")
	_expect_eq(CATALOG.shop_contents().size(), 6, "all six non-basic skills have shop definitions")
	for content: SkillContentDefinition in CATALOG.shop_contents():
		_expect(content.purchase_price > 0, "shop content has positive purchase price: %s" % String(content.skill_id))
		if content.gameplay_definition.is_active_skill():
			_expect(content.active_progression != null and content.active_progression.is_valid(), "active has valid progression: %s" % String(content.skill_id))
			_expect_eq(content.active_progression.definition_for_level(1).upgrade_price, 0, "Lv1 has no upgrade price")
		else:
			_expect(content.active_progression == null, "passive has no level definition")
	var source_rules := RunRulesSnapshot.formal_disabled()
	var session := _make_session(0, source_rules)
	var snapshot := session.snapshot()
	_expect(snapshot.rules != source_rules, "RunSession copies rules at creation")
	_expect_eq(snapshot.rules.progression_mode, RunFeatureMode.Value.DISABLED, "progression mode frozen disabled")
	_expect_eq(snapshot.rules.relic_mode, RunFeatureMode.Value.DISABLED, "relic mode frozen disabled")
	_expect_eq(snapshot.rules.upgrade_refund_basis_points, 7000, "refund is frozen at 7000 basis points")
	_expect_eq(snapshot.rules.terminal_enemy_dream_dust_reward, 0, "terminal enemy reward is explicitly zero")
	_expect_eq(snapshot.rules.terminal_room_dream_dust_reward, 0, "terminal room reward is explicitly zero")
	_expect(not snapshot.rules.terminal_shop_enabled, "terminal shop is explicitly disabled")


func _test_disabled_observe_enabled_modes() -> void:
	var disabled := _make_session(0, RunRulesSnapshot.formal_disabled())
	_expect(disabled.begin_combat_room(&"disabled_room").accepted, "disabled room begins")
	_expect(disabled.handle_event(EnemyKilledEvent.new(
		&"disabled_kill", &"disabled_room", &"enemy", 250, 7
	)).accepted, "disabled kill still commits for dedup and dream dust")
	var disabled_after_kill := disabled.snapshot()
	_expect_eq(disabled_after_kill.progression.level, 1, "disabled progression stays Lv1")
	_expect_eq(disabled_after_kill.progression.experience, 0, "disabled progression stays XP0")
	_expect_eq(disabled_after_kill.progression.unspent_stat_points, 0, "disabled progression has zero points")
	_expect_eq(disabled_after_kill.progression.allocated_stats.total_points, 0, "disabled allocated stats stay zero")
	_expect_eq(disabled_after_kill.economy.balance, 7, "independent dream dust reward still commits")
	_expect_eq(disabled_after_kill.observed_experience, 0, "disabled mode does not observe theoretical XP")
	_expect_eq(disabled_after_kill.relics.owned_relic_ids.size(), 0, "disabled relic snapshot is neutral")
	_expect(disabled.handle_event(RoomCompletedEvent.new(
		&"disabled_done", &"disabled_room", 125, 0, 13
	)).accepted, "disabled room completion commits dream dust")
	var disabled_done := disabled.snapshot()
	_expect_eq(disabled_done.economy.balance, 20, "kill and room dream dust sum independently")
	_expect_eq(disabled_done.progression.experience, 0, "room XP is neutral while disabled")
	var free_reward := disabled.generate_reward(
		RoomRewardContext.new(&"disabled_room", RewardType.SKILL),
		2701
	)
	_expect(not free_reward.accepted and free_reward.reject_reason == RunCommandResult.RejectReason.FEATURE_DISABLED, "formal mode rejects legacy free rewards")

	var observe_rules := RunRulesSnapshot.new(
		RunFeatureMode.Value.OBSERVE_ONLY,
		RunFeatureMode.Value.OBSERVE_ONLY,
		7000,
		true
	)
	var observed := _make_session(0, observe_rules)
	_expect(observed.begin_combat_room(&"observe_room").accepted, "observe room begins")
	_expect(observed.handle_event(EnemyKilledEvent.new(
		&"observe_kill", &"observe_room", &"enemy", 80, 3
	)).accepted, "observe kill commits")
	var observed_snapshot := observed.snapshot()
	_expect_eq(observed_snapshot.progression.experience, 0, "observe mode keeps authority XP0")
	_expect_eq(observed_snapshot.observed_experience, 80, "observe mode records theoretical XP")
	_expect_eq(observed_snapshot.observed_relic_events, 1, "observe mode records theoretical relic event")
	_expect_eq(observed_snapshot.economy.balance, 3, "observe mode still uses dream dust")

	var enabled := _make_session(0, RunRulesSnapshot.legacy_enabled())
	_expect(enabled.begin_combat_room(&"enabled_room").accepted, "enabled room begins")
	_expect(enabled.handle_event(EnemyKilledEvent.new(
		&"enabled_kill", &"enabled_room", &"enemy", 100, 0
	)).accepted, "enabled kill commits")
	_expect_eq(enabled.snapshot().progression.level, 2, "enabled legacy progression still levels")
	_expect_eq(enabled.snapshot().progression.unspent_stat_points, 1, "enabled legacy level grants point")


func _test_active_and_passive_purchase() -> void:
	var session := _shop_session(500)
	var opened := session.open_shop_draft()
	var shop := opened.shop_snapshot
	var notifications: Array[StringName] = []
	session.snapshot_changed.connect(func(_snapshot: RunSnapshot, cause: StringName) -> void:
		notifications.append(cause)
	)
	var active_offer := _offer_for_skill(shop, &"elemental_fury")
	var before := session.snapshot()
	var active := session.purchase_skill(
		&"purchase_fury",
		before.revision,
		shop.session_id,
		active_offer.offer_id
	)
	_expect(active.accepted, "active purchase succeeds")
	_expect_eq(active.run_snapshot.economy.balance, before.economy.balance - active_offer.purchase_price, "active price deducted once")
	var active_progress := active.run_snapshot.skills.progress_for(&"elemental_fury")
	_expect(active_progress != null and active_progress.is_active(), "active ownership has active kind")
	_expect_eq(active_progress.level, 1, "purchased active starts Lv1")
	_expect_eq(active_progress.cumulative_upgrade_spend, 0, "purchase price is not upgrade spend")
	_expect_eq(active.shop_commit.charged_dream_dust, active_offer.purchase_price, "typed purchase summary records charge")
	_expect_eq(opened.draft.baseline_run_revision, active.run_snapshot.revision, "Task25 draft rebases after purchase")

	var passive_offer := _offer_for_skill(shop, &"burning")
	var passive := session.purchase_skill(
		&"purchase_burning",
		active.run_snapshot.revision,
		shop.session_id,
		passive_offer.offer_id
	)
	_expect(passive.accepted, "passive purchase succeeds")
	var passive_progress := passive.run_snapshot.skills.progress_for(&"burning")
	_expect(passive_progress != null and passive_progress.is_passive(), "passive ownership has passive kind")
	_expect_eq(passive_progress.level, 1, "passive is represented at fixed base level")
	_expect_eq(passive_progress.cumulative_upgrade_spend, 0, "passive never has upgrade spend")
	var passive_upgrade := session.upgrade_active_skill(
		&"upgrade_passive",
		passive.run_snapshot.revision,
		shop.session_id,
		&"burning"
	)
	_expect(not passive_upgrade.accepted and passive_upgrade.reject_reason == RunCommandResult.RejectReason.PASSIVE_HAS_NO_LEVELS, "passive upgrade has typed rejection")
	_expect_eq(session.snapshot().revision, passive.run_snapshot.revision, "passive rejection does not advance revision")
	_expect_eq(notifications, [&"shop_skill_purchased", &"shop_skill_purchased"], "only two successful purchases notify")


func _test_active_upgrade_curve_and_max() -> void:
	var session := _shop_session(500)
	var shop := session.open_shop_draft().shop_snapshot
	var before := session.snapshot()
	var level_two := session.upgrade_active_skill(
		&"bolt_lv2", before.revision, shop.session_id, &"element_bolt"
	)
	_expect(level_two.accepted, "initial active upgrades to Lv2")
	_expect_eq(level_two.run_snapshot.skills.progress_for(&"element_bolt").level, 2, "bolt reaches Lv2")
	_expect_eq(level_two.shop_commit.charged_dream_dust, 55, "Lv2 uses configured target-level price")
	_expect_eq(level_two.run_snapshot.skills.progress_for(&"element_bolt").cumulative_upgrade_spend, 55, "actual Lv2 spend accumulates")
	_expect(is_equal_approx(session.active_skill_level_effect(&"element_bolt").damage_scale, 1.25), "Lv2 effect resolves from content")
	var level_three := session.upgrade_active_skill(
		&"bolt_lv3", level_two.run_snapshot.revision, shop.session_id, &"element_bolt"
	)
	_expect(level_three.accepted, "bolt upgrades to Lv3")
	_expect_eq(level_three.shop_commit.charged_dream_dust, 95, "Lv3 uses configured target-level price")
	_expect_eq(level_three.run_snapshot.skills.progress_for(&"element_bolt").cumulative_upgrade_spend, 150, "actual prices accumulate independently")
	_expect(is_equal_approx(session.active_skill_level_effect(&"element_bolt").damage_scale, 1.55), "Lv3 damage scale resolves")
	var full_signature := _signature(session.snapshot())
	var max_reject := session.upgrade_active_skill(
		&"bolt_lv4", level_three.run_snapshot.revision, shop.session_id, &"element_bolt"
	)
	_expect(not max_reject.accepted and max_reject.reject_reason == RunCommandResult.RejectReason.MAX_LEVEL_REACHED, "max level has typed rejection")
	_expect_eq(_signature(session.snapshot()), full_signature, "max-level failure changes no authority")

	var poor := _shop_session(10)
	var poor_shop := poor.open_shop_draft().shop_snapshot
	var poor_before := _signature(poor.snapshot())
	var insufficient := poor.upgrade_active_skill(
		&"poor_upgrade", poor.snapshot().revision, poor_shop.session_id, &"element_bolt"
	)
	_expect(not insufficient.accepted and insufficient.reject_reason == RunCommandResult.RejectReason.INSUFFICIENT_DREAM_DUST, "insufficient upgrade has typed rejection")
	_expect_eq(_signature(poor.snapshot()), poor_before, "insufficient upgrade changes no authority")


func _test_reset_floor_and_purchase_not_refunded() -> void:
	var session := _shop_session(500)
	var shop := session.open_shop_draft().shop_snapshot
	var laser_offer := _offer_for_skill(shop, &"elemental_laser")
	var purchased := session.purchase_skill(
		&"laser_buy", session.snapshot().revision, shop.session_id, laser_offer.offer_id
	)
	_expect(purchased.accepted, "laser purchase succeeds")
	var upgraded := session.upgrade_active_skill(
		&"laser_lv2", purchased.run_snapshot.revision, shop.session_id, &"elemental_laser"
	)
	_expect(upgraded.accepted, "laser Lv2 upgrade succeeds")
	_expect_eq(upgraded.run_snapshot.skills.progress_for(&"elemental_laser").cumulative_upgrade_spend, 65, "laser records only upgrade spend")
	var reset := session.reset_active_skill_upgrades(
		&"laser_reset", upgraded.run_snapshot.revision, shop.session_id, &"elemental_laser"
	)
	_expect(reset.accepted, "laser reset succeeds")
	_expect_eq(reset.shop_commit.refunded_dream_dust, 45, "65 at 70 percent floors to 45")
	_expect_eq(reset.run_snapshot.economy.balance, 500 - 120 - 65 + 45, "purchase price is not included in refund")
	_expect_eq(reset.run_snapshot.economy.total_spent_on_purchases, 120, "purchase audit remains spent")
	_expect_eq(reset.run_snapshot.economy.total_spent_on_upgrades, 65, "upgrade audit remains spent")
	_expect_eq(reset.run_snapshot.economy.total_refunded, 45, "refund audit records only returned upgrade share")
	var reset_progress := reset.run_snapshot.skills.progress_for(&"elemental_laser")
	_expect_eq(reset_progress.level, 1, "reset returns active to Lv1")
	_expect_eq(reset_progress.cumulative_upgrade_spend, 0, "reset clears refundable investment")
	_expect(reset.run_snapshot.skills.owns(&"elemental_laser"), "reset does not revoke ownership")
	_expect(reset.run_snapshot.economy.is_valid(), "wallet remains conserved after reset")
	var replay := session.reset_active_skill_upgrades(
		&"laser_reset", upgraded.run_snapshot.revision, shop.session_id, &"elemental_laser"
	)
	_expect(replay == reset, "exact reset replay returns the committed result")
	_expect_eq(session.snapshot().economy.total_refunded, 45, "reset replay cannot mint dust")
	var second_reset := session.reset_active_skill_upgrades(
		&"laser_reset_again", session.snapshot().revision, shop.session_id, &"elemental_laser"
	)
	_expect(not second_reset.accepted and second_reset.reject_reason == RunCommandResult.RejectReason.NO_UPGRADE_INVESTMENT, "new reset without investment rejects")


func _test_economy_rejections_are_atomic() -> void:
	var outside := _make_session(500, RunRulesSnapshot.legacy_enabled())
	var outside_before := _signature(outside.snapshot())
	var outside_result := outside.purchase_skill(&"outside", outside.snapshot().revision, &"none", &"none")
	_expect(not outside_result.accepted and outside_result.reject_reason == RunCommandResult.RejectReason.INVALID_STATE, "non-shop command rejects")
	_expect_eq(_signature(outside.snapshot()), outside_before, "non-shop rejection changes nothing")

	var session := _shop_session(500)
	var shop := session.open_shop_draft().shop_snapshot
	var base_signature := _signature(session.snapshot())
	var stale_revision := session.purchase_skill(
		&"stale_revision", session.snapshot().revision - 1, shop.session_id, shop.offers[0].offer_id
	)
	_expect(not stale_revision.accepted and stale_revision.reject_reason == RunCommandResult.RejectReason.STALE_RUN_REVISION, "stale run revision rejects")
	_expect_eq(_signature(session.snapshot()), base_signature, "stale revision changes nothing")
	var stale_session := session.purchase_skill(
		&"stale_session", session.snapshot().revision, &"old_shop", shop.offers[0].offer_id
	)
	_expect(not stale_session.accepted and stale_session.reject_reason == RunCommandResult.RejectReason.STALE_SHOP_SESSION, "stale shop session rejects")
	_expect_eq(_signature(session.snapshot()), base_signature, "stale session changes nothing")
	var unknown_offer := session.purchase_skill(
		&"unknown_offer", session.snapshot().revision, shop.session_id, &"unknown"
	)
	_expect(not unknown_offer.accepted and unknown_offer.reject_reason == RunCommandResult.RejectReason.UNKNOWN_OFFER, "unknown offer rejects")
	_expect_eq(_signature(session.snapshot()), base_signature, "unknown offer changes nothing")
	var invalid_skill := session.upgrade_active_skill(
		&"invalid_skill", session.snapshot().revision, shop.session_id, &"not_a_skill"
	)
	_expect(not invalid_skill.accepted and invalid_skill.detail == &"unknown_skill_id", "illegal skill ID rejects explicitly")
	_expect_eq(_signature(session.snapshot()), base_signature, "illegal ID changes nothing")
	var unowned := session.upgrade_active_skill(
		&"unowned", session.snapshot().revision, shop.session_id, &"elemental_fury"
	)
	_expect(not unowned.accepted and unowned.detail == &"skill_not_owned", "unowned active rejects")
	_expect_eq(_signature(session.snapshot()), base_signature, "unowned rejection changes nothing")


func _test_command_replay_and_id_reuse() -> void:
	var session := _shop_session(500)
	var shop := session.open_shop_draft().shop_snapshot
	var offer := _offer_for_skill(shop, &"elemental_fury")
	var causes: Array[StringName] = []
	session.snapshot_changed.connect(func(_snapshot: RunSnapshot, cause: StringName) -> void:
		causes.append(cause)
	)
	var first := session.purchase_skill(
		&"stable_command", session.snapshot().revision, shop.session_id, offer.offer_id
	)
	var replay := session.purchase_skill(
		&"stable_command", first.run_snapshot.revision - 1, shop.session_id, offer.offer_id
	)
	_expect(first.accepted and replay == first, "exact command replay precedes stale revision validation")
	_expect_eq(causes, [&"shop_skill_purchased"], "exact replay emits no duplicate notification")
	var reused := session.purchase_skill(
		&"stable_command",
		first.run_snapshot.revision,
		shop.session_id,
		_offer_for_skill(shop, &"burning").offer_id
	)
	_expect(not reused.accepted and reused.reject_reason == RunCommandResult.RejectReason.COMMAND_ID_REUSED, "same command ID with different payload rejects")
	_expect_eq(session.snapshot().revision, first.run_snapshot.revision, "command ID reuse changes no revision")
	var missing := session.upgrade_active_skill(
		&"", session.snapshot().revision, shop.session_id, &"element_bolt"
	)
	_expect(not missing.accepted and missing.detail == &"missing_command_id", "empty command ID rejects")


func _test_dream_dust_rewards_and_terminal_zero() -> void:
	var session := _make_session(0, RunRulesSnapshot.formal_disabled())
	_expect(session.begin_combat_room(&"dust_room").accepted, "dust room begins")
	var first := session.handle_event(EnemyKilledEvent.new(
		&"dust_kill", &"dust_room", &"enemy", 999, 17
	))
	_expect(first.accepted and first.run_snapshot.economy.balance == 17, "kill reward credits independent dream dust")
	var duplicate_before := _signature(session.snapshot())
	var duplicate := session.handle_event(EnemyKilledEvent.new(
		&"dust_kill", &"dust_room", &"enemy", 999, 17
	))
	_expect(not duplicate.accepted, "duplicate reward event rejects")
	_expect_eq(_signature(session.snapshot()), duplicate_before, "duplicate reward cannot mint dust")
	var terminal_invalid := EnemyKilledEvent.new(
		&"boss_bad", &"dust_room", &"boss", 0, 1, true
	)
	_expect(not terminal_invalid.is_valid(), "terminal enemy cannot declare dream dust")
	var terminal := session.handle_event(EnemyKilledEvent.new(
		&"boss_zero", &"dust_room", &"boss", 0, 0, true
	))
	_expect(terminal.accepted, "terminal zero-dust kill remains auditable")
	_expect_eq(terminal.run_snapshot.economy.balance, 17, "terminal kill generates zero dream dust")
	var room_terminal := session.handle_event(RoomCompletedEvent.new(
		&"boss_done", &"dust_room", 0, 0, 0, true
	))
	_expect(room_terminal.accepted, "terminal zero-dust room completion commits")
	_expect_eq(room_terminal.run_snapshot.economy.balance, 17, "terminal room generates zero dream dust")
	_expect(room_terminal.run_snapshot.shop == null, "terminal field does not create a shop transaction")
	_expect(room_terminal.run_snapshot.economy.is_valid(), "event wallet obeys conservation")


func _test_loadout_and_room_preserve_level() -> void:
	var runtime := RuntimeSkillLoadout.new(
		CATALOG.equippable_gameplay_definitions(),
		CATALOG.default_loadout_snapshot()
	)
	var session := _shop_session(500, runtime)
	var opened := session.open_shop_draft()
	var shop := opened.shop_snapshot
	var upgraded := session.upgrade_active_skill(
		&"persist_lv2", session.snapshot().revision, shop.session_id, &"element_bolt"
	)
	_expect(upgraded.accepted, "persistence fixture upgrades bolt")
	var economy_before_move := upgraded.run_snapshot.economy
	var candidate := _move_skill(
		upgraded.run_snapshot.loadout,
		SkillSlotIds.ACTIVE_1,
		SkillSlotIds.ACTIVE_2
	)
	var moved := session.apply_shop_loadout_immediately(opened.draft, candidate)
	_expect(moved.accepted, "normal loadout move succeeds")
	_expect_eq(moved.run_snapshot.skills.progress_for(&"element_bolt").level, 2, "loadout move preserves level")
	_expect_eq(moved.run_snapshot.economy.balance, economy_before_move.balance, "loadout move creates no refund")
	_expect_eq(moved.run_snapshot.economy.total_refunded, economy_before_move.total_refunded, "loadout move leaves refund audit unchanged")
	var left := session.confirm_shop(opened.draft)
	_expect(left.accepted, "shop exit succeeds after move")
	_expect_eq(left.run_snapshot.skills.progress_for(&"element_bolt").level, 2, "shop exit preserves active level")
	_expect(session.begin_combat_room(&"next_room").accepted, "next room begins")
	_expect_eq(session.snapshot().skills.progress_for(&"element_bolt").level, 2, "cross-room snapshot preserves active level")
	_expect_eq(session.snapshot().economy.total_refunded, 0, "cross-room transition does not refund")


func _test_final_loadout_port_rejection_is_atomic() -> void:
	var port := RejectingLoadoutPort.new(CATALOG.default_loadout_snapshot())
	var session := _shop_session(500, port)
	var opened := session.open_shop_draft()
	var before := _signature(session.snapshot())
	var candidate := _move_skill(
		session.snapshot().loadout,
		SkillSlotIds.ACTIVE_1,
		SkillSlotIds.ACTIVE_2
	)
	var rejected := session.apply_shop_loadout_immediately(opened.draft, candidate)
	_expect(not rejected.accepted and rejected.detail == &"task27_final_port_rejected", "final loadout port rejection is returned")
	_expect_eq(port.commit_calls, 1, "final port is attempted once")
	_expect_eq(_signature(session.snapshot()), before, "final port rejection leaves economy, level and revision unchanged")
	_expect_eq(opened.draft.baseline_run_revision, session.snapshot().revision, "failed final port does not rebase draft")


func _test_snapshot_collections_are_copies() -> void:
	var session := _shop_session(500)
	var snapshot := session.snapshot()
	var ids := snapshot.skills.owned_skill_ids
	var progress := snapshot.skills.progress_entries
	var offers := snapshot.shop.offers
	ids.clear()
	progress.clear()
	offers.clear()
	_expect_eq(snapshot.skills.owned_skill_ids.size(), 4, "owned IDs getter returns an isolated copy")
	_expect(snapshot.skills.owns(&"element_bolt"), "owned ID copy mutation cannot remove initial bolt")
	_expect_eq(snapshot.skills.progress_entries.size(), 4, "progress entries getter returns a copy")
	_expect(snapshot.shop.offers.size() >= 5, "shop offers getter returns a copy")
	_expect(snapshot.economy.is_valid(), "economy snapshot is immutable and conserved")


func _make_session(
		initial_dream_dust: int,
		rules: RunRulesSnapshot,
		loadout_port: RuntimeLoadoutPort = null
) -> RunSession:
	return RunSession.new(
		_dummy_reward_catalog(),
		[],
		[&"element_bolt"],
		[ElementIds.WATER, ElementIds.FIRE],
		loadout_port,
		GrowthEffectPort.new(),
		rules,
		CATALOG,
		initial_dream_dust
	)


func _shop_session(
		initial_dream_dust: int,
		loadout_port: RuntimeLoadoutPort = null
) -> RunSession:
	var session := _make_session(
		initial_dream_dust,
		RunRulesSnapshot.legacy_enabled(),
		loadout_port
	)
	_reach_shop(session)
	return session


func _reach_shop(session: RunSession) -> void:
	for room_number: int in range(1, 4):
		var room_id := StringName("task27_shop_room_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "shop path room begins")
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("task27_shop_done_%d" % room_number),
			room_id,
			0
		)).accepted, "shop path room completes")
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL),
			3700 + room_number
		)
		_expect(generated.accepted, "shop path legacy reward fixture generates")
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "shop path legacy reward fixture claims")
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		_expect(session.choose_route(route_id).accepted, "shop path route advances")
	_expect(session.snapshot().route.phase == RunPhase.SHOP, "shop fixture reaches SHOP")
	_expect(session.snapshot().shop != null and session.snapshot().shop.is_valid(), "shop fixture exposes fixed authoritative snapshot")


func _dummy_reward_catalog() -> Array[SkillRewardDefinition]:
	var result: Array[SkillRewardDefinition] = []
	for index: int in 8:
		var definition := SkillRewardDefinition.new()
		definition.skill_id = StringName("reward_dummy_%d" % index)
		definition.display_name = "Reward Dummy %d" % index
		definition.description = "Task27 legacy-flow-only fixture"
		definition.initial_pool = true
		definition.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
		result.append(definition)
	return result


func _offer_for_skill(shop: ShopSnapshot, skill_id: StringName) -> ShopOfferSnapshot:
	for offer: ShopOfferSnapshot in shop.offers:
		if offer.skill_id == skill_id:
			return offer
	return null


func _move_skill(
		current: RuntimeLoadoutSnapshot,
		from_slot: StringName,
		to_slot: StringName
) -> RuntimeLoadoutSnapshot:
	var moving := current.get_skill_id(from_slot)
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in current.entries:
		if entry.slot_id == from_slot:
			entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, &""))
		elif entry.slot_id == to_slot:
			entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, moving))
		else:
			entries.append(entry)
	return RuntimeLoadoutSnapshot.new(entries, current.revision)


func _signature(snapshot: RunSnapshot) -> String:
	var progress_parts: PackedStringArray = PackedStringArray()
	for progress: SkillProgressSnapshot in snapshot.skills.progress_entries:
		progress_parts.append("%s:%d:%d:%d" % [
			String(progress.skill_id),
			progress.activation_kind,
			progress.level,
			progress.cumulative_upgrade_spend,
		])
	return "%d|%d|%d|%d|%d|%d|%s|%d|%d|%d|%d" % [
		snapshot.revision,
		snapshot.economy.balance,
		snapshot.economy.total_earned,
		snapshot.economy.total_spent_on_purchases,
		snapshot.economy.total_spent_on_upgrades,
		snapshot.economy.total_refunded,
		",".join(progress_parts),
		snapshot.progression.level,
		snapshot.progression.experience,
		snapshot.progression.unspent_stat_points,
		snapshot.loadout.revision,
	]


func _run_test(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callable.call()
	if _failures.size() == before:
		print("PASS: " + test_name)
	else:
		for index: int in range(before, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (actual=%s expected=%s)" % [message, str(actual), str(expected)])
