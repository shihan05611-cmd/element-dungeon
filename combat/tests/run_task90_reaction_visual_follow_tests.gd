extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _feedback: CombatFeedback
var _host: RunSessionHost
var _delivery_serial: int = 90000
var _cast_serial: int = 90100


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
	_feedback = _room.get_node("WorldFeedbackLayer") as CombatFeedback
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)

	await _harness.run_test("local_hit_offset_follows_each_frame_without_moving_damage_number", _test_local_hit_offset_follow)
	await _harness.run_test("left_right_and_multiple_targets_follow_independently", _test_left_right_multiple_targets)
	await _harness.run_test("invalid_host_falls_back_and_tree_exit_freezes", _test_fallback_and_tree_exit)
	await _harness.run_test("released_host_freezes_then_keeps_original_lifetime", _test_released_host_lifetime)
	await _harness.run_test("reduced_motion_still_anchors_while_static_and_boss_stay_stable", _test_reduced_motion_static_and_boss)
	await _harness.run_test("sixteen_cap_and_existing_dedupe_key_remain_bounded", _test_cap_dedupe_and_cleanup)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 90 REACTION VISUAL FOLLOW TESTS"))


func _test_local_hit_offset_follow() -> void:
	await _reset_fixture()
	_enemy.global_position = Vector2(790.0, 470.0)
	var hit_position := _enemy.global_position + Vector2(18.0, -37.0)
	_enemy.element_carrier.set_amounts_silent(1, 0)
	var result := _submit_hit(_enemy, ElementIds.FIRE, 1, 4.0, hit_position, Vector2.RIGHT)
	var visual := _latest_visual()
	var damage_group := _latest_damage_group()
	var local_offset := _enemy.to_local(hit_position)
	var damage_x := damage_group.global_position.x
	_expect(result.reaction_triggered and visual != null, "real accepted reaction creates a composition")
	_expect((visual.get("local_hit_offset") as Vector2).is_equal_approx(local_offset), "composition stores the target-local authored hit offset")
	_expect(visual.global_position.is_equal_approx(_enemy.to_global(local_offset)), "spawn frame uses the target-local offset")
	for displacement: Vector2 in [Vector2(24.0, -5.0), Vector2(63.0, 7.0), Vector2(101.0, -2.0)]:
		_enemy.global_position = Vector2(790.0, 470.0) + displacement
		await process_frame
		_expect(visual.global_position.is_equal_approx(_enemy.to_global(local_offset)), "composition follows target transform at displacement %s" % displacement)
	_expect(absf(damage_group.global_position.x - damage_x) < 0.5, "damage number does not inherit target horizontal displacement")


func _test_left_right_multiple_targets() -> void:
	await _reset_fixture()
	var second := ENEMY_SCENE.instantiate() as CombatEnemy
	_room.add_child(second)
	await process_frame
	second.set_physics_process(false)
	second.ai_enabled = false
	second.global_position = Vector2(925.0, 470.0)
	_feedback.observe_receiver(second.combat_receiver)
	_enemy.global_position = Vector2(705.0, 470.0)
	_enemy.element_carrier.set_amounts_silent(1, 0)
	second.element_carrier.set_amounts_silent(0, 1)
	var first_hit := _enemy.global_position + Vector2(-13.0, -32.0)
	var second_hit := second.global_position + Vector2(17.0, -39.0)
	_submit_hit(_enemy, ElementIds.FIRE, 1, 3.0, first_hit, Vector2.LEFT)
	var first_visual := _latest_visual()
	_submit_hit(second, ElementIds.WATER, 1, 3.0, second_hit, Vector2.RIGHT)
	var second_visual := _latest_visual()
	var first_offset := _enemy.to_local(first_hit)
	var second_offset := second.to_local(second_hit)
	_enemy.global_position += Vector2(-84.0, -6.0)
	second.global_position += Vector2(92.0, 8.0)
	await process_frame
	_expect(first_visual != second_visual, "simultaneous targets own independent feedback compositions")
	_expect(first_visual.global_position.is_equal_approx(_enemy.to_global(first_offset)), "left-moving target keeps its original body offset")
	_expect(second_visual.global_position.is_equal_approx(second.to_global(second_offset)), "right-moving target keeps its original body offset")
	second.queue_free()
	await process_frame


func _test_fallback_and_tree_exit() -> void:
	await _reset_fixture()
	_enemy.element_carrier.set_amounts_silent(1, 0)
	var fallback_position := Vector2(744.0, 408.0)
	var result := _submit_hit(_enemy, ElementIds.FIRE, 1, 2.0, fallback_position, Vector2.RIGHT)
	await _clear_feedback()
	_feedback.call(&"_spawn_reaction_visual", result, null)
	var fallback_visual := _latest_visual()
	await process_frame
	_expect(fallback_visual.global_position.is_equal_approx(fallback_position), "missing receiver host falls back to authoritative hit_position")
	_expect(not (fallback_visual.get("_following_target") as bool), "fallback composition has no tracking reference")

	await _clear_feedback()
	var fixture := _make_receiver_fixture(Vector2(660.0, 390.0))
	var target := fixture["target"] as Node2D
	var receiver := fixture["receiver"] as CombatReceiver
	_feedback.call(&"_spawn_reaction_visual", result, receiver)
	var visual := _latest_visual()
	var offset := target.to_local(result.hit_position)
	target.global_position += Vector2(35.0, 11.0)
	await process_frame
	var frozen_position := visual.global_position
	_expect(frozen_position.is_equal_approx(target.to_global(offset)), "fixture follows while its host remains in the tree")
	_room.remove_child(target)
	await process_frame
	target.position += Vector2(180.0, -90.0)
	await process_frame
	_expect(visual.global_position.is_equal_approx(frozen_position), "tree-exited host freezes the last valid world position")
	_expect(not (visual.get("_following_target") as bool), "tree exit permanently stops following")
	target.queue_free()


func _test_released_host_lifetime() -> void:
	await _reset_fixture()
	_enemy.element_carrier.set_amounts_silent(1, 0)
	var result := _submit_hit(_enemy, ElementIds.FIRE, 1, 2.0, Vector2(790.0, 420.0), Vector2.RIGHT)
	await _clear_feedback()
	var fixture := _make_receiver_fixture(Vector2(790.0, 460.0))
	var target := fixture["target"] as Node2D
	var receiver := fixture["receiver"] as CombatReceiver
	_feedback.call(&"_spawn_reaction_visual", result, receiver)
	var visual := _latest_visual()
	target.global_position += Vector2(46.0, -4.0)
	await process_frame
	var frozen_position := visual.global_position
	target.queue_free()
	await process_frame
	_expect(is_instance_valid(visual) and visual.global_position.is_equal_approx(frozen_position), "released host leaves the composition frozen and alive")
	_expect(not (visual.get("_following_target") as bool) and visual.get("_target_ref") == null, "released host leaves no retained target reference")
	await create_timer(0.30).timeout
	_expect(is_instance_valid(visual) and not visual.is_queued_for_deletion(), "frozen composition remains during the original 0.42 second lifetime")
	await create_timer(0.18).timeout
	_expect(not is_instance_valid(visual) and _feedback.active_reaction_visual_count() == 0, "frozen composition cleans up after the original lifetime")


func _test_reduced_motion_static_and_boss() -> void:
	await _reset_fixture()
	_feedback.set_reduced_motion(true)
	_enemy.global_position = Vector2(780.0, 470.0)
	_enemy.element_carrier.set_amounts_silent(0, 3)
	var hit_position := _enemy.global_position + Vector2(7.0, -36.0)
	_submit_hit(_enemy, ElementIds.WATER, 3, 4.0, hit_position, Vector2.RIGHT)
	var visual := _latest_visual()
	var local_offset := _enemy.to_local(hit_position)
	var damage_group := _latest_damage_group()
	var damage_position := damage_group.global_position
	await create_timer(0.08).timeout
	_expect(visual.global_position.is_equal_approx(hit_position), "static ordinary target keeps the existing authored position")
	_enemy.global_position += Vector2(72.0, 0.0)
	await process_frame
	await process_frame
	_expect(visual.global_position.is_equal_approx(_enemy.to_global(local_offset)), "reduced motion still follows target anchoring")
	_expect(damage_group.global_position.is_equal_approx(damage_position), "reduced-motion damage number stays at the original hit region")

	await _clear_feedback()
	_feedback.set_reduced_motion(false)
	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	_room.add_child(boss)
	await physics_frame
	boss.set_physics_process(false)
	boss.ai_enabled = false
	boss.global_position = Vector2(825.0, 515.0)
	boss.scale = Vector2.ONE * 4.0
	_feedback.observe_receiver(boss.combat_receiver)
	boss.element_carrier.set_amounts_silent(0, 3)
	var boss_hit := boss.global_position + Vector2(-29.0, -111.0)
	_submit_hit(boss, ElementIds.WATER, 3, 2.0, boss_hit, Vector2.LEFT)
	var boss_visual := _latest_visual()
	await create_timer(0.15).timeout
	_expect(boss_visual.global_position.is_equal_approx(boss_hit), "stationary Boss keeps its existing hit-position appearance")
	_expect(boss_visual.scale.is_equal_approx(Vector2.ONE), "Boss transform still does not scale the reaction composition root")
	boss.queue_free()
	await process_frame


func _test_cap_dedupe_and_cleanup() -> void:
	await _reset_fixture()
	var duplicate_result: CombatResult
	for index: int in 20:
		_enemy.damage_receiver.restore_full(false)
		_enemy.element_carrier.set_amounts_silent(1, 0)
		duplicate_result = _submit_hit(
			_enemy,
			ElementIds.FIRE,
			1,
			1.0,
			_enemy.global_position + Vector2(float(index), -32.0),
			Vector2.RIGHT,
			index
		)
	_expect(_feedback.active_reaction_visual_count() == CombatFeedback.MAX_ACTIVE_REACTION_VISUALS, "rapid tracked reactions retain the 16-composition cap")
	var shown_count := (_feedback.get("_shown_order") as Array).size()
	var child_count := _feedback.get_child_count()
	_feedback.call(&"_on_committed_result", duplicate_result, _enemy.combat_receiver)
	_expect((_feedback.get("_shown_order") as Array).size() == shown_count, "existing cast-delivery-hit-receiver dedupe key is unchanged")
	_expect(_feedback.get_child_count() == child_count, "dedupe prevents an extra label and tracked composition")
	await create_timer(0.52).timeout
	_expect(_feedback.active_reaction_visual_count() == 0 and _reaction_visuals().is_empty(), "all capped tracked compositions clean up without residue")


func _submit_hit(
		target: CombatEnemy,
		element_id: StringName,
		element_amount: int,
		offensive_damage: float,
		hit_position: Vector2,
		hit_direction: Vector2,
		hit_index: int = 0
) -> CombatResult:
	_delivery_serial += 1
	_cast_serial += 1
	var stats := CombatStatSnapshot.new(1.0, 0.0)
	var payload := RuntimeAttackPayload.from_locked_inputs(
		stats.effective_attack,
		offensive_damage / stats.effective_attack,
		0.0,
		offensive_damage,
		element_id,
		element_amount,
		PackedStringArray(["task90"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task90_follow_probe",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	var request := HitRequest.new(snapshot, payload, _delivery_serial, hit_index, hit_position, hit_direction)
	return target.combat_receiver.receive_hit(request)


func _make_receiver_fixture(position: Vector2) -> Dictionary:
	var target := Node2D.new()
	target.name = "Task90ReceiverFixture"
	target.global_position = position
	var receiver := CombatReceiver.new()
	receiver.name = "CombatReceiver"
	target.add_child(receiver)
	_room.add_child(target)
	return {"target": target, "receiver": receiver}


func _reset_fixture() -> void:
	await _clear_feedback()
	_feedback.set_reduced_motion(false)
	_enemy.scale = Vector2.ONE
	_enemy.rotation = 0.0
	_enemy.global_position = Vector2(790.0, 470.0)
	_enemy.defeated = false
	_enemy.hurt_time = 0.0
	_enemy.attack_time = 0.0
	_enemy.combat_receiver.accepting_hits = true
	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	_enemy.element_carrier.clear_all(false)


func _clear_feedback() -> void:
	for tween: Tween in get_processed_tweens():
		tween.kill()
	for child: Node in _feedback.get_children():
		child.queue_free()
	await process_frame
	_feedback.set("_active_labels", [])
	_feedback.set("_active_reaction_visuals", [])


func _latest_visual() -> Node2D:
	var visuals := _reaction_visuals()
	return visuals.back() as Node2D if not visuals.is_empty() else null


func _reaction_visuals() -> Array[Node]:
	return _feedback.find_children("ReactionComposition_*", "Node2D", false, false)


func _latest_damage_group() -> Control:
	return _feedback.get_node("DamageFeedback_%d" % (_feedback.get("_spawn_serial") as int)) as Control


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
