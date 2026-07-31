class_name LaserVfxPresentation
extends Node2D

const WATER_SEGMENT: Texture2D = preload(
	"res://assets/generated/vfx/elemental_laser/beam_segment_water.png"
)
const FIRE_SEGMENT: Texture2D = preload(
	"res://assets/generated/vfx/elemental_laser/beam_segment_fire.png"
)
const WATER_TICK_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/laser_tick_water_frames.tres"
)
const FIRE_TICK_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/laser_tick_fire_frames.tres"
)

const BEAM_LENGTH := 320.0
const BEAM_WIDTH := 24.0

var locked_element_id: StringName = &""
var pulse_count: int = 0
var _delivery_ref: WeakRef
var _pulse_tween: Tween


func configure(delivery: ElementBeamDelivery, element_id: StringName) -> bool:
	if (
		delivery == null
		or not is_instance_valid(delivery)
		or not ElementIds.is_combat_element(element_id)
	):
		return false
	_delivery_ref = weakref(delivery)
	locked_element_id = element_id
	var texture := WATER_SEGMENT if element_id == ElementIds.WATER else FIRE_SEGMENT
	for child: Node in get_children():
		var segment := child as Sprite2D
		if segment != null:
			segment.texture = texture
	_follow_delivery()
	set_process(true)
	return true


func pulse(target_positions: Array[Vector2]) -> void:
	pulse_count += 1
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	modulate = Color.WHITE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.045)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.13)
	for target_position: Vector2 in target_positions:
		_spawn_target_flash(target_position)


func stop() -> void:
	set_process(false)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	queue_free()


func visual_size() -> Vector2:
	return Vector2(BEAM_LENGTH, BEAM_WIDTH)


func _process(_delta: float) -> void:
	if not _follow_delivery():
		stop()


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


func _spawn_target_flash(target_position: Vector2) -> void:
	var flash := AnimatedSprite2D.new()
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.sprite_frames = (
		WATER_TICK_FRAMES
		if locked_element_id == ElementIds.WATER
		else FIRE_TICK_FRAMES
	)
	flash.animation = &"tick"
	flash.z_index = 3
	add_child(flash)
	flash.top_level = true
	flash.global_position = target_position
	flash.animation_finished.connect(flash.queue_free)
	flash.play()


func _exit_tree() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	_delivery_ref = null

