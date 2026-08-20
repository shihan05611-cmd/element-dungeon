extends SceneTree

## Task 69: Boss attack timing alignment + ranged stand-off distance.
## Covers every assertion listed in
## docs/agent_tasks/pending/69_boss_combat_timing_and_ranged_standoff.md §5.1.

const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BOSS_FRAMES: SpriteFrames = preload("res://resources/animations/boss_tide_ember_frames.tres")
const EMBER_FORM: BossFormDefinition = preload("res://resources/run/enemies/boss_forms/boss_form_ember.tres")
const TIDE_FORM: BossFormDefinition = preload("res://resources/run/enemies/boss_forms/boss_form_tide.tres")
const PLAIN_FORM: BossFormDefinition = preload("res://resources/run/enemies/boss_forms/boss_form_plain.tres")
const BOSS_TUNING: BossTuning = preload("res://resources/run/enemies/boss_forms/boss_tuning.tres")
const TestHarness := preload("res://combat/tests/test_harness.gd")

const FORM_PATHS := {
	&"ember": "res://resources/run/enemies/boss_forms/boss_form_ember.tres",
	&"tide": "res://resources/run/enemies/boss_forms/boss_form_tide.tres",
	&"plain": "res://resources/run/enemies/boss_forms/boss_form_plain.tres",
}
const TUNING_PATH := "res://resources/run/enemies/boss_forms/boss_tuning.tres"
const FRAMES_PATH := "res://resources/animations/boss_tide_ember_frames.tres"

## Task 68 manifest_v2.md §2/§4: frame counts of the v2 sheets that this task
## wires in. Frozen here so a regression back to the single-frame v1 assets
## (or any silent re-cut) fails loudly instead of quietly killing the timing.
const EXPECTED_FRAME_COUNTS := {
	&"plain_idle": 6,
	&"plain_walk": 8,
	&"plain_attack": 8,
	&"ember_idle": 6,
	&"ember_walk": 8,
	&"ember_attack": 8,
	&"tide_idle": 6,
	&"tide_walk": 8,
	&"tide_attack": 8,
	&"hurt": 4,
	&"death": 4,
}
const FRAME_CELL := 200

var _harness := TestHarness.new()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_test("new_field_validation_branches", _test_new_field_validation_branches)
	await _run_test("form_resources_declare_new_fields", _test_form_resources_declare_new_fields)
	await _run_test("close_range_blocks_new_ranged_telegraph", _test_close_range_blocks_new_ranged_telegraph)
	await _run_test("active_telegraph_survives_point_blank", _test_active_telegraph_survives_point_blank)
	await _run_test("ranged_cooldown_drains_while_gated", _test_ranged_cooldown_drains_while_gated)
	await _run_test("close_range_melee_cooldown_scale", _test_close_range_melee_cooldown_scale)
	await _run_test("animation_frame_counts_match_manifest", _test_animation_frame_counts_match_manifest)
	await _run_test("attack_windup_aligns_with_telegraph_and_delivery", _test_attack_windup_aligns_with_telegraph_and_delivery)
	_finish()


# ---------------------------------------------------------------------------
# §5.1.1 validation_error() positive/negative coverage for the new fields.
# ---------------------------------------------------------------------------
func _test_new_field_validation_branches() -> void:
	var form := BossFormDefinition.new()
	form.form_id = &"probe"
	form.element_id = ElementIds.FIRE
	form.countered_by = ElementIds.WATER
	_expect_eq(form.validation_error(), &"", "a fresh definition with default new fields is valid")
	_expect_eq(form.ranged_minimum_distance, 130.0, "ranged_minimum_distance defaults to 130.0")
	_expect_eq(form.melee_cooldown_close_range_scale, 0.6, "melee_cooldown_close_range_scale defaults to 0.6")

	form.ranged_minimum_distance = 0.0
	_expect_eq(form.validation_error(), &"", "zero ranged_minimum_distance is the valid lower boundary (gate disabled)")
	form.ranged_minimum_distance = -1.0
	_expect_eq(form.validation_error(), &"invalid_ranged_minimum_distance", "negative ranged_minimum_distance is rejected")
	form.ranged_minimum_distance = NAN
	_expect_eq(form.validation_error(), &"invalid_ranged_minimum_distance", "NaN ranged_minimum_distance is rejected")
	form.ranged_minimum_distance = INF
	_expect_eq(form.validation_error(), &"invalid_ranged_minimum_distance", "infinite ranged_minimum_distance is rejected")
	form.ranged_minimum_distance = 130.0

	form.melee_cooldown_close_range_scale = 1.0
	_expect_eq(form.validation_error(), &"", "scale == 1.0 is the valid upper boundary (no acceleration)")
	form.melee_cooldown_close_range_scale = 0.0
	_expect_eq(form.validation_error(), &"invalid_melee_cooldown_close_range_scale", "zero scale is rejected (would divide by zero)")
	form.melee_cooldown_close_range_scale = -0.5
	_expect_eq(form.validation_error(), &"invalid_melee_cooldown_close_range_scale", "negative scale is rejected")
	form.melee_cooldown_close_range_scale = 1.5
	_expect_eq(form.validation_error(), &"invalid_melee_cooldown_close_range_scale", "scale above 1.0 is rejected (would slow melee recovery down)")
	form.melee_cooldown_close_range_scale = NAN
	_expect_eq(form.validation_error(), &"invalid_melee_cooldown_close_range_scale", "NaN scale is rejected")
	form.melee_cooldown_close_range_scale = 0.6
	_expect_eq(form.validation_error(), &"", "restoring both fields returns the definition to valid")

	var tuning := BossTuning.new()
	_expect_eq(tuning.validation_error(), &"", "a fresh BossTuning with the default impact index is valid")
	_expect_eq(tuning.melee_attack_impact_frame_index, 4, "melee_attack_impact_frame_index defaults to the manifest's frame 4")
	tuning.melee_attack_impact_frame_index = 0
	_expect_eq(tuning.validation_error(), &"", "index 0 is the valid lower boundary")
	tuning.melee_attack_impact_frame_index = -1
	_expect_eq(tuning.validation_error(), &"invalid_melee_attack_impact_frame_index", "negative impact frame index is rejected")
	tuning.melee_attack_impact_frame_index = 4
	_expect_eq(tuning.validation_error(), &"", "restoring the index returns the tuning to valid")


# ---------------------------------------------------------------------------
# §5.1.2 all three form .tres files explicitly declare the new fields and
# still validate once loaded; boss_tuning.tres declares the impact index.
# ---------------------------------------------------------------------------
func _test_form_resources_declare_new_fields() -> void:
	var forms := {&"ember": EMBER_FORM, &"tide": TIDE_FORM, &"plain": PLAIN_FORM}
	for form_id: StringName in FORM_PATHS:
		var text := FileAccess.get_file_as_string(FORM_PATHS[form_id])
		_expect(text.contains("ranged_minimum_distance = "), "%s.tres explicitly writes ranged_minimum_distance" % form_id)
		_expect(text.contains("melee_cooldown_close_range_scale = "), "%s.tres explicitly writes melee_cooldown_close_range_scale" % form_id)
		var form: BossFormDefinition = forms[form_id]
		_expect_eq(form.validation_error(), &"", "%s form passes validation after loading" % form_id)
		_expect_eq(form.ranged_minimum_distance, 130.0, "%s form's stand-off distance is 130px" % form_id)
		_expect_eq(form.melee_cooldown_close_range_scale, 0.6, "%s form's close-range melee cooldown scale is 0.6" % form_id)
		# §2.3's rationale: the ring has to sit above the player's 78px basic
		# attack reach and above the Boss's own 100px melee hitbox.
		_expect(form.ranged_minimum_distance > 78.0, "%s form's stand-off ring is wider than the player's 78px basic attack reach" % form_id)
		_expect(form.ranged_minimum_distance > 100.0, "%s form's stand-off ring is wider than the Boss's 100px melee hitbox" % form_id)
		_expect(form.ranged_minimum_distance > form.melee_range, "%s form's stand-off ring is wider than its own melee trigger range" % form_id)
	var tuning_text := FileAccess.get_file_as_string(TUNING_PATH)
	_expect(tuning_text.contains("melee_attack_impact_frame_index = "), "boss_tuning.tres explicitly writes melee_attack_impact_frame_index")
	_expect_eq(BOSS_TUNING.validation_error(), &"", "boss_tuning.tres passes validation after loading")
	_expect_eq(BOSS_TUNING.melee_attack_impact_frame_index, 4, "boss_tuning.tres declares the manifest's impact frame index 4")


# ---------------------------------------------------------------------------
# §5.1.3 inside the ring with no telegraph running, no projectile is ever
# created no matter how long the Boss is left to think about it.
# ---------------------------------------------------------------------------
func _test_close_range_blocks_new_ranged_telegraph() -> void:
	var ctx := await _make_boss(&"tide", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var distance := boss.current_form.ranged_minimum_distance - 20.0
	_expect(distance > boss.current_form.melee_range, "probe distance stays outside melee range so only the ranged gate is under test")
	# Counted off the Boss's own delivery_created signal rather than by walking
	# the tree: a point-blank bolt can hit and free itself inside the same
	# frame it spawns, and the tide form's summons bring their own projectiles.
	var spawned := _track_projectile_spawns(boss)
	boss._boss_projectile_cooldown = 0.0
	await _hold_distance(ctx, distance, 90)
	_expect(not boss._telegraph_active, "no ranged telegraph is ever opened inside the stand-off ring")
	_expect_eq(boss._boss_projectile_cooldown, 0.0, "the ranged cooldown was ready the whole time -- only the distance gate held fire")
	_expect_eq(boss.boss_projectiles_fired, 0, "the Boss never launched a ranged volley during 90 physics frames inside the ring")
	_expect_eq(spawned.size(), 0, "zero Boss-owned projectiles were created inside the ring")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# §5.1.4 a telegraph that was legally opened outside the ring always fires,
# even if the player closes to point-blank mid-windup (no free cancel).
# ---------------------------------------------------------------------------
func _test_active_telegraph_survives_point_blank() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var form := boss.current_form
	boss._boss_projectile_cooldown = 0.0
	var opened := await _hold_distance_until(ctx, form.ranged_minimum_distance + 300.0, 30,
		func() -> bool: return boss._telegraph_active)
	_expect(opened, "a ranged telegraph opens normally outside the stand-off ring")
	var spawned := _track_projectile_spawns(boss)
	var fired_before := boss.boss_projectiles_fired
	# Rush in: from here on the player sits well inside the ring.
	var closed := await _hold_distance_until(ctx, 40.0, 120,
		func() -> bool: return boss.boss_projectiles_fired > fired_before)
	_expect(closed, "the already-active telegraph still fires after the player closes to point-blank")
	_expect(not boss._telegraph_active, "the telegraph resolved by firing rather than by being cancelled")
	_expect_eq(spawned.size(), form.ranged_projectile_profile.spread_count,
		"the interrupted-looking shot still launches its full spread_count")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# §5.1.5 the ranged cooldown keeps draining while the gate suppresses firing,
# so retreating out of the ring is punished on the very next frames.
# ---------------------------------------------------------------------------
func _test_ranged_cooldown_drains_while_gated() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var form := boss.current_form
	boss._boss_projectile_cooldown = 0.5
	var before := _count_projectiles()
	await _hold_distance(ctx, form.ranged_minimum_distance - 20.0, 60)
	_expect_eq(boss._boss_projectile_cooldown, 0.0, "the ranged cooldown still reached zero while fire was gated")
	_expect(not boss._telegraph_active, "a drained cooldown alone never opens a telegraph inside the ring")
	_expect_eq(_count_projectiles() - before, 0, "still nothing fired while inside the ring")
	var opened := await _hold_distance_until(ctx, form.ranged_minimum_distance + 300.0, 4,
		func() -> bool: return boss._telegraph_active)
	_expect(opened, "stepping back out of the ring opens a telegraph within 4 physics frames (no re-arm penalty)")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# §5.1.6 melee cooldown drains at delta / melee_cooldown_close_range_scale
# inside the ring, and at plain delta outside it.
# ---------------------------------------------------------------------------
func _test_close_range_melee_cooldown_scale() -> void:
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var form := boss.current_form
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var frames := 30
	var tolerance := step * 1.5

	boss._boss_projectile_cooldown = 999.0
	boss.attack_cooldown = 10.0
	var start_close := boss.attack_cooldown
	await _hold_distance(ctx, form.ranged_minimum_distance - 20.0, frames)
	var close_drop := start_close - boss.attack_cooldown
	_expect_near(close_drop, float(frames) * step / form.melee_cooldown_close_range_scale, tolerance / form.melee_cooldown_close_range_scale,
		"inside the ring the melee cooldown drains at delta / melee_cooldown_close_range_scale")

	boss._boss_projectile_cooldown = 999.0
	boss.attack_cooldown = 10.0
	var start_far := boss.attack_cooldown
	await _hold_distance(ctx, form.ranged_minimum_distance + 300.0, frames)
	var far_drop := start_far - boss.attack_cooldown
	_expect_near(far_drop, float(frames) * step, tolerance,
		"outside the ring the melee cooldown drains at the plain delta rate")
	_expect(close_drop > far_drop, "close range genuinely recovers the melee faster than long range")
	# The whole point of §2.4: the ember form's 2.4s cooldown must land near
	# 1.44s at point-blank, not stay a 2.4s dead window.
	_expect_near(form.attack_cooldown * form.melee_cooldown_close_range_scale, 1.44, 0.001,
		"the ember form's effective point-blank melee cooldown is ~1.44s")
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# §5.1.7 the wired SpriteFrames matches the Task 68 manifest, and every one
# of the 11 animations is genuinely multi-frame.
# ---------------------------------------------------------------------------
func _test_animation_frame_counts_match_manifest() -> void:
	var names := BOSS_FRAMES.get_animation_names()
	_expect_eq(names.size(), EXPECTED_FRAME_COUNTS.size(), "the Boss SpriteFrames still declares exactly 11 animations")
	var frames_text := FileAccess.get_file_as_string(FRAMES_PATH)
	_expect(not frames_text.contains("_v1.png"), "no v1 single-frame sheet is referenced any more")
	for animation_name: StringName in EXPECTED_FRAME_COUNTS:
		_expect(BOSS_FRAMES.has_animation(animation_name), "animation %s exists" % animation_name)
		if not BOSS_FRAMES.has_animation(animation_name):
			continue
		var count := BOSS_FRAMES.get_frame_count(animation_name)
		_expect(count > 1, "animation %s is multi-frame (regression guard against the v1 single-frame assets)" % animation_name)
		_expect_eq(count, EXPECTED_FRAME_COUNTS[animation_name], "animation %s frame count matches manifest_v2.md" % animation_name)
		for index: int in count:
			var texture := BOSS_FRAMES.get_frame_texture(animation_name, index) as AtlasTexture
			_expect(texture != null, "animation %s frame %d is an AtlasTexture slice" % [animation_name, index])
			if texture == null:
				continue
			_expect_eq(texture.region, Rect2(index * FRAME_CELL, 0, FRAME_CELL, FRAME_CELL),
				"animation %s frame %d slices the 200x200 cell at the manifest's horizontal offset" % [animation_name, index])
		var loops := BOSS_FRAMES.get_animation_loop(animation_name)
		var should_loop := String(animation_name).ends_with("idle") or String(animation_name).ends_with("walk")
		_expect_eq(loops, should_loop, "animation %s keeps its original loop flag" % animation_name)


# ---------------------------------------------------------------------------
# §5.1.8 the attack clip's windup segment equals melee_telegraph_duration for
# every form, and the impact frame lands on the frame the DelayedAreaDelivery
# leaves WAITING.
# ---------------------------------------------------------------------------
func _test_attack_windup_aligns_with_telegraph_and_delivery() -> void:
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	for form_id: StringName in [&"ember", &"tide", &"plain"]:
		var ctx := await _make_boss(form_id, false)
		var boss: BossTideEmber = ctx[&"boss"]
		var form := boss.current_form
		var windup := boss.attack_windup_duration()
		var recovery := boss.attack_recovery_duration()
		_expect_near(windup, form.melee_telegraph_duration, step,
			"%s: attack animation windup segment equals melee_telegraph_duration" % form_id)
		_expect_near(recovery, BossTideEmber.MELEE_ACTIVE_DURATION + BossTideEmber.MELEE_RECOVERY_DURATION, step,
			"%s: attack animation impact+recovery segment equals MELEE_ACTIVE + MELEE_RECOVERY" % form_id)
		_expect_near(windup + recovery,
			maxf(form.melee_telegraph_duration, 0.05) + BossTideEmber.MELEE_ACTIVE_DURATION + BossTideEmber.MELEE_RECOVERY_DURATION,
			step, "%s: the whole attack clip is exactly as long as attack_time" % form_id)
		await _destroy(ctx)

	# Live alignment on the ember form: drive one real melee swing and check
	# where the sprite is when the hitbox actually goes live.
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	var form := boss.current_form
	player.global_position = boss.global_position + Vector2(50.0, 0.0)
	boss.attack_cooldown = 0.0
	var delivery: DelayedAreaDelivery = null
	for i in 8:
		await physics_frame
		delivery = _latest_delivery(boss)
		if delivery != null:
			break
	_expect(delivery != null, "the melee swing spawned a DelayedAreaDelivery")
	if delivery == null:
		await _destroy(ctx)
		return
	_expect_eq(delivery.trigger_delay, form.melee_telegraph_duration,
		"the delivery's WAITING window is driven by melee_telegraph_duration (telegraph/damage alignment untouched)")
	_expect_eq(sprite_animation_of(boss), boss._animation_name(&"attack"), "the attack clip is what plays during the telegraph")
	_expect(boss.sprite.frame < BOSS_TUNING.melee_attack_impact_frame_index,
		"the sprite is still inside the windup segment while the delivery is WAITING")
	var elapsed := 0.0
	var guard := 0
	while is_instance_valid(delivery) and delivery.delayed_phase == DelayedAreaDelivery.Phase.WAITING and guard < 240:
		await physics_frame
		elapsed += step
		guard += 1
	_expect(is_instance_valid(delivery) and delivery.delayed_phase == DelayedAreaDelivery.Phase.ACTIVE,
		"the delivery reached its ACTIVE (damage) phase")
	_expect_near(elapsed, boss.attack_windup_duration(), step * 2.0,
		"the hitbox goes live exactly one animation-windup after the swing starts")
	var impact_index: int = BOSS_TUNING.melee_attack_impact_frame_index
	_expect(absi(boss.sprite.frame - impact_index) <= 1,
		"the sprite is on the impact frame (%d, +/- one frame) at the instant damage goes live, got %d" % [impact_index, boss.sprite.frame])
	await _destroy(ctx)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func sprite_animation_of(boss: BossTideEmber) -> StringName:
	return boss.sprite.animation


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
	# Mirrors run_task61_*: initial element layers land on the Boss's first
	# real physics tick, so every fixture observes the same post-first-tick
	# state a live room's Boss would have.
	for i in 3:
		await physics_frame
	return {&"world": world, &"boss": boss, &"player": player}


func _destroy(ctx: Dictionary) -> void:
	(ctx[&"world"] as Node).queue_free()
	await process_frame


## Pins the player at an exact horizontal offset (and identical height) for a
## fixed number of physics frames. Without pinning, the Boss's own chase would
## silently walk the distance under test across the gate boundary.
func _hold_distance(ctx: Dictionary, distance: float, frames: int) -> void:
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	for i in frames:
		player.global_position = boss.global_position + Vector2(distance, 0.0)
		await physics_frame


## Same pinning, but stops as soon as `predicate` becomes true. Returns whether
## it did within the frame budget.
func _hold_distance_until(ctx: Dictionary, distance: float, max_frames: int, predicate: Callable) -> bool:
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	for i in max_frames:
		player.global_position = boss.global_position + Vector2(distance, 0.0)
		await physics_frame
		if predicate.call():
			return true
	return false


func _latest_delivery(boss: BossTideEmber) -> DelayedAreaDelivery:
	var found: DelayedAreaDelivery = null
	for reference: WeakRef in boss._active_deliveries:
		var node: Variant = reference.get_ref()
		if node is DelayedAreaDelivery and is_instance_valid(node):
			found = node
	return found


## Records every ProjectileDelivery this Boss creates, via its own
## delivery_created signal. Immune both to projectiles that free themselves
## the same frame they spawn (point-blank hits) and to shots fired by summons.
func _track_projectile_spawns(boss: BossTideEmber) -> Array[Node]:
	var spawned: Array[Node] = []
	boss.delivery_created.connect(func(delivery: Node) -> void:
		if delivery is ProjectileDelivery:
			spawned.append(delivery)
	)
	return spawned


func _count_projectiles() -> int:
	var count := 0
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


func _run_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _expect_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	_harness.expect_near(actual, expected, tolerance, description)


func _finish() -> void:
	quit(_harness.report("TASK 69 BOSS TIMING AND STANDOFF TESTS"))
