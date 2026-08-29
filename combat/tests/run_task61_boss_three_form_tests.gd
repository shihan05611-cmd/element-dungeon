extends SceneTree

## Task 61: Tide-Ember Sovereign three-form Boss. Covers every branch
## required by docs/agent_tasks/pending/61_boss_three_form_implementation.md §7.

const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const VFX_SCENE: PackedScene = preload("res://scenes/vfx/skill_vfx_coordinator.tscn")
const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const BOSS_ROOM: CombatRoomDefinition = preload("res://resources/run/rooms/combat_06_final_boss.tres")
const TestHarness := preload("res://combat/tests/test_harness.gd")

var _harness := TestHarness.new()
var _hit_seq: int = 6_100_000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_test("switch_counter_exact_15_and_reset", _test_switch_counter_exact_15_and_reset)
	await _run_test("same_element_does_not_count", _test_same_element_does_not_count)
	await _run_test("alternation_cap_enters_plain", _test_alternation_cap_enters_plain)
	await _run_test("plain_form_exit_both_branches", _test_plain_form_exit_both_branches)
	await _run_test("plain_form_no_attachment", _test_plain_form_no_attachment)
	await _run_test("plain_form_reaction_behavior", _test_plain_form_reaction_behavior)
	await _run_test("same_element_mitigation_exact_value", _test_same_element_mitigation_exact_value)
	await _run_test("cross_element_bonus_damage", _test_cross_element_bonus_damage)
	await _run_test("attach_layers_regen_cap_reset", _test_attach_layers_regen_cap_reset)
	await _run_test("hit_does_not_interrupt_attack_or_telegraph", _test_hit_does_not_interrupt_attack_or_telegraph)
	await _run_test("poise_break_and_reset", _test_poise_break_and_reset)
	await _run_test("form_transition_presentation", _test_form_transition_presentation)
	await _run_test("melee_telegraph_waiting_to_active", _test_melee_telegraph_waiting_to_active)
	await _run_test("ranged_telegraph_lock_and_count", _test_ranged_telegraph_lock_and_count)
	await _run_test("summon_cap_and_death_cleanup", _test_summon_cap_and_death_cleanup)
	await _run_test("run_coordinator_binds_summon_feedback", _test_run_coordinator_binds_summon_feedback)
	await _run_test("death_flow_zero_dream_dust", _test_death_flow_zero_dream_dust)
	await _run_test("damage_resolver_validation_branches", _test_damage_resolver_validation_branches)
	_finish()


# ---------------------------------------------------------------------------
# 1. Switch counting: exactly 15 counter hits switch once; 14 does not;
#    resets to zero after switching.
# ---------------------------------------------------------------------------
func _test_switch_counter_exact_15_and_reset() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	for i in 14:
		_hit(boss, ElementIds.WATER, 1)
	_expect_eq(boss.current_form_id, &"ember", "14 counter hits do not switch the form")
	_expect_eq(boss.counter_hits, 14, "counter reaches 14")
	_hit(boss, ElementIds.WATER, 1)
	_expect_eq(boss.current_form_id, &"tide", "the 15th counter hit switches ember -> tide")
	_expect_eq(boss.counter_hits, 0, "counter resets to zero after switching")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 2. Same-element hits never advance the counter.
# ---------------------------------------------------------------------------
func _test_same_element_does_not_count() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	for i in 20:
		_hit(boss, ElementIds.FIRE, 1)
	_expect_eq(boss.counter_hits, 0, "same-element (fire on ember) hits never increment the counter")
	_expect_eq(boss.current_form_id, &"ember", "form never switches from same-element hits alone")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 3. Alternation cap: water/fire alternation twice, third switch forces
#    the neutral form and resets the alternation counter.
# ---------------------------------------------------------------------------
func _test_alternation_cap_enters_plain() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	_hit_n(boss, ElementIds.WATER, 1, 15)
	_expect_eq(boss.current_form_id, &"tide", "1st switch ember -> tide")
	_expect_eq(boss.alternation_count, 1, "alternation counter is 1 after the first switch")
	_clear_transition(boss)
	_hit_n(boss, ElementIds.FIRE, 1, 15)
	_expect_eq(boss.current_form_id, &"ember", "2nd switch tide -> ember")
	_expect_eq(boss.alternation_count, 2, "alternation counter is 2 after the second switch")
	_clear_transition(boss)
	_hit_n(boss, ElementIds.WATER, 1, 15)
	_expect_eq(boss.current_form_id, &"plain", "3rd switch is forced to the neutral form")
	_expect_eq(boss.alternation_count, 0, "alternation counter resets to zero entering the neutral form")
	_expect(boss.entered_plain_form, "entered_plain_form flips true")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 4. Neutral-form exit: whichever element hits 15 times picks the next form.
# ---------------------------------------------------------------------------
func _test_plain_form_exit_both_branches() -> void:
	var ctx := await _make_boss(&"plain")
	var boss: BossTideEmber = ctx[&"boss"]
	_hit_n(boss, ElementIds.WATER, 1, 15)
	_expect_eq(boss.current_form_id, &"tide", "neutral form: water x15 switches to tide")
	await _destroy(ctx)

	ctx = await _make_boss(&"plain")
	boss = ctx[&"boss"]
	_hit_n(boss, ElementIds.FIRE, 1, 15)
	_expect_eq(boss.current_form_id, &"ember", "neutral form: fire x15 switches to ember")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 5. Neutral form carries no attachment.
# ---------------------------------------------------------------------------
func _test_plain_form_no_attachment() -> void:
	var ctx := await _make_boss(&"plain")
	var boss: BossTideEmber = ctx[&"boss"]
	_expect_eq(boss.element_carrier.get_amount(ElementIds.WATER), 0, "neutral form starts with zero water")
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), 0, "neutral form starts with zero fire")
	# No pre-existing attachment means the same-element mitigation predicate
	# (carrier already had this element before the hit) cannot fire on the
	# very first hit -- final damage must equal the un-mitigated formula.
	var result := _hit(boss, ElementIds.FIRE, 1)
	_expect(not result.mitigation_applied, "first hit on an empty neutral carrier is never mitigated")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 6. Neutral form still supports the normal cross-element reaction bonus.
# ---------------------------------------------------------------------------
func _test_plain_form_reaction_behavior() -> void:
	var ctx := await _make_boss(&"plain")
	var boss: BossTideEmber = ctx[&"boss"]
	_hit(boss, ElementIds.WATER, 4)
	var result := _hit(boss, ElementIds.FIRE, 2)
	_expect(result.reaction_consumed > 0, "alternating water then fire on the neutral form produces a real reaction")
	_expect(result.reaction_multiplier > 1.0, "neutral form reaction still grants a bonus multiplier")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 7. Same-element mitigation must land on the EXACT documented value,
#    distinguishing "before defense" from "after defense" placement.
# ---------------------------------------------------------------------------
func _test_same_element_mitigation_exact_value() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), 5, "ember form starts with 5 fire layers")
	var order: Array[String] = []
	_connect_order_tracking(boss.combat_receiver, order)
	var result := _hit(boss, ElementIds.FIRE, 1, 10.0)
	_expect(result.accepted, "same-element hit is accepted (not treated as invulnerable)")
	_expect_eq(result.reaction_multiplier, 1.0, "same-element hit produces no reaction bonus")
	_expect_eq(result.final_damage, 2, "(10*1.0 - 3.0) * 0.25 = 1.75 -> rounds to 2, matching §3.6's worked table")
	_expect(result.mitigation_applied, "mitigation_applied is true for this hit")
	_expect(boss.element_carrier.get_amount(ElementIds.FIRE) > 0, "fire element is still attached after the hit")
	_expect_eq(order, ["hit_resolved", "element_state_changed", "health_state_changed", "presentation_requested"], "frozen signal order preserved (no reaction/death for this hit)")

	# Layer count must not change the mitigation factor.
	var ctx2 := await _make_boss(&"ember")
	var boss2: BossTideEmber = ctx2[&"boss"]
	boss2.element_carrier.set_amounts_silent(0, 10)
	var result2 := _hit(boss2, ElementIds.FIRE, 1, 10.0)
	_expect_eq(result2.final_damage, 2, "mitigation factor is identical at 10 layers as at 5 layers")
	await _destroy(ctx)
	await _destroy(ctx2)


# ---------------------------------------------------------------------------
# 8. Cross-element hits deal significantly more damage than same-element.
# ---------------------------------------------------------------------------
func _test_cross_element_bonus_damage() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	var result := _hit(boss, ElementIds.WATER, 1, 10.0)
	_expect(result.reaction_consumed > 0, "water into a fire-attached carrier consumes a reaction")
	_expect_eq(result.reaction_multiplier, 1.3, "reaction_multiplier == 1.0 + 0.3*consumed for consumed=1")
	_expect_eq(result.final_damage, 10, "(10*1.3 - 3.0) rounds to 10, unmitigated")
	_expect(result.final_damage > 2, "cross-element damage is clearly higher than the same-element case (2)")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 9. Layer count: 5 on switch, +1 every 3s regardless of consumption, capped
#    at 10, reset to 5 on the next switch, consumption still regenerates.
# ---------------------------------------------------------------------------
func _test_attach_layers_regen_cap_reset() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), 5, "switch grants exactly 5 layers")
	boss._advance_layer_regen(3.0)
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), 6, "layers regen +1 after exactly one interval, untouched by consumption")
	for i in 10:
		boss._advance_layer_regen(3.0)
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), 10, "layers clamp at the configured cap (10)")

	# Consumption then regen still works normally.
	_hit(boss, ElementIds.WATER, 10)
	var after_consume := boss.element_carrier.get_amount(ElementIds.FIRE)
	_expect(after_consume < 10, "a strong reaction actually consumes layers")
	boss._advance_layer_regen(3.0)
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), mini(10, after_consume + 1), "regen resumes normally after consumption")

	_hit_n(boss, ElementIds.WATER, 1, 15)
	_expect_eq(boss.current_form_id, &"tide", "switched to tide")
	_expect_eq(boss.element_carrier.get_amount(ElementIds.WATER), 5, "switching resets the new form's layers back to exactly 5")
	_expect_eq(boss.element_carrier.get_amount(ElementIds.FIRE), 0, "old element is fully cleared on switch")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 10. Regular hits never interrupt an in-progress attack or ranged telegraph.
# ---------------------------------------------------------------------------
func _test_hit_does_not_interrupt_attack_or_telegraph() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	player.global_position = boss.global_position + Vector2(500.0, 0.0)
	boss._boss_projectile_cooldown = 0.0
	for i in 6:
		await physics_frame
	_expect(boss._telegraph_active, "boss entered a ranged telegraph")
	var locked_direction := boss._telegraph_locked_direction
	var remaining_before := boss._telegraph_time_remaining
	_hit(boss, ElementIds.FIRE, 1)
	_expect(boss._telegraph_active, "a normal (sub-threshold) hit does not cancel the active telegraph")
	_expect_eq(boss._telegraph_locked_direction, locked_direction, "telegraph direction stays locked through a hit")
	_expect(boss._telegraph_time_remaining <= remaining_before, "telegraph timer is untouched (only advanced by delta, not reset) by the hit")
	var fired_before := boss.boss_projectiles_fired
	var frames := 0
	while boss._telegraph_active and frames < 240:
		await physics_frame
		frames += 1
	_expect(boss.boss_projectiles_fired > fired_before, "the telegraphed ranged attack still fires on schedule despite being hit")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 11. Poise: accumulates hits, breaks into a long stagger, then resets.
# ---------------------------------------------------------------------------
func _test_poise_break_and_reset() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	_expect(boss.poise_enabled, "Boss opts into the poise system")
	for i in boss.poise_hit_threshold - 1:
		boss._on_poise_hit()
	_expect_eq(boss.poise_stun_time, 0.0, "poise has not broken yet below threshold")
	boss._on_poise_hit()
	_expect(boss.poise_stun_time > 0.0, "poise breaks at the threshold and opens a stagger window")
	_expect_eq(boss.poise_hits, 0, "poise hit counter resets immediately on break")
	for i in 400:
		if boss.poise_stun_time <= 0.0:
			break
		await physics_frame
	_expect_eq(boss.poise_stun_time, 0.0, "the stagger window ends on its own")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 12. Form-transition presentation: invulnerable rejects hits, residual
#     deliveries are cleared, attachment has switched.
# ---------------------------------------------------------------------------
func _test_form_transition_presentation() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	player.global_position = boss.global_position + Vector2(60.0, 0.0)
	boss.facing = 1.0
	boss._spawn_melee_delayed_delivery(boss.current_form)
	_expect_eq(boss._active_deliveries.size(), 1, "a delivery was tracked before the transition")
	_hit_n(boss, ElementIds.WATER, 1, 15)
	_expect_eq(boss.current_form_id, &"tide", "switched to tide")
	_expect(boss.combat_receiver.invulnerable, "the boss is invulnerable during the transition beat")
	var rejected := _hit(boss, ElementIds.FIRE, 1)
	_expect(not rejected.accepted, "hits during the transition are rejected outright")
	_expect_eq(boss.element_carrier.get_amount(ElementIds.WATER), 5, "attachment already switched to the new form")
	var stale_delivery: Variant = boss._active_deliveries[0].get_ref() if boss._active_deliveries.size() > 0 else null
	_expect(boss._active_deliveries.is_empty(), "residual delivery tracking is cleared on transition")
	if stale_delivery != null:
		_expect((stale_delivery as Node).is_queued_for_deletion(), "the residual delivery itself was queued for deletion")
	for i in 60:
		await physics_frame
	_expect(not boss.combat_receiver.invulnerable, "invulnerability lifts after the configured transition duration")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 13. Melee telegraph reuses DelayedAreaDelivery's WAITING -> ACTIVE timing
#     and deals no damage during the wait.
# ---------------------------------------------------------------------------
func _test_melee_telegraph_waiting_to_active() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	player.global_position = boss.global_position + Vector2(50.0, 0.0)
	boss.attack_cooldown = 0.0
	for i in 6:
		await physics_frame
	var delivery: DelayedAreaDelivery = null
	for reference: WeakRef in boss._active_deliveries:
		var node: Variant = reference.get_ref()
		if node is DelayedAreaDelivery:
			delivery = node
	_expect(delivery != null, "melee attack spawned a DelayedAreaDelivery")
	if delivery == null:
		await _destroy(ctx)
		return
	_expect_eq(delivery.delayed_phase, DelayedAreaDelivery.Phase.WAITING, "delivery starts in WAITING")
	var health_before := player.damage_receiver.current_health
	var waited := 0
	while delivery.delayed_phase == DelayedAreaDelivery.Phase.WAITING and waited < 240 and is_instance_valid(delivery):
		await physics_frame
		waited += 1
	_expect(player.damage_receiver.current_health == health_before, "no damage is dealt during the WAITING telegraph window")
	if is_instance_valid(delivery):
		_expect_eq(delivery.delayed_phase, DelayedAreaDelivery.Phase.ACTIVE, "delivery transitions WAITING -> ACTIVE once trigger_delay elapses")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 14. Ranged telegraph: boss holds still, direction locks, exactly the
#     configured shot count fires once the telegraph ends.
# ---------------------------------------------------------------------------
func _test_ranged_telegraph_lock_and_count() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	player.global_position = boss.global_position + Vector2(500.0, 0.0)
	boss._boss_projectile_cooldown = 0.0
	for i in 6:
		await physics_frame
	_expect(boss._telegraph_active, "ranged telegraph is active")
	_expect_eq(boss.velocity.x, 0.0, "boss holds horizontally still during the ranged telegraph")
	var direction := boss._telegraph_locked_direction
	player.global_position += Vector2(0.0, -40.0)
	await physics_frame
	_expect_eq(boss._telegraph_locked_direction, direction, "direction stays locked even if the player moves mid-telegraph")
	var before_count := _count_projectiles()
	var frames := 0
	while boss._telegraph_active and frames < 240:
		await physics_frame
		frames += 1
	await physics_frame
	var after_count := _count_projectiles()
	_expect_eq(after_count - before_count, boss.ember_form.ranged_projectile_profile.spread_count, "exactly spread_count projectiles fire once the telegraph completes")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 15. Summon cap: never exceeds summon_max_alive; defeat handling is explicit
#     (summons are not force-removed, but tracking stops referencing the dead
#     boss and no error occurs).
# ---------------------------------------------------------------------------
func _test_summon_cap_and_death_cleanup() -> void:
	var ctx := await _make_boss(&"tide")
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	var created_summons: Array[CombatEnemy] = []
	boss.summon_created.connect(func(summon: CombatEnemy) -> void: created_summons.append(summon))
	var feedback := CombatFeedback.new()
	(ctx[&"world"] as Node).add_child(feedback)
	var vfx := VFX_SCENE.instantiate() as SkillVfxCoordinator
	(ctx[&"world"] as Node).add_child(vfx)
	feedback.observe_receiver(boss.combat_receiver)
	var initial_enemies: Array[CombatEnemy] = [boss]
	_expect(vfx.set_enemies(initial_enemies), "Boss fixture binds its initial VFX target")
	boss.summon_created.connect(func(summon: CombatEnemy) -> void:
		feedback.observe_receiver(summon.combat_receiver)
		vfx.add_enemy(summon)
	)
	# Task 71 C5 made summoning telegraphed: _start_summon() now only opens the
	# warning window and the instantiate() happens when that window closes, so
	# the cap has to be read AFTER the window has been driven to completion.
	# Reading it straight after the call would make every assertion below
	# trivially true against a count of zero.
	boss._start_summon(boss.tide_form)
	await _resolve_summon_window(boss)
	_expect(boss._alive_summon_count() <= boss.tide_form.summon_max_alive, "summon count never exceeds summon_max_alive after one cast")
	var count_after_first := boss._alive_summon_count()
	_expect(count_after_first > 0, "the first cast actually produced summons (guards this test against going vacuous)")
	_expect_eq(created_summons.size(), count_after_first, "every instantiated summon is published for runtime feedback binding")
	for summon: CombatEnemy in created_summons:
		_expect_eq(summon.damage_receiver.maximum_health, 25, "Boss summon maximum health is reduced to 25")
		_expect_eq(summon.damage_receiver.current_health, 25, "Boss summon starts at full 25 health")
		_expect(bool(summon.get("_formal_run_spawn")), "Boss summon uses formal-run defeat cleanup")
	var feedback_before := feedback.get_child_count()
	var water_loops_before := vfx.unending_loop_count
	var summon_hit := _hit(created_summons[0], ElementIds.WATER, 2, 5.0)
	await process_frame
	_expect(summon_hit.accepted, "registered Boss summon accepts a real elemental hit")
	_expect_eq(created_summons[0].element_carrier.get_amount(ElementIds.WATER), 2, "Boss summon stores the attached water layers")
	_expect(vfx.unending_loop_count == water_loops_before + 1, "Boss summon displays its water attachment VFX")
	_expect(feedback.get_child_count() > feedback_before, "Boss summon displays a damage number")
	boss._summon_cooldown_remaining = 0.0
	boss._start_summon(boss.tide_form)
	await _resolve_summon_window(boss)
	_expect(boss._alive_summon_count() <= boss.tide_form.summon_max_alive, "a second cast still respects the cap (no more slots were free)")
	_expect_eq(boss._alive_summon_count(), count_after_first, "no new summon spawns once the cap is already reached")
	# Lethal hit -> death_candidate -> defeated; summons are independent
	# CombatEnemy instances and are left alive/uninterrupted (explicit choice:
	# Boss death does not cascade-kill its summons).
	var lethal := _hit(boss, ElementIds.WATER, 10, 99999.0)
	_expect(boss.defeated, "boss is defeated by the lethal hit")
	_expect_eq(boss._alive_summon_count(), count_after_first, "existing summons are left alone (not force-freed) when the boss dies")
	var defeated_summon := created_summons[0]
	var summon_lethal := _hit(defeated_summon, ElementIds.NONE, 0, 99999.0)
	_expect(summon_lethal.accepted and defeated_summon.defeated, "Boss summon reaches defeated state through real damage")
	_expect(not defeated_summon.prompt.visible, "formal Boss summon never shows the test-room R reset prompt")
	var defeated_summon_ref: WeakRef = weakref(defeated_summon)
	await process_frame
	var defeated_summon_after: Variant = defeated_summon_ref.get_ref()
	_expect(defeated_summon_after == null or (defeated_summon_after as Node).is_queued_for_deletion(), "defeated Boss summon schedules formal cleanup")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# 16. The formal RunFlowCoordinator receives the Boss summon signal and
#     incrementally binds damage numbers plus element-attachment VFX.
# ---------------------------------------------------------------------------
func _test_run_coordinator_binds_summon_feedback() -> void:
	var game := RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	root.add_child(game)
	current_scene = game
	var boot_frames := 0
	while (game.active_room == null or not game.vfx.configured) and boot_frames < 300:
		await process_frame
		boot_frames += 1
	_expect(game.active_room != null and game.vfx.configured, "formal RunGame boots before the summon binding probe")
	if game.active_room == null or not game.vfx.configured:
		game.queue_free()
		await process_frame
		return
	for enemy: CombatEnemy in game.active_enemies:
		enemy.ai_enabled = false

	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	boss.starting_form_id = &"tide"
	boss.ai_enabled = false
	game.add_child(boss)
	boss.player = game.player
	for i in 3:
		await physics_frame
	var boss_targets: Array[CombatEnemy] = [boss]
	game.call(&"_bind_persistent_feedback", boss_targets)
	var water_loops_before := game.vfx.unending_loop_count
	boss._resolve_summon(boss.tide_form)
	await process_frame

	var sentry: TidalSentry
	for child: Node in game.get_children():
		if child is TidalSentry:
			sentry = child as TidalSentry
			break
	_expect(sentry != null, "formal coordinator observes a real Boss-created TidalSentry")
	if sentry != null:
		_expect_eq(sentry.damage_receiver.maximum_health, 25, "formal Boss summon has 25 maximum health")
		var feedback_before := game.feedback.get_child_count()
		var hit := _hit(sentry, ElementIds.WATER, 2, 5.0)
		await process_frame
		_expect(hit.accepted, "formal Boss summon accepts elemental damage")
		_expect(game.vfx.unending_loop_count == water_loops_before + 1, "formal coordinator shows the summon water attachment VFX")
		_expect(game.feedback.get_child_count() > feedback_before, "formal coordinator shows the summon damage number")
		var lethal := _hit(sentry, ElementIds.NONE, 0, 99999.0)
		_expect(lethal.accepted and not sentry.prompt.visible, "formal summon defeat suppresses the R reset prompt")
	game.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 17. Death flow: death_candidate reaches defeated state; the formal spawn
#     definition backing the real Boss room awards zero dream dust.
# ---------------------------------------------------------------------------
func _test_death_flow_zero_dream_dust() -> void:
	var ctx := await _make_boss(&"ember")
	var boss: BossTideEmber = ctx[&"boss"]
	var defeated_signaled := {&"fired": false}
	boss.enemy_defeated.connect(func() -> void: defeated_signaled[&"fired"] = true)
	_hit(boss, ElementIds.WATER, 10, 99999.0)
	_expect(boss.defeated, "lethal hit sets defeated")
	_expect(defeated_signaled[&"fired"], "enemy_defeated signal fires")
	_expect(not boss.combat_receiver.accepting_hits, "combat_receiver stops accepting hits once defeated")
	await _destroy(ctx)

	for spawn: EnemySpawnDefinition in BOSS_ROOM.enemy_spawns:
		_expect_eq(spawn.dream_dust_reward, 0, "the formal Boss spawn definition awards zero dream dust")
		_expect_eq(spawn.validation_error(true), &"", "the formal Boss spawn definition passes terminal-room validation")


# ---------------------------------------------------------------------------
# 18. DamageResolver: every validation branch for the new mitigation_factor
#     parameter, plus the pre-existing branches remain intact.
# ---------------------------------------------------------------------------
func _test_damage_resolver_validation_branches() -> void:
	var ok := DamageResolver.resolve(10.0, 1.0, 3.0, 0.25)
	_expect(ok.is_valid(), "a valid mitigation_factor resolves cleanly")
	_expect_eq(ok.final_damage, 2, "sanity: same worked example as §3.6")

	var default_ok := DamageResolver.resolve(10.0, 1.0, 3.0)
	_expect(default_ok.is_valid(), "mitigation_factor defaults to 1.0 (no-op) when omitted")
	_expect_eq(default_ok.final_damage, 7, "default (unmitigated) path is unchanged: 10-3=7")

	var zero := DamageResolver.resolve(10.0, 1.0, 3.0, 0.0)
	_expect_eq(zero.validation_error, &"invalid_mitigation_factor", "zero mitigation_factor is rejected")

	var negative := DamageResolver.resolve(10.0, 1.0, 3.0, -0.1)
	_expect_eq(negative.validation_error, &"invalid_mitigation_factor", "negative mitigation_factor is rejected")

	var above_one := DamageResolver.resolve(10.0, 1.0, 3.0, 1.5)
	_expect_eq(above_one.validation_error, &"invalid_mitigation_factor", "mitigation_factor above 1.0 is rejected")

	var nan_factor := DamageResolver.resolve(10.0, 1.0, 3.0, NAN)
	_expect_eq(nan_factor.validation_error, &"invalid_mitigation_factor", "NaN mitigation_factor is rejected")

	var boundary := DamageResolver.resolve(10.0, 1.0, 3.0, 1.0)
	_expect(boundary.is_valid(), "mitigation_factor == 1.0 is the valid upper boundary")

	# Pre-existing branches remain intact.
	_expect_eq(DamageResolver.resolve(-1.0, 1.0, 3.0).validation_error, &"invalid_offensive_damage", "existing offensive_damage branch intact")
	_expect_eq(DamageResolver.resolve(10.0, 0.5, 3.0).validation_error, &"invalid_reaction_multiplier", "existing reaction_multiplier branch intact")
	_expect_eq(DamageResolver.resolve(10.0, 1.0, -1.0).validation_error, &"invalid_defense", "existing defense branch intact")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _make_boss(form_id: StringName, ai_enabled: bool = false) -> Dictionary:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	boss.starting_form_id = form_id
	world.add_child(boss)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = boss.global_position + Vector2(-300.0, 0.0)
	world.add_child(player)
	boss.player = player
	boss.ai_enabled = ai_enabled
	# Initial element layers are applied on the Boss's first physics tick
	# (not _ready()) so they survive RunFlowCoordinator's real staging ->
	# active reparenting, which fires ElementCarrier._exit_tree() and would
	# otherwise silently wipe layers set any earlier. Await one frame here so
	# every test fixture observes the same post-first-tick state a real
	# room's Boss would have.
	for i in 3:
		await physics_frame
	return {&"world": world, &"boss": boss, &"player": player}


## Drives a pending Task 71 summon telegraph to the frame the summons are
## actually instantiated. The Boss advances that window from its own
## _physics_process, which is gated on ai_enabled, so ai is toggled on just
## for the pump; while attack_time is running the Boss's physics takes the
## early-return branch and cannot start any other action, so this does not
## introduce AI-dependent behaviour into the fixture.
func _resolve_summon_window(boss: BossTideEmber) -> void:
	var previous_ai := boss.ai_enabled
	boss.ai_enabled = true
	var guard := 0
	while boss._summon_pending_form != null and guard < 240:
		await physics_frame
		guard += 1
	boss.ai_enabled = previous_ai


func _destroy(ctx: Dictionary) -> void:
	(ctx[&"world"] as Node).queue_free()
	await process_frame


func _hit(enemy: CombatEnemy, element_id: StringName, amount: int, offensive: float = 10.0) -> CombatResult:
	var cast := CastSnapshot.new(_next_hit_id(), &"task61_probe", 1, 1, &"player", ElementIds.NONE, CombatStatSnapshot.new())
	var payload := RuntimeAttackPayload.new(offensive, offensive, element_id, amount)
	return enemy.combat_receiver.receive_hit(HitRequest.new(cast, payload, _next_hit_id(), 0, enemy.global_position, Vector2.RIGHT))


func _hit_n(boss: BossTideEmber, element_id: StringName, amount: int, count: int) -> void:
	for i in count:
		_hit(boss, element_id, amount)


## Test-only shortcut for state-machine tests that fire batches of hits with
## no physics frames in between: ends the still-running form-transition
## invulnerability window immediately so the next batch of counter hits is
## not silently rejected (mirrors what a few real seconds of gameplay would
## do; §3.7's transition duration itself is covered by
## _test_form_transition_presentation).
func _clear_transition(boss: BossTideEmber) -> void:
	boss.combat_receiver.invulnerable = false
	boss._transition_invulnerable_time = 0.0


func _connect_order_tracking(receiver: CombatReceiver, order: Array[String]) -> void:
	receiver.hit_resolved.connect(func(_r: CombatResult) -> void: order.append("hit_resolved"))
	receiver.reaction_triggered.connect(func(_r: CombatResult) -> void: order.append("reaction_triggered"))
	receiver.element_state_changed.connect(func(_r: CombatResult) -> void: order.append("element_state_changed"))
	receiver.health_state_changed.connect(func(_c: int, _m: int, _d: int, _r: CombatResult) -> void: order.append("health_state_changed"))
	receiver.death_candidate.connect(func(_r: CombatResult) -> void: order.append("death_candidate"))
	receiver.presentation_requested.connect(func(_r: CombatResult) -> void: order.append("presentation_requested"))


func _count_projectiles() -> int:
	var count := 0
	for node: Node in get_nodes_in_group(&"__unused__"):
		count += 1
	for child: Node in root.get_children():
		count += _count_projectiles_under(child)
	return count


func _count_projectiles_under(node: Node) -> int:
	var count := 0
	if node is ProjectileDelivery:
		count += 1
	for child: Node in node.get_children():
		count += _count_projectiles_under(child)
	return count


func _next_hit_id() -> int:
	_hit_seq += 1
	return _hit_seq


func _run_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _finish() -> void:
	quit(_harness.report("TASK 61 BOSS THREE FORM TESTS"))
