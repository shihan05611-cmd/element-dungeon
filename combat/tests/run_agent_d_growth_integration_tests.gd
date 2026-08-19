extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

## Task 10 end-to-end contract runner:
## Godot --headless --path <project> --script res://combat/tests/run_agent_d_growth_integration_tests.gd

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

const ELEMENT_BOLT: SkillDefinition = preload("res://resources/element_bolt.tres")
const BASIC_SLASH: SkillDefinition = preload("res://resources/element_slash.tres")
const WATER_LANCE: SkillDefinition = preload("res://resources/skills/water_lance.tres")
const FIRE_LANCE: SkillDefinition = preload("res://resources/skills/fire_lance.tres")
const PASSIVE_VITALITY: SkillDefinition = preload("res://resources/skills/passive_vitality.tres")
const PASSIVE_ENERGY: SkillDefinition = preload("res://resources/skills/passive_energy.tres")
const PASSIVE_FOCUS: SkillDefinition = preload("res://resources/skills/passive_focus.tres")
const PASSIVE_BALANCE: SkillDefinition = preload("res://resources/skills/passive_balance.tres")

const WATER_REWARD: SkillRewardDefinition = preload("res://resources/growth/skill_rewards/water_lance_reward.tres")
const FIRE_REWARD: SkillRewardDefinition = preload("res://resources/growth/skill_rewards/fire_lance_reward.tres")
const MANUAL_SPRING: RelicDefinition = preload("res://resources/growth/relics/manual_spring.tres")
const AUTO_SPARK: RelicDefinition = preload("res://resources/growth/relics/auto_spark.tres")
const LEGACY_WATER: SkillLoadout = preload("res://resources/water_loadout.tres")
const LEGACY_FIRE: SkillLoadout = preload("res://resources/fire_loadout.tres")


class RecordingGrowthPort:
	extends GrowthEffectPort

	var energy_sources: Array[StringName] = []

	func restore_energy(_amount: int, source_relic_id: StringName, _event_id: StringName) -> bool:
		energy_sources.append(source_relic_id)
		return true


var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _target: CombatEnemy
var _host: RunSessionHost


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_room = Node2D.new()
	_room.name = "Task10LegacyFixtureRoom"
	root.add_child(_room)
	current_scene = _room
	_player = PLAYER_SCENE.instantiate() as PlayerCharacter
	_target = ENEMY_SCENE.instantiate() as CombatEnemy
	_host = RunSessionHost.new()
	_player.name = "Player"
	_target.name = "Orc"
	_host.name = "RunSessionHost"
	_host.room_id = &"task_10_fixture_room"
	_target.ai_enabled = false
	_room.add_child(_player)
	_room.add_child(_target)
	_room.add_child(_host)
	await process_frame
	await physics_frame
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_target.set_physics_process(false)
	var enemies: Array[CombatEnemy] = [_target]
	_expect(_host.configure(
		_player,
		enemies,
		_integration_content_catalog()
	), "task 10 legacy regression fixture configures through one catalog")

	_run_test("formal_shared_runtime", _test_formal_shared_runtime)
	_run_test("same_skill_across_elements", _test_same_skill_across_elements)
	_run_test("exclusive_switch_transaction", _test_exclusive_switch_transaction)
	_run_test("passive_active_slot_and_lifecycle", _test_passive_active_slot_and_lifecycle)
	_run_test("growth_adapter_composition", _test_growth_adapter_composition)
	_run_test("form_relic_source_filters", _test_form_relic_source_filters)
	_run_test("legacy_migration_is_one_time", _test_legacy_migration_is_one_time)
	_run_test("persisted_four_passive_multi_enemy_room", _test_persisted_four_passive_multi_enemy_room)
	_run_test("zero_active_four_passive_shop", _test_zero_active_four_passive_shop)
	await _test_ordinary_attack_completes_host_room()
	_harness.tests += 1

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("AGENT D TASK 10 TESTS"))


func _run_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _test_formal_shared_runtime() -> void:
	_expect(_host != null and _host.get_parent() == _room, "RunSessionHost is owned by the room")
	_expect(_host.run_session != null and _host.runtime_loadout != null, "room host owns run and loadout runtime")
	_expect(_host.persistence_adapter != null and _host.persistence_adapter.restored, "formal host restores through persistence adapter")
	_expect(_host.saved_shared_loadout.same_mapping(_host.runtime_loadout.snapshot()), "formal host persists the live shared mapping")
	_expect(_player.skill_controller.runtime_loadout == _host.runtime_loadout, "player consumes the host runtime loadout")
	_expect(_player.current_element_controller == _player.get_node("ElementFormController"), "player has one current-element source")
	var snapshot := _host.runtime_loadout.snapshot()
	_expect(snapshot.entries.size() == 7, "formal loadout has exactly seven shared slots")
	_expect(snapshot.get_skill_id(SkillSlotIds.ACTIVE_1) == ELEMENT_BOLT.skill_id, "formal active one contains the shared bolt")
	_expect(not _snapshot_contains(snapshot, BASIC_SLASH.skill_id), "ordinary attack is outside the shared loadout")
	_expect(not InputMap.has_action(&"cast_passive_1"), "passive slot has no release action")
	var ordinary_skill := _host.content_catalog.fixed_basic_attack_definition()
	_expect(
		ordinary_skill != null and ordinary_skill.skill_id == BASIC_SLASH.skill_id,
		"formal player resolves the independent ordinary attack from the run catalog"
	)


func _test_same_skill_across_elements() -> void:
	var equipped := _replace_formal_loadout(
		ELEMENT_BOLT.skill_id,
		WATER_LANCE.skill_id,
		FIRE_LANCE.skill_id,
		&""
	)
	_expect(equipped.accepted, "three distinct active skills equip in shared slots")
	var expected: Dictionary[StringName, StringName] = {
		SkillSlotIds.ACTIVE_1: ELEMENT_BOLT.skill_id,
		SkillSlotIds.ACTIVE_2: WATER_LANCE.skill_id,
		SkillSlotIds.ACTIVE_3: FIRE_LANCE.skill_id,
	}
	var mapping_before := _host.runtime_loadout.snapshot()
	for element_id: StringName in [ElementIds.WATER, ElementIds.FIRE]:
		for slot_id: StringName in SkillSlotIds.active():
			_set_form(element_id)
			_reset_cast_state()
			var attempt := _player.try_cast_slot(slot_id)
			_expect(attempt.accepted, "%s releases from %s state" % [String(slot_id), String(element_id)])
			_expect(attempt.skill_id == expected[slot_id], "%s preserves skill identity in %s state" % [String(slot_id), String(element_id)])
			if attempt.accepted:
				_player.skill_controller.cancel_current_cast(&"task_10_test", _player.skill_executor.current_cast_id)
			_player.skill_executor.advance(1.0)
		_expect(mapping_before.same_mapping(_host.runtime_loadout.snapshot()), "all active mappings remain unchanged after %s casts" % String(element_id))


func _test_exclusive_switch_transaction() -> void:
	var replace := _replace_formal_loadout(FIRE_LANCE.skill_id, ELEMENT_BOLT.skill_id, &"", &"")
	_expect(replace.accepted, "exclusive fire skill equips in shared active slot")
	_set_form(ElementIds.WATER)
	_reset_cast_state()
	var mapping_before := _host.runtime_loadout.snapshot()
	var projected: Array[FormChangedEvent] = []
	var capture: Callable = func(event: RunEvent, result: RunCommandResult) -> void:
		if event is FormChangedEvent and result.accepted:
			projected.append(event as FormChangedEvent)
	_host.run_event_projected.connect(capture)
	_player.energy_component.set_current(0)
	var rejected := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(not rejected.accepted, "insufficient-energy exclusive cast is rejected")
	_expect(_player.current_element_controller.current_element_id == ElementIds.WATER, "rejected exclusive cast does not switch")
	_expect(projected.is_empty(), "rejected exclusive cast projects no form event")

	_player.energy_component.set_current(100)
	var accepted := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(accepted.accepted, "funded exclusive cast is accepted")
	_expect(_player.current_element_controller.current_element_id == ElementIds.FIRE, "accepted exclusive cast switches atomically")
	_expect(projected.size() == 1 and projected[0].source == FormChangedEvent.Source.SKILL_AUTO, "auto switch source is bridged")
	_expect(projected[0].sequence > 0 and projected[0].timestamp_msec >= 0, "bridge preserves sequence and timestamp")
	_expect(mapping_before.same_mapping(_host.runtime_loadout.snapshot()), "automatic element change does not rewrite mapping")
	_player.skill_controller.cancel_current_cast(&"task_10_test", _player.skill_executor.current_cast_id)
	_player.skill_executor.advance(1.0)

	_player.energy_component.set_current(100)
	var same_element := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(same_element.accepted, "same-element exclusive cast remains usable")
	_expect(projected.size() == 1, "same-element exclusive cast does not emit another change event")
	_player.skill_controller.cancel_current_cast(&"task_10_test", _player.skill_executor.current_cast_id)
	_player.skill_executor.advance(1.0)
	_host.run_event_projected.disconnect(capture)


func _test_passive_active_slot_and_lifecycle() -> void:
	var before := _host.runtime_loadout.snapshot()
	var illegal := _replace_formal_loadout(PASSIVE_VITALITY.skill_id, ELEMENT_BOLT.skill_id, &"", &"")
	_expect(not illegal.accepted and illegal.detail == &"passive_skill_in_active_slot", "active slot rejects passive skill")
	_expect(_host.runtime_loadout.snapshot().same_mapping(before), "rejected passive-in-active mapping is atomic")
	var one_passive := _replace_formal_loadout(ELEMENT_BOLT.skill_id, &"", &"", PASSIVE_VITALITY.skill_id)
	_expect(one_passive.accepted, "passive equips in PASSIVE_1")
	_expect(_host.passive_adapter.registered_skill_ids() == [PASSIVE_VITALITY.skill_id], "passive slot registers once")
	_expect(_host.runtime_loadout.registered_passive_slot_ids == [SkillSlotIds.PASSIVE_1], "passive registration keeps slot audit")
	_expect(_player.damage_receiver.maximum_health == 120, "passive slot applies its effect")

	var four := _replace_formal_loadout(
		&"",
		&"",
		&"",
		PASSIVE_VITALITY.skill_id,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id
	)
	_expect(four.accepted, "zero-active four-passive mapping is accepted")
	_expect(_unique_count(_host.passive_adapter.registered_skill_ids()) == 4, "four passives register exactly once")
	_expect(_player.damage_receiver.maximum_health == 130, "four-passive health aggregate is atomic")
	_expect(_player.energy_component.maximum == 115, "four-passive energy aggregate is atomic")
	_expect(is_equal_approx(_player.attack_multiplier, 1.155), "four-passive attack aggregate is composed")

	_player.skill_controller.on_owner_died()
	_expect(_host.passive_adapter.registered_runtimes.is_empty(), "death clears passive registrations")
	_expect(_player.damage_receiver.maximum_health == 100 and _player.energy_component.maximum == 100, "death removes passive stat effects")
	_player.skill_controller.on_owner_respawned()
	_expect(_unique_count(_host.passive_adapter.registered_skill_ids()) == 4, "respawn rebuilds each passive once")
	_player.prepare_floor_transition()
	_expect(_unique_count(_host.passive_adapter.registered_skill_ids()) == 4, "floor transition does not duplicate passives")
	_player.reload_run_state()
	_expect(_unique_count(_host.passive_adapter.registered_skill_ids()) == 4, "run reload does not duplicate passives")


func _test_growth_adapter_composition() -> void:
	var progression := ProgressionSnapshot.new(3, 0, 100, 0, AllocatedStatsSnapshot.new(2, 2, 1))
	_expect(_host.growth_adapter.apply_progression(progression), "progression applies through narrow growth adapter")
	_expect(_player.damage_receiver.maximum_health == 150, "progression vitality composes with passive health")
	_expect(_player.energy_component.maximum == 120, "progression energy composes with passive energy")
	_expect(is_equal_approx(_player.attack_multiplier, 1.2705), "progression attack composes with passives")
	_expect(_host.growth_adapter.apply_temporary_attack_multiplier(1.5, 2.0, &"test_relic", &"temp:1"), "temporary attack modifier applies")
	_expect(is_equal_approx(_player.attack_multiplier, 1.90575), "temporary attack composes multiplicatively")
	_expect(not _host.growth_adapter.apply_temporary_attack_multiplier(1.5, 2.0, &"test_relic", &"temp:1"), "same relic and event share one temporary instance")
	_expect(_host.growth_adapter.apply_temporary_attack_multiplier(2.0, 2.0, &"other_relic", &"temp:1"), "different relic may respond to the same event")
	_expect(is_equal_approx(_player.attack_multiplier, 3.8115), "temporary instances compose by source and event identity")
	_host.growth_adapter.advance(2.0)
	_expect(is_equal_approx(_player.attack_multiplier, 1.2705), "temporary attack expires cleanly")
	_host.growth_adapter.apply_progression(ProgressionSnapshot.new())


func _test_form_relic_source_filters() -> void:
	var port := RecordingGrowthPort.new()
	var controller := RelicController.new(port)
	_expect(controller.register_owned_relic(MANUAL_SPRING).accepted, "manual-filter relic registers")
	_expect(controller.register_owned_relic(AUTO_SPARK).accepted, "auto-filter relic registers")
	var manual := FormChangedEvent.new(&"manual:1", &"filter_room", ElementIds.WATER, ElementIds.FIRE, FormChangedEvent.Source.MANUAL, 1, 10)
	var automatic := FormChangedEvent.new(&"auto:2", &"filter_room", ElementIds.FIRE, ElementIds.WATER, FormChangedEvent.Source.SKILL_AUTO, 2, 20)
	_expect(controller.handle_event(manual).accepted, "manual form event dispatches")
	_expect(port.energy_sources == [MANUAL_SPRING.relic_id], "manual event triggers only manual relic")
	_expect(controller.handle_event(automatic).accepted, "automatic form event dispatches")
	_expect(port.energy_sources == [MANUAL_SPRING.relic_id, AUTO_SPARK.relic_id], "automatic event triggers only auto relic")
	var next_manual := FormChangedEvent.new(&"manual:3", &"filter_room", ElementIds.WATER, ElementIds.FIRE, FormChangedEvent.Source.MANUAL, 3, 30)
	_expect(controller.handle_event(next_manual).accepted, "next unique manual event dispatches")
	_expect(port.energy_sources == [MANUAL_SPRING.relic_id, AUTO_SPARK.relic_id, MANUAL_SPRING.relic_id], "source filters remain stable across events")


func _test_legacy_migration_is_one_time() -> void:
	var harness := Node2D.new()
	harness.name = "LegacyMigrationHarness"
	_room.add_child(harness)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	var enemy := ENEMY_SCENE.instantiate() as CombatEnemy
	var host := RunSessionHost.new()
	player.name = "Player"
	enemy.name = "LegacyOrc"
	host.name = "RunSessionHost"
	host.room_id = &"legacy_migration_room"
	harness.add_child(player)
	harness.add_child(enemy)
	harness.add_child(host)
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	var enemies: Array[CombatEnemy] = [enemy]
	var legacy_water := SkillLoadout.new()
	legacy_water.form_element_id = ElementIds.WATER
	legacy_water.slots = {
		&"a_bolt": ELEMENT_BOLT,
		&"b_slash": BASIC_SLASH,
		&"c_lance": WATER_LANCE,
		&"d_overflow": _test_route_filler_skill(),
		&"e_passive": PASSIVE_VITALITY,
	}
	var legacy: Array[SkillLoadout] = [legacy_water, LEGACY_FIRE]
	var migration_rewards := _integration_reward_catalog()
	var overflow_shop_skills: Array[SkillDefinition] = [
		PASSIVE_ENERGY,
		PASSIVE_FOCUS,
		PASSIVE_BALANCE,
	]
	for reward_skill: SkillDefinition in overflow_shop_skills:
		var reward := SkillRewardDefinition.new()
		reward.skill_id = reward_skill.skill_id
		reward.display_name = "Migration shop %s" % String(reward_skill.skill_id)
		reward.description = "Keeps the formal migration run reward pool open until its first shop"
		reward.initial_pool = true
		reward.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
		migration_rewards.append(reward)
	_expect(host.configure(
		player,
		enemies,
		_integration_content_catalog(migration_rewards),
		null,
		legacy
	), "formal host accepts legacy element loadouts")
	_expect(host.persistence_adapter.migrated_legacy and host.persistence_adapter.restored, "formal host performs one-time migration")
	_expect(host.saved_shared_loadout.entries.size() == 7, "formal migration saves the shared seven-slot shape")
	_expect(not host.persistence_adapter.legacy_state_retained, "formal migration retains no legacy state")
	_expect(not _snapshot_contains(host.saved_shared_loadout, BASIC_SLASH.skill_id), "formal migration removes fixed basic attack from shared slots")
	_expect(host.content_catalog.fixed_basic_attack_definition().skill_id == BASIC_SLASH.skill_id, "migrated run retains catalog basic attack outside shared slots")
	_expect(_snapshot_contains(host.saved_shared_loadout, ELEMENT_BOLT.skill_id), "formal migration preserves legacy bolt ownership")
	_expect(host.run_session.snapshot().skills.owns(&"task_10_route_filler"), "migration overflow remains owned but unequipped")
	_expect(host.run_session.snapshot().route.phase == RunPhase.COMBAT, "migrated shared mapping enters combat")

	# Traverse the real reward/route cycle to the first shop. The overflow
	# passive must pass RunSession ownership validation and RuntimeLoadout's
	# normal atomic shop commit; direct loadout replacement would miss both.
	var session := host.run_session
	var migration_room_ids: Array[StringName] = [
		&"legacy_migration_room",
		&"legacy_migration_room_2",
		&"legacy_migration_room_3",
	]
	for room_index in migration_room_ids.size():
		var migration_room_id := migration_room_ids[room_index]
		if room_index > 0:
			_expect(session.begin_combat_room(migration_room_id).accepted, "migration shop path room begins")
		var completed := session.handle_event(RoomCompletedEvent.new(
			StringName("legacy_migration_done_%d" % room_index),
			migration_room_id,
			0
		))
		_expect(completed.accepted, "migration shop path room completes")
		var generated := session.generate_reward(
			RoomRewardContext.new(migration_room_id, RewardType.SKILL, room_index == 0),
			7100 + room_index
		)
		_expect(generated.accepted, "migration shop path reward generates")
		if not generated.accepted or generated.reward_offer.options.is_empty():
			harness.free()
			return
		var option := generated.reward_offer.options[0]
		_expect(
			session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted,
			"migration shop path reward claims"
		)
		var route_id := RunDirector.SKILL_ROUTE_ID if room_index < 2 else RunDirector.SHOP_ROUTE_ID
		_expect(session.choose_route(route_id).accepted, "migration shop path route chosen")

	var opened := session.open_shop_draft()
	_expect(opened.accepted, "migration overflow opens through the normal shop flow")
	if not opened.accepted:
		harness.free()
		return
	_expect(
		opened.draft.try_assign_slot(SkillSlotIds.ACTIVE_2, &"task_10_route_filler").accepted,
		"migration overflow assigns to the vacant shared active slot"
	)
	var confirmed := session.confirm_shop(opened.draft)
	_expect(confirmed.accepted, "migration overflow shop confirmation succeeds")
	_expect(
		host.runtime_loadout.snapshot().get_skill_id(SkillSlotIds.ACTIVE_2) == &"task_10_route_filler",
		"migration overflow is equipped after normal shop confirmation"
	)
	_expect(
		host.saved_shared_loadout.get_skill_id(SkillSlotIds.ACTIVE_2) == &"task_10_route_filler",
		"confirmed overflow equipment is persisted by the host"
	)
	_expect(not host.persistence_adapter.restore(null, ElementIds.FIRE, [ElementIds.WATER, ElementIds.FIRE], legacy), "host migration adapter cannot restore twice")
	harness.free()


func _test_persisted_four_passive_multi_enemy_room() -> void:
	var harness := Node2D.new()
	harness.name = "PersistedMultiEnemyHarness"
	_room.add_child(harness)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	var enemy_a := ENEMY_SCENE.instantiate() as CombatEnemy
	var enemy_b := ENEMY_SCENE.instantiate() as CombatEnemy
	var host := RunSessionHost.new()
	player.name = "Player"
	enemy_a.name = "OrcA"
	enemy_b.name = "OrcB"
	host.name = "RunSessionHost"
	host.room_id = &"persisted_multi_enemy_room"
	harness.add_child(player)
	harness.add_child(enemy_a)
	harness.add_child(enemy_b)
	harness.add_child(host)
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	for enemy: CombatEnemy in [enemy_a, enemy_b]:
		enemy.set_physics_process(false)
		enemy.ai_enabled = false
	var saved := _shared_snapshot(
		&"",
		&"",
		&"",
		PASSIVE_VITALITY.skill_id,
		7,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id
	)
	var enemies: Array[CombatEnemy] = [enemy_a, enemy_b]
	var projected_kills: Array[EnemyKilledEvent] = []
	host.run_event_projected.connect(func(event: RunEvent, result: RunCommandResult) -> void:
		if event is EnemyKilledEvent and result.accepted:
			projected_kills.append(event as EnemyKilledEvent)
	)
	_expect(host.configure(
		player,
		enemies,
		_integration_content_catalog(),
		saved
	), "formal host restores persisted four-passive snapshot")
	_expect(not host.persistence_adapter.migrated_legacy, "saved shared snapshot bypasses legacy migration")
	_expect(host.saved_shared_loadout.same_mapping(saved), "formal host retains persisted four-passive mapping")
	_expect(host.runtime_loadout.snapshot().same_mapping(saved), "combat runtime starts from persisted mapping")
	_expect(host.passive_adapter.registered_skill_ids().size() == 4, "loaded passives register before combat")
	_expect(player.damage_receiver.maximum_health == 130 and player.energy_component.maximum == 115, "loaded passive stats apply before combat")
	var ordinary := player.try_basic_attack()
	_expect(ordinary.accepted, "ordinary attack remains available after four-passive load")
	player.skill_controller.cancel_current_cast(&"task_10_test", player.skill_executor.current_cast_id)
	player.skill_executor.advance(1.0)
	var first := _defeat_enemy(enemy_a, player, 910001)
	_expect(first.accepted and enemy_a.defeated, "first same-type enemy defeat commits")
	_expect(host.run_session.snapshot().route.phase == RunPhase.COMBAT, "room remains active while second same-type enemy lives")
	_expect(projected_kills.size() == 1, "first same-type enemy produces one kill event")
	var second := _defeat_enemy(enemy_b, player, 910002)
	_expect(second.accepted and enemy_b.defeated, "second same-type enemy defeat commits")
	_expect(projected_kills.size() == 2, "both same-type enemy instances produce kill events")
	if projected_kills.size() == 2:
		_expect(projected_kills[0].enemy_id != projected_kills[1].enemy_id, "same content id receives unique room-instance event ids")
	_expect(host.run_session.snapshot().route.phase == RunPhase.REWARD, "two-enemy persisted-loadout room completes")
	var offer := host.run_session.snapshot().pending_reward
	_expect(offer != null and offer.options.size() == 3, "completed persisted-loadout room generates first skill reward")
	_expect(host.last_error.is_empty(), "persisted multi-enemy host reports no integration error")
	harness.free()
func _test_zero_active_four_passive_shop() -> void:
	var all_skills: Array[SkillDefinition] = [
		ELEMENT_BOLT,
		BASIC_SLASH,
		WATER_LANCE,
		FIRE_LANCE,
		PASSIVE_VITALITY,
		PASSIVE_ENERGY,
		PASSIVE_FOCUS,
		PASSIVE_BALANCE,
	]
	var initial := _shared_snapshot(
		&"",
		&"",
		&"",
		PASSIVE_VITALITY.skill_id,
		0,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id
	)
	var runtime := RuntimeSkillLoadout.new(all_skills, initial, PassiveEffectPort.new())
	var slash_reward := SkillRewardDefinition.new()
	slash_reward.skill_id = BASIC_SLASH.skill_id
	slash_reward.display_name = "Test slash reward"
	slash_reward.description = "Task 10 route filler"
	slash_reward.initial_pool = true
	slash_reward.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
	var rewards: Array[SkillRewardDefinition] = [WATER_REWARD, FIRE_REWARD, slash_reward]
	var owned: Array[StringName] = [
		PASSIVE_VITALITY.skill_id,
		PASSIVE_ENERGY.skill_id,
		PASSIVE_FOCUS.skill_id,
		PASSIVE_BALANCE.skill_id,
	]
	var session := RunSession.new(rewards, [MANUAL_SPRING], owned, [ElementIds.WATER, ElementIds.FIRE], runtime, GrowthEffectPort.new())
	for room_number in range(1, 4):
		var room_id := StringName("four_passive_room_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "four-passive combat room begins")
		_expect(session.handle_event(RoomCompletedEvent.new(StringName("done:%d" % room_number), room_id, 0)).accepted, "four-passive combat room completes")
		var generated := session.generate_reward(RoomRewardContext.new(room_id, RewardType.SKILL), 9000 + room_number)
		_expect(generated.accepted and not generated.reward_offer.options.is_empty(), "four-passive route reward generates")
		var option := generated.reward_offer.options[0]
		_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "four-passive route reward claims")
		if room_number < 3:
			_expect(session.choose_route(RunDirector.SKILL_ROUTE_ID).accepted, "four-passive route continues")
		else:
			_expect(session.choose_route(RunDirector.SHOP_ROUTE_ID).accepted, "third room enters shared shop")
	var opened := session.open_shop_draft()
	_expect(opened.accepted, "shared shop draft opens for zero-active mapping")
	_expect(opened.draft.preview_loadout().same_mapping(initial), "shop draft contains one shared seven-slot mapping")
	_expect(session.confirm_shop(opened.draft).accepted, "zero-active four-passive mapping confirms")
	_expect(runtime.snapshot().same_mapping(initial), "confirmed mapping survives combat transition")
	var persistence := SharedLoadoutPersistenceAdapter.new()
	_expect(persistence.save_shared(runtime.snapshot()), "zero-active four-passive mapping saves")
	var restored := SharedLoadoutPersistenceAdapter.new()
	_expect(restored.restore(persistence.saved_snapshot, ElementIds.WATER, [ElementIds.WATER, ElementIds.FIRE]), "zero-active four-passive mapping loads")
	_expect(restored.saved_snapshot.same_mapping(initial), "loaded four-passive mapping is unchanged")


func _test_ordinary_attack_completes_host_room() -> void:
	_reset_cast_state()
	var ordinary := _player.try_basic_attack()
	_expect(ordinary.accepted, "ordinary attack remains usable with zero active skills")
	_player.skill_controller.cancel_current_cast(&"task_10_test", _player.skill_executor.current_cast_id)
	_player.skill_executor.advance(1.0)
	_target.defeated = false
	_target.combat_receiver.accepting_hits = true
	_target.combat_receiver.clear_recent_hits()
	_target.damage_receiver.restore_full(false)
	var cast := CastSnapshot.new(
		900001,
		&"task_10_finisher",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(999.0, 999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(cast, payload, 900001, 0, _target.global_position, Vector2.RIGHT)
	var result := _target.combat_receiver.receive_hit(request)
	await process_frame
	_expect(result.accepted and result.current_health == 0, "committed ordinary combat can defeat the room enemy")
	_expect(_target.defeated, "formal enemy consumes committed death candidate")
	_expect(_host.run_session.snapshot().route.phase == RunPhase.REWARD, "formal host completes room after all enemies fall")
	var offer := _host.run_session.snapshot().pending_reward
	_expect(offer != null and offer.reward_type == RewardType.SKILL and offer.options.size() == 3, "first formal room generates fixed three-choice skill reward")
	_expect(_host.last_error.is_empty(), "formal host reports no integration error")
	print("PASS ordinary_attack_completes_host_room")


func _integration_skill_catalog() -> Array[SkillDefinition]:
	return [
		ELEMENT_BOLT,
		BASIC_SLASH,
		WATER_LANCE,
		FIRE_LANCE,
		PASSIVE_VITALITY,
		PASSIVE_ENERGY,
		PASSIVE_FOCUS,
		PASSIVE_BALANCE,
		_test_route_filler_skill(),
	]


func _integration_reward_catalog() -> Array[SkillRewardDefinition]:
	var filler_reward := SkillRewardDefinition.new()
	filler_reward.skill_id = &"task_10_route_filler"
	filler_reward.display_name = "Test route filler"
	filler_reward.description = "Task 10 host integration reward fixture"
	filler_reward.initial_pool = true
	filler_reward.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
	return [WATER_REWARD, FIRE_REWARD, filler_reward]


func _test_route_filler_skill() -> SkillDefinition:
	var filler := WATER_LANCE.duplicate(true) as SkillDefinition
	filler.skill_id = &"task_10_route_filler"
	return filler


func _integration_content_catalog(
		rewards: Array[SkillRewardDefinition] = _integration_reward_catalog()
) -> RunContentCatalog:
	var reward_by_id: Dictionary[StringName, SkillRewardDefinition] = {}
	for reward: SkillRewardDefinition in rewards:
		reward_by_id[reward.skill_id] = reward
	var contents: Array[SkillContentDefinition] = []
	for skill: SkillDefinition in _integration_skill_catalog():
		var content := SkillContentDefinition.new()
		content.skill_id = skill.skill_id
		content.display_name = "Test %s" % String(skill.skill_id)
		content.description = "Task 10 legacy integration fixture"
		content.gameplay_definition = skill
		content.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
		content.fixed_basic_attack = skill == BASIC_SLASH
		content.equippable = not content.fixed_basic_attack
		if skill == ELEMENT_BOLT:
			content.initially_owned = true
			content.default_slot_id = SkillSlotIds.ACTIVE_1
		var reward := reward_by_id.get(skill.skill_id) as SkillRewardDefinition
		if reward != null and not content.fixed_basic_attack:
			content.display_name = reward.display_name
			content.description = reward.description
			content.reward_pool = true
			content.initial_reward_pool = reward.initial_pool
			content.allowed_form_ids = reward.allowed_form_ids.duplicate()
		contents.append(content)
	var catalog := RunContentCatalog.new()
	catalog.skill_contents = contents
	catalog.fixed_basic_attack_id = BASIC_SLASH.skill_id
	catalog.relic_definitions = _integration_relic_catalog()
	return catalog


func _integration_relic_catalog() -> Array[RelicDefinition]:
	return [MANUAL_SPRING]


func _defeat_enemy(enemy: CombatEnemy, player: PlayerCharacter, cast_id: int) -> CombatResult:
	enemy.defeated = false
	enemy.combat_receiver.accepting_hits = true
	enemy.combat_receiver.clear_recent_hits()
	enemy.damage_receiver.restore_full(false)
	var cast := CastSnapshot.new(
		cast_id,
		&"task_10_multi_enemy_finisher",
		player.get_instance_id(),
		player.get_instance_id(),
		&"player",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(999.0, 999.0, ElementIds.NONE, 0)
	var request := HitRequest.new(cast, payload, cast_id, 0, enemy.global_position, Vector2.RIGHT)
	return enemy.combat_receiver.receive_hit(request)
func _replace_formal_loadout(
		active_1: StringName,
		active_2: StringName,
		active_3: StringName,
		passive_1: StringName,
		passive_2: StringName = &"",
		passive_3: StringName = &"",
		passive_4: StringName = &""
) -> RuntimeLoadoutChangeResult:
	return _host.runtime_loadout.try_replace_snapshot(_shared_snapshot(
		active_1,
		active_2,
		active_3,
		passive_1,
		_host.runtime_loadout.snapshot().revision,
		passive_2,
		passive_3,
		passive_4
	))


func _shared_snapshot(
		active_1: StringName,
		active_2: StringName,
		active_3: StringName,
		passive_1: StringName,
		revision: int,
		passive_2: StringName = &"",
		passive_3: StringName = &"",
		passive_4: StringName = &""
) -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new([
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, active_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, active_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, active_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, passive_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, passive_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3, passive_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4, passive_4),
	], revision)


func _set_form(element_id: StringName) -> void:
	_player.skill_executor.advance(2.0)
	_player.hurt_time = 0.0
	_player.defeated = false
	_player.request_element(element_id)


func _reset_cast_state() -> void:
	_player.skill_executor.advance(2.0)
	_player.hurt_time = 0.0
	_player.defeated = false
	_player.energy_component.set_current(_player.energy_component.maximum)


func _snapshot_contains(snapshot: RuntimeLoadoutSnapshot, skill_id: StringName) -> bool:
	for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
		if entry.skill_id == skill_id:
			return true
	return false


func _unique_count(values: Array[StringName]) -> int:
	var unique: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		unique[value] = true
	return unique.size()


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
