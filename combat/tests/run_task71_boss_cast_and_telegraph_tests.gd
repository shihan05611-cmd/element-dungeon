extends SceneTree

## Task 71: dedicated ranged cast action + the multi-type telegraph system.
## Covers every assertion listed in
## docs/agent_tasks/pending/71_boss_cast_wiring_and_multi_telegraph.md §5.1.

const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SENTRY_SCENE: PackedScene = preload("res://scenes/run/enemies/tidal_sentry.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const INDICATOR_SCENE: PackedScene = preload("res://scenes/combat/enemy_telegraph_indicator.tscn")
const MELEE_DELIVERY_SCENE: PackedScene = preload("res://scenes/run/boss_melee_delivery.tscn")
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

## Task 70 manifest_v2.md §9.4/§9.5: the cast sheets are 8 frames of 200x200,
## launch frame index 5 (0-based), identical for all three forms.
const CAST_FRAME_COUNT := 8
const CAST_LAUNCH_FRAME_INDEX := 5
const FRAME_CELL := 200

## The type -> icon sheet mapping Task 70 delivered. Kept here so a silent
## re-point of the SpriteFrames at the wrong sheet fails loudly.
const EXPECTED_ICON_SHEETS := {
	EnemyTelegraphIndicator.TelegraphType.RANGED: "telegraph_alert_v1.png",
	EnemyTelegraphIndicator.TelegraphType.MELEE: "telegraph_melee_v1.png",
	EnemyTelegraphIndicator.TelegraphType.SUMMON: "telegraph_summon_v1.png",
}
const EXPECTED_STATIC_SHEETS := {
	EnemyTelegraphIndicator.TelegraphType.RANGED: "telegraph_alert_static_v1.png",
	EnemyTelegraphIndicator.TelegraphType.MELEE: "telegraph_melee_static_v1.png",
	EnemyTelegraphIndicator.TelegraphType.SUMMON: "telegraph_summon_static_v1.png",
}

var _harness := TestHarness.new()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _run_test("new_field_validation_branches", _test_new_field_validation_branches)
	await _run_test("cast_animations_match_manifest", _test_cast_animations_match_manifest)
	await _run_test("ranged_windup_uses_cast_clip", _test_ranged_windup_uses_cast_clip)
	await _run_test("projectile_spawns_on_launch_frame", _test_projectile_spawns_on_launch_frame)
	await _run_test("telegraph_type_default_and_variants", _test_telegraph_type_default_and_variants)
	await _run_test("melee_range_box_matches_delivery", _test_melee_range_box_matches_delivery)
	await _run_test("summon_telegraph_window_and_interrupt", _test_summon_telegraph_window_and_interrupt)
	await _run_test("reduced_motion_uses_static_icon", _test_reduced_motion_uses_static_icon)
	_finish()


# ---------------------------------------------------------------------------
# §5.1.1 validation_error() positive/negative coverage for the two new
# configuration fields, plus the three form .tres files declaring them.
# ---------------------------------------------------------------------------
func _test_new_field_validation_branches() -> void:
	var tuning := BossTuning.new()
	_expect_eq(tuning.validation_error(), &"", "a fresh BossTuning with the default launch index is valid")
	_expect_eq(tuning.ranged_cast_launch_frame_index, CAST_LAUNCH_FRAME_INDEX,
		"ranged_cast_launch_frame_index defaults to the Task 70 manifest's frame 5")
	tuning.ranged_cast_launch_frame_index = 0
	_expect_eq(tuning.validation_error(), &"", "index 0 is the valid lower boundary")
	tuning.ranged_cast_launch_frame_index = -1
	_expect_eq(tuning.validation_error(), &"invalid_ranged_cast_launch_frame_index",
		"a negative launch frame index is rejected")
	tuning.ranged_cast_launch_frame_index = CAST_LAUNCH_FRAME_INDEX
	_expect_eq(tuning.validation_error(), &"", "restoring the index returns the tuning to valid")
	# The melee index must keep validating independently -- Task 69's field.
	tuning.melee_attack_impact_frame_index = -1
	_expect_eq(tuning.validation_error(), &"invalid_melee_attack_impact_frame_index",
		"the Task 69 impact index still has its own branch (the new check did not shadow it)")

	var form := BossFormDefinition.new()
	form.form_id = &"probe"
	form.element_id = ElementIds.FIRE
	form.countered_by = ElementIds.WATER
	_expect_eq(form.validation_error(), &"", "a fresh definition with the default summon telegraph is valid")
	_expect_eq(form.summon_telegraph_duration, 0.9, "summon_telegraph_duration defaults to 0.9")
	_expect(form.summon_telegraph_duration > form.melee_telegraph_duration,
		"the summon window is longer than the melee one (§2 C5: time to actually react)")
	form.summon_telegraph_duration = 0.0
	_expect_eq(form.validation_error(), &"",
		"zero is the valid lower boundary (opts a form out of the telegraph)")
	form.summon_telegraph_duration = -0.1
	_expect_eq(form.validation_error(), &"invalid_summon_telegraph_duration", "a negative window is rejected")
	form.summon_telegraph_duration = NAN
	_expect_eq(form.validation_error(), &"invalid_summon_telegraph_duration", "NaN is rejected")
	form.summon_telegraph_duration = INF
	_expect_eq(form.validation_error(), &"invalid_summon_telegraph_duration", "an infinite window is rejected")
	form.summon_telegraph_duration = 0.9
	_expect_eq(form.validation_error(), &"", "restoring the window returns the definition to valid")

	var tuning_text := FileAccess.get_file_as_string(TUNING_PATH)
	_expect(tuning_text.contains("ranged_cast_launch_frame_index = "),
		"boss_tuning.tres explicitly writes ranged_cast_launch_frame_index")
	_expect_eq(BOSS_TUNING.validation_error(), &"", "boss_tuning.tres passes validation after loading")
	_expect_eq(BOSS_TUNING.ranged_cast_launch_frame_index, CAST_LAUNCH_FRAME_INDEX,
		"boss_tuning.tres declares the manifest's launch frame index 5")

	var forms := {&"ember": EMBER_FORM, &"tide": TIDE_FORM, &"plain": PLAIN_FORM}
	for form_id: StringName in FORM_PATHS:
		var text := FileAccess.get_file_as_string(FORM_PATHS[form_id])
		_expect(text.contains("summon_telegraph_duration = "),
			"%s.tres explicitly writes summon_telegraph_duration" % form_id)
		var loaded: BossFormDefinition = forms[form_id]
		_expect_eq(loaded.validation_error(), &"", "%s form passes validation after loading" % form_id)
		_expect_eq(loaded.summon_telegraph_duration, 0.9, "%s form declares the 0.9s summon window" % form_id)


# ---------------------------------------------------------------------------
# §5.1.2 the three {form}_cast animations exist, match the Task 70 manifest
# frame count, slice 200x200 cells at the right offsets, and never loop.
# ---------------------------------------------------------------------------
func _test_cast_animations_match_manifest() -> void:
	var frames_text := FileAccess.get_file_as_string(FRAMES_PATH)
	for form_id: StringName in [&"plain", &"ember", &"tide"]:
		var animation_name := StringName("%s_cast" % form_id)
		_expect(BOSS_FRAMES.has_animation(animation_name), "animation %s exists" % animation_name)
		if not BOSS_FRAMES.has_animation(animation_name):
			continue
		_expect_eq(BOSS_FRAMES.get_frame_count(animation_name), CAST_FRAME_COUNT,
			"%s frame count matches Task 70 manifest_v2.md §9.4" % animation_name)
		_expect_eq(BOSS_FRAMES.get_animation_loop(animation_name), false,
			"%s is a non-looping clip" % animation_name)
		_expect(frames_text.contains("boss_%s_cast_v1.png" % form_id),
			"the SpriteFrames references the delivered boss_%s_cast_v1.png sheet" % form_id)
		for index: int in CAST_FRAME_COUNT:
			var texture := BOSS_FRAMES.get_frame_texture(animation_name, index) as AtlasTexture
			_expect(texture != null, "%s frame %d is an AtlasTexture slice" % [animation_name, index])
			if texture == null:
				continue
			_expect_eq(texture.region, Rect2(index * FRAME_CELL, 0, FRAME_CELL, FRAME_CELL),
				"%s frame %d slices the 200x200 cell at the right horizontal offset" % [animation_name, index])
	# The launch index must actually be inside the clip, otherwise every
	# derived duration silently collapses.
	_expect(BOSS_TUNING.ranged_cast_launch_frame_index < CAST_FRAME_COUNT,
		"the configured launch frame index lies inside the cast clip")

	# §2 C1's unification: one authored windup length, three profiles agreeing
	# with it, so nothing has to be time-stretched any more.
	for form_id: StringName in [&"ember", &"tide", &"plain"]:
		var ctx := await _make_boss(form_id, false)
		var boss: BossTideEmber = ctx[&"boss"]
		var profile := boss.current_form.ranged_projectile_profile
		_expect_near(boss.cast_windup_duration(), profile.telegraph_duration, 0.001,
			"%s: the cast clip's windup segment equals the bolt profile's telegraph_duration" % form_id)
		_expect(boss.cast_recovery_duration() > 0.0,
			"%s: the cast clip has a real post-launch recovery segment" % form_id)
		_expect_near(boss.cast_windup_duration() + boss.cast_recovery_duration(),
			_clip_total_duration(StringName("%s_cast" % form_id)), 0.001,
			"%s: windup + recovery covers the whole cast clip (no frames unaccounted for)" % form_id)
		await _destroy(ctx)
	_expect_near(EMBER_FORM.ranged_projectile_profile.telegraph_duration,
		TIDE_FORM.ranged_projectile_profile.telegraph_duration, 0.0001,
		"ember and tide now share one telegraph_duration")
	_expect_near(EMBER_FORM.ranged_projectile_profile.telegraph_duration,
		PLAIN_FORM.ranged_projectile_profile.telegraph_duration, 0.0001,
		"ember and plain now share one telegraph_duration")
	# Only telegraph_duration was allowed to move (§3): the spread/damage/speed
	# numbers this task must not touch are pinned here.
	_expect_eq(EMBER_FORM.ranged_projectile_profile.spread_count, 3, "ember spread_count untouched")
	_expect_eq(TIDE_FORM.ranged_projectile_profile.spread_count, 5, "tide spread_count untouched")
	_expect_eq(PLAIN_FORM.ranged_projectile_profile.spread_count, 1, "plain spread_count untouched")
	_expect_eq(TIDE_FORM.ranged_projectile_profile.spread_angle_degrees, 60.0, "tide spread angle untouched")
	_expect_eq(EMBER_FORM.ranged_projectile_profile.damage, 10.0, "ember bolt damage untouched")
	_expect_eq(TIDE_FORM.ranged_projectile_profile.damage, 9.0, "tide bolt damage untouched")
	_expect_eq(PLAIN_FORM.ranged_projectile_profile.speed, 280.0, "plain bolt speed untouched")


# ---------------------------------------------------------------------------
# §5.1.3 the ranged windup plays {form}_cast, never {form}_attack, and
# speed_scale is pinned at 1.0 for the entire cycle (Task 69's stretch is
# gone, not merely re-tuned).
# ---------------------------------------------------------------------------
func _test_ranged_windup_uses_cast_clip() -> void:
	for form_id: StringName in [&"ember", &"tide", &"plain"]:
		var ctx := await _make_boss(form_id, true)
		var boss: BossTideEmber = ctx[&"boss"]
		boss._boss_projectile_cooldown = 0.0
		_suppress_summons(boss)
		var opened := await _hold_distance_until(ctx, 420.0, 30, func() -> bool: return boss._telegraph_active)
		_expect(opened, "%s: a ranged telegraph opens outside the stand-off ring" % form_id)
		if not opened:
			await _destroy(ctx)
			continue
		_expect_eq(boss.sprite.animation, boss._animation_name(&"cast"),
			"%s: the windup plays the dedicated cast clip" % form_id)
		_expect(boss.sprite.animation != boss._animation_name(&"attack"),
			"%s: the windup no longer borrows the melee attack clip" % form_id)
		_expect(boss.sprite.frame < BOSS_TUNING.ranged_cast_launch_frame_index,
			"%s: the sprite is inside the cast windup segment while the telegraph runs" % form_id)
		# Sample speed_scale across the whole windup + launch + recovery.
		var max_deviation := 0.0
		var fired_before := boss.boss_projectiles_fired
		for i in 90:
			max_deviation = maxf(max_deviation, absf(boss.sprite.speed_scale - 1.0))
			if boss.boss_projectiles_fired > fired_before and boss.attack_time <= 0.0:
				break
			await _hold_frame(ctx, 420.0)
		max_deviation = maxf(max_deviation, absf(boss.sprite.speed_scale - 1.0))
		_expect(boss.boss_projectiles_fired > fired_before, "%s: the ranged shot actually fired" % form_id)
		_expect_near(max_deviation, 0.0, 0.0001,
			"%s: speed_scale never leaves 1.0 anywhere in the ranged cycle" % form_id)
		await _destroy(ctx)

	# The retired Task 69 stretch factors must not survive anywhere in the
	# Boss script, not even as a fallback branch.
	var script_text := FileAccess.get_file_as_string("res://scripts/run/enemies/boss_tide_ember.gd")
	_expect(not script_text.contains("_play_attack_from_frame"),
		"the attack-only playback helper was generalized away")
	_expect(not script_text.contains("windup / profile.telegraph_duration"),
		"the speed_scale stretch expression is gone from the Boss script")
	_expect(script_text.count("tuning.ranged_cast_launch_frame_index") >= 3,
		"every launch-frame use in the Boss script reads the tuning field")
	_expect(not script_text.contains("&\"cast\", 5)"),
		"the launch frame index is never written as a literal in the Boss script")


# ---------------------------------------------------------------------------
# §5.1.4 on the exact physics frame a bolt is created, the sprite sits on the
# configured launch frame.
# ---------------------------------------------------------------------------
func _test_projectile_spawns_on_launch_frame() -> void:
	for form_id: StringName in [&"ember", &"tide", &"plain"]:
		var ctx := await _make_boss(form_id, true)
		var boss: BossTideEmber = ctx[&"boss"]
		boss._boss_projectile_cooldown = 0.0
		_suppress_summons(boss)
		var fired_before := boss.boss_projectiles_fired
		var frame_on_spawn := -1
		var animation_on_spawn := StringName()
		for i in 120:
			await _hold_frame(ctx, 420.0)
			if boss.boss_projectiles_fired > fired_before:
				frame_on_spawn = boss.sprite.frame
				animation_on_spawn = boss.sprite.animation
				break
		_expect(frame_on_spawn >= 0, "%s: a bolt was created within the frame budget" % form_id)
		_expect_eq(animation_on_spawn, boss._animation_name(&"cast"),
			"%s: the cast clip is what is on screen when the bolt spawns" % form_id)
		_expect_eq(frame_on_spawn, BOSS_TUNING.ranged_cast_launch_frame_index,
			"%s: the sprite is exactly on the configured launch frame when the bolt spawns" % form_id)
		# And the post-launch hold is derived from the cast clip, not the
		# melee clip (Task 69 used attack_recovery_duration() here).
		_expect_near(boss.attack_time, boss.cast_recovery_duration(),
			1.0 / float(Engine.physics_ticks_per_second) * 1.5,
			"%s: the post-launch hold equals the cast clip's recovery segment" % form_id)
		await _destroy(ctx)


# ---------------------------------------------------------------------------
# §5.1.5 C3 backward compatibility: no type argument == the historical ranged
# alert, for every consumer; the three named types give three different icons.
# ---------------------------------------------------------------------------
func _test_telegraph_type_default_and_variants() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var indicator := INDICATOR_SCENE.instantiate() as EnemyTelegraphIndicator
	world.add_child(indicator)
	await process_frame

	_expect_eq(indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.RANGED,
		"a freshly instanced indicator starts on the ranged type")
	_expect(indicator.start(0.5), "start(duration) with no type is still the whole legacy call signature")
	_expect_eq(indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.RANGED,
		"omitting the type keeps the historical ranged alert")
	_expect(indicator.is_active, "the legacy call still activates the indicator")
	_expect(indicator.visible, "the legacy call still makes the indicator visible")

	var textures := {}
	for kind: int in [
		EnemyTelegraphIndicator.TelegraphType.RANGED,
		EnemyTelegraphIndicator.TelegraphType.MELEE,
		EnemyTelegraphIndicator.TelegraphType.SUMMON,
	]:
		indicator.start(0.5, kind)
		_expect_eq(indicator.telegraph_type, kind, "start() honours the requested type %d" % kind)
		var path := _current_icon_path(indicator)
		_expect(path.contains(EXPECTED_ICON_SHEETS[kind]),
			"type %d shows %s (got %s)" % [kind, EXPECTED_ICON_SHEETS[kind], path])
		textures[kind] = path
	_expect_eq(textures.values().size(), 3, "three types were sampled")
	_expect(textures[0] != textures[1] and textures[1] != textures[2] and textures[0] != textures[2],
		"the three types genuinely draw three different sheets, not one recoloured one")

	# The explicit setter is an equivalent route to the same state.
	indicator.start(0.5)
	indicator.set_telegraph_type(EnemyTelegraphIndicator.TelegraphType.SUMMON)
	_expect(_current_icon_path(indicator).contains(EXPECTED_ICON_SHEETS[EnemyTelegraphIndicator.TelegraphType.SUMMON]),
		"set_telegraph_type() re-skins a running telegraph")
	# ...and a subsequent type-less start() resets to ranged, so a Boss melee
	# or summon warning can never leak into the next ranged one.
	indicator.start(0.5)
	_expect_eq(indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.RANGED,
		"a type-less start() resets the type instead of inheriting the previous one")

	# The signal contract and the viewport clamp are untouched.
	var completed := [0]
	var cancelled := [0]
	indicator.telegraph_completed.connect(func() -> void: completed[0] += 1)
	indicator.telegraph_cancelled.connect(func() -> void: cancelled[0] += 1)
	indicator.start(0.1, EnemyTelegraphIndicator.TelegraphType.MELEE)
	indicator.advance(0.2)
	_expect_eq(completed[0], 1, "telegraph_completed still fires when the window elapses")
	_expect(not indicator.is_active, "the indicator deactivates on completion")
	indicator.start(0.5, EnemyTelegraphIndicator.TelegraphType.SUMMON)
	indicator.cancel()
	_expect_eq(cancelled[0], 1, "telegraph_cancelled still fires on cancel()")
	_expect(not indicator.visible, "a cancelled indicator hides itself")
	_expect(not indicator.start(0.0), "start() still rejects a non-positive duration")
	_expect(not indicator.start(NAN), "start() still rejects NaN")
	world.queue_free()
	await process_frame

	# Live consumer 1: the tidal sentry drives the shared ranged cycle from its
	# own untouched _physics_process.
	var sentry_ctx := await _make_ranged_enemy(SENTRY_SCENE)
	var sentry: CombatEnemy = sentry_ctx[&"enemy"]
	_expect(sentry.telegraph_indicator != null, "tidal_sentry owns a telegraph indicator")
	sentry._boss_projectile_cooldown = 0.0
	var sentry_opened := false
	for i in 90:
		await physics_frame
		if sentry.telegraph_indicator != null and sentry.telegraph_indicator.is_active:
			sentry_opened = true
			break
	_expect(sentry_opened, "tidal_sentry opens its telegraph through the untouched shared cycle")
	if sentry_opened:
		_expect_eq(sentry.telegraph_indicator.telegraph_type,
			EnemyTelegraphIndicator.TelegraphType.RANGED,
			"tidal_sentry still gets the ranged alert (C3 default, call site unchanged)")
		_expect(_current_icon_path(sentry.telegraph_indicator).contains("telegraph_alert_v1.png"),
			"tidal_sentry draws the historical alert sheet")
	await _destroy(sentry_ctx)

	# Live consumer 2: scenes/enemy.tscn mounts the same indicator but its AI
	# never routes through the ranged cycle on its own, so the inherited call
	# site -- CombatEnemy._begin_ranged_attack_telegraph, which this task did
	# not touch -- is exercised directly.
	var enemy_ctx := await _make_ranged_enemy(ENEMY_SCENE)
	var enemy: CombatEnemy = enemy_ctx[&"enemy"]
	_expect(enemy.telegraph_indicator != null, "scenes/enemy.tscn owns a telegraph indicator")
	enemy._begin_ranged_attack_telegraph(enemy.ranged_projectile_profile, &"probe_regular_enemy")
	_expect(enemy._telegraph_active, "the regular enemy opened the inherited ranged telegraph")
	_expect(enemy.telegraph_indicator.is_active, "the regular enemy's indicator is showing")
	_expect_eq(enemy.telegraph_indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.RANGED,
		"the regular enemy still gets the ranged alert (C3 default, call site unchanged)")
	_expect(_current_icon_path(enemy.telegraph_indicator).contains("telegraph_alert_v1.png"),
		"the regular enemy draws the historical alert sheet")
	await _destroy(enemy_ctx)

	# ...and so does the Boss's own ranged attack.
	var boss_ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = boss_ctx[&"boss"]
	boss._boss_projectile_cooldown = 0.0
	_suppress_summons(boss)
	var boss_opened := await _hold_distance_until(boss_ctx, 420.0, 30,
		func() -> bool: return boss.telegraph_indicator.is_active)
	_expect(boss_opened, "the Boss's ranged telegraph opens")
	if boss_opened:
		_expect_eq(boss.telegraph_indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.RANGED,
			"the Boss's ranged attack uses the ranged type")
	await _destroy(boss_ctx)

	# ...and its melee and summon use their own types.
	var melee_ctx := await _make_boss(&"ember", true)
	var melee_boss: BossTideEmber = melee_ctx[&"boss"]
	var delivery := await _drive_melee_swing(melee_ctx, 1.0)
	_expect(delivery != null, "a melee swing spawned its delivery")
	_expect_eq(melee_boss.telegraph_indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.MELEE,
		"the Boss's melee swing shows the melee type")
	await _destroy(melee_ctx)

	var summon_ctx := await _make_boss(&"tide", true)
	var summon_boss: BossTideEmber = summon_ctx[&"boss"]
	summon_boss._start_summon(summon_boss.tide_form)
	_expect_eq(summon_boss.telegraph_indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.SUMMON,
		"the Boss's summon shows the summon type")
	await _destroy(summon_ctx)


# ---------------------------------------------------------------------------
# §5.1.6 C4: the ground box is exactly the delivery's real query rectangle,
# for both facings; it is gone the instant the hitbox goes live; and form
# switch / death clear it.
# ---------------------------------------------------------------------------
func _test_melee_range_box_matches_delivery() -> void:
	# Independent derivation of the expected geometry, read straight off the
	# delivery scene rather than restated as literals.
	var probe := MELEE_DELIVERY_SCENE.instantiate() as DelayedAreaDelivery
	var probe_shape := probe.hit_shape as RectangleShape2D
	_expect(probe_shape != null, "boss_melee_delivery.tscn carries a RectangleShape2D hit_shape")
	var expected_size := probe_shape.size
	var expected_offset := probe.query_offset
	probe.free()
	_expect(expected_size.x > 0.0 and expected_size.y > 0.0, "the hit rectangle has a real size")

	for facing: float in [1.0, -1.0]:
		var ctx := await _make_boss(&"ember", true)
		var boss: BossTideEmber = ctx[&"boss"]
		var telegraph: Node2D = boss.get_node("MeleeRangeTelegraph")
		var fill: Polygon2D = telegraph.get_node("Fill")
		var outline: Line2D = telegraph.get_node("Outline")
		_expect(not telegraph.visible, "the range box is hidden before any swing (facing %.0f)" % facing)
		var boss_origin := boss.global_position
		var delivery := await _drive_melee_swing(ctx, facing)
		_expect(delivery != null, "facing %.0f: the melee swing spawned a delivery" % facing)
		if delivery == null:
			await _destroy(ctx)
			continue
		_expect(telegraph.visible, "facing %.0f: the range box is shown during the telegraph window" % facing)
		_expect_eq(fill.polygon.size(), 4, "facing %.0f: the fill polygon is a quad" % facing)
		_expect_eq(outline.points.size(), 4, "facing %.0f: the outline traces the same quad" % facing)

		var world_rect := _world_rect_of(telegraph, fill.polygon)
		var expected_center := boss_origin + Vector2(expected_offset.x * facing, expected_offset.y)
		var expected_rect := Rect2(expected_center - expected_size * 0.5, expected_size)
		_expect(world_rect.position.is_equal_approx(expected_rect.position),
			"facing %.0f: box origin matches the delivery's query rectangle (expected %s, got %s)"
				% [facing, expected_rect.position, world_rect.position])
		_expect(world_rect.size.is_equal_approx(expected_rect.size),
			"facing %.0f: box size matches hit_shape.size (expected %s, got %s)"
				% [facing, expected_rect.size, world_rect.size])
		# Cross-check against the delivery's OWN query transform, so the test
		# does not merely re-derive what the Boss derived.
		var query_origin := delivery.global_position + delivery.query_offset.rotated(delivery.direction.angle())
		_expect(world_rect.get_center().is_equal_approx(query_origin),
			"facing %.0f: the box centre is the delivery's actual query origin" % facing)

		# The box must be gone the moment the hitbox opens.
		var guard := 0
		while is_instance_valid(delivery) and delivery.delayed_phase == DelayedAreaDelivery.Phase.WAITING and guard < 240:
			await physics_frame
			guard += 1
		_expect(is_instance_valid(delivery) and delivery.delayed_phase != DelayedAreaDelivery.Phase.WAITING,
			"facing %.0f: the delivery left its WAITING phase" % facing)
		_expect(not telegraph.visible,
			"facing %.0f: the range box is already hidden when the hitbox goes live" % facing)
		await _destroy(ctx)

	# Form switch clears it.
	var switch_ctx := await _make_boss(&"ember", true)
	var switch_boss: BossTideEmber = switch_ctx[&"boss"]
	var switch_telegraph: Node2D = switch_boss.get_node("MeleeRangeTelegraph")
	var switch_delivery := await _drive_melee_swing(switch_ctx, 1.0)
	_expect(switch_delivery != null and switch_telegraph.visible, "a swing is telegraphing before the form switch")
	switch_boss._begin_form_transition(&"tide")
	_expect(not switch_telegraph.visible, "a form transition clears the range box")
	await _destroy(switch_ctx)

	# Death clears it.
	var death_ctx := await _make_boss(&"ember", true)
	var death_boss: BossTideEmber = death_ctx[&"boss"]
	var death_telegraph: Node2D = death_boss.get_node("MeleeRangeTelegraph")
	var death_delivery := await _drive_melee_swing(death_ctx, 1.0)
	_expect(death_delivery != null and death_telegraph.visible, "a swing is telegraphing before the killing blow")
	death_boss._on_death_candidate(null)
	_expect(death_boss.defeated, "the Boss is defeated")
	_expect(not death_telegraph.visible, "death clears the range box")
	await _destroy(death_ctx)


# ---------------------------------------------------------------------------
# §5.1.7 C5: nothing is instantiated until the summon window closes; a poise
# break inside the window cancels the summon, refunds the cooldown and clears
# the warning.
# ---------------------------------------------------------------------------
func _test_summon_telegraph_window_and_interrupt() -> void:
	var step := 1.0 / float(Engine.physics_ticks_per_second)

	# --- the window actually delays the spawn ---
	var ctx := await _make_boss(&"tide", true)
	var boss: BossTideEmber = ctx[&"boss"]
	var form := boss.tide_form
	var window := form.summon_telegraph_duration
	_expect(window > 0.0, "the tide form declares a real summon window")
	boss._start_summon(form)
	_expect_eq(boss._alive_summon_count(), 0, "nothing is instantiated by _start_summon() itself")
	_expect(boss.telegraph_indicator.is_active, "the summon warning is showing")
	_expect_eq(boss.telegraph_indicator.telegraph_type, EnemyTelegraphIndicator.TelegraphType.SUMMON,
		"the warning uses the summon type")
	_expect_eq(boss.sprite.animation, boss._animation_name(&"cast"),
		"the summon channel plays the cast windup")
	var frames_before_end := int(floor(window / step)) - 2
	for i in maxi(frames_before_end, 1):
		await _hold_frame(ctx, 420.0)
	_expect_eq(boss._alive_summon_count(), 0, "still nothing spawned one frame before the window closes")
	var spawned := false
	for i in 30:
		await _hold_frame(ctx, 420.0)
		if boss._alive_summon_count() > 0:
			spawned = true
			break
	_expect(spawned, "the summons appear once the window closes")
	_expect(boss._alive_summon_count() <= form.summon_max_alive, "the cap still holds after the delayed spawn")
	_expect_eq(boss._alive_summon_count(), mini(form.summon_count_per_cast, form.summon_max_alive),
		"the delayed cast spawns summon_count_per_cast summons")
	_expect(not boss.telegraph_indicator.is_active, "the warning is gone once the summon resolves")
	# A second cast while the cap is full must still add nothing.
	var count_after_first := boss._alive_summon_count()
	boss._summon_cooldown_remaining = 0.0
	boss._start_summon(form)
	for i in 90:
		await _hold_frame(ctx, 420.0)
	_expect_eq(boss._alive_summon_count(), count_after_first,
		"a second, fully telegraphed cast respects summon_max_alive")
	await _destroy(ctx)

	# --- poise break inside the window cancels and refunds ---
	var break_ctx := await _make_boss(&"tide", true)
	var break_boss: BossTideEmber = break_ctx[&"boss"]
	break_boss._start_summon(break_boss.tide_form)
	_expect(break_boss._summon_cooldown_remaining > 0.0, "the cooldown is armed while the window runs")
	for i in 6:
		await _hold_frame(break_ctx, 420.0)
	_expect_eq(break_boss._alive_summon_count(), 0, "still mid-window before the interrupt")
	var poise_before := break_boss.poise_stun_time
	for i in break_boss.poise_hit_threshold:
		break_boss._on_poise_hit()
	_expect(break_boss.poise_stun_time > poise_before, "the poise threshold opened a real stagger")
	_expect_eq(break_boss._summon_cooldown_remaining, 0.0,
		"the poise break refunded the summon cooldown (the cast never happened)")
	_expect(not break_boss.telegraph_indicator.is_active, "the poise break cleared the summon warning")
	break_boss.ai_enabled = false
	for i in 120:
		await physics_frame
	_expect_eq(break_boss._alive_summon_count(), 0, "the interrupted summon never spawns anything")
	await _destroy(break_ctx)

	# --- an ordinary hit does NOT interrupt (Task 61 poise design untouched) ---
	var hit_ctx := await _make_boss(&"tide", true)
	var hit_boss: BossTideEmber = hit_ctx[&"boss"]
	hit_boss._start_summon(hit_boss.tide_form)
	hit_boss._on_poise_hit()
	_expect(hit_boss._summon_pending_form != null, "a single ordinary hit leaves the summon channelling")
	_expect(hit_boss.telegraph_indicator.is_active, "the warning survives an ordinary hit")
	var resolved := false
	for i in 90:
		await _hold_frame(hit_ctx, 420.0)
		if hit_boss._alive_summon_count() > 0:
			resolved = true
			break
	_expect(resolved, "the un-interrupted summon still resolves normally")
	await _destroy(hit_ctx)

	# --- a form switch clears the pending summon too ---
	var switch_ctx := await _make_boss(&"tide", true)
	var switch_boss: BossTideEmber = switch_ctx[&"boss"]
	switch_boss._start_summon(switch_boss.tide_form)
	switch_boss._begin_form_transition(&"ember")
	_expect(switch_boss._summon_pending_form == null, "a form transition clears the pending summon")
	_expect(not switch_boss.telegraph_indicator.is_active, "a form transition clears the summon warning")
	for i in 90:
		await physics_frame
	_expect_eq(switch_boss._alive_summon_count(), 0, "the cleared summon never spawns")
	await _destroy(switch_ctx)


# ---------------------------------------------------------------------------
# §5.1.8 reduced motion: the static single-frame icon, no tween, and the
# ground box degrades to a static outline.
# ---------------------------------------------------------------------------
func _test_reduced_motion_uses_static_icon() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var indicator := INDICATOR_SCENE.instantiate() as EnemyTelegraphIndicator
	world.add_child(indicator)
	await process_frame
	var mark: AnimatedSprite2D = indicator.get_node("Mark")

	indicator.set_reduced_motion(true)
	for kind: int in [
		EnemyTelegraphIndicator.TelegraphType.RANGED,
		EnemyTelegraphIndicator.TelegraphType.MELEE,
		EnemyTelegraphIndicator.TelegraphType.SUMMON,
	]:
		indicator.start(0.5, kind)
		_expect(not mark.is_playing(), "type %d: reduced motion never plays the bounce clip" % kind)
		_expect_eq(mark.sprite_frames.get_frame_count(mark.animation), 1,
			"type %d: reduced motion shows a single-frame clip" % kind)
		_expect(_current_icon_path(indicator).contains(EXPECTED_STATIC_SHEETS[kind]),
			"type %d: reduced motion shows %s" % [kind, EXPECTED_STATIC_SHEETS[kind]])
		_expect(indicator._tween == null, "type %d: reduced motion creates no tween" % kind)
		_expect_eq(indicator.modulate.a, 1.0, "type %d: reduced motion shows at full opacity immediately" % kind)
		_expect_eq(indicator.scale, Vector2.ONE, "type %d: reduced motion never scales the mark" % kind)

	# Motion back on: the authored 3-frame bounce plays, and the only tween is
	# the one-shot fade -- the old looping scale pulse is gone, so the sheet's
	# own bounce is never doubled up.
	indicator.set_reduced_motion(false)
	indicator.start(0.5, EnemyTelegraphIndicator.TelegraphType.RANGED)
	_expect(mark.is_playing(), "with motion on, the authored bounce clip plays")
	_expect_eq(mark.sprite_frames.get_frame_count(mark.animation), 3,
		"the authored bounce is the 3-frame sheet Task 60/70 delivered")
	_expect(mark.sprite_frames.get_animation_loop(mark.animation), "the bounce loops for the whole window")
	var script_text := FileAccess.get_file_as_string("res://combat/presentation/enemy_telegraph_indicator.gd")
	_expect(not script_text.contains("set_loops"), "the looping scale pulse tween is gone")
	_expect(not script_text.contains("Vector2(1.08"), "the 1.08 scale bounce is gone")
	_expect(not script_text.contains("_mark: Label"), "the placeholder Label node type is gone from the script")
	_expect(script_text.contains("_mark: AnimatedSprite2D"), "the mark is a real sprite now")
	var scene_text := FileAccess.get_file_as_string("res://scenes/combat/enemy_telegraph_indicator.tscn")
	_expect(not scene_text.contains("type=\"Label\""), "the placeholder Label node is gone from the scene")
	_expect(scene_text.contains("telegraph_alert_v1.png"), "the scene finally references the Task 60 art")
	world.queue_free()
	await process_frame

	# The Boss's ground box respects the same setting.
	var ctx := await _make_boss(&"ember", true)
	var boss: BossTideEmber = ctx[&"boss"]
	boss.telegraph_indicator.set_reduced_motion(true)
	var telegraph: Node2D = boss.get_node("MeleeRangeTelegraph")
	var fill: Polygon2D = telegraph.get_node("Fill")
	var outline: Line2D = telegraph.get_node("Outline")
	var delivery := await _drive_melee_swing(ctx, 1.0)
	_expect(delivery != null, "a melee swing spawned its delivery under reduced motion")
	_expect(telegraph.visible, "the range box still warns under reduced motion")
	_expect(not fill.visible, "reduced motion drops the pulsing fill")
	_expect(outline.visible, "reduced motion keeps the static outline")
	var alphas: Array[float] = []
	for i in 8:
		await physics_frame
		alphas.append(telegraph.modulate.a)
	var alpha_spread: float = float(alphas.max()) - float(alphas.min())
	_expect_near(alpha_spread, 0.0, 0.0001, "reduced motion holds the box at a constant alpha (no blink)")
	await _destroy(ctx)

	# ...and without it, the box does pulse.
	var motion_ctx := await _make_boss(&"ember", true)
	var motion_boss: BossTideEmber = motion_ctx[&"boss"]
	motion_boss.telegraph_indicator.set_reduced_motion(false)
	var motion_telegraph: Node2D = motion_boss.get_node("MeleeRangeTelegraph")
	var motion_delivery := await _drive_melee_swing(motion_ctx, 1.0)
	_expect(motion_delivery != null, "a melee swing spawned its delivery with motion on")
	var motion_alphas: Array[float] = []
	for i in 10:
		await physics_frame
		if motion_telegraph.visible:
			motion_alphas.append(motion_telegraph.modulate.a)
	_expect(motion_alphas.size() >= 2, "sampled the box across several frames")
	if motion_alphas.size() >= 2:
		_expect(float(motion_alphas.max()) - float(motion_alphas.min()) > 0.01,
			"with motion on, the box alpha genuinely pulses")
	await _destroy(motion_ctx)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _clip_total_duration(animation_name: StringName) -> float:
	var speed := BOSS_FRAMES.get_animation_speed(animation_name)
	if speed <= 0.0:
		return 0.0
	var total := 0.0
	for index: int in BOSS_FRAMES.get_frame_count(animation_name):
		total += BOSS_FRAMES.get_frame_duration(animation_name, index) / speed
	return total


## Resource path of whatever texture the indicator is showing right now,
## unwrapping the AtlasTexture slices used by the bounce sheets.
func _current_icon_path(indicator: EnemyTelegraphIndicator) -> String:
	var mark: AnimatedSprite2D = indicator.get_node("Mark")
	var frames := mark.sprite_frames
	if frames == null or not frames.has_animation(mark.animation):
		return ""
	var texture := frames.get_frame_texture(mark.animation, maxi(mark.frame, 0))
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		return atlas.resource_path if atlas != null else ""
	return texture.resource_path if texture != null else ""


func _world_rect_of(node: Node2D, polygon: PackedVector2Array) -> Rect2:
	var transform := node.global_transform
	var rect := Rect2(transform * polygon[0], Vector2.ZERO)
	for index: int in range(1, polygon.size()):
		rect = rect.expand(transform * polygon[index])
	return rect


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
	for i in 3:
		await physics_frame
	return {&"world": world, &"boss": boss, &"player": player}


func _make_ranged_enemy(scene: PackedScene) -> Dictionary:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	# TidalSentry only fires while is_on_floor(); give the fixture real ground
	# on the world layer (bit 0) that both enemy scenes mask against.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000.0, 40.0)
	floor_shape.shape = floor_rect
	floor_shape.position = Vector2(0.0, 40.0)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var enemy := scene.instantiate() as CombatEnemy
	enemy.global_position = Vector2(0.0, -4.0)
	world.add_child(enemy)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = enemy.global_position + Vector2(-160.0, 0.0)
	world.add_child(player)
	enemy.player = player
	enemy.ai_enabled = true
	for i in 3:
		await physics_frame
	return {&"world": world, &"enemy": enemy, &"player": player}


func _destroy(ctx: Dictionary) -> void:
	(ctx[&"world"] as Node).queue_free()
	await process_frame


func _hold_frame(ctx: Dictionary, distance: float) -> void:
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	player.global_position = boss.global_position + Vector2(distance, 0.0)
	await physics_frame


func _hold_distance_until(ctx: Dictionary, distance: float, max_frames: int, predicate: Callable) -> bool:
	for i in max_frames:
		await _hold_frame(ctx, distance)
		if predicate.call():
			return true
	return false


## Parks the player just inside melee range on the requested side and waits
## for the swing's DelayedAreaDelivery to appear.
func _drive_melee_swing(ctx: Dictionary, facing: float) -> DelayedAreaDelivery:
	var boss: BossTideEmber = ctx[&"boss"]
	var player: PlayerCharacter = ctx[&"player"]
	player.global_position = boss.global_position + Vector2(50.0 * facing, 0.0)
	boss.attack_cooldown = 0.0
	boss._boss_projectile_cooldown = 999.0
	for i in 8:
		await physics_frame
		player.global_position = boss.global_position + Vector2(50.0 * facing, 0.0)
		var delivery := _latest_delivery(boss)
		if delivery != null:
			return delivery
	return null


## The tide form's summon is gated on cooldown, not distance, so it fires on
## the fixture's very first tick and would swallow the frames a ranged probe
## needs. Parks it (and any already-opened window) without touching any tuning
## the production build ships.
func _suppress_summons(boss: BossTideEmber) -> void:
	boss._cancel_pending_summon(false)
	boss.attack_time = 0.0
	boss._summon_cooldown_remaining = 999.0
	if boss.telegraph_indicator != null:
		boss.telegraph_indicator.cancel()


func _latest_delivery(boss: BossTideEmber) -> DelayedAreaDelivery:
	var found: DelayedAreaDelivery = null
	for reference: WeakRef in boss._active_deliveries:
		var node: Variant = reference.get_ref()
		if node is DelayedAreaDelivery and is_instance_valid(node):
			found = node
	return found


func _run_test(test_name: String, callable: Callable) -> void:
	await _harness.run_test(test_name, callable)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_harness.expect_eq(actual, expected, description)


func _expect_near(actual: float, expected: float, tolerance: float, description: String) -> void:
	_harness.expect_near(actual, expected, tolerance, description)


func _finish() -> void:
	quit(_harness.report("TASK 71 BOSS CAST AND TELEGRAPH TESTS"))
