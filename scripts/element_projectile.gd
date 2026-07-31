class_name ElementProjectile
extends ProjectileDelivery

@export var water_color := Color("58d9ff")
@export var fire_color := Color("ff754f")

@onready var projectile_sprite := get_node_or_null("ProjectileSprite") as AnimatedSprite2D

var locked_element_color: Color:
	get:
		return _element_color

var locked_presentation_tags: PackedStringArray:
	get:
		return _locked_presentation_tags.duplicate()

var _element_color := Color.WHITE
var _locked_presentation_tags: PackedStringArray = PackedStringArray()


func _on_delivery_ready() -> void:
	_locked_presentation_tags = payload.presentation_tags if payload != null else PackedStringArray()
	var animation_name: StringName = &""
	if payload != null and payload.element_id == ElementIds.WATER:
		_element_color = water_color
		animation_name = &"water"
	elif payload != null and payload.element_id == ElementIds.FIRE:
		_element_color = fire_color
		animation_name = &"fire"
	else:
		_element_color = Color("f4f1df")
	_play_projectile_animation(animation_name)
	super()


func _on_delivery_cleanup() -> void:
	_element_color = Color.WHITE
	_locked_presentation_tags = PackedStringArray()
	if projectile_sprite != null:
		projectile_sprite.stop()
		projectile_sprite.visible = false
		projectile_sprite.frame = 0
		projectile_sprite.rotation = 0.0
	super()


func _play_projectile_animation(animation_name: StringName) -> void:
	if (
		projectile_sprite == null
		or animation_name.is_empty()
		or not projectile_sprite.sprite_frames.has_animation(animation_name)
	):
		return
	projectile_sprite.rotation = direction.angle() - global_rotation
	projectile_sprite.visible = true
	projectile_sprite.play(animation_name)
