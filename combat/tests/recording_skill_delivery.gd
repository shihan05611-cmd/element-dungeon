class_name RecordingSkillDelivery
extends Node2D

## Test double for Agent C's public pre-tree initialization protocol.

var cast_snapshot: CastSnapshot
var payload: RuntimeAttackPayload
var delivery_id: int = 0
var initial_transform: Transform2D = Transform2D.IDENTITY
var direction: Vector2 = Vector2.ZERO
var initialized: bool = false
var initialized_inside_tree: bool = false
var ready_after_initialize: bool = false
var close_count: int = 0


func initialize_delivery(
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload,
		p_delivery_id: int,
		p_initial_transform: Transform2D,
		p_direction: Vector2
) -> bool:
	initialized_inside_tree = is_inside_tree()
	cast_snapshot = p_cast_snapshot
	payload = p_payload
	delivery_id = p_delivery_id
	initial_transform = p_initial_transform
	direction = p_direction
	initialized = (
		cast_snapshot != null
		and cast_snapshot.is_valid()
		and payload != null
		and payload.is_valid()
		and delivery_id > 0
	)
	return initialized


func _ready() -> void:
	ready_after_initialize = initialized
	global_transform = initial_transform


func close_hit_window() -> void:
	close_count += 1
