extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")

class MutableEffectPort:
	extends ActiveSkillLevelEffectPort

	var effects: Dictionary = {}

	func set_effect(effect: ActiveSkillLevelEffectSnapshot) -> void:
		effects[effect.skill_id] = effect

	func clear() -> void:
		effects.clear()

	func effect_for(skill_id: StringName) -> ActiveSkillLevelEffectSnapshot:
		return effects.get(skill_id, ActiveSkillLevelEffectSnapshot.neutral(skill_id))


var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _host: RunSessionHost
var _port := MutableEffectPort.new()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)
	_expect(_player.skill_controller.set_active_skill_level_effect_port(_port), "mutable test port connects")

	_run_test("missing_port_and_unconfigured_content_are_neutral", _test_missing_port_and_unconfigured_content_are_neutral)
	_run_test("bolt_fury_laser_damage_scaling", _test_bolt_fury_laser_damage_scaling)
	_run_test("accepted_cast_freezes_level_effect", _test_accepted_cast_freezes_level_effect)
	await _run_async_test("reclaim_resource_gain_scaling", _test_reclaim_resource_gain_scaling)
	_run_test("sp_cooldown_range_and_behavior_unchanged", _test_sp_cooldown_range_and_behavior_unchanged)
	_run_test("effect_contract_has_no_forbidden_fields", _test_effect_contract_has_no_forbidden_fields)
	_run_test("run_session_adapter_supplies_authoritative_level", _test_run_session_adapter_supplies_authoritative_level)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 27 SKILL LEVEL EFFECT TESTS"))


func _test_missing_port_and_unconfigured_content_are_neutral() -> void:
	_reset_cast()
	_expect(_player.skill_controller.set_active_skill_level_effect_port(null), "missing port can be installed explicitly")
	_expect(_equip(&"element_bolt"), "bolt equips for neutral test")
	_player.energy_component.set_current(100)
	var bolt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(bolt.accepted, "bolt accepts without level port")
	_expect(bolt.cast_snapshot.level_effect.is_neutral(), "missing port freezes neutral level effect")
	_expect_eq(bolt.cast_snapshot.level_effect.level, 1, "missing port reports Lv1")
	_expect(is_equal_approx(bolt.payload.offensive_damage, 10.0), "missing port preserves bolt damage")
	_reset_cast()
	var adapter := RunSkillLevelEffectAdapter.new(_host.run_session)
	_expect(_player.skill_controller.set_active_skill_level_effect_port(adapter), "host adapter connects")
	var basic := _player.try_basic_attack()
	_expect(basic.accepted, "fixed basic attack remains castable")
	_expect(basic.cast_snapshot.level_effect.is_neutral(), "content without active progression is neutral")
	_reset_cast()
	_expect(_player.skill_controller.set_active_skill_level_effect_port(_port), "mutable port reconnects")


func _test_bolt_fury_laser_damage_scaling() -> void:
	_port.clear()
	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"element_bolt", 2, 1.25))
	_expect(_equip(&"element_bolt"), "bolt equips")
	_player.energy_component.set_current(100)
	var bolt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(bolt.accepted, "Lv2 bolt accepts")
	_expect_eq(bolt.cast_snapshot.level_effect.level, 2, "bolt freezes Lv2")
	_expect(is_equal_approx(bolt.payload.offensive_damage, 12.5), "bolt damage scales by 1.25")
	_expect_eq(bolt.payload.element_amount, 1, "bolt attachment amount is unchanged")
	_reset_cast()

	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"elemental_fury", 2, 1.2))
	_expect(_equip(&"elemental_fury"), "fury equips")
	_player.energy_component.set_current(20)
	var fury := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(fury.accepted, "Lv2 fury accepts at original minimum SP")
	_expect(is_equal_approx(fury.payload.damage_multiplier, 1.6), "fury skill multiplier remains defined by energy")
	_expect(is_equal_approx(fury.payload.offensive_damage, 19.2), "fury damage receives locked 1.2 scale")
	_expect_eq(fury.execution_snapshot.energy_spent, 20, "fury still spends all original energy")
	_reset_cast()

	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"elemental_laser", 2, 1.2))
	_expect(_equip(&"elemental_laser"), "laser equips")
	_player.energy_component.set_current(100)
	var laser := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(laser.accepted, "Lv2 laser accepts")
	var channel := laser.execution_snapshot as ChannelExecutionSnapshot
	var tick := channel.build_tick_payload()
	_expect(is_equal_approx(tick.offensive_damage, 6.0), "laser tick damage receives locked 1.2 scale")
	_expect_eq(channel.energy_per_tick, 5, "laser SP per tick is unchanged")
	_expect(is_equal_approx(channel.tick_interval, 0.5), "laser timing is unchanged")
	_expect_eq(channel.element_amount, 1, "laser attachment amount is unchanged")
	_reset_cast()


func _test_accepted_cast_freezes_level_effect() -> void:
	_port.clear()
	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"element_bolt", 2, 1.25))
	_expect(_equip(&"element_bolt"), "freeze fixture equips bolt")
	_player.energy_component.set_current(100)
	var accepted_lv2 := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(accepted_lv2.accepted, "Lv2 freeze fixture accepts")
	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"element_bolt", 3, 1.55))
	_expect_eq(accepted_lv2.cast_snapshot.level_effect.level, 2, "accepted cast keeps old level")
	_expect(is_equal_approx(accepted_lv2.payload.offensive_damage, 12.5), "accepted payload is not polluted by later upgrade")
	_reset_cast()
	_player.energy_component.set_current(100)
	var accepted_lv3 := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(accepted_lv3.accepted, "next cast accepts updated level")
	_expect_eq(accepted_lv3.cast_snapshot.level_effect.level, 3, "next cast sees Lv3")
	_expect(is_equal_approx(accepted_lv3.payload.offensive_damage, 15.5), "next cast uses updated damage scale")
	_reset_cast()


func _test_reclaim_resource_gain_scaling() -> void:
	_port.clear()
	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(
		&"element_reclaim", 2, 1.0, 1.0, 1.0, 1.25
	))
	_expect(_equip(&"element_reclaim"), "reclaim equips")
	_set_element(ElementIds.WATER)
	_player.global_position = Vector2(390.0, 470.0)
	_enemy.global_position = Vector2(470.0, 470.0)
	_enemy.element_carrier.clear_all(false)
	_enemy.element_carrier.set_amounts_silent(2, 0)
	_player.energy_component.set_current(0)
	await physics_frame
	var reclaim := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(reclaim.accepted, "Lv2 reclaim accepts with matching layers")
	_expect(is_equal_approx(
		reclaim.cast_snapshot.level_effect.resource_gain_scale,
		1.25
	), "reclaim cast freezes the Lv2 resource scale")
	var reclaim_snapshot := reclaim.execution_snapshot as ElementReclaimExecutionSnapshot
	_expect_eq(reclaim_snapshot.matched_element_amount, 2, "reclaim consumes the same two layers")
	_expect_eq(reclaim_snapshot.theoretical_energy_restore, 12, "10 base resource gain scales by 1.25 and floors")
	_expect_eq(_player.energy_component.current_energy, 12, "scaled resource gain is actually committed")
	_expect_eq(_enemy.element_carrier.snapshot().water_amount, 0, "element consumption behavior is unchanged")
	_reset_cast()


func _test_sp_cooldown_range_and_behavior_unchanged() -> void:
	_port.clear()
	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"element_bolt", 3, 2.0))
	_expect(_equip(&"element_bolt"), "SP boundary fixture equips bolt")
	_player.energy_component.set_current(10)
	var bolt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(bolt.accepted, "leveled bolt still accepts at exactly 10 SP")
	_expect_eq(_player.energy_component.current_energy, 0, "leveled bolt still spends exactly 10 SP")
	_expect(is_zero_approx(CATALOG.gameplay_for(&"element_bolt").cooldown), "bolt cooldown definition remains zero")
	_reset_cast()

	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(&"elemental_fury", 3, 1.45))
	_expect(_equip(&"elemental_fury"), "behavior fixture equips fury")
	_player.energy_component.set_current(73)
	var fury := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(fury.accepted, "leveled fury accepts")
	var burst := fury.execution_snapshot as AllEnergyBurstExecutionSnapshot
	var expected_radius_steps := floori(73.0 / 100.0 * 10.0)
	_expect(is_equal_approx(burst.radius_scale, 1.0 + expected_radius_steps * 0.10), "fury radius formula is unchanged")
	_expect_eq(burst.payload.element_amount, 3, "fury element amount still follows energy only")
	_expect_eq(burst.energy_spent, 73, "fury SP consumption behavior is unchanged")
	_expect_eq(burst.movement_policy, SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT, "fury movement behavior is unchanged")
	_reset_cast()

	_port.set_effect(ActiveSkillLevelEffectSnapshot.new(
		&"element_reclaim", 3, 1.0, 1.0, 1.0, 1.5
	))
	_expect_eq(CATALOG.gameplay_for(&"element_reclaim").cooldown, 5.0, "reclaim cooldown remains five seconds")
	_expect_eq((CATALOG.gameplay_for(&"element_reclaim").execution_definition as ElementReclaimExecution).active_time, 0.0, "reclaim execution timing is unchanged")


func _test_effect_contract_has_no_forbidden_fields() -> void:
	var effect := ActiveSkillLevelEffectSnapshot.new(&"element_bolt", 2, 1.25)
	var names: Array[StringName] = []
	for property: Dictionary in effect.get_property_list():
		names.append(StringName(property.get("name", "")))
	for forbidden: StringName in [
		&"energy_cost",
		&"sp_cost",
		&"cooldown",
		&"range",
		&"radius",
		&"element_amount",
		&"reaction_multiplier",
		&"slot_count",
		&"behavior",
	]:
		_expect(not names.has(forbidden), "narrow level effect excludes %s" % String(forbidden))
	_expect(effect.is_valid(), "whitelisted level effect is valid")


func _test_run_session_adapter_supplies_authoritative_level() -> void:
	var session := _authoritative_shop_session()
	var shop := session.open_shop_draft().shop_snapshot
	var upgraded := session.upgrade_active_skill(
		&"adapter_bolt_lv2",
		session.snapshot().revision,
		shop.session_id,
		&"element_bolt"
	)
	_expect(upgraded.accepted, "authority upgrades bolt before adapter binding")
	_expect(_player.configure_run_skill_level_effects(session), "Player binds RunSession narrow adapter")
	_expect(_equip(&"element_bolt"), "adapter fixture equips bolt")
	_player.energy_component.set_current(100)
	var cast := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(cast.accepted, "adapter-backed bolt cast accepts")
	_expect_eq(cast.cast_snapshot.level_effect.level, 2, "adapter resolves authoritative Lv2")
	_expect(is_equal_approx(cast.payload.offensive_damage, 12.5), "adapter-backed cast uses authoritative effect")
	_expect_eq(cast.execution_snapshot.energy_spent, 10, "adapter does not alter SP cost")
	_reset_cast()
	_expect(_player.skill_controller.set_active_skill_level_effect_port(_port), "mutable test port restored")


func _authoritative_shop_session() -> RunSession:
	var session := RunSession.new(
		_dummy_rewards(),
		[],
		[&"element_bolt"],
		[ElementIds.WATER, ElementIds.FIRE],
		null,
		GrowthEffectPort.new(),
		RunRulesSnapshot.legacy_enabled(),
		CATALOG,
		500
	)
	for room_number: int in range(1, 4):
		var room_id := StringName("task27_combat_shop_%d" % room_number)
		_expect(session.begin_combat_room(room_id).accepted, "adapter shop room begins")
		_expect(session.handle_event(RoomCompletedEvent.new(
			StringName("task27_combat_done_%d" % room_number), room_id, 0
		)).accepted, "adapter shop room completes")
		var generated := session.generate_reward(
			RoomRewardContext.new(room_id, RewardType.SKILL),
			4700 + room_number
		)
		_expect(generated.accepted, "adapter legacy reward fixture generates")
		_expect(session.claim_reward(
			generated.reward_offer.offer_id,
			generated.reward_offer.options[0].option_id
		).accepted, "adapter legacy reward fixture claims")
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		_expect(session.choose_route(route_id).accepted, "adapter shop route advances")
	return session


func _dummy_rewards() -> Array[SkillRewardDefinition]:
	var result: Array[SkillRewardDefinition] = []
	for index: int in 8:
		var definition := SkillRewardDefinition.new()
		definition.skill_id = StringName("combat_reward_dummy_%d" % index)
		definition.display_name = "Combat Reward Dummy %d" % index
		definition.description = "Task27 legacy-flow-only fixture"
		definition.initial_pool = true
		definition.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
		result.append(definition)
	return result


func _equip(skill_id: StringName) -> bool:
	_reset_cast()
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(
			slot_id,
			skill_id if slot_id == SkillSlotIds.ACTIVE_1 else &""
		))
	return _host.runtime_loadout.try_replace_snapshot(
		RuntimeLoadoutSnapshot.new(entries, current.revision)
	).accepted


func _set_element(element_id: StringName) -> void:
	_reset_cast()
	if _player.current_element_controller.current_element_id == element_id:
		return
	var result := _player.request_element(element_id)
	_expect(result != null and result.accepted, "element change accepts")


func _reset_cast() -> void:
	if _player == null:
		return
	if _player.skill_executor.current_phase != SkillExecutor.Phase.IDLE:
		_player.skill_executor.cancel_current_cast(
			&"task27_test_reset",
			_player.skill_executor.current_cast_id
		)
	_player.skill_executor.advance(30.0)


func _run_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _run_async_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_harness.expect_eq(actual, expected, message)
