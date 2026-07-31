class_name FuryVfxPresentation
extends Node2D

const WATER_TINT := Color("71ddff")
const FIRE_TINT := Color("ff8a45")

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
	scale = Vector2.ONE * (visual_diameter / 64.0)
	sprite.modulate = WATER_TINT if element_id == ElementIds.WATER else FIRE_TINT
	sprite.frame = 0
	sprite.play(&"burst")
	return true


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)

