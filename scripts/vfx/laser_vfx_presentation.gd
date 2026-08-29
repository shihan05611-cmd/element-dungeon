class_name LaserVfxPresentation
extends Node2D

## Fully procedural sustained-beam presentation. It owns no beam textures: the
## haze, body, inner glow, hot core, travelling energy pulses, muzzle flare and
## drifting motes are all rebuilt every frame in `_draw()` from the authoritative
## geometry reported by `ElementBeamDelivery`. Only the per-target hit pulse
## still uses an authored sprite sheet.

const WATER_TICK_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/laser_tick_water_frames.tres"
)
const FIRE_TICK_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/laser_tick_fire_frames.tres"
)

const BEAM_LENGTH := 320.0
const BEAM_WIDTH := 24.0
const BAND_SAMPLES := 32
const MOTE_LIMIT := 40

# Per-element tint stops, ordered from the soft outer haze to the white-hot core.
const WATER_PALETTE := {
	"haze": Color(0.20, 0.55, 1.00),
	"body": Color(0.35, 0.75, 1.00),
	"inner": Color(0.65, 0.90, 1.00),
	"core": Color(0.90, 0.98, 1.00),
	"mote_a": Color(0.55, 0.85, 1.00),
	"mote_b": Color(0.95, 1.00, 1.00),
}
const FIRE_PALETTE := {
	"haze": Color(1.00, 0.35, 0.10),
	"body": Color(1.00, 0.55, 0.15),
	"inner": Color(1.00, 0.78, 0.35),
	"core": Color(1.00, 0.95, 0.75),
	"mote_a": Color(1.00, 0.55, 0.15),
	"mote_b": Color(1.00, 0.90, 0.55),
}

var locked_element_id: StringName = &""
var pulse_count: int = 0

var _delivery_ref: WeakRef
var _is_fire: bool = false
var _palette: Dictionary = WATER_PALETTE
var _time: float = 0.0
var _seed: float = 0.0
var _pulse_energy: float = 0.0
var _mote_accum: float = 0.0
var _motes: Array[Dictionary] = []
var _glow_tex: GradientTexture2D


func configure(delivery: ElementBeamDelivery, element_id: StringName) -> bool:
	if (
		delivery == null
		or not is_instance_valid(delivery)
		or not ElementIds.is_combat_element(element_id)
	):
		return false
	_delivery_ref = weakref(delivery)
	locked_element_id = element_id
	_is_fire = element_id == ElementIds.FIRE
	_palette = FIRE_PALETTE if _is_fire else WATER_PALETTE
	_seed = randf() * 100.0
	_glow_tex = _build_radial_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	modulate = Color.WHITE
	_follow_delivery()
	set_process(true)
	queue_redraw()
	return true


func pulse(target_positions: Array[Vector2]) -> void:
	pulse_count += 1
	_pulse_energy = 1.0
	for target_position: Vector2 in target_positions:
		_spawn_target_flash(target_position)
	queue_redraw()


func stop() -> void:
	set_process(false)
	queue_free()


func visual_size() -> Vector2:
	return Vector2(BEAM_LENGTH, BEAM_WIDTH)


func _process(delta: float) -> void:
	if not _follow_delivery():
		stop()
		return
	_time += delta
	_pulse_energy = maxf(0.0, _pulse_energy - delta * 5.5)
	_advance_motes(delta)
	queue_redraw()


func _follow_delivery() -> bool:
	var delivery := (
		_delivery_ref.get_ref() as ElementBeamDelivery
		if _delivery_ref != null
		else null
	)
	if (
		delivery == null
		or not is_instance_valid(delivery)
		or delivery.is_queued_for_deletion()
		or delivery.is_finished
	):
		return false
	global_position = delivery.global_position
	rotation = delivery.direction.angle()
	return true


func _draw() -> void:
	if _glow_tex == null:
		return
	var energy := _pulse_energy
	var bright := 0.80 + 0.75 * energy
	var half := BEAM_WIDTH * 0.5
	var flicker := 0.85 + 0.15 * sin(_time * 38.0 + _seed)

	# Outer haze -- soft falloff around the beam, tapers slightly toward the far tip.
	_emit_band(
		func(t: float) -> float:
			return half * (1.35 + 0.4 * energy) - t * half * 0.45 + _edge_offset(t, 2.0),
		_palette["haze"],
		0.13 + 0.1 * energy,
		bright
	)
	# Body -- the main coloured column.
	_emit_band(
		func(t: float) -> float:
			return half * (0.95 + 0.12 * energy) * flicker + _edge_offset(t, 1.7) - t * half * 0.12,
		_palette["body"],
		0.54 + 0.28 * energy,
		bright
	)
	# Inner glow -- brighter, tighter, blends body toward the core.
	_emit_band(
		func(t: float) -> float:
			return half * 0.55 * flicker + _edge_offset(t, 0.6),
		_palette["inner"],
		0.55 + 0.28 * energy,
		bright
	)
	# Hot core -- near white, almost straight (fire keeps a faint jitter).
	var core_jitter := 0.28 if _is_fire else 0.0
	_emit_band(
		func(t: float) -> float:
			return maxf(1.5, half * 0.22 * (0.8 + 0.2 * flicker)) + _edge_offset(t, core_jitter),
		_palette["core"],
		0.85 + 0.15 * energy,
		bright
	)

	_draw_energy_pulses(half, energy)
	_draw_muzzle(half)
	_draw_motes()


func _emit_band(half_at: Callable, tint: Color, base_alpha: float, bright: float) -> void:
	var last := BAND_SAMPLES - 1
	for i in range(last):
		var t0 := float(i) / float(last)
		var t1 := float(i + 1) / float(last)
		var x0 := t0 * BEAM_LENGTH
		var x1 := t1 * BEAM_LENGTH
		var raw0: float = half_at.call(t0)
		var raw1: float = half_at.call(t1)
		var h0 := maxf(0.0, raw0)
		var h1 := maxf(0.0, raw1)
		var a0 := clampf(base_alpha * bright * _end_fade(t0), 0.0, 1.0)
		var a1 := clampf(base_alpha * bright * _end_fade(t1), 0.0, 1.0)
		var c0 := Color(tint.r, tint.g, tint.b, a0)
		var c1 := Color(tint.r, tint.g, tint.b, a1)
		var quad := PackedVector2Array([
			Vector2(x0, -h0), Vector2(x1, -h1), Vector2(x1, h1), Vector2(x0, h0)
		])
		draw_polygon(quad, PackedColorArray([c0, c1, c1, c0]))


func _draw_energy_pulses(half: float, energy: float) -> void:
	var count := 4
	var speed := 360.0 if _is_fire else 250.0
	var core: Color = _palette["core"]
	for k in range(count):
		var px := fmod(
			_time * speed + float(k) * BEAM_LENGTH / float(count) + _seed * 40.0,
			BEAM_LENGTH
		)
		var t := px / BEAM_LENGTH
		var fade := _end_fade(t)
		if fade <= 0.01:
			continue
		var size := half * (1.2 + 1.1 * energy) * fade
		var alpha := clampf((0.3 + 0.35 * energy) * fade, 0.0, 1.0)
		_blit_glow(Vector2(px, 0.0), size, Color(core.r, core.g, core.b, alpha))


func _draw_muzzle(half: float) -> void:
	# One steady, condensed energy core at the emitter. It is deliberately
	# constant -- it does NOT react to the per-tick hit pulse, only the beam
	# does. No star, no scattered sparks.
	var body: Color = _palette["body"]
	var core: Color = _palette["core"]
	_blit_glow(Vector2.ZERO, half * 2.8, Color(body.r, body.g, body.b, 0.18))
	_blit_glow(Vector2.ZERO, half * 2.1, Color(core.r, core.g, core.b, 0.42))
	_blit_glow(Vector2.ZERO, half * 1.5, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2.ZERO, half * 1.05, Color(1.0, 1.0, 1.0, 1.0), true, -1.0, true)


func _draw_motes() -> void:
	for mote: Dictionary in _motes:
		var life: float = clampf(mote["life"] / mote["max_life"], 0.0, 1.0)
		var size: float = mote["size"] * (0.35 + 0.65 * life)
		var tint: Color = mote["color"]
		_blit_glow(mote["pos"], size, Color(tint.r, tint.g, tint.b, 0.6 * life))


func _blit_glow(center: Vector2, radius: float, tint: Color) -> void:
	if radius <= 0.1 or tint.a <= 0.01:
		return
	var rect := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	draw_texture_rect(_glow_tex, rect, false, tint)


func _edge_offset(t: float, amplitude: float) -> float:
	if amplitude <= 0.0:
		return 0.0
	var x := t * BEAM_LENGTH
	if _is_fire:
		var n0 := sin(x * 0.70 + _seed) * sin(x * 0.31 - _time * 22.0)
		var n1 := sin(x * 1.90 - _seed * 3.0 + _time * 30.0)
		return (n0 * 0.6 + n1 * 0.4) * amplitude
	var w0 := sin(x * 0.05 - _time * 6.0 + _seed)
	var w1 := sin(x * 0.13 + _time * 3.0)
	return (w0 * 0.7 + w1 * 0.3) * amplitude


func _end_fade(t: float) -> float:
	# Ramp up out of the muzzle core, then disperse toward the far end -- the
	# beam is piercing and simply thins out, there is no terminating node.
	return smoothstep(0.0, 0.03, t) * smoothstep(1.0, 0.8, t)


func _advance_motes(delta: float) -> void:
	_mote_accum += delta
	var interval := 0.045 if _is_fire else 0.085
	while _mote_accum >= interval:
		_mote_accum -= interval
		if _motes.size() < MOTE_LIMIT:
			_motes.append(_make_mote())
	for i in range(_motes.size() - 1, -1, -1):
		var mote: Dictionary = _motes[i]
		mote["life"] -= delta
		if mote["life"] <= 0.0:
			_motes.remove_at(i)
			continue
		mote["pos"] += mote["velocity"] * delta


func _make_mote() -> Dictionary:
	var along := randf() * BEAM_LENGTH
	var offset := randf_range(-BEAM_WIDTH * 0.4, BEAM_WIDTH * 0.4)
	var blend := randf()
	var color: Color = (_palette["mote_a"] as Color).lerp(_palette["mote_b"], blend)
	if _is_fire:
		return {
			"pos": Vector2(along, offset),
			"velocity": Vector2(randf_range(15.0, 70.0), randf_range(-72.0, -28.0)),
			"life": randf_range(0.40, 0.70),
			"max_life": 0.70,
			"size": randf_range(2.0, 4.2),
			"color": color,
		}
	return {
		"pos": Vector2(along, offset),
		"velocity": Vector2(randf_range(-12.0, 22.0), randf_range(18.0, 52.0)),
		"life": randf_range(0.30, 0.55),
		"max_life": 0.55,
		"size": randf_range(1.6, 3.2),
		"color": color,
	}


func _build_radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.75))
	gradient.set_offset(gradient.get_point_count() - 1, 1.0)
	gradient.set_color(gradient.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _spawn_target_flash(target_position: Vector2) -> void:
	var flash := AnimatedSprite2D.new()
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.sprite_frames = WATER_TICK_FRAMES if not _is_fire else FIRE_TICK_FRAMES
	flash.animation = &"tick"
	flash.z_index = 3
	add_child(flash)
	flash.top_level = true
	flash.global_position = target_position
	flash.animation_finished.connect(flash.queue_free)
	flash.play()


func _exit_tree() -> void:
	_delivery_ref = null
	_motes.clear()
