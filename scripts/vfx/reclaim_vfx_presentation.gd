class_name ReclaimVfxPresentation
extends Node2D

const WATER_PARTICLE_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/reclaim_particle_water_frames.tres"
)
const FIRE_PARTICLE_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/reclaim_particle_fire_frames.tres"
)
const EXTRACT_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/reclaim_extract_frames.tres"
)
const ARRIVAL_FRAMES: SpriteFrames = preload(
	"res://resources/vfx/reclaim_arrival_frames.tres"
)
const WATER_TINT := Color("71ddff")
const FIRE_TINT := Color("ff8a45")

const PARTICLES_PER_TARGET := 3
const PARTICLE_STAGGER := 0.025
const TRAVEL_DURATION := 0.40

var locked_element_id: StringName = &""
var target_count: int = 0
var particle_count: int = 0
var _player_ref: WeakRef


func play_reclaim(event: ReclaimVfxEvent, player: Node2D) -> bool:
	if event == null or not event.is_valid() or not _is_live_node(player):
		return false
	locked_element_id = event.element_id
	target_count = event.target_positions.size()
	particle_count = target_count * PARTICLES_PER_TARGET
	_player_ref = weakref(player)
	var latest_arrival := 0.0
	var target_index := 0
	for target_position: Vector2 in event.target_positions:
		_spawn_one_shot(EXTRACT_FRAMES, target_position, &"extract", true)
		for particle_index in PARTICLES_PER_TARGET:
			var delay := (
				float(target_index * PARTICLES_PER_TARGET + particle_index)
				* PARTICLE_STAGGER
			)
			latest_arrival = maxf(latest_arrival, delay + TRAVEL_DURATION)
			_spawn_particle(target_position, delay, particle_index)
		target_index += 1
	var completion := create_tween()
	completion.tween_interval(latest_arrival)
	completion.tween_callback(_spawn_arrival)
	completion.tween_interval(0.38)
	completion.tween_callback(queue_free)
	return true


func _spawn_particle(start: Vector2, delay: float, variant_index: int) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = (
		WATER_PARTICLE_FRAMES
		if locked_element_id == ElementIds.WATER
		else FIRE_PARTICLE_FRAMES
	)
	sprite.animation = &"travel"
	sprite.z_index = 2
	add_child(sprite)
	sprite.top_level = true
	sprite.global_position = start
	sprite.play()
	var player := _player_ref.get_ref() as Node2D if _player_ref != null else null
	var destination := player.global_position if _is_live_node(player) else start
	var lateral := -1.0 if variant_index % 2 == 0 else 1.0
	var control := (start + destination) * 0.5 + Vector2(28.0 * lateral, -54.0)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(
		_set_particle_curve_position.bind(sprite, start, control, destination),
		0.0,
		1.0,
		TRAVEL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(sprite.queue_free)


func _set_particle_curve_position(
		progress: float,
		sprite: AnimatedSprite2D,
		start: Vector2,
		control: Vector2,
		destination: Vector2
) -> void:
	if not _is_live_node(sprite):
		return
	var inverse := 1.0 - progress
	sprite.global_position = (
		inverse * inverse * start
		+ 2.0 * inverse * progress * control
		+ progress * progress * destination
	)


func _spawn_arrival() -> void:
	var player := _player_ref.get_ref() as Node2D if _player_ref != null else null
	if _is_live_node(player):
		_spawn_one_shot(ARRIVAL_FRAMES, player.global_position, &"arrival", true)


func _spawn_one_shot(
		frames: SpriteFrames,
		world_position: Vector2,
		animation_name: StringName,
		tint_locked_element: bool
) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = frames
	sprite.animation = animation_name
	sprite.z_index = 3
	if tint_locked_element:
		sprite.modulate = (
			WATER_TINT
			if locked_element_id == ElementIds.WATER
			else FIRE_TINT
		)
	add_child(sprite)
	sprite.top_level = true
	sprite.global_position = world_position
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play()


static func _is_live_node(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and not node.is_queued_for_deletion()
		and node.is_inside_tree()
	)


func _exit_tree() -> void:
	_player_ref = null

