class_name DeliveryBase
extends Node2D

## Narrow, rule-free base for all combat deliveries. Cast-time data can only be
## supplied once, before the node enters the SceneTree.

signal hit_submitted(result: CombatResult, receiver: CombatReceiver, hurtbox: CombatHurtbox)
signal delivery_finished(reason: StringName)

const FINISH_HIT: StringName = &"hit"
const FINISH_BLOCKED: StringName = &"blocked"
const FINISH_MAX_DISTANCE: StringName = &"max_distance"
const FINISH_CANCELLED: StringName = &"cancelled"
const FINISH_INVALID_CONFIGURATION: StringName = &"invalid_configuration"
const FINISH_TREE_EXITED: StringName = &"tree_exited"

@export var queue_free_on_finish: bool = true

var cast_snapshot: CastSnapshot:
	get:
		return _cast_snapshot

var payload: RuntimeAttackPayload:
	get:
		return _payload

var delivery_id: int:
	get:
		return _delivery_id

var direction: Vector2:
	get:
		return _direction

var validation_error: StringName:
	get:
		return _validation_error

var is_initialized: bool:
	get:
		return _is_initialized

var is_finished: bool:
	get:
		return _is_finished

var finish_reason: StringName:
	get:
		return _finish_reason

var reuse_generation: int:
	get:
		return _reuse_generation

var cleanup_complete: bool:
	get:
		return _cleanup_complete

var _cast_snapshot: CastSnapshot
var _payload: RuntimeAttackPayload
var _delivery_id: int = 0
var _start_world_transform: Transform2D = Transform2D.IDENTITY
var _direction: Vector2 = Vector2.RIGHT
var _validation_error: StringName = &""
var _is_initialized: bool = false
var _is_runtime_ready: bool = false
var _is_finished: bool = false
var _finish_reason: StringName = &""
var _reuse_generation: int = 0
var _cleanup_complete: bool = false
var _hit_receivers_by_index: Dictionary = {}


func initialize(
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload,
		p_delivery_id: int,
		p_start_world_transform: Transform2D,
		p_direction: Vector2
) -> bool:
	if _is_initialized:
		_validation_error = &"already_initialized"
		return false
	if is_inside_tree():
		_validation_error = &"initialize_before_add_child"
		return false

	var error := _validate_initialization(
		p_cast_snapshot,
		p_payload,
		p_delivery_id,
		p_start_world_transform,
		p_direction
	)
	if not error.is_empty():
		_validation_error = error
		return false

	_cast_snapshot = p_cast_snapshot
	_payload = p_payload
	_delivery_id = p_delivery_id
	_start_world_transform = p_start_world_transform
	_direction = p_direction.normalized()
	_validation_error = &""
	_is_initialized = true
	_cleanup_complete = false
	return true


func initialize_delivery(
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload,
		p_delivery_id: int,
		p_start_world_transform: Transform2D,
		p_direction: Vector2
) -> bool:
	return initialize(
		p_cast_snapshot,
		p_payload,
		p_delivery_id,
		p_start_world_transform,
		p_direction
	)


func cancel() -> void:
	finish(FINISH_CANCELLED)


## Optional active-window protocol. Persistent projectiles inherit this no-op;
## melee and area deliveries override it to stop submitting new overlaps.
func close_hit_window() -> void:
	pass


func finish(reason: StringName) -> void:
	if _is_finished:
		return
	_is_finished = true
	_finish_reason = reason if not reason.is_empty() else &"finished"
	set_physics_process(false)
	clear_hit_records()
	delivery_finished.emit(_finish_reason)
	_cleanup_finished_run()
	if queue_free_on_finish:
		queue_free()


## Pool boundary: only a completed, detached and fully-cleaned instance can
## become fresh again. Configuration Resources remain on the node; every piece
## of per-cast runtime state is cleared before this succeeds.
func prepare_for_reuse() -> bool:
	if is_inside_tree():
		_validation_error = &"reuse_requires_detached_delivery"
		return false
	if is_queued_for_deletion():
		_validation_error = &"reuse_rejects_queued_for_deletion"
		return false
	if not _is_finished:
		_validation_error = &"reuse_requires_finished_delivery"
		return false
	if not _cleanup_complete:
		_validation_error = &"reuse_requires_completed_cleanup"
		return false

	_is_initialized = false
	_is_runtime_ready = false
	_is_finished = false
	_finish_reason = &""
	_validation_error = &""
	_cleanup_complete = false
	_reuse_generation += 1
	# Godot only calls _ready once per Node lifetime unless a detached pooled
	# instance explicitly requests it before re-entering the SceneTree.
	request_ready()
	return true


func clear_hit_records(hit_index: int = -1) -> void:
	if hit_index < 0:
		_hit_receivers_by_index.clear()
	else:
		_hit_receivers_by_index.erase(hit_index)


func get_recorded_target_count(hit_index: int) -> int:
	var recorded: Dictionary = _hit_receivers_by_index.get(hit_index, {})
	return recorded.size()



func _ready() -> void:
	set_physics_process(false)
	if not _is_initialized:
		_validation_error = &"not_initialized"
		finish(FINISH_INVALID_CONFIGURATION)
		return
	global_transform = _start_world_transform
	_is_runtime_ready = true
	_on_delivery_ready()


func _on_delivery_ready() -> void:
	pass


func _runtime_is_ready() -> bool:
	return _is_runtime_ready and not _is_finished


func _fail_configuration(error: StringName) -> void:
	_validation_error = error
	finish(FINISH_INVALID_CONFIGURATION)


func _on_delivery_cleanup() -> void:
	pass


func _disconnect_owned_signal(signal_name: StringName) -> void:
	for connection in get_signal_connection_list(signal_name):
		var callable: Callable = connection.get("callable", Callable())
		if callable.is_valid() and is_connected(signal_name, callable):
			disconnect(signal_name, callable)


func _submit_hurtbox_hit(
		hurtbox: CombatHurtbox,
		hit_index: int,
		hit_position: Vector2,
		hit_direction: Vector2
) -> CombatResult:
	return _submit_hurtbox_hit_with_payload(
		hurtbox,
		hit_index,
		hit_position,
		hit_direction,
		_payload
	)


func _submit_hurtbox_hit_with_payload(
		hurtbox: CombatHurtbox,
		hit_index: int,
		hit_position: Vector2,
		hit_direction: Vector2,
		request_payload: RuntimeAttackPayload
) -> CombatResult:
	if not _runtime_is_ready() or hurtbox == null or not is_instance_valid(hurtbox):
		return null
	if hit_index < 0 or request_payload == null or not request_payload.is_valid():
		return null

	var receiver := hurtbox.get_combat_receiver()
	if not _is_live_receiver(receiver):
		return null
	var receiver_id := receiver.get_instance_id()
	var recorded: Dictionary = _hit_receivers_by_index.get(hit_index, {})
	if recorded.has(receiver_id):
		return null

	# Record before the synchronous call. Rejections such as dodge/block are a
	# completed contact for this hit window and must not be retried every tick.
	recorded[receiver_id] = true
	_hit_receivers_by_index[hit_index] = recorded
	var request := HitRequest.new(
		_cast_snapshot,
		request_payload,
		_delivery_id,
		hit_index,
		hit_position,
		hit_direction
	)
	var result := receiver.receive_hit(request)
	hit_submitted.emit(result, receiver, hurtbox)
	return result


func _exit_tree() -> void:
	set_physics_process(false)
	if not _is_finished:
		_is_finished = true
		_finish_reason = FINISH_TREE_EXITED
		clear_hit_records()
		delivery_finished.emit(_finish_reason)
	_cleanup_finished_run()


func _cleanup_finished_run() -> void:
	if _cleanup_complete:
		return
	set_physics_process(false)
	clear_hit_records()
	_on_delivery_cleanup()
	_cast_snapshot = null
	_payload = null
	_delivery_id = 0
	_start_world_transform = Transform2D.IDENTITY
	_direction = Vector2.ZERO
	_is_runtime_ready = false
	_cleanup_complete = true
	_disconnect_owned_signal(&"hit_submitted")
	_disconnect_owned_signal(&"delivery_finished")


static func _validate_initialization(
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload,
		p_delivery_id: int,
		p_start_world_transform: Transform2D,
		p_direction: Vector2
) -> StringName:
	if p_cast_snapshot == null or not p_cast_snapshot.is_valid():
		return &"invalid_cast_snapshot"
	if p_payload == null or not p_payload.is_valid():
		return &"invalid_payload"
	if p_delivery_id <= 0:
		return &"missing_delivery_id"
	if not _is_finite_transform(p_start_world_transform):
		return &"invalid_start_transform"
	if not _is_finite_vector(p_direction) or p_direction.is_zero_approx():
		return &"invalid_direction"
	return &""


static func _is_live_receiver(receiver: CombatReceiver) -> bool:
	return (
		receiver != null
		and is_instance_valid(receiver)
		and not receiver.is_queued_for_deletion()
	)


static func _is_finite_transform(value: Transform2D) -> bool:
	return (
		_is_finite_vector(value.x)
		and _is_finite_vector(value.y)
		and _is_finite_vector(value.origin)
	)


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)








