extends Node2D
## Dev-only harness for previewing the fully procedural LaserVfxPresentation
## without a combat run. Not referenced by gameplay, catalog or tests.
##
## It fakes an ElementBeamDelivery with `.new()` (never entered into the tree),
## which is enough for `configure()` / `_follow_delivery()` -- those only read
## `global_position`, `direction` and `is_finished`.
##
## Controls:
##   Space        pulse both beams once (per-tick brighten + hit flashes)
##   A            toggle auto-pulse (0.5s cadence, on by default)
##   Left / Right  rotate both beams to check rotation-follow
##   B            toggle the nominal 320x24 beam bounds overlay
##   R            rebuild (re-seed the beams, straighten direction)

const LaserScript := preload("res://scripts/vfx/laser_vfx_presentation.gd")
const DeliveryScript := preload("res://combat/delivery/element_beam_delivery.gd")

const FIRE_ORIGIN := Vector2(190.0, 210.0)
const WATER_ORIGIN := Vector2(190.0, 430.0)
const AUTO_INTERVAL := 0.5

@onready var _hint: Label = $Hint

var _keep_deliveries: Array = []
var _auto_pulse := true
var _show_bounds := false
var _angle := 0.0
var _auto_timer: Timer


func _ready() -> void:
	_auto_timer = Timer.new()
	_auto_timer.wait_time = AUTO_INTERVAL
	add_child(_auto_timer)
	_auto_timer.timeout.connect(_pulse_all)
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		if child is LaserVfxPresentation:
			child.stop()
	_keep_deliveries.clear()
	_angle = 0.0
	_spawn(&"fire", FIRE_ORIGIN)
	_spawn(&"water", WATER_ORIGIN)
	_apply_auto()
	queue_redraw()
	_refresh_hint()


func _spawn(element_id: StringName, origin: Vector2) -> void:
	var delivery := DeliveryScript.new()
	delivery.global_position = origin
	delivery.set(&"_direction", Vector2.RIGHT)
	_keep_deliveries.append(delivery)
	var laser := LaserScript.new()
	add_child(laser)
	if not laser.configure(delivery, element_id):
		push_error("laser_vfx_preview: configure failed for %s" % element_id)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			_pulse_all()
		KEY_A:
			_auto_pulse = not _auto_pulse
			_apply_auto()
			_refresh_hint()
		KEY_LEFT:
			_rotate(-0.15)
		KEY_RIGHT:
			_rotate(0.15)
		KEY_B:
			_show_bounds = not _show_bounds
			queue_redraw()
			_refresh_hint()
		KEY_R:
			_rebuild()


func _rotate(delta_angle: float) -> void:
	_angle += delta_angle
	var facing := Vector2.RIGHT.rotated(_angle)
	for delivery: Object in _keep_deliveries:
		if is_instance_valid(delivery):
			delivery.set(&"_direction", facing)
	queue_redraw()
	_refresh_hint()


func _pulse_all() -> void:
	for child: Node in get_children():
		var laser := child as LaserVfxPresentation
		if laser == null:
			continue
		var basis := Transform2D(laser.rotation, laser.global_position)
		var targets: Array[Vector2] = [
			basis * Vector2(120.0, 0.0),
			basis * Vector2(240.0, 0.0),
		]
		laser.pulse(targets)


func _apply_auto() -> void:
	if _auto_pulse:
		_auto_timer.start()
	else:
		_auto_timer.stop()


func _process(_delta: float) -> void:
	if _show_bounds:
		queue_redraw()


func _draw() -> void:
	if not _show_bounds:
		return
	for origin: Vector2 in [FIRE_ORIGIN, WATER_ORIGIN]:
		var basis := Transform2D(_angle, origin)
		var corners := PackedVector2Array([
			basis * Vector2(0.0, -12.0),
			basis * Vector2(320.0, -12.0),
			basis * Vector2(320.0, 12.0),
			basis * Vector2(0.0, 12.0),
		])
		draw_polyline(corners + PackedVector2Array([corners[0]]), Color(1, 1, 1, 0.35), 1.0)


func _refresh_hint() -> void:
	if _hint == null:
		return
	_hint.text = "\n".join([
		"LaserVfxPresentation preview",
		"Space  pulse   A  auto-pulse: %s" % ("on" if _auto_pulse else "off"),
		"Left/Right  rotate (%.0f deg)   B  bounds: %s   R  rebuild" % [
			rad_to_deg(_angle), "on" if _show_bounds else "off",
		],
	])
