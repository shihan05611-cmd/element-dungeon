class_name ElementReactionVisual
extends Node2D

const WATER := &"water"
const FIRE := &"fire"
const MAX_STRENGTH_TIER := 3
const LIFETIME_SECONDS := 0.42

@onready var consumed_sprite: AnimatedSprite2D = $ConsumedElement
@onready var attacking_sprite: AnimatedSprite2D = $AttackingElement
@onready var center_flash: Polygon2D = $CenterFlash

var source_element_id: StringName = &""
var consumed_element_id: StringName = &""
var strength_tier: int = 1
var reduced_motion: bool = false
var phase_order: PackedStringArray = PackedStringArray()
var local_hit_offset: Vector2 = Vector2.ZERO

var _target_ref: WeakRef
var _following_target: bool = false


func follow_target(target: Node2D, hit_offset: Vector2) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree():
		return
	local_hit_offset = hit_offset
	_target_ref = weakref(target)
	_following_target = true
	global_position = target.to_global(local_hit_offset)


func _process(_delta: float) -> void:
	if not _following_target:
		return
	var target := _target_ref.get_ref() as Node2D if _target_ref != null else null
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree():
		_following_target = false
		_target_ref = null
		return
	global_position = target.to_global(local_hit_offset)


func configure(element_id: StringName, consumed_layers: int, motion_reduced: bool) -> void:
	source_element_id = element_id
	consumed_element_id = FIRE if source_element_id == WATER else WATER
	strength_tier = clampi(consumed_layers, 1, MAX_STRENGTH_TIER)
	reduced_motion = motion_reduced
	phase_order = PackedStringArray([
		String(consumed_element_id),
		String(source_element_id),
	])
	_apply_element_frames()
	if reduced_motion:
		_play_reduced_motion()
	else:
		_play_composition()


func _apply_element_frames() -> void:
	var water_frames := preload("res://resources/vfx/unending_trigger_frames.tres") as SpriteFrames
	var fire_frames := preload("res://resources/vfx/burning_tick_frames.tres") as SpriteFrames
	consumed_sprite.sprite_frames = water_frames if consumed_element_id == WATER else fire_frames
	attacking_sprite.sprite_frames = water_frames if source_element_id == WATER else fire_frames
	consumed_sprite.animation = &"trigger"
	attacking_sprite.animation = &"trigger"


func _play_composition() -> void:
	var tier_scale := [0.0, 1.15, 1.45, 1.75][strength_tier] as float
	var phase_delay := [0.0, 0.13, 0.105, 0.08][strength_tier] as float
	var brightness := [0.0, 0.82, 1.0, 1.2][strength_tier] as float
	var approach_x := -34.0 if consumed_element_id == WATER else 34.0
	consumed_sprite.position = Vector2(approach_x, 0.0)
	consumed_sprite.scale = Vector2.ONE * tier_scale * 1.12
	consumed_sprite.modulate = Color(brightness, brightness, brightness, 0.95)
	consumed_sprite.rotation = -0.12 if consumed_element_id == WATER else 0.12
	consumed_sprite.play(&"trigger")
	consumed_sprite.frame = 2

	attacking_sprite.position = Vector2.ZERO
	attacking_sprite.scale = Vector2.ONE * tier_scale * 0.38
	attacking_sprite.modulate = Color(brightness, brightness, brightness, 0.0)
	attacking_sprite.rotation = 0.10 if source_element_id == WATER else -0.10
	attacking_sprite.stop()
	attacking_sprite.frame = 0
	center_flash.position = Vector2(approach_x, 0.0)
	center_flash.scale = Vector2.ONE * (0.78 + float(strength_tier) * 0.16)
	center_flash.color = Color("43c8ff") if consumed_element_id == WATER else Color("ff7a38")
	center_flash.modulate = Color(1.0, 1.0, 1.0, 0.85)

	var consume_tween := create_tween().set_parallel(true)
	consume_tween.tween_property(consumed_sprite, "position", Vector2.ZERO, phase_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	consume_tween.tween_property(consumed_sprite, "scale", Vector2.ONE * tier_scale * 0.48, phase_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	consume_tween.tween_property(consumed_sprite, "modulate:a", 0.08, phase_delay)
	consume_tween.tween_property(consumed_sprite, "rotation", 0.0, phase_delay)
	consume_tween.tween_property(center_flash, "position", Vector2.ZERO, phase_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	consume_tween.tween_property(center_flash, "scale", Vector2.ONE * 0.42, phase_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	consume_tween.tween_property(center_flash, "modulate:a", 0.12, phase_delay)

	var burst_tween := create_tween()
	burst_tween.tween_interval(phase_delay)
	burst_tween.tween_callback(_begin_attack_phase.bind(brightness))
	burst_tween.set_parallel(true)
	burst_tween.tween_property(attacking_sprite, "scale", Vector2.ONE * tier_scale * 1.36, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(attacking_sprite, "modulate:a", 0.0, 0.25).set_delay(0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	burst_tween.tween_property(attacking_sprite, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(center_flash, "scale", center_flash.scale * 1.45, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(center_flash, "modulate:a", 0.0, 0.18).set_delay(0.05)

	var lifecycle := create_tween()
	lifecycle.tween_interval(LIFETIME_SECONDS)
	lifecycle.tween_callback(queue_free)


func _begin_attack_phase(brightness: float) -> void:
	if not is_instance_valid(attacking_sprite):
		return
	attacking_sprite.modulate = Color(brightness, brightness, brightness, 0.98)
	attacking_sprite.play(&"trigger")
	attacking_sprite.frame = 2
	center_flash.modulate = Color(1.0, 1.0, 1.0, 0.88)


func _play_reduced_motion() -> void:
	var tier_scale := [0.0, 0.72, 0.88, 1.04][strength_tier] as float
	for sprite: AnimatedSprite2D in [consumed_sprite, attacking_sprite]:
		sprite.stop()
		sprite.frame = 3
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE * tier_scale
		sprite.modulate.a = 0.72
	center_flash.position = Vector2.ZERO
	center_flash.rotation = 0.0
	center_flash.scale = Vector2.ONE * (0.6 + float(strength_tier) * 0.1)
	center_flash.modulate = Color(1.0, 0.96, 0.82, 0.55)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(consumed_sprite, "modulate:a", 0.0, 0.12).set_delay(0.26)
	fade.tween_property(attacking_sprite, "modulate:a", 0.0, 0.12).set_delay(0.26)
	fade.tween_property(center_flash, "modulate:a", 0.0, 0.12).set_delay(0.26)
	fade.chain().tween_callback(queue_free)
