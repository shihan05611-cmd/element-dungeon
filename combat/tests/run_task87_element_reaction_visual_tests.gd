extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _feedback: CombatFeedback
var _host: RunSessionHost
var _delivery_serial: int = 87000
var _cast_serial: int = 87100


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

	await _harness.run_test("fire_into_water_consumes_then_bursts", _test_fire_into_water_consumes_then_bursts)
	await _harness.run_test("water_into_fire_reverses_composition", _test_water_into_fire_reverses_composition)
	await _harness.run_test("weak_medium_strong_caps_at_three", _test_weak_medium_strong_caps_at_three)
	await _harness.run_test("ordinary_same_and_rejected_hits_have_no_reaction", _test_non_reactions)
	await _harness.run_test("multiple_hits_and_boss_scale_keep_authoritative_positions", _test_multiple_and_boss_positions)
	await _harness.run_test("reduced_motion_is_static_and_semantic", _test_reduced_motion)
	await _harness.run_test("concurrency_cap_dedupe_and_lifecycle_cleanup", _test_concurrency_dedupe_and_cleanup)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 87 ELEMENT REACTION VISUAL TESTS"))


func _test_fire_into_water_consumes_then_bursts() -> void:
	await _reset_fixture()
	_enemy.element_carrier.set_amounts_silent(1, 0)
	var hit_position := Vector2(742.0, 428.0)
	var result := _submit_hit(ElementIds.FIRE, 1, 8.0, hit_position)
	_expect(result.accepted and result.reaction_triggered, "fire hit accepts a real water reaction")
	_expect(result.reaction_consumed == 1 and is_equal_approx(result.reaction_multiplier, 1.3), "weak reaction authority remains unchanged")
	var visual := _latest_visual()
	_expect(visual != null and visual.global_position.is_equal_approx(hit_position), "composition is centered on authoritative hit_position")
	_expect(visual.get("source_element_id") == ElementIds.FIRE and visual.get("consumed_element_id") == ElementIds.WATER, "fire source consumes water")
	_expect(visual.get("phase_order") == PackedStringArray(["water", "fire"]), "water inward phase precedes fire burst")
	_expect((_latest_damage_group().get_node("ReactionCue") as Label).text == "反应", "cue is exactly the fixed word")
	var lines := _feedback.presentation_text(result)
	_expect(lines.size() == 2 and lines[1] == "反应", "formal presentation has final damage plus fixed cue")
	_expect(not lines[1].contains("×") and not lines[1].contains("1") and not lines[1].contains("层"), "formal cue exposes no mechanical values")
	var child_count := _feedback.get_child_count()
	_feedback.call("_on_committed_result", result, _enemy.combat_receiver)
	_expect(_feedback.get_child_count() == child_count, "cast delivery hit receiver identity suppresses duplicate presentation")


func _test_water_into_fire_reverses_composition() -> void:
	await _reset_fixture()
	_enemy.element_carrier.set_amounts_silent(0, 2)
	var result := _submit_hit(ElementIds.WATER, 2, 8.0, Vector2(816.0, 446.0))
	var visual := _latest_visual()
	_expect(result.accepted and result.reaction_consumed == 2, "water hit accepts a medium fire reaction")
	_expect(visual != null and visual.get("source_element_id") == ElementIds.WATER, "water remains the attacking element")
	_expect(visual.get("phase_order") == PackedStringArray(["fire", "water"]), "fire inward phase precedes water burst")
	var consumed := visual.get_node("ConsumedElement") as AnimatedSprite2D
	var attacking := visual.get_node("AttackingElement") as AnimatedSprite2D
	_expect(consumed.sprite_frames.resource_path == "res://resources/vfx/burning_tick_frames.tres", "consumed fire reuses burning tick SpriteFrames")
	_expect(attacking.sprite_frames.resource_path == "res://resources/vfx/unending_trigger_frames.tres", "attacking water reuses unending trigger SpriteFrames")


func _test_weak_medium_strong_caps_at_three() -> void:
	var observed_tiers: Array[int] = []
	var observed_scales: Array[float] = []
	for consumed_layers: int in [1, 2, 4]:
		await _reset_fixture()
		_enemy.element_carrier.set_amounts_silent(consumed_layers, 0)
		var result := _submit_hit(ElementIds.FIRE, consumed_layers, 4.0, Vector2(790.0, 430.0))
		var visual := _latest_visual()
		_expect(result.reaction_consumed == consumed_layers, "combat result retains exact consumed amount %d" % consumed_layers)
		observed_tiers.append(visual.get("strength_tier") as int)
		observed_scales.append((visual.get_node("ConsumedElement") as AnimatedSprite2D).scale.x)
	_expect(observed_tiers == [1, 2, 3], "presentation maps one two and three-plus to bounded tiers")
	_expect(observed_scales[0] < observed_scales[1] and observed_scales[1] < observed_scales[2], "bounded tiers remain visually distinguishable by scale")


func _test_non_reactions() -> void:
	await _reset_fixture()
	var ordinary := _submit_hit(ElementIds.NONE, 0, 5.0, Vector2(800.0, 440.0))
	_expect(ordinary.accepted and not ordinary.reaction_triggered, "ordinary hit remains accepted without reaction")
	_expect(_feedback.active_reaction_visual_count() == 0 and _latest_damage_group().get_node_or_null("ReactionCue") == null, "ordinary hit creates only final damage")
	await _reset_fixture()
	_enemy.element_carrier.set_amounts_silent(0, 2)
	var same := _submit_hit(ElementIds.FIRE, 1, 5.0, Vector2(800.0, 440.0))
	_expect(same.accepted and not same.reaction_triggered, "same-element hit remains non-reactive")
	_expect(_feedback.active_reaction_visual_count() == 0 and _latest_damage_group().get_node_or_null("ReactionCue") == null, "same-element hit creates no reaction composition or cue")
	await _reset_fixture()
	_enemy.combat_receiver.accepting_hits = false
	var rejected := _submit_hit(ElementIds.FIRE, 1, 5.0, Vector2(800.0, 440.0))
	_feedback.call("_on_committed_result", rejected, _enemy.combat_receiver)
	_expect(not rejected.accepted and _feedback.get_child_count() == 0, "unaccepted result cannot create world presentation")


func _test_multiple_and_boss_positions() -> void:
	await _reset_fixture()
	var positions: Array[Vector2] = [Vector2(690.0, 410.0), Vector2(910.0, 468.0)]
	for position: Vector2 in positions:
		_enemy.element_carrier.set_amounts_silent(1, 0)
		_submit_hit(ElementIds.FIRE, 1, 2.0, position)
	var visuals := _reaction_visuals()
	_expect(visuals.size() == 2, "two target-style results create independent compositions")
	_expect((visuals[0] as Node2D).global_position.is_equal_approx(positions[0]) and (visuals[1] as Node2D).global_position.is_equal_approx(positions[1]), "each composition keeps its own hit position")
	await _reset_fixture()
	_enemy.scale = Vector2.ONE * 4.0
	_enemy.element_carrier.set_amounts_silent(0, 3)
	var boss_hit_position := _enemy.global_position + Vector2(37.0, -51.0)
	_submit_hit(ElementIds.WATER, 3, 2.0, boss_hit_position)
	var boss_visual := _latest_visual()
	_expect(boss_visual.global_position.is_equal_approx(boss_hit_position), "boss-sized target still centers on hit_position")
	_expect((boss_visual.get_node("AttackingElement") as AnimatedSprite2D).scale.x < 2.0, "composition scale is tier-bounded rather than receiver-scaled")
	_enemy.scale = Vector2.ONE


func _test_reduced_motion() -> void:
	await _reset_fixture()
	_feedback.set_reduced_motion(true)
	_enemy.element_carrier.set_amounts_silent(0, 3)
	var result := _submit_hit(ElementIds.WATER, 3, 6.0, Vector2(820.0, 420.0))
	var visual := _latest_visual()
	var consumed := visual.get_node("ConsumedElement") as AnimatedSprite2D
	var attacking := visual.get_node("AttackingElement") as AnimatedSprite2D
	_expect(visual.get("reduced_motion") as bool, "composition receives reduced-motion mode")
	_expect(consumed.position == Vector2.ZERO and attacking.position == Vector2.ZERO, "reduced-motion sprites do not translate")
	_expect(is_zero_approx(consumed.rotation) and is_zero_approx(attacking.rotation), "reduced-motion sprites do not rotate")
	_expect(not consumed.is_playing() and not attacking.is_playing(), "reduced-motion composition uses one static frame")
	var group := _latest_damage_group()
	var group_position := group.position
	await create_timer(0.12).timeout
	_expect(is_instance_valid(group) and group.position.is_equal_approx(group_position), "reduced-motion cue has no floating movement")
	_expect(_feedback.presentation_text(result) == PackedStringArray([str(result.final_damage), "反应"]), "reduced motion preserves final damage and fixed reaction semantics")
	_feedback.set_reduced_motion(false)


func _test_concurrency_dedupe_and_cleanup() -> void:
	await _reset_fixture()
	for index: int in 20:
		_enemy.damage_receiver.restore_full(false)
		_enemy.element_carrier.set_amounts_silent(1, 0)
		_submit_hit(ElementIds.FIRE, 1, 1.0, Vector2(650.0 + float(index) * 8.0, 430.0), index)
	_expect(_feedback.active_reaction_visual_count() == CombatFeedback.MAX_ACTIVE_REACTION_VISUALS, "reaction composition count is capped under rapid hits")
	await process_frame
	_expect(_reaction_visuals().size() <= CombatFeedback.MAX_ACTIVE_REACTION_VISUALS, "evicted compositions leave the scene tree")
	await create_timer(0.52).timeout
	_expect(_feedback.active_reaction_visual_count() == 0 and _reaction_visuals().is_empty(), "all compositions release within bounded lifetime")
	_expect(_feedback.find_children("ReactionCue", "Label", true, false).is_empty(), "short cues leave no cross-room-style residue")


func _submit_hit(
		element_id: StringName,
		element_amount: int,
		offensive_damage: float,
		hit_position: Vector2,
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
		PackedStringArray(["task87"])
	)
	var snapshot := CastSnapshot.new(
		_cast_serial,
		&"task87_feedback_probe",
		_player.get_instance_id(),
		_player.get_instance_id(),
		&"player",
		element_id,
		stats
	)
	var request := HitRequest.new(snapshot, payload, _delivery_serial, hit_index, hit_position, Vector2.RIGHT)
	return _enemy.combat_receiver.receive_hit(request)


func _reset_fixture() -> void:
	for tween: Tween in get_processed_tweens():
		tween.kill()
	for child: Node in _feedback.get_children():
		child.queue_free()
	await process_frame
	_feedback.set("_active_labels", [])
	_feedback.set("_active_reaction_visuals", [])
	_enemy.scale = Vector2.ONE
	_enemy.defeated = false
	_enemy.hurt_time = 0.0
	_enemy.attack_time = 0.0
	_enemy.combat_receiver.accepting_hits = true
	_enemy.combat_receiver.clear_recent_hits()
	_enemy.damage_receiver.restore_full(false)
	_enemy.element_carrier.clear_all(false)


func _latest_visual() -> Node2D:
	var visuals := _reaction_visuals()
	return visuals.back() as Node2D if not visuals.is_empty() else null


func _reaction_visuals() -> Array[Node]:
	return _feedback.find_children("ReactionComposition_*", "Node2D", false, false)


func _latest_damage_group() -> Control:
	return _feedback.get_node("DamageFeedback_%d" % (_feedback.get("_spawn_serial") as int)) as Control


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
