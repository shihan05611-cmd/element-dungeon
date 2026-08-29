extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const TRANSIENT_MELEE_SCENE: PackedScene = preload("res://scenes/transient_melee_delivery.tscn")
const FIRE_AIRFLOW_TEXTURE: Texture2D = preload("res://assets/characters/cat/cat_fire_attack_airflow.png")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const HURTBOX_LAYER := 8

class TargetRig:
	extends RefCounted
	var host: Node2D
	var receiver: CombatReceiver
	var carrier: ElementCarrier

var _harness := TestHarness.new()
var _identity := 81_000


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	_run("catalog_and_default_active_2", _test_catalog_and_default_active_2)
	await _run_async("fire_transaction_is_atomic_and_preserves_water", _test_fire_transaction_is_atomic_and_preserves_water)
	await _run_async("player_basic_attack_snapshots_and_lifecycle_clear", _test_player_basic_attack_snapshots_and_lifecycle_clear)
	await _run_async("ignition_melee_range_snapshot_and_airflow", _test_ignition_melee_range_snapshot_and_airflow)
	_finish()


func _test_catalog_and_default_active_2() -> void:
	var content := CATALOG.content_for(&"ignition")
	_expect(CATALOG.validation_error().is_empty(), "catalog accepts the ignition content")
	_expect(content != null and content.initially_owned, "ignition is initially owned for the demo")
	_expect(content != null and not content.reward_pool and content.purchase_price == 0, "ignition stays out of rewards, shops, and economy")
	_expect_eq(CATALOG.default_loadout_snapshot().get_skill_id(SkillSlotIds.ACTIVE_2), &"ignition", "ignition defaults to ACTIVE_2")
	var skill := CATALOG.gameplay_for(&"ignition")
	_expect(skill != null and skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT and skill.required_element_id == ElementIds.FIRE, "ignition has fixed FIRE semantics")
	_expect(skill != null and is_equal_approx(skill.cooldown, 8.0) and skill.energy_cost == 0, "ignition is an eight-second zero-SP active")
	_expect(content != null and content.active_progression != null and content.active_progression.is_valid(), "ignition owns a valid active progression")
	if content != null and content.active_progression != null:
		var levels := content.active_progression.levels
		_expect_eq(levels.size(), 3, "ignition has exactly three levels")
		_expect(is_equal_approx(levels[0].damage_scale, 1.0) and is_equal_approx(levels[1].damage_scale, 1.2) and is_equal_approx(levels[2].damage_scale, 1.4), "ignition scales only the 5 percent per-layer increment")
		_expect_eq(levels[1].upgrade_price, 60, "ignition Lv2 costs 60 dream dust")
		_expect_eq(levels[2].upgrade_price, 100, "ignition Lv3 costs 100 dream dust")


func _test_fire_transaction_is_atomic_and_preserves_water() -> void:
	var rig := await _make_viewport_rig()
	var world := rig.world as Node2D
	var source := rig.source as Node2D
	var state := rig.state as IgnitionState
	var first := _make_target(world, Vector2(820, 350), 4, 1)
	var second := _make_target(world, Vector2(940, 350), 7, 5)
	var third := _make_target(world, Vector2(1060, 350), 2, 10)
	await physics_frame
	var received_events: Array[ReclaimVfxEvent] = []
	var port := RangeIgnitionPort.new(source, state, HURTBOX_LAYER, 256, func(event: ReclaimVfxEvent) -> void: received_events.append(event))
	var prepared := port.prepare(_cast_snapshot(source))
	_expect(prepared.accepted, "three visible FIRE targets prepare even with no EnergyComponent")
	_expect_eq(prepared.matched_element_amount, 16, "all FIRE layers sum deterministically")
	var transaction := prepared.transaction as RangeIgnitionPort.IgnitionTransaction
	_expect(transaction != null and transaction.validation_error().is_empty(), "ignition locks a valid atomic transaction")
	transaction.commit_silent()
	transaction.publish_committed()
	_expect_eq(first.carrier.get_amount(ElementIds.FIRE), 0, "first target fire clears")
	_expect_eq(second.carrier.get_amount(ElementIds.FIRE), 0, "second target fire clears")
	_expect_eq(third.carrier.get_amount(ElementIds.FIRE), 0, "third target fire clears")
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 4, "first target water remains")
	_expect_eq(second.carrier.get_amount(ElementIds.WATER), 7, "second target water remains")
	_expect_eq(third.carrier.get_amount(ElementIds.WATER), 2, "third target water remains")
	_expect(state.active and state.absorbed_fire_layers == 16, "committed transaction activates ignition with its aggregate")
	_expect_near(state.multiplier, 1.8, 0.0001, "aggregate multiplier is exactly 1 + 0.05*N")
	_expect(received_events.size() == 1 and received_events[0].element_id == ElementIds.FIRE and received_events[0].target_positions.size() == 3, "commit publishes one reusable fire reclaim VFX event")
	state.clear(&"test")
	var level_three := ActiveSkillLevelEffectSnapshot.new(&"ignition", 3, 1.4)
	_expect(state.activate_silent(20, level_three.damage_scale), "accepted Lv3 snapshot activates ignition")
	_expect_near(state.multiplier, 2.4, 0.0001, "Lv3 twenty layers equal 1 + 20 x 0.05 x 1.4")
	_expect_near(IgnitionState.multiplier_for(1, 1.4), 1.07, 0.0001, "Lv3 one layer adds seven percent")
	_expect_near(IgnitionState.multiplier_for(5, 1.4), 1.35, 0.0001, "Lv3 five layers add thirty-five percent")
	_expect_near(IgnitionState.multiplier_for(20, 1.4), 2.4, 0.0001, "Lv3 twenty layers add one hundred forty percent")
	var later_level := ActiveSkillLevelEffectSnapshot.new(&"ignition", 1, 1.0)
	_expect_near(state.multiplier, 2.4, 0.0001, "later level reset data cannot mutate the already accepted ignition")
	_expect(later_level.level == 1, "snapshot fixture changes only the next release level")
	state.clear(&"level_snapshot_test")
	first.carrier.set_amounts_silent(2, 1)
	second.carrier.set_amounts_silent(3, 5)
	await physics_frame
	var rejected := port.prepare(_cast_snapshot(source))
	second.receiver.accepting_hits = false
	_expect(rejected.accepted and rejected.transaction.validation_error() == &"reclaim_target_unavailable", "invalidated target rejects the complete prepared set")
	_expect_eq(first.carrier.get_amount(ElementIds.FIRE), 1, "atomic rejection preserves first target")
	_expect_eq(second.carrier.get_amount(ElementIds.FIRE), 5, "atomic rejection preserves second target")
	first.carrier.set_amounts_silent(2, 0)
	second.carrier.set_amounts_silent(3, 0)
	second.receiver.accepting_hits = true
	await physics_frame
	var empty := RangeIgnitionPort.new(source, state, HURTBOX_LAYER, 256).prepare(_cast_snapshot(source))
	_expect(not empty.accepted and empty.reject_reason == CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "no fire rejects before state or cooldown commit")
	(rig.viewport as SubViewport).queue_free()
	await process_frame


func _test_player_basic_attack_snapshots_and_lifecycle_clear() -> void:
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	var state := player.get_node("IgnitionState") as IgnitionState
	enemy.element_carrier.set_amounts_silent(2, 0)
	var form_before := player.current_element_controller.current_element_id
	var energy_before := player.energy_component.current_energy
	var no_fire := player.try_cast_slot(SkillSlotIds.ACTIVE_2)
	_expect(not no_fire.accepted and no_fire.reject_reason == CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "no fire rejects the active before cooldown commit")
	_expect(not state.active and player.current_element_controller.current_element_id == form_before and player.energy_component.current_energy == energy_before, "rejected ignition changes neither player state, form, nor SP")
	state.activate_silent(1)
	_expect_near(state.multiplier, 1.05, 0.0001, "one layer yields five percent")
	state.activate_silent(5)
	_expect_near(state.multiplier, 1.25, 0.0001, "five layers yield twenty-five percent")
	state.activate_silent(20)
	_expect_near(state.multiplier, 2.0, 0.0001, "twenty layers yield one hundred percent")
	state.activate_silent(5)
	var buffed := player.try_basic_attack()
	_expect(buffed.accepted and buffed.payload != null, "ignition accepts the fixed basic attack")
	_expect_near(buffed.payload.offensive_damage, 6.25, 0.0001, "five absorbed layers apply exactly 25 percent basic-attack damage")
	_expect_eq(buffed.payload.element_id, ElementIds.FIRE, "ignition basic attack locks FIRE")
	_expect_eq(buffed.payload.element_amount, 1, "ignition basic attack locks one FIRE layer")
	state.clear(&"test_expire")
	_expect_near(buffed.payload.offensive_damage, 6.25, 0.0001, "already accepted basic attack retains its locked multiplier after expiry")
	player.skill_executor.advance(1.0)
	var neutral := player.try_basic_attack()
	_expect(neutral.accepted and neutral.payload != null, "post-expiry basic attack accepts")
	_expect_near(neutral.payload.offensive_damage, 5.0, 0.0001, "post-expiry basic attack restores neutral base damage")
	state.activate_silent(1)
	player.skill_controller.on_floor_changed()
	_expect(not state.active, "room transition clears ignition")
	state.activate_silent(1)
	player.skill_controller.on_run_reloaded()
	_expect(not state.active, "run reload clears ignition")
	state.activate_silent(1)
	player.skill_controller.on_owner_died()
	_expect(not state.active, "death clears ignition")
	state.activate_silent(1)
	state._process(7.5)
	state.activate_silent(20)
	state._process(7.5)
	_expect(state.active and state.absorbed_fire_layers == 20, "recast replaces old aggregate and refreshes the full duration")
	_expect_near(state.multiplier, 2.0, 0.0001, "twenty layers have no artificial cap")
	state._process(0.6)
	_expect(not state.active, "ignition expires deterministically at eight seconds")
	room.queue_free()
	await process_frame


func _test_ignition_melee_range_snapshot_and_airflow() -> void:
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	player.global_position = Vector2(400, 470)
	var state := player.get_node("IgnitionState") as IgnitionState
	var airflow_base_scale := player.basic_attack_airflow.scale
	var airflow_base_position := player.basic_attack_airflow.position
	var measured_alpha_min_x := _critical_airflow_alpha_min_x()
	var normal_query_front := _normal_query_front(player)
	var normal_visual_front := (PlayerCharacter.BASIC_ATTACK_FRAME_SIZE.x * 0.5 - measured_alpha_min_x) * airflow_base_scale.x
	var fixed_margin := normal_query_front - normal_visual_front
	var ignition_visual_front := normal_visual_front * PlayerCharacter.IGNITION_AIRFLOW_SCALE_MULTIPLIER
	var expected_ignition_query_front := ignition_visual_front + fixed_margin
	var expected_query_multiplier := expected_ignition_query_front / normal_query_front
	_expect_eq(measured_alpha_min_x, int(PlayerCharacter.BASIC_ATTACK_CRITICAL_ALPHA_MIN_X), "critical FIRE airflow frame measurement keeps the configured alpha edge")
	_expect_near(normal_query_front, PlayerCharacter.BASIC_ATTACK_QUERY_FRONT, 0.0001, "normal real melee query front stays unchanged")
	_expect_near(normal_visual_front, PlayerCharacter.BASIC_ATTACK_VISUAL_FRONT, 0.0001, "normal critical-frame visual front is measured from the real airflow sheet")
	_expect_near(fixed_margin, PlayerCharacter.BASIC_ATTACK_FIXED_FORWARD_MARGIN, 0.0001, "normal query keeps its fixed authored forward margin P")
	_expect_near(expected_ignition_query_front, PlayerCharacter.IGNITION_QUERY_FRONT, 0.0001, "ignition query front equals 1.5x visual front plus the unscaled normal margin")
	_expect_near(expected_query_multiplier, PlayerCharacter.IGNITION_MELEE_QUERY_MULTIPLIER, 0.0001, "ignition snapshot multiplier is derived from the measured visual boundary formula")
	_expect(player.request_element(ElementIds.FIRE).accepted, "normal fire form is available")
	await create_timer(0.25).timeout
	var normal := await _basic_attack_hits(player, enemy, 1.0, normal_query_front + 19.0)
	_expect(not normal.hit, "normal FIRE basic attack cannot hit beyond its base range")
	_expect_near(normal.airflow_scale.x, airflow_base_scale.x, 0.0001, "normal FIRE airflow keeps authored scale")
	_expect(normal.airflow_modulate.is_equal_approx(normal.body_modulate), "normal FIRE airflow keeps authored color")
	var fire_body_scale := player.sprite.scale
	var fire_body_modulate := player.sprite.modulate
	state.activate_silent(5)
	var ignition_right := await _basic_attack_hits(player, enemy, 1.0, expected_ignition_query_front + 17.0)
	_expect(ignition_right.hit, "right-facing ignition hits immediately inside its visual-derived query boundary")
	_expect_near(ignition_right.airflow_scale.x, airflow_base_scale.x * PlayerCharacter.IGNITION_AIRFLOW_SCALE_MULTIPLIER, 0.0001, "only ignition airflow scales to exactly 1.5x")
	_expect(ignition_right.airflow_modulate.is_equal_approx(Color("ff7a20")), "ignition airflow becomes obvious orange")
	_expect(ignition_right.body_scale.is_equal_approx(fire_body_scale) and ignition_right.body_modulate.is_equal_approx(fire_body_modulate), "ignition leaves the player body scale and color untouched")
	_expect(player.basic_attack_airflow.scale.is_equal_approx(airflow_base_scale) and player.basic_attack_airflow.position.is_equal_approx(airflow_base_position), "animation completion restores airflow scale and position while ignition remains active")
	enemy.queue_free()
	await process_frame
	enemy = await _add_static_enemy(room)
	var ignition_left := await _basic_attack_hits(player, enemy, -1.0, expected_ignition_query_front + 17.0)
	_expect(ignition_left.hit, "left-facing ignition mirrors the same visual-derived inside boundary")
	enemy.queue_free()
	await process_frame
	enemy = await _add_static_enemy(room)
	var ignition_outer := await _basic_attack_hits(player, enemy, 1.0, expected_ignition_query_front + 19.0)
	_expect(not ignition_outer.hit, "ignition does not hit immediately outside its visual-derived query boundary")
	enemy.queue_free()
	await process_frame
	enemy = await _add_static_enemy(room)
	var accepted_before_expiry := player.try_basic_attack()
	_expect(accepted_before_expiry.accepted and is_equal_approx(accepted_before_expiry.payload.melee_query_multiplier, expected_query_multiplier), "accepted ignition basic locks the visual-derived query multiplier")
	state.clear(&"range_snapshot_test")
	enemy.global_position = player.global_position + Vector2(expected_ignition_query_front + 17.0, 0)
	enemy.damage_receiver.restore_full()
	enemy.combat_receiver.accepting_hits = true
	enemy.combat_receiver.clear_recent_hits()
	enemy.hurt_time = 0.0
	await physics_frame
	var resolved: Array[CombatResult] = []
	var resolved_callback := func(result: CombatResult) -> void:
		resolved.append(result)
	enemy.combat_receiver.hit_resolved.connect(resolved_callback)
	var accepted_delivery: MeleeDelivery
	var accepted_hits: Array[CombatResult] = []
	var delivery_callback := func(delivery: Node) -> void:
		accepted_delivery = delivery as MeleeDelivery
	player.delivery_created.connect(delivery_callback)
	player.skill_executor.advance(0.1)
	if player.delivery_created.is_connected(delivery_callback):
		player.delivery_created.disconnect(delivery_callback)
	if accepted_delivery != null:
		accepted_delivery.hit_submitted.connect(func(result: CombatResult, _receiver: CombatReceiver, _hurtbox: CombatHurtbox) -> void: accepted_hits.append(result))
	await physics_frame
	_expect(resolved.any(func(result: CombatResult) -> bool: return result != null and result.accepted), "accepted ignition attack keeps expanded real range after status expiry")
	if enemy.combat_receiver.hit_resolved.is_connected(resolved_callback):
		enemy.combat_receiver.hit_resolved.disconnect(resolved_callback)
	_expect_near(player.basic_attack_airflow.scale.x, airflow_base_scale.x, 0.0001, "status expiry restores airflow scale immediately")
	_expect(player.basic_attack_airflow.position.is_equal_approx(airflow_base_position), "status expiry restores airflow position without drift")
	_expect(player.basic_attack_airflow.modulate.is_equal_approx(player.sprite.modulate), "status expiry restores airflow color immediately")
	await _finish_basic_attack(player)
	var neutral := await _basic_attack_hits(player, enemy, 1.0, normal_query_front + 19.0)
	_expect(not neutral.hit, "post-expiry basic attack returns to base range")
	room.queue_free()
	await process_frame


func _basic_attack_hits(player: PlayerCharacter, enemy: CombatEnemy, facing: float, distance: float) -> Dictionary:
	player.facing = facing
	enemy.global_position = player.global_position + Vector2(facing * distance, 0.0)
	enemy.damage_receiver.restore_full()
	enemy.combat_receiver.accepting_hits = true
	enemy.combat_receiver.clear_recent_hits()
	enemy.hurt_time = 0.0
	await physics_frame
	var resolved: Array[CombatResult] = []
	var resolved_callback := func(result: CombatResult) -> void:
		resolved.append(result)
	enemy.combat_receiver.hit_resolved.connect(resolved_callback)
	var delivery: MeleeDelivery
	var delivery_callback := func(created: Node) -> void:
		delivery = created as MeleeDelivery
	player.delivery_created.connect(delivery_callback)
	var attempt := player.try_basic_attack()
	_expect(attempt.accepted, "test basic attack accepts")
	var observation := {
		"hit": false,
		"airflow_scale": player.basic_attack_airflow.scale,
		"airflow_modulate": player.basic_attack_airflow.modulate,
		"body_scale": player.sprite.scale,
		"body_modulate": player.sprite.modulate,
	}
	player.skill_executor.advance(0.1)
	if player.delivery_created.is_connected(delivery_callback):
		player.delivery_created.disconnect(delivery_callback)
	await physics_frame
	observation.hit = enemy.damage_receiver.current_health < enemy.damage_receiver.maximum_health
	if enemy.combat_receiver.hit_resolved.is_connected(resolved_callback):
		enemy.combat_receiver.hit_resolved.disconnect(resolved_callback)
	await _finish_basic_attack(player)
	return observation


func _finish_basic_attack(player: PlayerCharacter) -> void:
	player.skill_executor.advance(1.0)
	await physics_frame


func _add_static_enemy(room: Node2D) -> CombatEnemy:
	var enemy := ENEMY_SCENE.instantiate() as CombatEnemy
	room.add_child(enemy)
	await process_frame
	await physics_frame
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	return enemy


func _critical_airflow_alpha_min_x() -> int:
	var image := FIRE_AIRFLOW_TEXTURE.get_image()
	if image == null:
		return -1
	var frame_start := PlayerCharacter.BASIC_ATTACK_CRITICAL_AIRFLOW_FRAME * int(PlayerCharacter.BASIC_ATTACK_FRAME_SIZE.x)
	for local_x: int in range(int(PlayerCharacter.BASIC_ATTACK_FRAME_SIZE.x)):
		for y: int in range(int(PlayerCharacter.BASIC_ATTACK_FRAME_SIZE.y)):
			if image.get_pixel(frame_start + local_x, y).a > 0.0:
				return local_x
	return -1


func _normal_query_front(player: PlayerCharacter) -> float:
	var delivery := TRANSIENT_MELEE_SCENE.instantiate() as MeleeDelivery
	var rectangle := delivery.hit_shape as RectangleShape2D
	var basic_attack := player.get("_basic_attack_definition") as SkillDefinition
	var spawn := player._capture_spawn_snapshot(basic_attack)
	var spawn_distance := absf(spawn.initial_transform.origin.x - player.global_position.x)
	var query_front := spawn_distance + delivery.query_offset.x + rectangle.size.x * 0.5
	delivery.free()
	return query_front


func _make_viewport_rig() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(920, 350)
	camera.enabled = true
	world.add_child(camera)
	var source := Node2D.new()
	source.position = camera.position
	world.add_child(source)
	var state := IgnitionState.new()
	state.set_process(false)
	source.add_child(state)
	await process_frame
	await physics_frame
	return {"viewport": viewport, "world": world, "source": source, "state": state}


func _make_target(parent: Node2D, position: Vector2, water: int, fire: int) -> TargetRig:
	var rig := TargetRig.new()
	rig.host = Node2D.new()
	rig.host.position = position
	parent.add_child(rig.host)
	rig.receiver = CombatReceiver.new()
	rig.receiver.target_team_id = &"enemy"
	rig.host.add_child(rig.receiver)
	rig.carrier = ElementCarrier.new()
	rig.carrier.set_amounts_silent(water, fire)
	rig.host.add_child(rig.carrier)
	rig.receiver.configure_components(rig.carrier, null)
	var hurtbox := CombatHurtbox.new()
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.configure_receiver(rig.receiver)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	hurtbox.add_child(collision)
	rig.host.add_child(hurtbox)
	return rig


func _cast_snapshot(source: Node2D) -> CastSnapshot:
	_identity += 1
	return CastSnapshot.new(_identity, &"ignition", source.get_instance_id(), source.get_instance_id(), &"player", ElementIds.FIRE, CombatStatSnapshot.new())


func _run(name: String, callable: Callable) -> void:
	_harness.tests += 1
	var before := _harness.failures.size()
	callable.call()
	if _harness.failures.size() == before:
		print("PASS " + name)
	else:
		for index in range(before, _harness.failures.size()):
			_harness.failures[index] = name + ": " + _harness.failures[index]


func _run_async(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_harness.expect_eq(actual, expected, message)


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_harness.expect_near(actual, expected, tolerance, message)


func _finish() -> void:
	quit(_harness.report("TASK 81 IGNITION TESTS"))
