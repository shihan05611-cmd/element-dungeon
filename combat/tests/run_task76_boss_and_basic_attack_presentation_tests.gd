extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const INDICATOR_SCENE: PackedScene = preload("res://scenes/combat/enemy_telegraph_indicator.tscn")
const ATTACK_SHEETS := [
	"cat_attack",
	"cat_water_attack",
	"cat_fire_attack",
]

var _harness := TestHarness.new()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _harness.run_test("attack_sheets_recompose_exactly", _test_attack_sheets_recompose_exactly)
	await _harness.run_test("airflow_node_tracks_and_toggles_independently", _test_airflow_node_tracks_and_toggles_independently)
	await _harness.run_test("boss_reactions_keep_current_form", _test_boss_reactions_keep_current_form)
	await _harness.run_test("telegraph_cleanup_is_idempotent", _test_telegraph_cleanup_is_idempotent)
	quit(_harness.report("TASK 76 BOSS AND BASIC ATTACK PRESENTATION TESTS"))


func _test_attack_sheets_recompose_exactly() -> void:
	for stem: String in ATTACK_SHEETS:
		var source := _load_image("res://assets/characters/cat/%s.png" % stem)
		var body := _load_image("res://assets/characters/cat/%s_body.png" % stem)
		var airflow := _load_image("res://assets/characters/cat/%s_airflow.png" % stem)
		_harness.expect(source != null and body != null and airflow != null, "%s split assets load" % stem)
		if source == null or body == null or airflow == null:
			continue
		_harness.expect_eq(body.get_size(), source.get_size(), "%s body dimensions stay unchanged" % stem)
		_harness.expect_eq(airflow.get_size(), source.get_size(), "%s airflow dimensions stay unchanged" % stem)
		var mismatch_count := 0
		var overlap_count := 0
		var airflow_pixels := 0
		for y in source.get_height():
			for x in source.get_width():
				var source_pixel := source.get_pixel(x, y)
				var body_pixel := body.get_pixel(x, y)
				var airflow_pixel := airflow.get_pixel(x, y)
				if body_pixel.a > 0.0 and airflow_pixel.a > 0.0:
					overlap_count += 1
				if airflow_pixel.a > 0.0:
					airflow_pixels += 1
				var reconstructed := body_pixel if body_pixel.a > 0.0 else airflow_pixel
				if source_pixel.a > 0.0 and reconstructed != source_pixel:
					mismatch_count += 1
				elif source_pixel.a == 0.0 and reconstructed.a > 0.0:
					mismatch_count += 1
		_harness.expect_eq(overlap_count, 0, "%s body and airflow own disjoint pixels" % stem)
		_harness.expect_eq(mismatch_count, 0, "%s default two-layer composition is pixel-exact" % stem)
		_harness.expect(airflow_pixels > 0, "%s has a physically independent airflow layer" % stem)


func _test_airflow_node_tracks_and_toggles_independently() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	world.add_child(player)
	await process_frame
	var airflow := player.basic_attack_airflow
	_harness.expect(airflow != null, "player owns a dedicated basic-attack airflow node")
	for animation: StringName in [&"attack", &"water_attack", &"fire_attack"]:
		player.sprite.play(animation)
		player.sprite.set_frame_and_progress(5, 0.0)
		player._sync_basic_attack_airflow()
		_harness.expect(airflow.visible, "%s shows airflow by default" % animation)
		_harness.expect_eq(airflow.region_rect, Rect2(400, 0, 80, 64), "%s airflow tracks the body frame" % animation)
		_harness.expect(airflow.texture.resource_path.ends_with("%s_airflow.png" % animation), "%s selects its own airflow sheet" % animation)
	player.set_basic_attack_airflow_enabled(false)
	_harness.expect(not airflow.visible, "airflow can be disabled without hiding the body")
	_harness.expect(player.sprite.visible, "disabling airflow leaves the character body visible")
	player.set_basic_attack_airflow_enabled(true)
	_harness.expect(airflow.visible, "airflow can be restored during the same attack")
	player.sprite.play(&"idle")
	player._sync_basic_attack_airflow()
	_harness.expect(not airflow.visible, "airflow clears immediately outside basic-attack clips")
	world.queue_free()
	await process_frame


func _test_boss_reactions_keep_current_form() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	boss.ai_enabled = false
	world.add_child(boss)
	await process_frame
	for form_id: StringName in [&"ember", &"tide", &"plain"]:
		if boss.current_form_id != form_id:
			boss._begin_form_transition(form_id)
		boss._play_pose(&"hurt")
		var expected_hurt := &"hurt" if form_id == &"plain" else StringName("%s_hurt" % form_id)
		_harness.expect_eq(boss.sprite.animation, expected_hurt, "%s hurt keeps the current form" % form_id)
		boss._play_pose(&"death")
		var expected_death := &"death" if form_id == &"plain" else StringName("%s_death" % form_id)
		_harness.expect_eq(boss.sprite.animation, expected_death, "%s death keeps the current form" % form_id)
	_harness.expect_eq(boss._animation_name(&"hurt"), &"hurt", "only the genuinely plain form resolves to neutral hurt")
	world.queue_free()
	await process_frame


func _test_telegraph_cleanup_is_idempotent() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var indicator := INDICATOR_SCENE.instantiate() as EnemyTelegraphIndicator
	world.add_child(indicator)
	await process_frame
	_harness.expect(indicator.start(0.2, EnemyTelegraphIndicator.TelegraphType.SUMMON), "valid summon warning starts")
	indicator.advance(0.2)
	_harness.expect(not indicator.visible and not indicator.is_active, "completed warning clears itself")
	indicator.visible = true
	indicator.cancel()
	_harness.expect(not indicator.visible and not indicator.is_active, "cancel also clears stale inactive visibility")
	indicator.start(0.2, EnemyTelegraphIndicator.TelegraphType.MELEE)
	_harness.expect(not indicator.start(0.0), "invalid replacement warning is rejected")
	_harness.expect(not indicator.visible and not indicator.is_active, "invalid replacement cannot leave the previous warning behind")
	world.queue_free()
	await process_frame


func _load_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	return texture.get_image() if texture != null else null
