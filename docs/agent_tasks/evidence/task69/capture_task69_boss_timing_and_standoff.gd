extends SceneTree

## Task 69 §5.3 visual evidence. Builds a minimal but *real* arena (formal
## Boss scene + formal player scene + a floor) and records four frame-by-frame
## sequences as annotated contact sheets, at both L2 resolutions:
##
##   1. one complete melee swing  -- windup start / ! window / impact frame /
##      the frame DelayedAreaDelivery goes ACTIVE, all readable per cell;
##   2. one complete ranged attack -- charge-up pose during the telegraph and
##      the impact pose on the frame the bolts spawn;
##   3. a walk loop (crop follows the Boss, so anything that changes between
##      cells is animation, never translation);
##   4. a 10s point-blank stand-off -- zero ranged shots, and melee output
##      recurring on the accelerated cooldown (no dead window).
##
## Every cell carries an on-screen overlay with the values actually measured
## on that frame, so the contact sheets are self-annotating rather than
## relying on this script's own frame arithmetic.
##
## Run (not headless -- a real framebuffer is required):
##   Godot_v4.7.1 --path . --display-driver windows --audio-driver Dummy \
##     --resolution 1920x1080 \
##     --script res://docs/agent_tasks/evidence/task69/capture_task69_boss_timing_and_standoff.gd

const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const BOSS_TUNING: BossTuning = preload("res://resources/run/enemies/boss_forms/boss_tuning.tres")
const OUT_DIR := "res://docs/agent_tasks/evidence/task69/screenshots/"

## The project stretches "canvas_items" from a 1152x648 base viewport onto the
## window, so world/canvas units are NOT framebuffer pixels: the arena is laid
## out in canvas units and _grab_cell() converts to pixels via the measured
## framebuffer / visible-rect ratio. Laying the arena out at raw framebuffer
## coordinates would push the Boss off the bottom of the canvas entirely.
const BOSS_ORIGIN := Vector2(400.0, 430.0)
const FLOOR_TOP := 462.0
const CELL := Vector2i(360, 400)
## Crop window in canvas units, relative to the Boss origin: wide enough for
## the attack sheet's widest frame, tall enough for the ! indicator at y-240
## and the overlay banner.
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


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		_resolution = resolution
		root.size = resolution
		await _wait_frames(6)
		print("=== resolution %dx%d ===" % [resolution.x, resolution.y])
		await _sequence_melee()
		await _sequence_ranged()
		await _sequence_walk()
		await _sequence_point_blank()
	print("TASK69 CAPTURE PASSED: %d files" % _saved)
	quit(0)


# ---------------------------------------------------------------------------
# Sequences
# ---------------------------------------------------------------------------
func _sequence_melee() -> void:
	await _build_arena(&"ember")
	var form := _boss.current_form
	_boss._boss_projectile_cooldown = 999.0
	_pin_player(60.0)
	_boss.attack_cooldown = 0.0
	var started := await _wait_until(func() -> bool: return _boss.attack_time > 0.0, 120)
	print("melee: swing_started=%s telegraph=%.3fs windup=%.3fs recovery=%.3fs" % [
		started, form.melee_telegraph_duration, _boss.attack_windup_duration(), _boss.attack_recovery_duration()])
	var cells: Array[Image] = []
	# attack_time is the Boss's own swing clock and counts down from the full
	# attack length, so elapsed derived from it is exact regardless of how many
	# physics frames each framebuffer readback happens to span.
	var total := _boss.attack_time
	var impact_cell := -1
	var active_cell := -1
	for index: int in 28:
		# The swing knocks the player back; re-pin so the Boss keeps facing a
		# target at a constant 60px instead of drifting into a chase.
		_pin_player(60.0)
		var elapsed := total - _boss.attack_time
		var delivery := _latest_delivery()
		var phase := _phase_name(delivery)
		if active_cell < 0 and phase == "ACTIVE":
			active_cell = index
		if impact_cell < 0 and _boss.sprite.frame >= BOSS_TUNING.melee_attack_impact_frame_index:
			impact_cell = index
		_set_overlay([
			"MELEE  cell %02d  swing t=%.3fs" % [index, elapsed],
			"anim=%s  frame=%d/%d" % [_boss.sprite.animation, _boss.sprite.frame, _boss.sprite.sprite_frames.get_frame_count(_boss.sprite.animation) - 1],
			"segment=%s" % _segment_label(),
			# The ! window and the hitbox share one clock: DelayedAreaDelivery
			# WAITING == telegraph, ACTIVE == damage live.
			"! telegraph=%s   hitbox=%s" % [_telegraph_label(delivery), phase],
			"attack_time=%.3f" % _boss.attack_time,
		])
		cells.append(await _grab_cell())
	print("melee: impact_frame_first_seen_cell=%d hitbox_active_first_seen_cell=%d" % [impact_cell, active_cell])
	_save_sheet("task69_melee_sequence", cells)
	# Authoritative measurement, taken WITHOUT framebuffer readbacks: stalling
	# the renderer to grab a cell inflates real time per physics frame, and the
	# sprite clock is real-time driven, so the contact sheet's cell index runs
	# a few percent ahead of pure game time. This second swing runs at native
	# speed and reports where the sprite actually is when damage goes live.
	# Wait for a NEW swing: the previous one's delivery is still tracked and
	# already past WAITING, so probing "the latest delivery" alone would read
	# the stale one and report a zero-length telegraph.
	var swings_before := _melee_swings
	for i: int in 240:
		_pin_player(60.0)
		_boss.attack_cooldown = 0.0
		await physics_frame
		if _melee_swings > swings_before:
			break
	var probe := _latest_delivery()
	var frames_waited := 0
	while is_instance_valid(probe) and probe.delayed_phase == DelayedAreaDelivery.Phase.WAITING and frames_waited < 240:
		_pin_player(60.0)
		await physics_frame
		frames_waited += 1
	print("melee(no-readback): hitbox went ACTIVE after %d physics frames (%.3fs), sprite frame=%d, configured impact index=%d" % [
		frames_waited, float(frames_waited) * _boss.get_physics_process_delta_time(),
		_boss.sprite.frame, BOSS_TUNING.melee_attack_impact_frame_index])
	await _teardown()


func _sequence_ranged() -> void:
	await _build_arena(&"ember")
	var profile := _boss.current_form.ranged_projectile_profile
	_pin_player(420.0)
	_boss.attack_cooldown = 999.0
	_boss._boss_projectile_cooldown = 0.0
	var started := await _wait_until(func() -> bool: return _boss._telegraph_active, 120)
	print("ranged: telegraph_started=%s telegraph=%.3fs windup=%.3fs speed_scale=%.3f" % [
		started, profile.telegraph_duration, _boss.attack_windup_duration(), _boss.sprite.speed_scale])
	var cells: Array[Image] = []
	var telegraph_total := _boss._telegraph_time_remaining
	var launch_cell := -1
	for index: int in 32:
		_pin_player(420.0)
		var elapsed := (telegraph_total - _boss._telegraph_time_remaining) if _boss._telegraph_active else (telegraph_total + _boss.attack_recovery_duration() - _boss.attack_time)
		if launch_cell < 0 and _projectiles_seen > 0:
			launch_cell = index
		_set_overlay([
			"RANGED  cell %02d  cycle t=%.3fs" % [index, elapsed],
			"anim=%s  frame=%d/%d" % [_boss.sprite.animation, _boss.sprite.frame, _boss.sprite.sprite_frames.get_frame_count(_boss.sprite.animation) - 1],
			"phase=%s" % ("CHARGE (telegraph)" if _boss._telegraph_active else ("LAUNCH/RECOVER" if _boss.attack_time > 0.0 else "idle/walk")),
			"speed_scale=%.3f  bolts_spawned=%d" % [_boss.sprite.speed_scale, _projectiles_seen],
			"telegraph_left=%.3f  attack_time=%.3f" % [_boss._telegraph_time_remaining, _boss.attack_time],
		])
		cells.append(await _grab_cell())
	print("ranged: first_cell_with_bolts=%d total_bolts=%d" % [launch_cell, _projectiles_seen])
	_save_sheet("task69_ranged_sequence", cells)
	# Same no-readback control run for the ranged cycle.
	await _wait_until(func() -> bool: return _boss.attack_time <= 0.0, 240)
	var bolts_before := _projectiles_seen
	_boss._boss_projectile_cooldown = 0.0
	var windup_frames := 0
	await _wait_until(func() -> bool: return _boss._telegraph_active, 120)
	var charge_frame_seen := _boss.sprite.frame
	var charge_anim := _boss.sprite.animation
	while _boss._telegraph_active and windup_frames < 240:
		_pin_player(420.0)
		await physics_frame
		windup_frames += 1
	print("ranged(no-readback): charge started on anim=%s frame=%d; telegraph ran %d physics frames (%.3fs); at launch sprite frame=%d, bolts=%d" % [
		charge_anim, charge_frame_seen, windup_frames,
		float(windup_frames) * _boss.get_physics_process_delta_time(),
		_boss.sprite.frame, _projectiles_seen - bolts_before])
	await _teardown()


func _sequence_walk() -> void:
	await _build_arena(&"ember")
	_boss.attack_cooldown = 999.0
	_boss._boss_projectile_cooldown = 999.0
	# Park the player far to the right so the Boss simply chases/walks.
	_player.global_position = _boss.global_position + Vector2(900.0, 0.0)
	await _wait_until(func() -> bool: return _boss.sprite.animation == _boss._animation_name(&"walk"), 120)
	var cells: Array[Image] = []
	var walk_frames: Array[int] = []
	var start_x := _boss.global_position.x
	for index: int in 32:
		_player.global_position = _boss.global_position + Vector2(900.0, 0.0)
		_set_overlay([
			"WALK  cell %02d" % index,
			"anim=%s  frame=%d/%d" % [_boss.sprite.animation, _boss.sprite.frame, _boss.sprite.sprite_frames.get_frame_count(_boss.sprite.animation) - 1],
			"crop follows the Boss:",
			"any change between cells is animation,",
			"travelled=%.0fpx" % (_boss.global_position.x - start_x),
		])
		cells.append(await _grab_cell())
		if not walk_frames.has(_boss.sprite.frame):
			walk_frames.append(_boss.sprite.frame)
	print("walk: distinct sprite frames observed across %d cells = %s (travelled %.0fpx)" % [
		cells.size(), str(walk_frames), _boss.global_position.x - start_x])
	_save_sheet("task69_walk_loop", cells)
	await _teardown()


func _sequence_point_blank() -> void:
	await _build_arena(&"ember")
	var form := _boss.current_form
	_boss._boss_projectile_cooldown = 0.0
	_boss.attack_cooldown = form.attack_cooldown
	var cells: Array[Image] = []
	var elapsed := 0.0
	var last_swing_at := 0.0
	var longest_gap := 0.0
	var swings_before := 0
	for index: int in 40:
		# 15 physics frames == 0.25s of game time between cells.
		for step: int in 15:
			_pin_player(60.0)
			await physics_frame
			elapsed += _boss.get_physics_process_delta_time()
			if _melee_swings > swings_before:
				longest_gap = maxf(longest_gap, elapsed - last_swing_at)
				last_swing_at = elapsed
				swings_before = _melee_swings
		_set_overlay([
			"POINT-BLANK  cell %02d  t=%.2fs" % [index, elapsed],
			"distance=60px  (ring=%.0fpx)" % form.ranged_minimum_distance,
			"ranged volleys=%d   bolts=%d" % [_boss.boss_projectiles_fired, _projectiles_seen],
			"melee swings=%d   cooldown=%.2fs" % [_melee_swings, _boss.attack_cooldown],
			"longest gap between swings=%.2fs" % longest_gap,
		])
		cells.append(await _grab_cell())
	longest_gap = maxf(longest_gap, elapsed - last_swing_at)
	print("point_blank: elapsed=%.2fs ranged_volleys=%d bolts=%d melee_swings=%d longest_gap=%.2fs effective_cooldown=%.2fs" % [
		elapsed, _boss.boss_projectiles_fired, _projectiles_seen, _melee_swings, longest_gap,
		form.attack_cooldown * form.melee_cooldown_close_range_scale])
	_save_sheet("task69_point_blank_standoff", cells)
	await _teardown()


# ---------------------------------------------------------------------------
# Arena / capture plumbing
# ---------------------------------------------------------------------------
func _build_arena(form_id: StringName) -> void:
	_projectiles_seen = 0
	_melee_swings = 0
	_world = Node2D.new()
	root.add_child(_world)
	current_scene = _world

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

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.07, 0.08, 0.12)
	backdrop.size = Vector2(12000.0, 4000.0)
	backdrop.position = Vector2(-2000.0, -1000.0)
	backdrop.z_index = -100
	_world.add_child(backdrop)

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


## One captured cell: advance a physics frame, let the frame render, read the
## framebuffer back and crop a Boss-centred window out of it.
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
	# Every cell is normalised to one grid slot, so the 1920x1080 and 2560x1440
	# sheets stay directly comparable despite the different framebuffer scales.
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return cell


func _save_sheet(base_name: String, cells: Array[Image]) -> void:
	if cells.is_empty():
		return
	var columns := GRID_COLUMNS
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


## Only meaningful while the attack clip is playing; walk/idle frames share
## the same frame indices and would otherwise be mislabelled.
func _segment_label() -> String:
	if _boss.sprite.animation != _boss._animation_name(&"attack"):
		return "-"
	if _boss.sprite.frame < BOSS_TUNING.melee_attack_impact_frame_index:
		return "WINDUP"
	if _boss.sprite.frame == BOSS_TUNING.melee_attack_impact_frame_index:
		return "IMPACT"
	return "RECOVERY"


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


func _telegraph_label(delivery: DelayedAreaDelivery) -> String:
	if delivery != null and delivery.delayed_phase == DelayedAreaDelivery.Phase.WAITING:
		return "ON"
	return "off"


func _wait_frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for i: int in max_frames:
		await physics_frame
		if predicate.call():
			return true
	return false
