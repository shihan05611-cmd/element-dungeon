extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

## Task 16 focused content/catalog and production-wiring runner.

const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")


class TestOwnerPort:
	extends PassiveOwnerPort

	func capture_attack_stats() -> CombatStatSnapshot:
		return CombatStatSnapshot.new()

	func restore_health(
			_amount: int,
			_source_skill_id: StringName,
			_event_id: StringName
	) -> bool:
		return true


class TestTargetPort:
	extends PassiveTargetPort

	func query_targets(_observed_element_id: StringName) -> Array[PassiveTargetSnapshot]:
		return []

	func submit_damage(_request: PassiveDamageRequest) -> bool:
		return true


class RecordingPassivePort:
	extends PassiveEffectPort

	var registered_ids: Array[StringName] = []

	func _init() -> void:
		super(PassiveRuntimeContext.new(TestOwnerPort.new(), TestTargetPort.new()))

	func commit_replace_effects(runtimes: Array[PassiveEffectRuntime]) -> void:
		registered_ids.clear()
		for runtime: PassiveEffectRuntime in runtimes:
			registered_ids.append(runtime.skill_id)


var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _target: CombatEnemy
var _host: RunSessionHost


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("formal_catalog_shape", _test_formal_catalog_shape)
	_run_test("six_skill_values", _test_six_skill_values)
	_run_test("reward_projection", _test_reward_projection)
	_run_test("catalog_rejections", _test_catalog_rejections)
	_run_test("five_skill_growth_loadout_loop", _test_five_skill_growth_loadout_loop)

	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_player = _room.get_node("Player") as PlayerCharacter
	_target = _room.get_node("Orc") as CombatEnemy
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_target.set_physics_process(false)
	_target.ai_enabled = false
	_host.set_process(false)

	_run_test("formal_host_projection", _test_formal_host_projection)
	await _run_async_test("fury_production_wiring", _test_fury_production_wiring)
	await _run_async_test("laser_production_wiring", _test_laser_production_wiring)
	await _run_async_test("reclaim_production_wiring", _test_reclaim_production_wiring)
	await _run_async_test("burning_production_wiring", _test_burning_production_wiring)
	await _run_async_test("unending_basic_attack_wiring", _test_unending_basic_attack_wiring)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 16 CONTENT CATALOG TESTS"))


func _test_formal_catalog_shape() -> void:
	_expect(CATALOG != null and CATALOG.validation_error().is_empty(), "formal catalog validates")
	_expect(CATALOG.gameplay_definitions().size() == 11, "catalog registers ignition beside the prior obtainable skills and basic attack")
	_expect(CATALOG.obtainable_contents().size() == 10, "catalog exposes the ignition demo content without adding a reward")
	_expect(CATALOG.reward_definitions().size() == 5, "catalog projects five chest rewards")
	_expect(CATALOG.initial_owned_skill_ids() == [&"element_bolt", &"ignition"], "element bolt and ignition are initially owned")
	var initial := CATALOG.default_loadout_snapshot()
	_expect(initial.get_skill_id(SkillSlotIds.ACTIVE_1) == &"element_bolt", "element bolt defaults to active one")
	_expect(initial.get_skill_id(SkillSlotIds.ACTIVE_2) == &"ignition", "ignition defaults to active two")
	_expect(initial.get_skill_id(SkillSlotIds.ACTIVE_3).is_empty(), "active three defaults empty")
	_expect(SkillSlotIds.passive().all(func(slot_id: StringName) -> bool:
		return initial.get_skill_id(slot_id).is_empty()
	), "all four passive slots default empty")
	var slash := CATALOG.content_for(&"element_slash")
	_expect(slash != null and slash.fixed_basic_attack and not slash.equippable, "fixed basic attack stays outside shared slots")
	_expect(CATALOG.reward_definitions().all(func(reward: SkillRewardDefinition) -> bool:
		return reward.skill_id != &"element_slash"
	), "fixed basic attack is absent from rewards")
	for legacy_id: StringName in [&"water_lance", &"fire_lance", &"passive_focus", &"passive_balance"]:
		_expect(CATALOG.content_for(legacy_id) == null, "legacy content is not double-registered: %s" % String(legacy_id))
	var formal_stat_passives := {
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
	for skill_id: StringName in formal_stat_passives:
		var expected: Dictionary = formal_stat_passives[skill_id]
		var content := CATALOG.content_for(skill_id)
		_expect(content != null and content.display_name == expected["name"], "formal stat passive has its product name: %s" % String(skill_id))
		_expect(content != null and content.description.contains("严格被动槽") and content.description.contains("最大"), "formal stat passive describes strict passive capacity: %s" % String(skill_id))
		_expect(content != null and content.icon != null and content.icon.resource_path == expected["icon"], "formal stat passive has its independent icon: %s" % String(skill_id))
		_expect(content != null and content.gameplay_definition.resource_path == expected["gameplay"], "formal stat passive points to the frozen gameplay resource: %s" % String(skill_id))
		_expect(content != null and content.equippable and content.purchase_price == 75, "formal stat passive is purchasable and equippable: %s" % String(skill_id))
		_expect(content != null and content.allowed_form_ids == [ElementIds.WATER, ElementIds.FIRE], "formal stat passive supports both formal forms: %s" % String(skill_id))
		_expect(content != null and not content.initially_owned and content.default_slot_id.is_empty(), "formal stat passive has no initial ownership or default slot: %s" % String(skill_id))
		_expect(content != null and not content.reward_pool and not content.initial_reward_pool, "formal stat passive does not expand historical rewards: %s" % String(skill_id))
		_expect(content != null and content.active_progression == null, "formal stat passive has no active levels: %s" % String(skill_id))
		_expect(content != null and content.presentation_scene == null and content.runtime_delivery_scene == null, "formal stat passive has no world presentation or delivery: %s" % String(skill_id))
		var effect := content.gameplay_definition.passive_effect_definition as StatModifierPassiveEffectDefinition
		_expect(effect != null and effect.maximum_health_bonus == expected["health"] and effect.maximum_energy_bonus == expected["energy"], "formal stat passive preserves its frozen modifier: %s" % String(skill_id))
	for content: SkillContentDefinition in CATALOG.skill_contents:
		if content.skill_id == &"element_slash":
			_expect(content.icon == null and content.presentation_scene == null, "fixed basic attack keeps presentation empty")
		elif content.skill_id == &"element_bolt":
			_expect(content.icon != null and content.presentation_scene == null, "element bolt uses its stable icon and existing projectile presentation")
		elif content.skill_id in [&"passive_vitality", &"passive_energy", &"passive_reaction_energy"]:
			_expect(content.icon != null and content.presentation_scene == null, "stat passive uses an icon without fake world presentation: %s" % String(content.skill_id))
		elif content.skill_id == &"ignition":
			_expect(content.icon == null and content.presentation_scene == null and content.runtime_delivery_scene == null, "ignition reuses existing presentation without adding an icon or delivery")
		else:
			_expect(content.icon != null and content.presentation_scene != null, "approved task-17 presentation fields are connected: %s" % String(content.skill_id))


func _test_six_skill_values() -> void:
	var bolt := CATALOG.gameplay_for(&"element_bolt")
	var bolt_execution := bolt.execution_definition as InstantDeliveryExecution
	_expect(bolt.element_policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT, "element bolt follows current element")
	_expect(bolt_execution.energy_cost == 10 and is_equal_approx(bolt_execution.payload.damage_multiplier, 1.0), "element bolt cost and damage are frozen")
	_expect(bolt_execution.payload.element_amount == 1 and is_zero_approx(bolt.cooldown), "element bolt attaches one layer with no cooldown")

	var fury := CATALOG.gameplay_for(&"elemental_fury")
	var fury_execution := fury.execution_definition as AllEnergyBurstExecution
	_expect(fury_execution.minimum_energy == 20, "fury minimum energy is twenty")
	_expect(is_equal_approx(fury_execution.damage_multiplier_per_energy, 0.08), "fury multiplier per energy is frozen")
	_expect(CATALOG.runtime_delivery_scene_for(fury.skill_id).resource_path == "res://combat/delivery/element_rage_delivery.tscn", "fury uses formal rage delivery")

	var laser := CATALOG.gameplay_for(&"elemental_laser")
	var laser_execution := laser.execution_definition as ChannelExecution
	_expect(is_equal_approx(laser_execution.tick_interval, 0.5) and laser_execution.energy_per_tick == 5, "laser tick economy is frozen")
	_expect(is_equal_approx(laser_execution.damage_multiplier, 0.5) and laser_execution.element_amount == 1, "laser tick payload is frozen")
	_expect(laser_execution.movement_policy == SkillExecutionSnapshot.MovementPolicy.ALLOW_MOVEMENT, "laser allows movement")
	_expect(CATALOG.runtime_delivery_scene_for(laser.skill_id).resource_path == "res://combat/delivery/element_beam_delivery.tscn", "laser uses formal beam delivery")

	var reclaim := CATALOG.gameplay_for(&"element_reclaim")
	_expect(reclaim.execution_definition is ElementReclaimExecution and is_equal_approx(reclaim.cooldown, 5.0), "reclaim uses functional execution and five-second cooldown")
	var burning := CATALOG.gameplay_for(&"burning")
	var burning_effect := burning.passive_effect_definition as BurningPassiveEffectDefinition
	_expect(burning.required_element_id == ElementIds.FIRE and is_equal_approx(burning_effect.tick_interval, 1.0), "burning has fixed fire one-second semantics")
	_expect(is_equal_approx(burning_effect.damage_multiplier_per_layer, 0.05), "burning damage per fire layer is frozen")
	var unending := CATALOG.gameplay_for(&"unending")
	var unending_effect := unending.passive_effect_definition as UnendingPassiveEffectDefinition
	_expect(unending.required_element_id == ElementIds.WATER and unending_effect.health_per_layer == 1, "unending has fixed water healing semantics")
	var reaction_energy := CATALOG.content_for(&"passive_reaction_energy")
	var reaction_effect := reaction_energy.gameplay_definition.passive_effect_definition as ReactionEnergyPassiveEffectDefinition
	_expect(reaction_energy.display_name == "元素回响" and reaction_energy.purchase_price == 75, "reaction energy has frozen product identity and price")
	_expect(reaction_energy.gameplay_definition.is_passive_skill() and reaction_energy.active_progression == null, "reaction energy is level-free passive-only content")
	_expect(not reaction_energy.reward_pool and not reaction_energy.initial_reward_pool, "reaction energy stays outside the disabled free reward flow")
	_expect(reaction_effect != null and reaction_effect.energy_restore == 10, "reaction energy restores the frozen ten SP")


func _test_reward_projection() -> void:
	var reward_ids: Array[StringName] = []
	for reward: SkillRewardDefinition in CATALOG.reward_definitions():
		var content := CATALOG.content_for(reward.skill_id)
		_expect(content != null, "reward resolves to registered content")
		_expect(reward.display_name == content.display_name and reward.description == content.description, "reward text is projected from content")
		_expect(reward.allowed_form_ids == content.allowed_form_ids, "reward forms are projected from content")
		reward_ids.append(reward.skill_id)
	var expected_ids: Array[StringName] = [&"burning", &"element_reclaim", &"elemental_fury", &"elemental_laser", &"unending"]
	_expect(reward_ids.size() == expected_ids.size() and expected_ids.all(func(skill_id: StringName) -> bool:
		return reward_ids.has(skill_id)
	), "reward pool contains exactly the remaining five skills")


func _test_catalog_rejections() -> void:
	var duplicate := RunContentCatalog.new()
	duplicate.skill_contents = [CATALOG.skill_contents[0], CATALOG.skill_contents[0]]
	duplicate.fixed_basic_attack_id = &"element_slash"
	duplicate.relic_definitions = CATALOG.relic_definitions
	_expect(duplicate.validation_error() == &"duplicate_skill_content_id", "duplicate content id is rejected explicitly")

	var missing := _content_fixture(&"missing_gameplay", null)
	var missing_catalog := _catalog_fixture([missing, CATALOG.content_for(&"element_slash")])
	_expect(missing_catalog.validation_error() == &"missing_gameplay_definition", "missing gameplay is rejected explicitly")

	var unknown_reward := _content_fixture(&"unknown_reward", CATALOG.gameplay_for(&"element_bolt"))
	unknown_reward.reward_pool = true
	unknown_reward.initial_reward_pool = true
	var unknown_catalog := _catalog_fixture([unknown_reward, CATALOG.content_for(&"element_slash")])
	_expect(unknown_catalog.validation_error() == &"reward_points_to_unknown_skill", "reward pointing to unknown gameplay id is rejected")

	var fixed_reward := _content_fixture(&"element_slash", CATALOG.gameplay_for(&"element_slash"))
	fixed_reward.fixed_basic_attack = true
	fixed_reward.equippable = false
	fixed_reward.reward_pool = true
	var fixed_catalog := _catalog_fixture([fixed_reward])
	_expect(fixed_catalog.validation_error() == &"fixed_basic_attack_has_shared_progression", "fixed basic attack entering rewards is rejected")


func _test_five_skill_growth_loadout_loop() -> void:
	for target_skill_id: StringName in [&"elemental_fury", &"elemental_laser", &"element_reclaim", &"burning", &"unending"]:
		var passive_port := RecordingPassivePort.new()
		var runtime := RuntimeSkillLoadout.new(
			CATALOG.equippable_gameplay_definitions(),
			CATALOG.default_loadout_snapshot(),
			passive_port
		)
		var session := RunSession.new(
			CATALOG.reward_definitions(),
			CATALOG.relic_definitions,
			CATALOG.initial_owned_skill_ids(),
			[ElementIds.WATER, ElementIds.FIRE],
			runtime,
			GrowthEffectPort.new()
		)
		for room_index in 3:
			var room_id := StringName("catalog_loop_%s_%d" % [String(target_skill_id), room_index])
			_expect(session.begin_combat_room(room_id).accepted, "catalog loop room begins")
			_expect(session.handle_event(RoomCompletedEvent.new(StringName("done:%s:%d" % [String(target_skill_id), room_index]), room_id, 0)).accepted, "catalog loop room completes")
			var context := RoomRewardContext.new(room_id, RewardType.SKILL)
			var reward_seed_value := 1600 + room_index
			if room_index == 0:
				reward_seed_value = _seed_containing(session.snapshot(), context, target_skill_id)
			var generated := session.generate_reward(context, reward_seed_value)
			_expect(generated.accepted, "catalog loop reward generates")
			var option := generated.reward_offer.options[0]
			if room_index == 0:
				for candidate: RewardOption in generated.reward_offer.options:
					if candidate.content_id == target_skill_id:
						option = candidate
						break
			_expect(session.claim_reward(generated.reward_offer.offer_id, option.option_id).accepted, "catalog loop reward claims")
			if room_index < 2:
				_expect(session.choose_route(RunDirector.SKILL_ROUTE_ID).accepted, "catalog loop continues on skill route")
			else:
				_expect(session.choose_route(RunDirector.SHOP_ROUTE_ID).accepted, "catalog loop reaches shop")
		_expect(session.snapshot().skills.owns(target_skill_id), "reward claim enters owned inventory: %s" % String(target_skill_id))
		var opened := session.open_shop_draft()
		_expect(opened.accepted, "catalog loop opens shop")
		var target_skill := CATALOG.gameplay_for(target_skill_id)
		var target_slot := SkillSlotIds.PASSIVE_1 if target_skill.is_passive_skill() else SkillSlotIds.ACTIVE_2
		_expect(opened.draft.try_assign_slot(target_slot, target_skill_id).accepted, "owned catalog skill can be assigned")
		_expect(session.confirm_shop(opened.draft).accepted, "catalog skill shop assignment commits")
		_expect(runtime.snapshot().get_skill_id(target_slot) == target_skill_id, "content id reaches runtime loadout")
		if target_skill.is_passive_skill():
			_expect(passive_port.registered_ids == [target_skill_id], "passive content creates exactly one runtime")


func _test_formal_host_projection() -> void:
	_expect(_host.content_catalog == CATALOG, "formal host consumes the single catalog resource")
	_expect(_host.runtime_loadout.snapshot().get_skill_id(SkillSlotIds.ACTIVE_1) == &"element_bolt", "formal host applies catalog default loadout")
	var owned := _host.run_session.snapshot().skills.owned_skill_ids
	_expect(owned.has(&"element_bolt") and owned.has(&"ignition"), "formal host projects catalog initial ownership: %s" % str(owned))
	_expect(_host.content_catalog.fixed_basic_attack_definition().skill_id == &"element_slash", "player basic attack comes from catalog")
	_expect(_host.runtime_loadout.get_skill(&"element_slash") == null, "fixed basic attack cannot enter shared runtime slots")


func _test_fury_production_wiring() -> void:
	_expect(_equip(SkillSlotIds.ACTIVE_2, &"elemental_fury"), "fury equips through runtime loadout")
	_reset_target()
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(390.0, 470.0)
	_player.facing = 1.0
	_set_element(ElementIds.WATER)
	await physics_frame
	_player.energy_component.set_current(19)
	var rejected := _player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(not rejected.accepted and rejected.reject_reason == CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, "formal fury rejects nineteen energy")
	_player.energy_component.set_current(20)
	var minimum := _player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(minimum.accepted and minimum.execution_snapshot is AllEnergyBurstExecutionSnapshot, "formal fury accepts twenty energy")
	var minimum_snapshot := minimum.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(minimum_snapshot.payload.element_amount == 1 and is_equal_approx(minimum_snapshot.payload.damage_multiplier, 1.6), "twenty-energy fury locks 160 percent and one layer")
	_player.skill_executor.advance(0.0)
	await process_frame
	await physics_frame
	_expect(_target.damage_receiver.current_health == 224, "formal rage delivery submits twenty-energy damage")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 1, "formal rage delivery submits locked water layer")

	_reset_target()
	_player.energy_component.set_current(100)
	var maximum := _player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(maximum.accepted, "formal fury accepts one hundred energy")
	var maximum_snapshot := maximum.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(maximum_snapshot.payload.element_amount == 5 and is_equal_approx(maximum_snapshot.payload.damage_multiplier, 8.0), "one-hundred-energy fury locks 800 percent and five layers")
	_expect(is_equal_approx(maximum_snapshot.radius_scale, 2.0), "one-hundred-energy fury locks double radius")
	_player.skill_executor.advance(0.0)
	await process_frame
	await physics_frame
	_expect(_target.damage_receiver.current_health == 160, "formal rage delivery submits one-hundred-energy damage")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 5, "formal rage delivery submits five locked layers")


func _test_laser_production_wiring() -> void:
	_expect(_equip(SkillSlotIds.ACTIVE_2, &"elemental_laser"), "laser equips through runtime loadout")
	_reset_target()
	var second := ENEMY_SCENE.instantiate() as CombatEnemy
	second.name = "LaserTargetTwo"
	_room.add_child(second)
	second.set_physics_process(false)
	second.ai_enabled = false
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(410.0, 470.0)
	second.global_position = Vector2(480.0, 470.0)
	_player.facing = 1.0
	_set_element(ElementIds.WATER)
	_player.energy_component.set_current(10)
	await physics_frame
	var attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(attempt.accepted and attempt.execution_snapshot is ChannelExecutionSnapshot, "formal laser channel is accepted")
	_player.skill_executor.advance(0.0)
	_expect(not bool(_player.call(&"_skill_locks_movement")), "formal laser channel does not lock movement")
	_player.skill_executor.advance(0.49)
	await physics_frame
	_expect(_target.damage_receiver.current_health == 240 and second.damage_receiver.current_health == 240, "laser has no early tick")
	_player.skill_executor.advance(0.01)
	await physics_frame
	_expect(_target.damage_receiver.current_health == 235 and second.damage_receiver.current_health == 235, "formal beam penetrates both legal targets")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 1 and second.element_carrier.get_amount(ElementIds.WATER) == 1, "formal beam attaches one locked layer to each target")
	_expect(_player.energy_component.current_energy == 5, "formal laser spends five energy at the first full tick")
	_expect(_player.release_channel_for_slot(SkillSlotIds.ACTIVE_2), "slot release ends the formal channel")
	_player.skill_executor.advance(0.0)
	_player.skill_executor.advance(0.5)
	await physics_frame
	_expect(_target.damage_receiver.current_health == 235 and second.damage_receiver.current_health == 235, "released beam produces no later tick")
	second.queue_free()
	await process_frame


func _test_reclaim_production_wiring() -> void:
	_expect(_equip(SkillSlotIds.ACTIVE_3, &"element_reclaim"), "reclaim equips through runtime loadout")
	_reset_target()
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(400.0, 470.0)
	_set_element(ElementIds.WATER)
	_player.energy_component.set_current(50)
	_target.element_carrier.set_amounts_silent(3, 2)
	await physics_frame
	var accepted := _player.try_cast_slot(SkillSlotIds.ACTIVE_3)
	_expect(accepted.accepted and accepted.execution_snapshot is ElementReclaimExecutionSnapshot, "formal reclaim accepts matching layers")
	_expect(_player.energy_component.current_energy == 65, "formal reclaim restores three layers times five energy")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 0 and _target.element_carrier.get_amount(ElementIds.FIRE) == 2, "formal reclaim atomically consumes only locked element")
	_player.skill_executor.advance(0.0)
	_player.skill_executor.advance(5.0)
	var no_layers := _player.try_cast_slot(SkillSlotIds.ACTIVE_3)
	_expect(not no_layers.accepted and no_layers.reject_reason == CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "formal reclaim rejects no matching layers")
	_target.element_carrier.set_amounts_silent(2, 2)
	_player.energy_component.set_current(_player.energy_component.maximum)
	var full := _player.try_cast_slot(SkillSlotIds.ACTIVE_3)
	_expect(not full.accepted and full.reject_reason == CastAttemptResult.RejectReason.NO_BENEFIT, "formal reclaim rejects full energy")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 2, "failed reclaim leaves target layers untouched")


func _test_burning_production_wiring() -> void:
	_reset_cast()
	_expect(_equip(SkillSlotIds.PASSIVE_1, &"burning"), "burning equips through runtime loadout")
	_reset_target()
	_set_element(ElementIds.WATER)
	_target.element_carrier.set_amounts_silent(0, 3)
	var before := _target.damage_receiver.current_health
	_expect(_host.passive_adapter.registered_skill_ids() == [&"burning"], "burning registers exactly one runtime")
	_expect(_host.passive_adapter.advance(1.0), "burning triggers at one second")
	_expect(_target.damage_receiver.current_health == before - 2, "three fire layers deal rounded fifteen-percent attack damage")
	_expect(_target.element_carrier.get_amount(ElementIds.FIRE) == 3, "burning does not consume fire layers")
	_player.skill_controller.on_owner_died()
	_expect(_host.passive_adapter.registered_skill_ids().is_empty(), "death unregisters burning runtime")
	_player.skill_controller.on_owner_respawned()
	_expect(_host.passive_adapter.registered_skill_ids() == [&"burning"], "respawn restores one burning runtime")
	_player.skill_controller.on_floor_changed()
	_expect(_host.passive_adapter.registered_skill_ids() == [&"burning"], "floor change rebuilds one burning runtime")
	_player.skill_controller.on_run_reloaded()
	_expect(_host.passive_adapter.registered_skill_ids() == [&"burning"], "reload rebuilds one burning runtime")
	var after_rebuild := _target.damage_receiver.current_health
	_host.passive_adapter.advance(1.0)
	_expect(_target.damage_receiver.current_health == after_rebuild - 2, "rebuilt burning runtime does not trigger twice")


func _test_unending_basic_attack_wiring() -> void:
	_reset_cast()
	_expect(_equip(SkillSlotIds.PASSIVE_1, &"unending"), "unending equips through runtime loadout")
	_reset_target()
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(365.0, 470.0)
	_player.facing = 1.0
	_set_element(ElementIds.FIRE)
	_target.element_carrier.set_amounts_silent(3, 0)
	_player.damage_receiver.replace_health_silent(80)
	await physics_frame
	var basic := _player.try_basic_attack()
	_expect(basic.accepted, "catalog fixed basic attack is available outside loadout")
	_player.skill_executor.advance(0.09)
	await _wait_physics(3)
	_expect(_player.damage_receiver.current_health == 83, "unending heals one per target water layer after basic hit")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 3, "unending does not consume target water layers")
	_expect(_host.passive_adapter.registered_skill_ids() == [&"unending"], "unending remains one runtime independent of current fire form")
	_player.skill_executor.advance(1.0)
	_reset_target()
	_target.global_position = Vector2(430.0, 470.0)
	_target.element_carrier.set_amounts_silent(3, 0)
	_player.damage_receiver.replace_health_silent(80)
	_set_element(ElementIds.WATER)
	_player.energy_component.set_current(100)
	var bolt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(bolt.accepted, "non-basic element bolt is accepted")
	_player.skill_executor.advance(0.13)
	await _wait_physics(10)
	_expect(_player.damage_receiver.current_health == 80, "unending ignores non-basic committed hits")


func _equip(slot_id: StringName, skill_id: StringName) -> bool:
	_reset_cast()
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for known_slot: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(
			known_slot,
			skill_id if known_slot == slot_id else current.get_skill_id(known_slot)
		))
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(
		entries,
		current.revision
	))
	return result.accepted


func _set_element(element_id: StringName) -> void:
	_reset_cast()
	_player.request_element(element_id)


func _reset_cast() -> void:
	if _player == null:
		return
	_player.defeated = false
	_player.hurt_time = 0.0
	_player.skill_executor.advance(5.0)


func _reset_target() -> void:
	_reset_cast()
	_target.defeated = false
	_target.combat_receiver.accepting_hits = true
	_target.combat_receiver.clear_recent_hits()
	_target.damage_receiver.restore_full(false)
	_target.element_carrier.clear_all(false)


func _wait_physics(frame_count: int) -> void:
	for _index in frame_count:
		await physics_frame


func _content_fixture(skill_id: StringName, gameplay: SkillDefinition) -> SkillContentDefinition:
	var content := SkillContentDefinition.new()
	content.skill_id = skill_id
	content.display_name = "Fixture"
	content.description = "Task 16 invalid configuration fixture"
	content.gameplay_definition = gameplay
	content.allowed_form_ids = [ElementIds.WATER, ElementIds.FIRE]
	return content


func _catalog_fixture(contents: Array[SkillContentDefinition]) -> RunContentCatalog:
	var catalog := RunContentCatalog.new()
	catalog.skill_contents = contents
	catalog.fixed_basic_attack_id = &"element_slash"
	catalog.relic_definitions = CATALOG.relic_definitions
	return catalog


func _seed_containing(
		snapshot: RunSnapshot,
		context: RoomRewardContext,
		target_skill_id: StringName
) -> int:
	for candidate_seed in range(1, 4097):
		var offer := RewardGenerator.generate(
			snapshot,
			context,
			candidate_seed,
			CATALOG.reward_definitions(),
			CATALOG.relic_definitions
		)
		if offer.valid and offer.contains_content(target_skill_id):
			return candidate_seed
	return 1


func _run_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	await _harness.run_test(test_name, test_callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
