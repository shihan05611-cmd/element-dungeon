class_name FuryVfxPresentation
extends Node2D

const WATER_TINT := Color("71ddff")
const FIRE_TINT := Color("ff8a45")
## burst_core.png's frame canvas is 64px, but the drawn flame only fills
## ~40px of it at its widest frame (measured, hard edge, no soft falloff) --
## scaling against the full 64px canvas made the rendered flame visibly
## smaller than the actual hit radius, and the gap grew with radius_scale
## since it was a constant proportional shortfall. Scale against the sprite's
## real peak content size instead so the drawn edge tracks the true radius.
const NATIVE_BURST_DIAMETER_PX := 40.0

@onready var sprite: AnimatedSprite2D = $Burst

var locked_element_id: StringName = &""
var authoritative_radius: float = 0.0
var playback_count: int = 0


func play_burst(origin: Vector2, radius: float, element_id: StringName) -> bool:
	if (
		not is_finite(radius)
		or radius <= 0.0
		or not ElementIds.is_combat_element(element_id)
	):
		return false
	global_position = origin
	authoritative_radius = radius
	locked_element_id = element_id
	playback_count += 1
	var visual_diameter := radius * 1.5
	scale = Vector2.ONE * (visual_diameter / NATIVE_BURST_DIAMETER_PX)
	sprite.modulate = WATER_TINT if element_id == ElementIds.WATER else FIRE_TINT
	sprite.frame = 0
	sprite.play(&"burst")
	return true


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)

