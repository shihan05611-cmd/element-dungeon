extends SceneTree

## Task 71 §5.3 visual evidence. Builds a real arena (formal Boss / enemy /
## sentry scenes + a floor) and records five pieces of evidence as annotated
## contact sheets, at both L2 resolutions:
##
##   1. one complete ranged attack -- every cell names the clip that is on
##      screen, the frame index inside it, which segment of the CAST clip that
##      is, speed_scale, and how many bolts exist;
##   2. the three telegraph icons on the live Boss (melee / ranged / summon);
##   3. the melee ground box with an INDEPENDENT overlay rectangle rebuilt from
##      the DelayedAreaDelivery's own query transform drawn on top of it -- if
##      the two outlines coincide, the warning is the hitbox;
##   4. the whole summon flow (warning window -> spawn), plus a second run in
##      which a poise break interrupts the window;
##   5. the regular enemy and the tidal sentry telegraph, before (the retired
##      font_size 40 "!" Label, rebuilt here from the pre-Task-71 .tscn) and
##      after (the wired art), side by side in one frame.
##
## Every cell carries an on-screen overlay with the values actually measured on
## that frame, so the sheets are self-annotating.
##
## Run (not headless -- a real framebuffer is required):
##   Godot_v4.7.1 --path . --display-driver windows --audio-driver Dummy \
##     --resolution 1920x1080 \
##     --script res://docs/agent_tasks/evidence/task71/capture_task71_cast_and_telegraphs.gd

const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const SENTRY_SCENE: PackedScene = preload("res://scenes/run/enemies/tidal_sentry.tscn")
const BOSS_TUNING: BossTuning = preload("res://resources/run/enemies/boss_forms/boss_tuning.tres")
const OUT_DIR := "res://docs/agent_tasks/evidence/task71/screenshots/"

## Same canvas-unit arena Task 69 used: the project stretches "canvas_items"
## from a 1152x648 base viewport, so world units are NOT framebuffer pixels.
const BOSS_ORIGIN := Vector2(400.0, 430.0)
const FLOOR_TOP := 462.0
const CELL := Vector2i(360, 400)
const CROP_OFFSET := Vector2(-200.0, -330.0)
const CROP_SIZE := Vector2(400.0, 420.0)
const GRID_COLUMNS := 8

var _world: Node2D
var _boss: BossTideEmber
var _player: PlayerCharacter
var _overlay: Label
var _resolution: Vector2i = Vector2i(1920, 1080)
var _saved := 0
var _projectiles_seen := 0
var _melee_swings := 0
var _probe_outline: Line2D


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		_resolution = resolution
		root.size = resolution
		await _wait_frames(6)
		print("=== resolution %dx%d ===" % [resolution.x, resolution.y])
		await _sequence_ranged_cast()
		await _sequence_telegraph_types()
		await _sequence_melee_range_box()
		await _sequence_summon_flow()
		await _sequence_summon_interrupt()
		await _sequence_indicator_before_after()
	print("TASK71 CAPTURE PASSED: %d files" % _saved)
	quit(0)


# ---------------------------------------------------------------------------
# 1. Full ranged attack on the dedicated cast clip.
# ---------------------------------------------------------------------------
func _sequence_ranged_cast() -> void:
	await _build_arena(&"ember")
	var profile := _boss.current_form.ranged_projectile_profile
	_pin_player(420.0)
	_boss.attack_cooldown = 999.0
	_boss._summon_cooldown_remaining = 999.0
	_boss._boss_projectile_cooldown = 0.0
	var started := await _wait_until(func() -> bool: return _boss._telegraph_active, 120)
	print("ranged_cast: started=%s telegraph=%.3fs cast_windup=%.3fs cast_recovery=%.3fs launch_frame=%d speed_scale=%.3f" % [
		started, profile.telegraph_duration, _boss.cast_windup_duration(),
		_boss.cast_recovery_duration(), BOSS_TUNING.ranged_cast_launch_frame_index, _boss.sprite.speed_scale])
	var cells: Array[Image] = []
	var telegraph_total := _boss._telegraph_time_remaining
	var launch_cell := -1
	var max_speed_deviation := 0.0
	for index: int in 32:
		_pin_player(420.0)
		max_speed_deviation = maxf(max_speed_deviation, absf(_boss.sprite.speed_scale - 1.0))
		var elapsed := (telegraph_total - _boss._telegraph_time_remaining) if _boss._telegraph_active \
			else (telegraph_total + _boss.cast_recovery_duration() - _boss.attack_time)
		if launch_cell < 0 and _projectiles_seen > 0:
			launch_cell = index
		_set_overlay([
			"RANGED CAST  cell %02d  cycle t=%.3fs" % [index, elapsed],
			"anim=%s  frame=%d/%d" % [_boss.sprite.animation, _boss.sprite.frame,
				_boss.sprite.sprite_frames.get_frame_count(_boss.sprite.animation) - 1],
			"cast segment=%s  (launch idx=%d)" % [_cast_segment_label(), BOSS_TUNING.ranged_cast_launch_frame_index],
			"phase=%s" % ("CHARGE (telegraph)" if _boss._telegraph_active else ("LAUNCH/RECOVER" if _boss.attack_time > 0.0 else "idle/walk")),
			"speed_scale=%.3f  bolts spawned=%d" % [_boss.sprite.speed_scale, _projectiles_seen],
		])
		cells.append(await _grab_cell())
	print("ranged_cast: first_cell_with_bolts=%d total_bolts=%d max|speed_scale-1|=%.4f" % [
		launch_cell, _projectiles_seen, max_speed_deviation])
	_save_sheet("task71_ranged_cast_sequence", cells)

	# No-readback control run: framebuffer stalls inflate wall-clock per
	# physics frame, so the authoritative launch-frame measurement is taken
	# without any capture in the loop.
	await _wait_until(func() -> bool: return _boss.attack_time <= 0.0, 240)
	var bolts_before := _projectiles_seen
	_boss._boss_projectile_cooldown = 0.0
	await _wait_until(func() -> bool: return _boss._telegraph_active, 120)
	var charge_anim := _boss.sprite.animation
	var charge_frame := _boss.sprite.frame
	var windup_frames := 0
	while _boss._telegraph_active and windup_frames < 240:
		_pin_player(420.0)
		await physics_frame
		windup_frames += 1
	print("ranged_cast(no-readback): charge on anim=%s frame=%d; telegraph ran %d physics frames (%.3fs); at launch anim=%s frame=%d (configured %d), bolts=%d, speed_scale=%.3f" % [
		charge_anim, charge_frame, windup_frames,
		float(windup_frames) * _boss.get_physics_process_delta_time(),
		_boss.sprite.animation, _boss.sprite.frame, BOSS_TUNING.ranged_cast_launch_frame_index,
		_projectiles_seen - bolts_before, _boss.sprite.speed_scale])
	await _teardown()


# ---------------------------------------------------------------------------
# 2. The three telegraph icons on the live Boss.
# ---------------------------------------------------------------------------
func _sequence_telegraph_types() -> void:
	var cells: Array[Image] = []

	# Melee.
	await _build_arena(&"ember")
	_boss._boss_projectile_cooldown = 999.0
	_boss._summon_cooldown_remaining = 999.0
	_pin_player(60.0)
	_boss.attack_cooldown = 0.0
	await _wait_until(func() -> bool: return _boss.telegraph_indicator.is_active, 120)
	_pin_player(60.0)
	_set_overlay_bottom(_type_overlay("MELEE"))
	cells.append(await _grab_cell())
	await _teardown()

	# Ranged.
	await _build_arena(&"ember")
	_boss.attack_cooldown = 999.0
	_boss._summon_cooldown_remaining = 999.0
	_pin_player(420.0)
	_boss._boss_projectile_cooldown = 0.0
	await _wait_until(func() -> bool: return _boss.telegraph_indicator.is_active, 120)
	_pin_player(420.0)
	_set_overlay_bottom(_type_overlay("RANGED"))
	cells.append(await _grab_cell())
	await _teardown()

	# Summon (tide form is the only one that summons).
	await _build_arena(&"tide")
	_boss.attack_cooldown = 999.0
	_boss._boss_projectile_cooldown = 999.0
	_pin_player(420.0)
	_boss._summon_cooldown_remaining = 0.0
	await _wait_until(func() -> bool: return _boss.telegraph_indicator.is_active, 180)
	_pin_player(420.0)
	_set_overlay_bottom(_type_overlay("SUMMON"))
	cells.append(await _grab_cell())
	await _teardown()

	_save_sheet("task71_telegraph_types", cells)


## Same as _set_overlay but anchored to the BOTTOM of the crop, so the head
## icon this sheet is about is never drawn behind the text.
func _set_overlay_bottom(lines: Array) -> void:
	_overlay.text = "
".join(lines)
	_overlay.position = _boss.global_position + CROP_OFFSET + Vector2(8.0, CROP_SIZE.y - 152.0)
	_overlay.size = Vector2(CROP_SIZE.x - 16.0, 146.0)


func _type_overlay(label: String) -> Array:
	var indicator := _boss.telegraph_indicator
	var mark := indicator.get_node("Mark") as AnimatedSprite2D
	return [
		"TELEGRAPH TYPE: %s" % label,
		"telegraph_type=%d  clip=%s" % [indicator.telegraph_type, mark.animation],
		"sheet=%s" % _icon_sheet_name(indicator),
		"frames in clip=%d  playing=%s" % [
			mark.sprite_frames.get_frame_count(mark.animation), mark.is_playing()],
		"boss anim=%s frame=%d" % [_boss.sprite.animation, _boss.sprite.frame],
	]


# ---------------------------------------------------------------------------
# 3. The melee ground box vs. the delivery's real query rectangle.
# ---------------------------------------------------------------------------
func _sequence_melee_range_box() -> void:
	for facing: float in [1.0, -1.0]:
		await _build_arena(&"ember")
		_boss._boss_projectile_cooldown = 999.0
		_boss._summon_cooldown_remaining = 999.0
		_pin_player(60.0 * facing)
		_boss.attack_cooldown = 0.0
		var started := await _wait_until(func() -> bool: return _latest_delivery() != null, 120)
		var delivery := _latest_delivery()
		print("melee_box(facing %.0f): swing=%s hit_shape=%s query_offset=%s dir=%s" % [
			facing, started,
			str((delivery.hit_shape as RectangleShape2D).size) if delivery != null else "-",
			str(delivery.query_offset) if delivery != null else "-",
			str(delivery.direction) if delivery != null else "-"])
		_draw_independent_probe(delivery)
		var cells: Array[Image] = []
		for index: int in 16:
			_pin_player(60.0 * facing)
			var telegraph: Node2D = _boss.get_node("MeleeRangeTelegraph")
			var phase := _phase_name(_latest_delivery())
			_set_overlay([
				"MELEE BOX  facing %s  cell %02d" % ["RIGHT" if facing > 0.0 else "LEFT", index],
				"orange = Boss warning box",
				"cyan = independent probe rect",
				"box=%s  hitbox=%s" % [telegraph.visible, phase],
				"attack_time=%.3f" % _boss.attack_time,
			])
			cells.append(await _grab_cell())
		_save_sheet("task71_melee_range_box_%s" % ("right" if facing > 0.0 else "left"), cells)
		await _teardown()


## An outline computed here, from the delivery's own exported parameters,
## with no reference to whatever the Boss drew. Overlaid in cyan so the two
## can be compared by eye in the contact sheet.
func _draw_independent_probe(delivery: DelayedAreaDelivery) -> void:
	if delivery == null:
		return
	var rectangle := delivery.hit_shape as RectangleShape2D
	if rectangle == null:
		return
	var angle := delivery.direction.angle()
	var transform := Transform2D(angle + delivery.query_rotation, delivery.query_offset.rotated(angle))
	var half := rectangle.size * 0.5
	_probe_outline = Line2D.new()
	_probe_outline.width = 1.0
	_probe_outline.default_color = Color(0.3, 1.0, 1.0, 0.95)
	_probe_outline.closed = true
	_probe_outline.z_index = 60
	_probe_outline.points = PackedVector2Array([
		transform * Vector2(-half.x, -half.y),
		transform * Vector2(half.x, -half.y),
		transform * Vector2(half.x, half.y),
		transform * Vector2(-half.x, half.y),
	])
	_probe_outline.global_position = delivery.global_position
	_world.add_child(_probe_outline)


# ---------------------------------------------------------------------------
# 4a. Summon: warning window -> spawn.
# ---------------------------------------------------------------------------
func _sequence_summon_flow() -> void:
	await _build_arena(&"tide")
	var form := _boss.current_form
	_boss.attack_cooldown = 999.0
	_boss._boss_projectile_cooldown = 999.0
	_pin_player(420.0)
	_boss._summon_cooldown_remaining = 0.0
	var started := await _wait_until(func() -> bool: return _boss._summon_pending_form != null, 180)
	print("summon_flow: window_opened=%s summon_telegraph_duration=%.3fs cooldown=%.3f" % [
		started, form.summon_telegraph_duration, _boss._summon_cooldown_remaining])
	var cells: Array[Image] = []
	var spawn_cell := -1
	for index: int in 24:
		# The window is 0.9s == 54 physics ticks; a framebuffer readback does
		# not advance a fixed number of ticks, so each cell explicitly steps
		# several physics frames to guarantee the whole window is covered.
		for step: int in 3:
			_pin_player(420.0)
			await physics_frame
		_pin_player(420.0)
		if spawn_cell < 0 and _boss._alive_summon_count() > 0:
			spawn_cell = index
		_set_overlay([
			"SUMMON FLOW  cell %02d" % index,
			"window left=%.3fs / %.3fs" % [maxf(_boss._summon_telegraph_remaining, 0.0), form.summon_telegraph_duration],
			"pending=%s   alive summons=%d" % [_boss._summon_pending_form != null, _boss._alive_summon_count()],
			"warning=%s type=%d" % [_boss.telegraph_indicator.is_active, _boss.telegraph_indicator.telegraph_type],
			"anim=%s frame=%d" % [_boss.sprite.animation, _boss.sprite.frame],
		])
		cells.append(await _grab_cell())
	print("summon_flow: first_cell_with_summons=%d alive=%d" % [spawn_cell, _boss._alive_summon_count()])
	_save_sheet("task71_summon_flow", cells)
	await _teardown()


# ---------------------------------------------------------------------------
# 4b. Summon interrupted by a poise break inside the window.
# ---------------------------------------------------------------------------
func _sequence_summon_interrupt() -> void:
	await _build_arena(&"tide")
	_boss.attack_cooldown = 999.0
	_boss._boss_projectile_cooldown = 999.0
	_pin_player(420.0)
	_boss._summon_cooldown_remaining = 0.0
	await _wait_until(func() -> bool: return _boss._summon_pending_form != null, 180)
	var cells: Array[Image] = []
	var broken := false
	for index: int in 20:
		_pin_player(420.0)
		if index == 5 and not broken:
			broken = true
			for i: int in _boss.poise_hit_threshold:
				_boss._on_poise_hit()
			print("summon_interrupt: poise broken at cell 5, stun=%.2fs cooldown_after=%.3f pending=%s" % [
				_boss.poise_stun_time, _boss._summon_cooldown_remaining, _boss._summon_pending_form != null])
		_set_overlay([
			"SUMMON INTERRUPT  cell %02d" % index,
			"pending=%s  alive summons=%d" % [_boss._summon_pending_form != null, _boss._alive_summon_count()],
			"warning=%s" % _boss.telegraph_indicator.is_active,
			"poise_stun=%.2fs  hits=%d/%d" % [_boss.poise_stun_time, _boss.poise_hits, _boss.poise_hit_threshold],
			"summon cooldown=%.3f (0=refunded)" % _boss._summon_cooldown_remaining,
		])
		cells.append(await _grab_cell())
	print("summon_interrupt: alive summons after interrupt=%d cooldown=%.3f" % [
		_boss._alive_summon_count(), _boss._summon_cooldown_remaining])
	_save_sheet("task71_summon_interrupt", cells)
	await _teardown()


# ---------------------------------------------------------------------------
# 5. Regular enemy + tidal sentry, retired "!" Label vs. the wired art.
# ---------------------------------------------------------------------------
func _sequence_indicator_before_after() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	current_scene = _world
	_add_floor()
	_add_backdrop()

	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.global_position = Vector2(120.0, FLOOR_TOP - 40.0)
	_world.add_child(player)

	var slots := [
		{&"scene": ENEMY_SCENE, &"x": 300.0, &"before": true, &"label": "enemy.tscn  BEFORE"},
		{&"scene": ENEMY_SCENE, &"x": 480.0, &"before": false, &"label": "enemy.tscn  AFTER"},
		{&"scene": SENTRY_SCENE, &"x": 660.0, &"before": true, &"label": "tidal_sentry  BEFORE"},
		{&"scene": SENTRY_SCENE, &"x": 840.0, &"before": false, &"label": "tidal_sentry  AFTER"},
	]
	for slot: Dictionary in slots:
		var enemy := (slot[&"scene"] as PackedScene).instantiate() as CombatEnemy
		enemy.global_position = Vector2(slot[&"x"], FLOOR_TOP - 40.0)
		_world.add_child(enemy)
		enemy.player = player
		enemy.ai_enabled = false
		await _wait_frames(2)
		if slot[&"before"]:
			enemy.telegraph_indicator.visible = false
			_attach_retired_label(enemy)
		else:
			enemy._begin_ranged_attack_telegraph(enemy.ranged_projectile_profile, &"task71_capture")
		var caption := Label.new()
		caption.text = slot[&"label"]
		caption.add_theme_font_size_override(&"font_size", 13)
		caption.add_theme_color_override(&"font_color", Color(0.85, 0.95, 1.0))
		caption.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 1))
		caption.position = Vector2(slot[&"x"] - 70.0, FLOOR_TOP + 8.0)
		caption.size = Vector2(150.0, 20.0)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_world.add_child(caption)

	_overlay = Label.new()
	_overlay.add_theme_font_size_override(&"font_size", 15)
	_overlay.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.7))
	_overlay.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 1))
	_overlay.z_index = 200
	_overlay.position = Vector2(180.0, 150.0)
	_overlay.size = Vector2(760.0, 120.0)
	_overlay.text = "\n".join([
		"C3 BACKWARD COMPATIBILITY -- neither scripts/enemy.gd nor tidal_sentry.gd was touched.",
		"BEFORE = the retired font_size 40 \"!\" Label, rebuilt here verbatim from the pre-Task-71 .tscn.",
		"AFTER  = the same start(duration) call, no type argument -> RANGED default -> telegraph_alert_v1.png.",
		"Position, timing, signals and the viewport clamp are unchanged; only the visual carrier moved.",
	])
	_world.add_child(_overlay)

	await _wait_frames(10)
	await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var scale := float(image.get_width()) / root.get_visible_rect().size.x
	var origin := Vector2i((Vector2(170.0, 140.0) * scale).round())
	var size_px := Vector2i((Vector2(790.0, 360.0) * scale).round())
	origin.x = clampi(origin.x, 0, maxi(image.get_width() - size_px.x, 0))
	origin.y = clampi(origin.y, 0, maxi(image.get_height() - size_px.y, 0))
	var region := image.get_region(Rect2i(origin, size_px))
	var path := "%stask71_indicator_before_after_%dx%d.png" % [OUT_DIR, _resolution.x, _resolution.y]
	var error := region.save_png(path)
	assert(error == OK)
	_saved += 1
	print("saved %s" % path)
	await _teardown()


## Rebuilds the node the Task 71 C2 change retired, from the pre-Task-71
## scenes/combat/enemy_telegraph_indicator.tscn definition:
##   Label, offsets (-22,-34)-(22,8), font_size 40, colour (1,0.85,0.15),
##   outline colour (0.12,0.07,0), outline_size 7, text "!", centred.
## The retired tween oscillated the whole node between scale 0.95 and 1.08,
## so a still at scale 1.0 is representative of the midpoint.
func _attach_retired_label(enemy: CombatEnemy) -> void:
	var holder := Node2D.new()
	holder.position = enemy.telegraph_indicator.position
	holder.z_index = 10
	var mark := Label.new()
	mark.text = "!"
	mark.position = Vector2(-22.0, -34.0)
	mark.size = Vector2(44.0, 42.0)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override(&"font_size", 40)
	mark.add_theme_color_override(&"font_color", Color(1, 0.85, 0.15, 1))
	mark.add_theme_color_override(&"font_outline_color", Color(0.12, 0.07, 0, 1))
	mark.add_theme_constant_override(&"outline_size", 7)
	holder.add_child(mark)
	enemy.add_child(holder)


# ---------------------------------------------------------------------------
# Arena / capture plumbing (same shape as Task 69's capture script)
# ---------------------------------------------------------------------------
func _build_arena(form_id: StringName) -> void:
	_projectiles_seen = 0
	_melee_swings = 0
	_probe_outline = null
	_world = Node2D.new()
	root.add_child(_world)
	current_scene = _world
	_add_floor()
	_add_backdrop()

	_boss = BOSS_SCENE.instantiate() as BossTideEmber
	_boss.starting_form_id = form_id
	_boss.global_position = BOSS_ORIGIN
	_world.add_child(_boss)
	_boss.delivery_created.connect(func(delivery: Node) -> void:
		if delivery is ProjectileDelivery:
			_projectiles_seen += 1
		elif delivery is DelayedAreaDelivery:
			_melee_swings += 1
	)

	_player = PLAYER_SCENE.instantiate() as PlayerCharacter
	_player.global_position = BOSS_ORIGIN + Vector2(-300.0, 0.0)
	_world.add_child(_player)
	_boss.player = _player
	_boss.ai_enabled = true

	_overlay = Label.new()
	_overlay.add_theme_font_size_override(&"font_size", 20)
	_overlay.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.7))
	_overlay.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 1))
	_overlay.add_theme_constant_override(&"shadow_offset_x", 2)
	_overlay.add_theme_constant_override(&"shadow_offset_y", 2)
	_overlay.z_index = 200
	_world.add_child(_overlay)

	await _wait_frames(8)


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12000.0, 200.0)
	floor_shape.shape = rect
	floor_shape.position = Vector2(0.0, 100.0)
	floor_body.position = Vector2(0.0, FLOOR_TOP)
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)


func _add_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.07, 0.08, 0.12)
	backdrop.size = Vector2(12000.0, 4000.0)
	backdrop.position = Vector2(-2000.0, -1000.0)
	backdrop.z_index = -100
	_world.add_child(backdrop)


func _teardown() -> void:
	_world.queue_free()
	await process_frame
	await process_frame


func _pin_player(distance: float) -> void:
	_player.global_position = Vector2(_boss.global_position.x + distance, _boss.global_position.y)


func _set_overlay(lines: Array) -> void:
	_overlay.text = "\n".join(lines)
	_overlay.position = _boss.global_position + CROP_OFFSET + Vector2(8.0, 6.0)
	_overlay.size = Vector2(CROP_SIZE.x - 16.0, 150.0)


func _grab_cell() -> Image:
	await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var scale := float(image.get_width()) / root.get_visible_rect().size.x
	var size_px := Vector2i((CROP_SIZE * scale).round())
	var origin := Vector2i(((_boss.global_position + CROP_OFFSET) * scale).round())
	origin.x = clampi(origin.x, 0, maxi(image.get_width() - size_px.x, 0))
	origin.y = clampi(origin.y, 0, maxi(image.get_height() - size_px.y, 0))
	var cell := image.get_region(Rect2i(origin, size_px))
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return cell


func _save_sheet(base_name: String, cells: Array[Image]) -> void:
	if cells.is_empty():
		return
	var columns := mini(GRID_COLUMNS, cells.size())
	var rows := int(ceil(float(cells.size()) / float(columns)))
	var sheet := Image.create_empty(columns * CELL.x, rows * CELL.y, false, cells[0].get_format())
	sheet.fill(Color(0.02, 0.02, 0.03))
	for index: int in cells.size():
		var cell := cells[index]
		if cell.get_format() != sheet.get_format():
			cell.convert(sheet.get_format())
		sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL),
			Vector2i((index % columns) * CELL.x, (index / columns) * CELL.y))
	var path := "%s%s_%dx%d.png" % [OUT_DIR, base_name, _resolution.x, _resolution.y]
	var error := sheet.save_png(path)
	assert(error == OK)
	_saved += 1
	print("saved %s (%d cells, %dx%d grid)" % [path, cells.size(), columns, rows])


func _cast_segment_label() -> String:
	if _boss.sprite.animation != _boss._animation_name(&"cast"):
		return "-"
	if _boss.sprite.frame < BOSS_TUNING.ranged_cast_launch_frame_index:
		return "WINDUP"
	if _boss.sprite.frame == BOSS_TUNING.ranged_cast_launch_frame_index:
		return "LAUNCH"
	return "RECOVERY"


func _icon_sheet_name(indicator: EnemyTelegraphIndicator) -> String:
	var mark := indicator.get_node("Mark") as AnimatedSprite2D
	var frames := mark.sprite_frames
	if frames == null or not frames.has_animation(mark.animation):
		return "-"
	var texture := frames.get_frame_texture(mark.animation, maxi(mark.frame, 0))
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		return atlas.resource_path.get_file() if atlas != null else "-"
	return texture.resource_path.get_file() if texture != null else "-"


func _latest_delivery() -> DelayedAreaDelivery:
	var found: DelayedAreaDelivery = null
	for reference: WeakRef in _boss._active_deliveries:
		var node: Variant = reference.get_ref()
		if node is DelayedAreaDelivery and is_instance_valid(node):
			found = node
	return found


func _phase_name(delivery: DelayedAreaDelivery) -> String:
	if delivery == null:
		return "-"
	match delivery.delayed_phase:
		DelayedAreaDelivery.Phase.WAITING:
			return "WAITING"
		DelayedAreaDelivery.Phase.ACTIVE:
			return "ACTIVE"
		_:
			return "COMPLETE"


func _wait_frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for i: int in max_frames:
		await physics_frame
		if predicate.call():
			return true
	return false
