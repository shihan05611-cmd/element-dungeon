extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const SLOTS: Array[StringName] = [
	SkillSlotIds.ACTIVE_1,
	SkillSlotIds.ACTIVE_2,
	SkillSlotIds.ACTIVE_3,
	SkillSlotIds.PASSIVE_1,
]

class RecordingLoadoutPort:
	extends RuntimeLoadoutPort

	const PORT_SLOTS: Array[StringName] = [
		SkillSlotIds.ACTIVE_1,
		SkillSlotIds.ACTIVE_2,
		SkillSlotIds.ACTIVE_3,
		SkillSlotIds.PASSIVE_1,
	]

	var current: RuntimeLoadoutSnapshot
	var passive_skill_ids: Array[StringName] = []
	var commit_count: int = 0
	var reject_commit: bool = false

	func _init(initial: RuntimeLoadoutSnapshot, passives: Array[StringName] = []) -> void:
		current = initial
		passive_skill_ids = passives.duplicate()

	func snapshot() -> RuntimeLoadoutSnapshot:
		return RuntimeLoadoutSnapshot.new(current.entries, current.revision)

	func validate_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		if candidate == null or not candidate.is_valid():
			return RuntimeLoadoutChangeResult.rejected(&"invalid_snapshot_structure", snapshot())
		if candidate.revision != current.revision:
			return RuntimeLoadoutChangeResult.rejected(&"stale_loadout_revision", snapshot())
		if candidate.entries.size() != PORT_SLOTS.size():
			return RuntimeLoadoutChangeResult.rejected(&"expected_four_shared_slots", snapshot())
		for slot_id: StringName in PORT_SLOTS:
			if not candidate.has_slot(slot_id):
				return RuntimeLoadoutChangeResult.rejected(&"missing_shared_slot", snapshot())
		var seen: Array[StringName] = []
		for entry: RuntimeLoadoutSlotSnapshot in candidate.entries:
			if not PORT_SLOTS.has(entry.slot_id):
				return RuntimeLoadoutChangeResult.rejected(&"unknown_shared_slot", snapshot())
			if entry.skill_id.is_empty():
				continue
			if seen.has(entry.skill_id):
				return RuntimeLoadoutChangeResult.rejected(&"duplicate_equipped_skill", snapshot())
			seen.append(entry.skill_id)
		var passive_id := candidate.get_skill_id(SkillSlotIds.PASSIVE_1)
		if not passive_id.is_empty() and not passive_skill_ids.has(passive_id):
			return RuntimeLoadoutChangeResult.rejected(&"active_skill_in_passive_slot", snapshot())
		return RuntimeLoadoutChangeResult.success(candidate)

	func try_replace_snapshot(candidate: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
		var validation := validate_snapshot(candidate)
		if not validation.accepted:
			return validation
		if reject_commit:
			return RuntimeLoadoutChangeResult.rejected(&"task25_commit_rejected", snapshot())
		current = RuntimeLoadoutSnapshot.new(candidate.entries, current.revision + 1)
		commit_count += 1
		return RuntimeLoadoutChangeResult.success(snapshot())


var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []
var _room: Node2D
var _host: RunSessionHost
var _overlay: RunOverlayInterface


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("legal_equip_is_immediate", _test_legal_equip_is_immediate)
	_run_test("move_and_unequip_are_immediate", _test_move_and_unequip_are_immediate)
	_run_test("rejections_are_atomic", _test_rejections_are_atomic)
	_run_test("identical_mapping_is_idempotent", _test_identical_mapping_is_idempotent)
	_run_test("pending_stats_survive_rebase", _test_pending_stats_survive_rebase)
	_run_test("confirm_has_no_second_loadout_commit", _test_confirm_has_no_second_loadout_commit)
	await _run_async_test("ui_paths_and_failure_recovery", _test_ui_paths_and_failure_recovery)
	await _run_async_test("reward_explicit_confirm_is_preserved", _test_reward_explicit_confirm_is_preserved)
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 25 IMMEDIATE SHOP EQUIP TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 25 IMMEDIATE SHOP EQUIP TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _test_legal_equip_is_immediate() -> void:
	var port := _make_port()
	var session := _make_shop_session(port)
	var draft := session.open_shop_draft().draft
	var causes: Array[StringName] = []
	session.snapshot_changed.connect(func(_current: RunSnapshot, cause: StringName) -> void:
		causes.append(cause)
	)
	var before := session.snapshot()
	var result := session.apply_shop_loadout_immediately(
		draft,
		_assign(before.loadout, SkillSlotIds.ACTIVE_2, &"skill_b")
	)
	_expect(result.accepted, "legal assignment succeeds without confirm_shop")
	_expect_eq(port.commit_count, 1, "RuntimeLoadout commits exactly once")
	_expect_eq(port.snapshot().get_skill_id(SkillSlotIds.ACTIVE_2), &"skill_b", "RuntimeLoadout changes immediately")
	_expect_eq(session.snapshot().loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"skill_b", "RunSession snapshot changes immediately")
	_expect_eq(result.run_snapshot.revision, before.revision + 1, "run revision advances once")
	_expect_eq(result.run_snapshot.loadout.revision, before.loadout.revision + 1, "loadout revision advances once")
	_expect_eq(causes.size(), 1, "one aggregate notification is emitted")
	_expect_eq(causes[0], &"shop_loadout_applied", "notification cause identifies immediate shop loadout")
	_expect_eq(draft.baseline_run_revision, result.run_snapshot.revision, "draft run baseline is rebased")
	_expect_eq(draft.baseline_loadout.revision, result.run_snapshot.loadout.revision, "draft loadout baseline is rebased")
	_expect(draft.preview_loadout().same_mapping(result.run_snapshot.loadout), "draft mapping aligns to authority")


func _test_move_and_unequip_are_immediate() -> void:
	var port := _make_port()
	var session := _make_shop_session(port)
	var draft := session.open_shop_draft().draft
	var moved := session.apply_shop_loadout_immediately(
		draft,
		_assign(session.snapshot().loadout, SkillSlotIds.ACTIVE_2, &"skill_a")
	)
	_expect(moved.accepted, "equipped skill moves to another slot")
	_expect(moved.run_snapshot.loadout.get_skill_id(SkillSlotIds.ACTIVE_1).is_empty(), "move clears source slot")
	_expect_eq(moved.run_snapshot.loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"skill_a", "move fills target slot")
	_expect_eq(port.commit_count, 1, "move commits once")
	var removed := session.apply_shop_loadout_immediately(
		draft,
		_assign(session.snapshot().loadout, SkillSlotIds.ACTIVE_2, &"")
	)
	_expect(removed.accepted, "unequip succeeds")
	_expect(removed.run_snapshot.loadout.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty(), "unequip clears authority")
	_expect_eq(port.commit_count, 2, "unequip adds one commit")
	_expect_eq(removed.run_snapshot.revision, moved.run_snapshot.revision + 1, "move and unequip each publish once")


func _test_rejections_are_atomic() -> void:
	var port := _make_port()
	var session := _make_shop_session(port)
	var draft := session.open_shop_draft().draft
	_expect(draft.try_allocate(GrowthStatIds.ATTACK, 1).accepted, "atomic fixture drafts one stat")
	var before := session.snapshot()
	var unowned := session.apply_shop_loadout_immediately(
		draft,
		_assign(before.loadout, SkillSlotIds.ACTIVE_2, &"not_owned")
	)
	_expect(not unowned.accepted and unowned.detail == &"loadout_contains_unowned_skill", "unowned skill is rejected")
	_expect_unchanged(session, draft, port, before, 1, "unowned")

	var duplicate_entries := before.loadout.entries
	for index: int in duplicate_entries.size():
		if duplicate_entries[index].slot_id == SkillSlotIds.ACTIVE_2:
			duplicate_entries[index] = RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, &"skill_a")
	var duplicate := session.apply_shop_loadout_immediately(
		draft,
		RuntimeLoadoutSnapshot.new(duplicate_entries, before.loadout.revision)
	)
	_expect(not duplicate.accepted and duplicate.detail == &"duplicate_equipped_skill", "duplicate mapping is rejected")
	_expect_unchanged(session, draft, port, before, 1, "duplicate")

	var illegal_entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in before.loadout.entries:
		if entry.slot_id != SkillSlotIds.ACTIVE_3:
			illegal_entries.append(entry)
	illegal_entries.append(RuntimeLoadoutSlotSnapshot.new(&"illegal_slot", &"skill_b"))
	var illegal := session.apply_shop_loadout_immediately(
		draft,
		RuntimeLoadoutSnapshot.new(illegal_entries, before.loadout.revision)
	)
	_expect(not illegal.accepted, "illegal slot shape is rejected")
	_expect_unchanged(session, draft, port, before, 1, "illegal slot")
	port.reject_commit = true
	var commit_rejected := session.apply_shop_loadout_immediately(
		draft,
		_assign(before.loadout, SkillSlotIds.ACTIVE_2, &"skill_b")
	)
	_expect(not commit_rejected.accepted and commit_rejected.detail == &"task25_commit_rejected", "RuntimeLoadout commit rejection is returned")
	_expect_unchanged(session, draft, port, before, 1, "commit rejection")

	var stale_port := _make_port()
	var stale_session := _make_shop_session(stale_port)
	var stale_draft := stale_session.open_shop_draft().draft
	_expect(stale_port.try_replace_snapshot(_assign(
		stale_port.snapshot(), SkillSlotIds.ACTIVE_2, &"skill_b"
	)).accepted, "stale fixture changes external authority")
	var stale_before := stale_session.snapshot()
	var stale := stale_session.apply_shop_loadout_immediately(
		stale_draft,
		_assign(stale_before.loadout, SkillSlotIds.ACTIVE_3, &"skill_c")
	)
	_expect(not stale.accepted and stale.reject_reason == RunCommandResult.RejectReason.STALE_DRAFT, "stale active draft is rejected")
	_expect(stale_session.snapshot().loadout.same_mapping(stale_before.loadout), "stale rejection leaves current authority unchanged")
	_expect_eq(stale_session.snapshot().revision, stale_before.revision, "stale rejection leaves run revision unchanged")
	_expect_eq(stale_port.commit_count, 1, "stale request adds no commit")

	var phase_port := _make_port()
	var phase_session := _make_shop_session(phase_port)
	var phase_draft := phase_session.open_shop_draft().draft
	_expect(phase_session.confirm_shop(phase_draft).accepted, "phase fixture leaves shop")
	var phase_before := phase_session.snapshot()
	var outside := phase_session.apply_shop_loadout_immediately(
		phase_draft,
		_assign(phase_before.loadout, SkillSlotIds.ACTIVE_2, &"skill_b")
	)
	_expect(not outside.accepted and outside.detail == &"shop_loadout_outside_shop", "non-shop request is rejected")
	_expect(phase_session.snapshot().loadout.same_mapping(phase_before.loadout), "non-shop rejection leaves mapping unchanged")
	_expect_eq(phase_session.snapshot().revision, phase_before.revision, "non-shop rejection leaves revision unchanged")


func _test_identical_mapping_is_idempotent() -> void:
	var port := _make_port()
	var session := _make_shop_session(port)
	var draft := session.open_shop_draft().draft
	var causes: Array[StringName] = []
	session.snapshot_changed.connect(func(_current: RunSnapshot, cause: StringName) -> void:
		causes.append(cause)
	)
	var before := session.snapshot()
	var result := session.apply_shop_loadout_immediately(draft, before.loadout)
	_expect(result.accepted, "identical mapping is accepted idempotently")
	_expect_eq(port.commit_count, 0, "idempotent request does not commit RuntimeLoadout")
	_expect_eq(session.snapshot().revision, before.revision, "idempotent request does not advance run revision")
	_expect_eq(session.snapshot().loadout.revision, before.loadout.revision, "idempotent request does not advance loadout revision")
	_expect_eq(causes.size(), 0, "idempotent request emits no notification")
	_expect_eq(draft.baseline_run_revision, before.revision, "aligned draft remains unchanged")


func _test_pending_stats_survive_rebase() -> void:
	var port := _make_port()
	var session := _make_shop_session(port)
	var draft := session.open_shop_draft().draft
	_expect(draft.try_allocate(GrowthStatIds.ATTACK, 1).accepted, "stat allocation is drafted")
	var preview_before := draft.preview_progression()
	var result := session.apply_shop_loadout_immediately(
		draft,
		_assign(session.snapshot().loadout, SkillSlotIds.ACTIVE_2, &"skill_b")
	)
	_expect(result.accepted, "loadout commits while stats remain pending")
	_expect_eq(draft.pending_allocation().attack_points, 1, "pending attack survives rebase")
	_expect_eq(draft.pending_allocation().total_points, 1, "pending total survives rebase")
	_expect_eq(draft.preview_progression().allocated_stats.attack_points, preview_before.allocated_stats.attack_points, "stat preview survives rebase")
	_expect_eq(draft.preview_progression().unspent_stat_points, preview_before.unspent_stat_points, "preview unspent survives rebase")
	_expect_eq(session.snapshot().progression.allocated_stats.attack_points, 0, "stat remains uncommitted until exit")


func _test_confirm_has_no_second_loadout_commit() -> void:
	var port := _make_port()
	var session := _make_shop_session(port)
	var draft := session.open_shop_draft().draft
	_expect(draft.try_allocate(GrowthStatIds.VITALITY, 1).accepted, "vitality is drafted")
	var immediate := session.apply_shop_loadout_immediately(
		draft,
		_assign(session.snapshot().loadout, SkillSlotIds.ACTIVE_2, &"skill_b")
	)
	_expect(immediate.accepted, "skill is authoritative before exit")
	var loadout_revision := port.snapshot().revision
	var run_revision := session.snapshot().revision
	var confirmed := session.confirm_shop(draft)
	_expect(confirmed.accepted, "final confirmation exits shop")
	_expect_eq(confirmed.run_snapshot.progression.allocated_stats.vitality_points, 1, "final confirmation commits stats")
	_expect_eq(confirmed.run_snapshot.route.phase, RunPhase.COMBAT, "final confirmation advances phase")
	_expect_eq(port.commit_count, 1, "final confirmation does not recommit loadout")
	_expect_eq(port.snapshot().revision, loadout_revision, "final confirmation does not advance loadout revision")
	_expect_eq(confirmed.run_snapshot.revision, run_revision + 1, "final confirmation advances aggregate revision once")
	_expect_eq(port.snapshot().get_skill_id(SkillSlotIds.ACTIVE_2), &"skill_b", "immediate mapping persists after exit")


func _test_ui_paths_and_failure_recovery() -> void:
	await _prepare_real_shop()
	_overlay.show_loadout()
	await _settle()
	var subtitle := _overlay.get("_subtitle") as Label
	var confirm := _overlay.get("_confirm") as Button
	_expect(subtitle.text.contains("技能装配即时生效") and subtitle.text.contains("属性分配在离店时确认"), "shop copy separates skill and stat timing")
	_expect_eq(confirm.text, "确认属性并离开", "shop button names only stats and exit")
	_expect(confirm.custom_minimum_size.y >= 44.0 and confirm.focus_mode == Control.FOCUS_ALL, "shop button keeps an accessible focus target")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var click_before := _host.run_session.snapshot()
	_overlay.call("_select_skill", &"element_bolt")
	_overlay.call("_on_slot_input", click, SkillSlotIds.ACTIVE_2)
	await _settle()
	var click_after := _host.run_session.snapshot()
	_expect_eq(click_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2), &"element_bolt", "click path commits authority immediately")
	_expect(click_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_1).is_empty(), "click move clears source authority")
	_expect_eq(click_after.revision, click_before.revision + 1, "click path advances revision once")
	_expect((_overlay.get("_status") as Label).text.contains("即时生效"), "click path reports immediate success")

	var drag_before := click_after
	_overlay.call("_slot_drop", Vector2.ZERO, {"skill_id": &"element_bolt"}, SkillSlotIds.ACTIVE_3)
	await _settle()
	var drag_after := _host.run_session.snapshot()
	_expect_eq(drag_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_3), &"element_bolt", "drag path commits authority immediately")
	_expect(drag_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_2).is_empty(), "drag move clears source authority")
	_expect_eq(drag_after.revision, drag_before.revision + 1, "drag path advances revision once")

	_overlay.set("_selected_skill_id", &"element_bolt")
	var clear_before := drag_after
	_overlay.call("_clear_selected_slot")
	await _settle()
	var clear_after := _host.run_session.snapshot()
	_expect(clear_after.loadout.get_skill_id(SkillSlotIds.ACTIVE_3).is_empty(), "clear path unequips authority immediately")
	_expect_eq(clear_after.revision, clear_before.revision + 1, "clear path advances revision once")
	_expect((_overlay.get("_status") as Label).text.contains("已卸下"), "clear path reports unequip")

	var failure_before := clear_after
	_overlay.call("_select_skill", &"element_bolt")
	_overlay.call("_on_slot_input", click, SkillSlotIds.PASSIVE_1)
	await _settle()
	var failure_after := _host.run_session.snapshot()
	_expect(failure_after.loadout.same_mapping(failure_before.loadout), "failed UI request leaves authority unchanged")
	_expect_eq(failure_after.revision, failure_before.revision, "failed UI request leaves revision unchanged")
	_expect(_overlay.current_preview().same_mapping(failure_after.loadout), "failed UI request restores authority preview")
	_expect_eq(_overlay.get("_selected_skill_id"), &"element_bolt", "failed UI request preserves selection")
	_expect((_overlay.get("_status") as Label).text.contains("主动技能不能放入 PASSIVE 1"), "failed UI request shows authority reason")
	var card := (_overlay.get("_skill_cards") as Dictionary).get(&"element_bolt") as Button
	_expect(card != null and root.gui_get_focus_owner() == card, "failed UI request restores skill focus")

	_overlay.call("_confirm_shop")
	await _settle()
	_overlay.show_loadout()
	await _settle()
	var combat_before := _host.run_session.snapshot()
	_overlay.call("_select_skill", &"element_bolt")
	_overlay.call("_on_slot_input", click, SkillSlotIds.ACTIVE_1)
	var combat_after := _host.run_session.snapshot()
	_expect(combat_after.loadout.same_mapping(combat_before.loadout), "formal combat interaction remains read-only")
	_expect((_overlay.get("_status") as Label).text.contains("战斗阶段为只读预览"), "combat read-only boundary is explained")


func _test_reward_explicit_confirm_is_preserved() -> void:
	var option := RewardOption.new(
		&"task25_option", RewardType.SKILL, &"element_bolt", "元素弹", "任务25保护任务24显式奖励确认。"
	)
	var options: Array[RewardOption] = [option]
	var offer := RewardOffer.new(
		&"task25_offer", &"task25_reward_room", RewardType.SKILL, 2501, options
	)
	var before_revision := _host.run_session.snapshot().revision
	var before_submits := _overlay.reward_submit_count()
	_overlay.show_reward(offer)
	await _settle()
	_expect_eq(_overlay.reward_selected_index(), 0, "single reward is focused without claim")
	_expect_eq(_host.run_session.snapshot().revision, before_revision, "reward focus does not mutate run")
	_expect(not _overlay.reward_confirm_button().disabled, "independent reward confirm remains available")
	_overlay.set("_reward_submitting", true)
	_overlay.reward_confirm_button().pressed.emit()
	_expect_eq(_overlay.reward_submit_count(), before_submits, "reward duplicate guard blocks re-entry")
	_overlay.set("_reward_submitting", false)
	_overlay.reward_confirm_button().pressed.emit()
	await _settle()
	_expect_eq(_overlay.reward_submit_count(), before_submits + 1, "only explicit confirm attempts reward authority")
	_expect_eq(_host.run_session.snapshot().revision, before_revision, "failed synthetic reward does not mutate run")
	_expect_eq(_overlay.reward_selected_index(), 0, "failed reward keeps selected candidate")
	_expect(root.gui_get_focus_owner() == _overlay.reward_card(0), "failed reward restores candidate focus")


func _expect_unchanged(
		session: RunSession,
		draft: ShopDraft,
		port: RecordingLoadoutPort,
		before: RunSnapshot,
		pending_points: int,
		label: String
) -> void:
	var after := session.snapshot()
	_expect(after.loadout.same_mapping(before.loadout), "%s failure leaves mapping unchanged" % label)
	_expect_eq(after.loadout.revision, before.loadout.revision, "%s failure leaves loadout revision unchanged" % label)
	_expect_eq(after.revision, before.revision, "%s failure leaves run revision unchanged" % label)
	_expect_eq(port.commit_count, 0, "%s failure performs no commit" % label)
	_expect_eq(draft.pending_allocation().total_points, pending_points, "%s failure preserves pending stats" % label)
	_expect(draft.preview_loadout().same_mapping(before.loadout), "%s failure preserves draft preview" % label)


func _make_port() -> RecordingLoadoutPort:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, &"skill_a"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"passive_a"),
	]
	var passives: Array[StringName] = [&"passive_a"]
	return RecordingLoadoutPort.new(RuntimeLoadoutSnapshot.new(entries, 3), passives)


func _make_shop_session(port: RecordingLoadoutPort) -> RunSession:
	var initial: Array[StringName] = [&"skill_a", &"skill_b", &"skill_c", &"passive_a"]
	var forms: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE]
	var relics: Array[RelicDefinition] = []
	var session := RunSession.new(_reward_catalog(), relics, initial, forms, port)
	_reach_shop(session)
	return session


func _reward_catalog() -> Array[SkillRewardDefinition]:
	var result: Array[SkillRewardDefinition] = []
	var ids: Array[StringName] = [
		&"skill_a", &"skill_b", &"skill_c", &"passive_a",
		&"reward_1", &"reward_2", &"reward_3", &"reward_4",
		&"reward_5", &"reward_6", &"reward_7", &"reward_8",
	]
	var forms: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE]
	for skill_id: StringName in ids:
		var definition := SkillRewardDefinition.new()
		definition.skill_id = skill_id
		definition.display_name = String(skill_id)
		definition.description = "Task 25 authoritative fixture"
		definition.initial_pool = true
		definition.allowed_form_ids = forms.duplicate()
		result.append(definition)
	return result


func _reach_shop(session: RunSession) -> void:
	for room_number: int in range(1, 4):
		var room_id := StringName("task25_room_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "domain fixture begins room %d" % room_number)
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("task25_done_%d" % room_number), room_id, 100
		)).accepted, "domain fixture completes room %d" % room_number)
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1), 2500 + room_number
		)
		_expect(generated.accepted, "domain fixture generates reward %d" % room_number)
		if not generated.accepted:
			return
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "domain fixture claims reward %d" % room_number)
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		_expect(session.choose_route(route_id).accepted, "domain fixture chooses route %d" % room_number)


func _assign(
		base: RuntimeLoadoutSnapshot,
		slot_id: StringName,
		skill_id: StringName
) -> RuntimeLoadoutSnapshot:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in base.entries:
		var next_skill := skill_id if entry.slot_id == slot_id else entry.skill_id
		if not skill_id.is_empty() and entry.slot_id != slot_id and entry.skill_id == skill_id:
			next_skill = &""
		entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, next_skill))
	return RuntimeLoadoutSnapshot.new(entries, base.revision)


func _prepare_real_shop() -> void:
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_overlay = (_room.get_node("CombatHUD") as CombatHUD).run_overlay as RunOverlayInterface
	var player := _room.get_node("Player") as PlayerCharacter
	var enemy := _room.get_node("Orc") as CombatEnemy
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	_host.set_process(false)
	var session := _host.run_session
	for room_number: int in range(1, 4):
		var room_id := session.snapshot().route.current_room_id
		if room_number > 1:
			room_id = StringName("task25_ui_room_%d" % room_number)
			_expect(session.begin_combat_room(room_id).accepted, "UI fixture begins room %d" % room_number)
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("task25_ui_done_%d" % room_number), room_id, 100
		)).accepted, "UI fixture completes room %d" % room_number)
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1), 2550 + room_number
		)
		_expect(generated.accepted, "UI fixture generates reward %d" % room_number)
		if not generated.accepted:
			return
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "UI fixture claims reward %d" % room_number)
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		_expect(session.choose_route(route_id).accepted, "UI fixture chooses route %d" % room_number)
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame


func _run_test(name: String, callback: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callback.call()
	if _failures.size() == before:
		print("PASS task25_" + name)


func _run_async_test(name: String, callback: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callback.call()
	if _failures.size() == before:
		print("PASS task25_" + name)


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])
