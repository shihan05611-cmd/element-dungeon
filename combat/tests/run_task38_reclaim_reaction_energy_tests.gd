extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const HURTBOX_LAYER: int = 8

class TargetRig:
	extends RefCounted
	var host: Node2D
	var receiver: CombatReceiver
	var carrier: ElementCarrier
	var hurtbox: CombatHurtbox

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []
var _identity: int = 38_000


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	await _run_async("reclaim_uses_visible_world_rectangle", _test_reclaim_visible_world_rectangle)
	await _run_async("reclaim_full_and_atomic_rejection", _test_reclaim_full_and_atomic_rejection)
	await _run_async("reaction_energy_formal_host_wiring", _test_reaction_energy_formal_host_wiring)
	_finish()


func _test_reclaim_visible_world_rectangle() -> void:
	var rig := await _make_viewport_rig()
	var world := rig.world as Node2D
	var source := rig.source as Node2D
	var energy := rig.energy as EnergyComponent
	var inside_far := _make_target(world, Vector2(1240.0, 500.0), 3, 0)
	var outside := _make_target(world, Vector2(1400.0, 500.0), 5, 0)
	var diagonal_outside := _make_target(world, Vector2(1360.0, 740.0), 7, 0)
	var different_element := _make_target(world, Vector2(1080.0, 560.0), 0, 4)
	_make_wall(world, Vector2(1120.0, 500.0))
	await physics_frame
	var port := RangeElementReclaimPort.new(source, energy, HURTBOX_LAYER, 256)
	var prepared := port.prepare(_reclaim_request(source, energy, ElementIds.WATER))
	_expect(prepared.accepted, "visible matching target prepares despite wall and old-radius distance")
	var transaction := prepared.transaction as RangeElementReclaimTransaction
	_expect(transaction != null and transaction.validation_error().is_empty(), "visible rectangle produces a valid transaction")
	_expect_eq(transaction.target_count, 1, "only one matching target lies inside the visible rectangle")
	_expect(source.global_position.distance_to(inside_far.host.global_position) > 160.0, "accepted target is beyond legacy 160 radius")
	transaction.commit_silent()
	transaction.publish_committed()
	_expect_eq(inside_far.carrier.get_amount(ElementIds.WATER), 0, "inside target is fully reclaimed")
	_expect_eq(outside.carrier.get_amount(ElementIds.WATER), 5, "horizontal offscreen target is excluded")
	_expect_eq(diagonal_outside.carrier.get_amount(ElementIds.WATER), 7, "diagonal offscreen target is excluded")
	_expect_eq(different_element.carrier.get_amount(ElementIds.FIRE), 4, "different element remains untouched")
	_expect_eq(energy.current_energy, 65, "three committed layers restore fifteen SP")
	(rig.viewport as SubViewport).queue_free()
	await process_frame


func _test_reclaim_full_and_atomic_rejection() -> void:
	var rig := await _make_viewport_rig()
	var world := rig.world as Node2D
	var source := rig.source as Node2D
	var energy := rig.energy as EnergyComponent
	var first := _make_target(world, Vector2(940.0, 500.0), 2, 0)
	var second := _make_target(world, Vector2(1080.0, 500.0), 3, 0)
	await physics_frame
	var port := RangeElementReclaimPort.new(source, energy, HURTBOX_LAYER, 256)
	var prepared := port.prepare(_reclaim_request(source, energy, ElementIds.WATER))
	var transaction := prepared.transaction as RangeElementReclaimTransaction
	_expect(prepared.accepted and transaction != null, "two visible targets prepare atomically")
	second.receiver.accepting_hits = false
	_expect_eq(transaction.validation_error(), &"reclaim_target_unavailable", "changed target rejects the whole transaction")
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 2, "atomic rejection preserves first target")
	_expect_eq(second.carrier.get_amount(ElementIds.WATER), 3, "atomic rejection preserves invalidated target")
	_expect_eq(energy.current_energy, 50, "atomic rejection restores no SP")
	energy.set_current(energy.maximum)
	var full := port.prepare(_reclaim_request(source, energy, ElementIds.WATER))
	_expect(not full.accepted, "full SP rejects before reclaim")
	_expect_eq(full.reject_reason, CastAttemptResult.RejectReason.NO_BENEFIT, "full SP uses the no-benefit rejection")
	_expect_eq(full.detail, &"energy_already_full", "full SP keeps the explicit rejection detail")
	first.receiver.accepting_hits = false
	var no_target_energy := EnergyComponent.new()
	no_target_energy.configure_runtime(100, 50)
	world.add_child(no_target_energy)
	var empty_port := RangeElementReclaimPort.new(source, no_target_energy, HURTBOX_LAYER, 256)
	var empty := empty_port.prepare(_reclaim_request(source, no_target_energy, ElementIds.WATER))
	_expect(not empty.accepted and empty.reject_reason == CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "no legal visible target rejects")
	var detached_source := Node2D.new()
	var detached_energy := EnergyComponent.new()
	detached_energy.configure_runtime(100, 50)
	var detached_port := RangeElementReclaimPort.new(detached_source, detached_energy, HURTBOX_LAYER, 256)
	var detached := detached_port.prepare(_reclaim_request(detached_source, detached_energy, ElementIds.WATER))
	_expect(not detached.accepted and detached.detail == &"reclaim_query_dependencies_unavailable", "source without a live Viewport keeps the explicit dependency rejection")
	detached_source.free()
	detached_energy.free()
	(rig.viewport as SubViewport).queue_free()
	await process_frame


func _test_reaction_energy_formal_host_wiring() -> void:
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	var host := room.get_node("RunSessionHost") as RunSessionHost
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	host.set_process(false)
	_expect(CATALOG.content_for(&"passive_reaction_energy") != null, "element echo is registered in the formal catalog")
	_expect(_equip_passive(host.runtime_loadout, SkillSlotIds.PASSIVE_1, &"passive_reaction_energy"), "element echo equips in a passive slot")
	_expect_eq(host.passive_adapter.registered_skill_ids(), [&"passive_reaction_energy"], "element echo creates exactly one runtime")
	player.energy_component.set_current(40)
	var reaction := _submit_player_hit(player, enemy, true)
	_expect(reaction.accepted and reaction.reaction_triggered, "formal enemy settlement reports a player reaction")
	_expect_eq(player.energy_component.current_energy, 50, "one accepted reaction restores exactly ten SP")
	var duplicate := enemy.combat_receiver.receive_hit(_request_for(player, true, reaction.cast_id, reaction.delivery_id, reaction.hit_index))
	_expect(not duplicate.accepted, "duplicate hit identity is rejected by the formal receiver")
	_expect_eq(player.energy_component.current_energy, 50, "duplicate result cannot restore twice")
	var no_reaction := _submit_player_hit(player, enemy, false)
	_expect(no_reaction.accepted and not no_reaction.reaction_triggered, "non-reaction settlement remains accepted")
	_expect_eq(player.energy_component.current_energy, 50, "non-reaction restores no SP")
	player.energy_component.set_current(95)
	var clamped := _submit_player_hit(player, enemy, true)
	_expect(clamped.reaction_triggered, "second reaction settles")
	_expect_eq(player.energy_component.current_energy, 100, "reaction restore clamps at maximum SP")
	var enemy_reaction := _standalone_reaction_result(99_001, 99_002, 0, enemy.get_instance_id())
	host.passive_adapter.on_combat_result(enemy_reaction, &"player", true, player.get_instance_id())
	_expect_eq(player.energy_component.current_energy, 100, "enemy reaction against player does not restore SP")
	player.energy_component.set_current(30)
	_expect(_equip_passive(host.runtime_loadout, SkillSlotIds.PASSIVE_1, &""), "element echo unequips")
	_submit_player_hit(player, enemy, true)
	_expect_eq(player.energy_component.current_energy, 30, "unequipped element echo does not trigger")
	_expect(_equip_passive(host.runtime_loadout, SkillSlotIds.PASSIVE_1, &"passive_reaction_energy"), "element echo re-equips")
	var registrations := host.runtime_loadout.passive_registration_commit_count
	var unregistrations := host.runtime_loadout.passive_unregistration_commit_count
	player.skill_controller.on_floor_changed()
	_expect_eq(host.runtime_loadout.registered_passive_skill_ids, [&"passive_reaction_energy"], "floor rebuild retains one element echo runtime")
	_expect_eq(host.runtime_loadout.passive_registration_commit_count, registrations + 1, "floor rebuild registers one batch")
	_expect_eq(host.runtime_loadout.passive_unregistration_commit_count, unregistrations + 1, "floor rebuild unregisters one batch")
	_submit_player_hit(player, enemy, true)
	_expect_eq(player.energy_component.current_energy, 40, "rebuilt runtime restores once without duplicate registration")
	room.queue_free()
	await process_frame


func _make_viewport_rig() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(1000.0, 500.0)
	camera.enabled = true
	world.add_child(camera)
	var source := Node2D.new()
	source.position = camera.position
	world.add_child(source)
	var energy := EnergyComponent.new()
	energy.configure_runtime(100, 50)
	energy.set_process(false)
	source.add_child(energy)
	await process_frame
	await physics_frame
	return {"viewport": viewport, "world": world, "source": source, "energy": energy}


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
	rig.hurtbox = CombatHurtbox.new()
	rig.hurtbox.collision_layer = HURTBOX_LAYER
	rig.hurtbox.collision_mask = 0
	rig.hurtbox.configure_receiver(rig.receiver)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	rig.hurtbox.add_child(collision)
	rig.host.add_child(rig.hurtbox)
	return rig


func _make_wall(parent: Node2D, position: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = 4
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24.0, 220.0)
	collision.shape = shape
	wall.add_child(collision)
	parent.add_child(wall)


func _reclaim_request(source: Node2D, energy: EnergyComponent, element_id: StringName) -> ElementReclaimRequest:
	_identity += 1
	return ElementReclaimRequest.new(
		CastSnapshot.new(_identity, &"element_reclaim", source.get_instance_id(), source.get_instance_id(), &"player", element_id, CombatStatSnapshot.new()),
		energy.current_energy,
		energy.maximum
	)


func _equip_passive(runtime: RuntimeSkillLoadout, slot_id: StringName, skill_id: StringName) -> bool:
	var current := runtime.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in current.entries:
		entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, skill_id if entry.slot_id == slot_id else entry.skill_id))
	return runtime.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision)).accepted


func _submit_player_hit(player: PlayerCharacter, enemy: CombatEnemy, reaction: bool) -> CombatResult:
	_identity += 1
	enemy.combat_receiver.accepting_hits = true
	enemy.element_carrier.set_amounts_silent(1 if reaction else 0, 0)
	return enemy.combat_receiver.receive_hit(_request_for(player, true, _identity, _identity + 10_000, 0))


func _request_for(player: PlayerCharacter, fire: bool, cast_id: int, delivery_id: int, hit_index: int) -> HitRequest:
	var element_id := ElementIds.FIRE if fire else ElementIds.NONE
	var amount := 1 if fire else 0
	var cast := CastSnapshot.new(cast_id, &"task38_hit", player.get_instance_id(), player.get_instance_id(), &"player", element_id, CombatStatSnapshot.new())
	return HitRequest.new(cast, RuntimeAttackPayload.from_locked_stats(cast.stat_snapshot, 0.0, element_id, amount), delivery_id, hit_index, Vector2.ZERO, Vector2.RIGHT)


func _standalone_reaction_result(cast_id: int, delivery_id: int, hit_index: int, root_owner_id: int) -> CombatResult:
	var receiver := CombatReceiver.new()
	receiver.target_team_id = &"player"
	var carrier := ElementCarrier.new()
	carrier.set_amounts_silent(1, 0)
	receiver.configure_components(carrier, null)
	var cast := CastSnapshot.new(cast_id, &"enemy_hit", root_owner_id, root_owner_id, &"enemy", ElementIds.FIRE, CombatStatSnapshot.new())
	var result := receiver.receive_hit(HitRequest.new(cast, RuntimeAttackPayload.from_locked_stats(cast.stat_snapshot, 0.0, ElementIds.FIRE, 1), delivery_id, hit_index, Vector2.ZERO, Vector2.LEFT))
	receiver.free()
	carrier.free()
	return result


func _run_async(name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callable.call()
	if _failures.size() == before:
		print("PASS: " + name)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 38 RECLAIM REACTION ENERGY TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 38 RECLAIM REACTION ENERGY TESTS FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
