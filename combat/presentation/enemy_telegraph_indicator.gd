class_name EnemyTelegraphIndicator
extends Node2D

## Reusable "about to attack" warning shown above an enemy's head. Purely
## presentational -- callers own all timing decisions and just call
## start()/advance()/cancel(). Follows its parent automatically since it is
## mounted as a normal scene child.
##
## Task 71 C2 finally wires the real art that Task 60 delivered and Task 70
## extended: the placeholder `!` Label is gone, replaced by an
## AnimatedSprite2D driving the authored 3-frame bounce sheets (and their
## single-frame reduced-motion counterparts).
##
## Task 71 C3 adds the telegraph TYPE. Three consumers share this scene
## (scenes/enemy.tscn, scenes/run/enemies/tidal_sentry.tscn and the Boss), and
## only the Boss knows about melee/summon telegraphs, so the type is an
## OPTIONAL trailing argument on start() that defaults to RANGED -- the
## historical yellow-alert behavior. CombatEnemy._begin_ranged_attack_telegraph
## calls start(duration) with no type and therefore keeps behaving exactly as
## before for regular enemies and the tidal sentry.

signal telegraph_completed
signal telegraph_cancelled

## Which kind of attack this warning stands for. RANGED is first (== 0) on
## purpose: it is the default for every existing caller.
enum TelegraphType {
	RANGED,
	MELEE,
	SUMMON,
}

## Animation names authored in the scene's SpriteFrames. `<base>` is the
## 3-frame authored bounce, `<base>_static` the single-frame reduced-motion
## downgrade delivered alongside it.
const ANIMATION_BASE_NAMES := {
	TelegraphType.RANGED: &"ranged",
	TelegraphType.MELEE: &"melee",
	TelegraphType.SUMMON: &"summon",
}

## Length of the one-shot fade-in. Task 71 C2 forbids stacking the old
## scale tween's bounce on top of the sheet's own 3-frame bounce, so the
## looping scale pulse is gone and only this non-looping alpha pop-in
## survives -- it is a fade, not a second bounce.
const SHOW_FADE_DURATION := 0.08

@export var reduced_motion: bool = false
@export_range(1.0, 512.0, 0.001, "or_greater") var top_screen_margin: float = 28.0

var is_active: bool:
	get:
		return _is_active

## Type of the warning currently displayed. Reset to RANGED by every start()
## call that does not name a type, so a Boss melee/summon telegraph can never
## leak into the next ranged one.
var telegraph_type: TelegraphType:
	get:
		return _telegraph_type

var _is_active: bool = false
var _time_remaining: float = 0.0
var _tween: Tween
var _base_position_y: float = 0.0
var _telegraph_type: TelegraphType = TelegraphType.RANGED

@onready var _mark: AnimatedSprite2D = $Mark


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_base_position_y = position.y
	_apply_type_animation()


func _process(_delta: float) -> void:
	if visible:
		_clamp_to_viewport_margin()


func start(duration: float, kind: TelegraphType = TelegraphType.RANGED) -> bool:
	if not is_finite(duration) or duration <= 0.0:
		return false
	_telegraph_type = kind
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


## Explicit setter alternative to start()'s optional argument, for callers
## that want to re-skin an already-running telegraph.
func set_telegraph_type(kind: TelegraphType) -> void:
	if _telegraph_type == kind:
		return
	_telegraph_type = kind
	_apply_type_animation()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if _is_active:
		_play_show_animation()
	elif _mark != null:
		_apply_type_animation()


func _play_show_animation() -> void:
	_kill_tween()
	_apply_type_animation()
	scale = Vector2.ONE
	if reduced_motion:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, SHOW_FADE_DURATION)


func _stop_animation() -> void:
	_kill_tween()
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2.ONE
	if _mark != null:
		_mark.stop()


## Single place that decides which of the six authored clips is on screen.
## Reduced motion picks the `_static` single-frame variant and never plays,
## so the setting genuinely removes the motion instead of merely slowing it.
func _apply_type_animation() -> void:
	if _mark == null:
		return
	var base: StringName = ANIMATION_BASE_NAMES[_telegraph_type]
	if reduced_motion:
		var static_name := StringName("%s_static" % base)
		_mark.stop()
		_mark.animation = static_name
		_mark.frame = 0
		return
	_mark.animation = base
	_mark.play(base)


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
