class_name EnemyTelegraphIndicator
extends Node2D

## Reusable "about to attack" warning shown above an enemy's head: a Dead
## Cells-style yellow "!" (placeholder Label glyph; Task 60 owns the real
## art). Purely presentational — callers own all timing decisions and just
## call start()/advance()/cancel(). Follows its parent automatically since it
## is mounted as a normal scene child.

signal telegraph_completed
signal telegraph_cancelled

@export var reduced_motion: bool = false
@export_range(1.0, 512.0, 0.001, "or_greater") var top_screen_margin: float = 28.0

var is_active: bool:
	get:
		return _is_active

var _is_active: bool = false
var _time_remaining: float = 0.0
var _tween: Tween
var _base_position_y: float = 0.0

@onready var _mark: Label = $Mark


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_base_position_y = position.y


func _process(_delta: float) -> void:
	if visible:
		_clamp_to_viewport_margin()


func start(duration: float) -> bool:
	if not is_finite(duration) or duration <= 0.0:
		return false
	_is_active = true
	_time_remaining = duration
	visible = true
	position.y = _base_position_y
	_play_show_animation()
	return true


func advance(delta: float) -> void:
	if not _is_active or not is_finite(delta) or delta <= 0.0:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_is_active = false
		visible = false
		_stop_animation()
		telegraph_completed.emit()


func cancel() -> void:
	if not _is_active:
		return
	_is_active = false
	_time_remaining = 0.0
	visible = false
	_stop_animation()
	telegraph_cancelled.emit()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if _is_active:
		_play_show_animation()


func _play_show_animation() -> void:
	_kill_tween()
	if reduced_motion:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = Vector2.ONE
		return
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(self, "modulate:a", 1.0, 0.08)
	_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.16).set_trans(Tween.TRANS_SINE)


func _stop_animation() -> void:
	_kill_tween()
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2.ONE


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Keeps the mark from being clipped when the enemy's head is near the top of
## the screen: if the current camera transform would draw it above
## top_screen_margin, nudge this node's local Y down just enough to sit at
## the margin instead. Exposed so tests can call it without a real frame.
func _clamp_to_viewport_margin() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var canvas_transform := viewport.get_canvas_transform()
	var screen_position := canvas_transform * global_position
	if screen_position.y >= top_screen_margin:
		return
	var inverse := canvas_transform.affine_inverse()
	var corrected_world := inverse * Vector2(screen_position.x, top_screen_margin)
	position.y += corrected_world.y - global_position.y
