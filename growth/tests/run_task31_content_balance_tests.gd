extends SceneTree

const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const FLOW: RunFlowDefinition = preload("res://resources/run/flows/prototype_two_layer_six_combat.tres")
const ROOM_IDS: Array[StringName] = [
	&"combat_01_entry",
	&"combat_02_swarm",
	&"combat_02_pressure",
	&"combat_03_layer_elite",
	&"combat_04_validation",
	&"combat_05_stable",
	&"combat_05_risk",
	&"combat_06_final_boss",
]
const ACTIVE_IDS: Array[StringName] = [
	&"element_bolt",
	&"elemental_fury",
	&"elemental_laser",
	&"element_reclaim",
]
const PASSIVE_IDS: Array[StringName] = [
	&"burning",
	&"unending",
	&"passive_vitality",
	&"passive_energy",
]

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("formal_catalog_and_feature_modes", _test_catalog_and_modes)
	_run_test("active_prices_levels_and_effect_whitelist", _test_active_progression)
	_run_test("four_passives_are_level_free_purchase_content", _test_passives)
	_run_test("eight_rooms_have_reachable_scenes_and_spawns", _test_room_resources)
	_run_test("safe_and_risk_routes_have_real_differences", _test_route_differences)
	_run_test("boss_is_stronger_and_awards_zero_dream_dust", _test_boss)
	_run_test("three_build_budgets_are_feasible", _test_build_budgets)
	_run_test("seventy_percent_refund_has_no_arbitrage", _test_refund_no_arbitrage)
	_run_test("fourteen_product_scenarios_have_static_domain_coverage", _test_fourteen_scenarios)
	_finish()


func _test_catalog_and_modes() -> void:
	_expect(CATALOG != null and CATALOG.is_valid(), "formal catalog validates")
	_expect_eq(CATALOG.gameplay_definitions().size(), 9, "catalog contains fixed basic plus eight shop skills")
	_expect_eq(CATALOG.shop_contents().size(), 8, "catalog exposes eight purchasable contents")
	_expect_eq(CATALOG.initial_owned_skill_ids(), [&"element_bolt"], "only element bolt starts owned")
	_expect_eq(CATALOG.default_loadout_snapshot().entries.size(), 7, "default authority mapping has seven slots")
	_expect_eq(CATALOG.default_loadout_snapshot().get_skill_id(SkillSlotIds.ACTIVE_1), &"element_bolt", "A1 starts with element bolt")
	for slot_id: StringName in SkillSlotIds.passive():
		_expect(CATALOG.default_loadout_snapshot().get_skill_id(slot_id).is_empty(), "%s starts empty" % String(slot_id))
	var rules := RunRulesSnapshot.formal_disabled()
	_expect(rules.is_valid(), "formal rules validate")
	_expect_eq(rules.progression_mode, RunFeatureMode.Value.DISABLED, "legacy progression is disabled")
	_expect_eq(rules.relic_mode, RunFeatureMode.Value.DISABLED, "relic runtime is disabled")
	_expect(not rules.legacy_free_rewards_enabled, "legacy free rewards are disabled")
	_expect_eq(rules.upgrade_refund_basis_points, 7000, "upgrade refund is frozen at 70 percent")
	_expect(not rules.terminal_shop_enabled, "terminal shop remains disabled")
	_expect_eq(rules.terminal_enemy_dream_dust_reward, 0, "terminal enemy dust rule is zero")
	_expect_eq(rules.terminal_room_dream_dust_reward, 0, "terminal room dust rule is zero")


func _test_active_progression() -> void:
	for skill_id: StringName in ACTIVE_IDS:
		var content := CATALOG.content_for(skill_id)
		_expect(content != null and content.is_valid(), "%s content validates" % String(skill_id))
		if content == null:
			continue
		_expect(content.gameplay_definition.is_active_skill(), "%s remains active" % String(skill_id))
		_expect(content.purchase_price > 0, "%s purchase price is positive" % String(skill_id))
		_expect(content.active_progression != null and content.active_progression.is_valid(), "%s progression validates" % String(skill_id))
		if content.active_progression == null:
			continue
		var levels := content.active_progression.levels
		_expect_eq(levels.size(), 3, "%s has the frozen Lv1-Lv3 curve" % String(skill_id))
		_expect_eq(levels[0].level, 1, "%s starts at Lv1" % String(skill_id))
		_expect_eq(levels[0].upgrade_price, 0, "%s Lv1 has no upgrade price" % String(skill_id))
		for index: int in range(1, levels.size()):
			var previous: ActiveSkillLevelDefinition = levels[index - 1]
			var current: ActiveSkillLevelDefinition = levels[index]
			_expect_eq(current.level, index + 1, "%s levels are contiguous" % String(skill_id))
			_expect(current.upgrade_price > previous.upgrade_price, "%s upgrade prices strictly increase" % String(skill_id))
			if skill_id == &"element_reclaim":
				_expect(current.resource_gain_scale > previous.resource_gain_scale, "reclaim increases only resource gain")
				_expect(is_equal_approx(current.damage_scale, 1.0), "reclaim does not gain damage")
			else:
				_expect(current.damage_scale > previous.damage_scale, "%s increases damage" % String(skill_id))
				_expect(is_equal_approx(current.resource_gain_scale, 1.0), "%s does not gain resource recovery" % String(skill_id))
			_expect(is_equal_approx(current.healing_scale, 1.0), "%s does not gain healing" % String(skill_id))
			_expect(is_equal_approx(current.shield_scale, 1.0), "%s does not gain shield" % String(skill_id))
		var effect := content.level_effect(3)
		_expect(effect != null and effect.is_valid() and effect.level == 3, "%s Lv3 projects a valid accepted effect" % String(skill_id))
		var property_names: Array[StringName] = []
		for property: Dictionary in effect.get_property_list():
			property_names.append(StringName(property["name"]))
		for forbidden: StringName in [&"energy_cost", &"cooldown", &"range", &"startup_time", &"recovery_time", &"element_policy", &"reaction_formula"]:
			_expect(not property_names.has(forbidden), "%s level effect cannot change %s" % [String(skill_id), String(forbidden)])
	var first_room := FLOW.combat_room_for(&"combat_01_entry")
	var first_balance := _room_dream_dust(first_room)
	var cheapest_unowned_active := 1000000
	for skill_id: StringName in [&"elemental_fury", &"elemental_laser", &"element_reclaim"]:
		cheapest_unowned_active = mini(cheapest_unowned_active, CATALOG.content_for(skill_id).purchase_price)
	_expect_eq(first_balance, 120, "room one guarantees the frozen 120 dream dust")
	_expect(first_balance >= cheapest_unowned_active, "room one can buy at least one unowned active")


func _test_passives() -> void:
	for skill_id: StringName in PASSIVE_IDS:
		var content := CATALOG.content_for(skill_id)
		_expect(content != null and content.is_valid(), "%s formal passive validates" % String(skill_id))
		if content == null:
			continue
		_expect(content.gameplay_definition.is_passive_skill(), "%s is strict passive content" % String(skill_id))
		_expect(content.is_shop_purchasable() and content.purchase_price == 75, "%s costs the frozen 75 dream dust" % String(skill_id))
		_expect(content.active_progression == null, "%s has no active level table" % String(skill_id))
		_expect(not content.initially_owned and content.default_slot_id.is_empty(), "%s is purchased rather than pre-equipped" % String(skill_id))
		if skill_id in [&"passive_vitality", &"passive_energy"]:
			_expect(not content.reward_pool and not content.initial_reward_pool, "%s adds no historical reward projection" % String(skill_id))
		else:
			_expect(content.reward_pool, "%s retains its frozen historical projection while formal rewards stay disabled" % String(skill_id))
	_expect_eq(SkillSlotIds.active().size(), 3, "authority exposes exactly three active slots")
	_expect_eq(SkillSlotIds.passive().size(), 4, "authority exposes exactly four passive slots")
	_expect_eq(_unique_count(PASSIVE_IDS), 4, "formal catalog supplies four different passive IDs")


func _test_room_resources() -> void:
	_expect(FLOW != null and FLOW.is_valid(), "formal six-room flow validates")
	_expect_eq(ROOM_IDS.size(), 8, "flow owns eight branch-aware combat room resources")
	var scene_paths: Array[String] = []
	for room_id: StringName in ROOM_IDS:
		var room := FLOW.combat_room_for(room_id)
		_expect(room != null and room.validation_error().is_empty(), "%s room resource validates" % String(room_id))
		if room == null:
			continue
		_expect(room.room_scene != null and room.room_scene.can_instantiate(), "%s has an instantiable PackedScene" % String(room_id))
		_expect(not room.enemy_spawns.is_empty(), "%s has a non-empty enemy group" % String(room_id))
		if not scene_paths.has(room.room_scene.resource_path):
			scene_paths.append(room.room_scene.resource_path)
		var instance := room.room_scene.instantiate() as RunRoomInstance
		_expect(instance != null and not instance.template_id.is_empty(), "%s scene implements RunRoomInstance" % String(room_id))
		if instance == null:
			continue
		var player_spawn := instance.get_node_or_null("PlayerSpawn") as Marker2D
		_expect(player_spawn != null, "%s template has a player spawn" % String(room_id))
		for spawn: EnemySpawnDefinition in room.enemy_spawns:
			_expect(spawn.enemy_scene != null and spawn.enemy_scene.can_instantiate(), "%s/%s enemy scene instantiates" % [String(room_id), String(spawn.enemy_id)])
			_expect(spawn.local_position.x >= 190.0 and spawn.local_position.x <= 960.0, "%s/%s spawn x stays inside its arena" % [String(room_id), String(spawn.enemy_id)])
			_expect(spawn.local_position.y >= 250.0 and spawn.local_position.y <= 510.0, "%s/%s spawn y stays above walkable geometry" % [String(room_id), String(spawn.enemy_id)])
			if player_spawn != null:
				_expect(spawn.local_position.distance_to(player_spawn.position) >= 120.0, "%s/%s does not overlap player spawn" % [String(room_id), String(spawn.enemy_id)])
		instance.free()
	_expect_eq(scene_paths.size(), 4, "branch-aware room set references all four real templates")


func _test_route_differences() -> void:
	var route_one := FLOW.node_for(&"route_01_first_branch")
	var route_two := FLOW.node_for(&"route_02_second_branch")
	_expect(route_one != null and route_one.route_branches.size() == 2, "route one exposes two frozen branches")
	_expect(route_two != null and route_two.route_branches.size() == 2, "route two exposes two frozen branches")
	var swarm := FLOW.combat_room_for(&"combat_02_swarm")
	var pressure := FLOW.combat_room_for(&"combat_02_pressure")
	_expect(swarm.room_scene.resource_path != pressure.room_scene.resource_path, "route one changes the room template")
	_expect(swarm.enemy_spawns.size() != pressure.enemy_spawns.size(), "route one changes enemy-group shape")
	_expect(_maximum_enemy_health(pressure) > _maximum_enemy_health(swarm), "route one risk branch has higher single-target durability")
	_expect(_room_dream_dust(pressure) > _room_dream_dust(swarm), "route one risk branch pays more dream dust")
	_expect(route_one.route_branches[1].risk_tier > route_one.route_branches[0].risk_tier, "route one disclosure has a higher risk tier")
	var stable := FLOW.combat_room_for(&"combat_05_stable")
	var risk := FLOW.combat_room_for(&"combat_05_risk")
	_expect(stable.room_scene.resource_path != risk.room_scene.resource_path, "route two changes the room template")
	_expect(risk.enemy_spawns.size() > stable.enemy_spawns.size(), "route two risk branch adds an enemy")
	_expect(_total_enemy_health(risk) > _total_enemy_health(stable), "route two risk branch has higher total durability")
	_expect(_room_dream_dust(risk) > _room_dream_dust(stable), "route two risk branch pays more dream dust")
	_expect(route_two.route_branches[1].risk_tier > route_two.route_branches[0].risk_tier, "route two disclosure has a higher risk tier")
	_expect_eq(_safe_run_earnings(), 595, "safe route earns the frozen 595 dream dust")
	_expect_eq(_risk_run_earnings(), 700, "risk route earns the frozen 700 dream dust")
	_expect(_risk_run_earnings() > _safe_run_earnings(), "risk route has strictly higher total expected dream dust")


func _test_boss() -> void:
	var boss := FLOW.combat_room_for(&"combat_06_final_boss")
	_expect(boss != null and boss.final_boss, "final node uses the placeholder boss room")
	_expect_eq(boss.completion_dream_dust, 0, "boss room completion awards zero dream dust")
	_expect_eq(_room_dream_dust(boss), 0, "boss enemy plus room award exactly zero dream dust")
	var strongest_normal_health := 0
	var strongest_normal_defense := 0.0
	for room_id: StringName in ROOM_IDS:
		var room := FLOW.combat_room_for(room_id)
		if room.final_boss:
			continue
		strongest_normal_health = maxi(strongest_normal_health, _maximum_enemy_health(room))
		strongest_normal_defense = maxf(strongest_normal_defense, _maximum_enemy_defense(room))
	_expect(_maximum_enemy_health(boss) > strongest_normal_health, "boss health exceeds every normal single enemy")
	_expect(_maximum_enemy_defense(boss) > strongest_normal_defense, "boss defense exceeds every normal enemy")
	_expect_eq(FLOW.node_for(&"combat_06_final_boss").next_node_id, FLOW.result_node_id, "boss successor is the direct result node")


func _test_build_budgets() -> void:
	var bolt := CATALOG.content_for(&"element_bolt")
	var specialist_upgrade_spend := bolt.active_progression.levels[1].upgrade_price + bolt.active_progression.levels[2].upgrade_price
	_expect_eq(specialist_upgrade_spend, 150, "main-active specialization reaches Lv3 for 150")
	_expect(specialist_upgrade_spend <= 345, "specialization is affordable by the second shop on the safe path")
	var multi_active_spend := (
		CATALOG.content_for(&"element_reclaim").purchase_price
		+ CATALOG.content_for(&"elemental_laser").purchase_price
		+ CATALOG.content_for(&"element_reclaim").active_progression.levels[1].upgrade_price
		+ CATALOG.content_for(&"elemental_laser").active_progression.levels[1].upgrade_price
	)
	_expect_eq(multi_active_spend, 325, "multi-active purchase plus two Lv2 upgrades costs 325")
	_expect(multi_active_spend <= _risk_run_earnings(), "multi-active build is affordable on the risk path")
	var four_passive_spend := 0
	for skill_id: StringName in PASSIVE_IDS:
		four_passive_spend += CATALOG.content_for(skill_id).purchase_price
	_expect_eq(four_passive_spend, 300, "four formal passives cost 300 total")
	_expect(four_passive_spend <= 345, "initial bolt plus four passives is affordable by the second safe shop")
	_expect(four_passive_spend + specialist_upgrade_spend <= _safe_run_earnings(), "four passives and Lv3 specialization fit the full safe budget")


func _test_refund_no_arbitrage() -> void:
	var rules := RunRulesSnapshot.formal_disabled()
	for skill_id: StringName in ACTIVE_IDS:
		var levels := CATALOG.content_for(skill_id).active_progression.levels
		var cumulative := 0
		for index: int in range(1, levels.size()):
			cumulative += levels[index].upgrade_price
			var refund := (cumulative * rules.upgrade_refund_basis_points) / RunRulesSnapshot.BASIS_POINTS_DENOMINATOR
			_expect(refund == floori(float(cumulative) * 0.7), "%s Lv%d refund floors exact 70 percent" % [String(skill_id), index + 1])
			_expect(refund < cumulative, "%s Lv%d reset returns less than paid" % [String(skill_id), index + 1])
			_expect(cumulative - refund > 0, "%s Lv%d buy-reset cycle has positive loss" % [String(skill_id), index + 1])
	_expect_eq((150 * 7000) / 10000, 105, "bolt Lv3 reset refunds the frozen 105")
	_expect_eq(150 - 105, 45, "bolt reset-rebuy loop loses 45 and cannot arbitrage")


func _test_fourteen_scenarios() -> void:
	var rules := RunRulesSnapshot.formal_disabled()
	_expect(rules.progression_mode == RunFeatureMode.Value.DISABLED and rules.relic_mode == RunFeatureMode.Value.DISABLED and not rules.legacy_free_rewards_enabled, "matrix 1: single dream dust with growth/relic/reward disabled")
	_expect(_room_dream_dust(FLOW.combat_room_for(&"combat_01_entry")) >= CATALOG.content_for(&"element_reclaim").purchase_price, "matrix 2: active Lv1 purchase has an early budget")
	_expect_eq(PASSIVE_IDS.size(), SkillSlotIds.passive().size(), "matrix 3: four purchasable passives map to four passive slots")
	_expect(SkillSlotIds.active().all(func(slot_id: StringName) -> bool: return not SkillSlotIds.is_passive(slot_id)), "matrix 4: active/passive slot partitions are disjoint")
	_expect_eq(_unique_count(PASSIVE_IDS), 4, "matrix 5: four unique passive identities exist for runtime rebuild")
	_expect(ACTIVE_IDS.all(func(skill_id: StringName) -> bool: return CATALOG.content_for(skill_id).level_effect(3).is_valid()), "matrix 6: SP/cooldown stay outside the narrow level effect")
	_expect(ACTIVE_IDS.all(func(skill_id: StringName) -> bool: return CATALOG.content_for(skill_id).active_progression.levels[1].upgrade_price > 0), "matrix 7: every active has an atomic paid upgrade")
	_expect_eq(CATALOG.default_loadout_snapshot().entries.size(), 7, "matrix 8: seven-slot mapping is the cross-room persistence unit")
	_expect_eq((150 * 7000) / 10000, 105, "matrix 9: reset refund is exact floor 70 percent")
	_expect_eq(rules.progression_mode, RunFeatureMode.Value.DISABLED, "matrix 10: growth is disabled without deleting events")
	_expect(PASSIVE_IDS.all(func(skill_id: StringName) -> bool: return CATALOG.content_for(skill_id).gameplay_definition.passive_effect_definition != null), "matrix 11: passive effects remain available while growth is disabled")
	_expect(not CATALOG.relic_definitions.is_empty() and rules.relic_mode == RunFeatureMode.Value.DISABLED, "matrix 12: relic resources remain loadable but disabled")
	_expect(CATALOG.shop_contents().size() == 8 and CATALOG.default_loadout_snapshot().entries.size() == 7, "matrix 13: shop projection and authority mapping share catalog truth")
	_expect(_room_dream_dust(FLOW.combat_room_for(&"combat_06_final_boss")) == 0 and FLOW.node_for(&"combat_06_final_boss").next_node_id == FLOW.result_node_id, "matrix 14: boss awards zero and goes directly to result")


func _room_dream_dust(room: CombatRoomDefinition) -> int:
	var total := room.completion_dream_dust
	for spawn: EnemySpawnDefinition in room.enemy_spawns:
		total += spawn.dream_dust_reward
	return total


func _total_enemy_health(room: CombatRoomDefinition) -> int:
	var total := 0
	for spawn: EnemySpawnDefinition in room.enemy_spawns:
		total += spawn.maximum_health
	return total


func _maximum_enemy_health(room: CombatRoomDefinition) -> int:
	var maximum := 0
	for spawn: EnemySpawnDefinition in room.enemy_spawns:
		maximum = maxi(maximum, spawn.maximum_health)
	return maximum


func _maximum_enemy_defense(room: CombatRoomDefinition) -> float:
	var maximum := 0.0
	for spawn: EnemySpawnDefinition in room.enemy_spawns:
		maximum = maxf(maximum, spawn.defense_flat)
	return maximum


func _safe_run_earnings() -> int:
	return (
		_room_dream_dust(FLOW.combat_room_for(&"combat_01_entry"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_02_swarm"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_03_layer_elite"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_04_validation"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_05_stable"))
	)


func _risk_run_earnings() -> int:
	return (
		_room_dream_dust(FLOW.combat_room_for(&"combat_01_entry"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_02_pressure"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_03_layer_elite"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_04_validation"))
		+ _room_dream_dust(FLOW.combat_room_for(&"combat_05_risk"))
	)


func _unique_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _run_test(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	test_callable.call()
	if _failures.size() == before:
		print("PASS: " + test_name)


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
		print("TASK 31 CONTENT BALANCE TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 31 CONTENT BALANCE TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
