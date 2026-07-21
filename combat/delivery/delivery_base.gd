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

var _cast_snapshot: CastSnapshot
var _payload: RuntimeAttackPayload
var _delivery_id: int = 0
var _start_world_transform: Transform2D = Transform2D.IDENTITY
var _direction: Vector2 = Vector2.RIGHT
var _validation_error: StringName = &""
var _is_initialized: bool = false
var _is_runtime_ready: bool = false
var _is_finished: bool = false
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


func finish(reason: StringName) -> void:
	if _is_finished:
		return
	_is_finished = true
	set_physics_process(false)
	clear_hit_records()
	delivery_finished.emit(reason)
	queue_free()


func clear_hit_records(hit_index: int = -1) -> void:
	if hit_index < 0:
		_hit_receivers_by_index.clear()
	else:
		_hit_receivers_by_index.erase(hit_index)


func get_recorded_target_count(hit_index: int) -> int:
	var recorded: Dictionary = _hit_receivers_by_index.get(hit_index, {})
	return recorded.size()


func has_recorded_target(hit_index: int, receiver: CombatReceiver) -> bool:
	if not _is_live_receiver(receiver):
		return false
	var recorded: Dictionary = _hit_receivers_by_index.get(hit_index, {})
	return recorded.has(receiver.get_instance_id())


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


func _submit_hurtbox_hit(
		hurtbox: CombatHurtbox,
		hit_index: int,
		hit_position: Vector2,
		hit_direction: Vector2
) -> CombatResult:
	if not _runtime_is_ready() or hurtbox == null or not is_instance_valid(hurtbox):
		return null
	if hit_index < 0:
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
		_payload,
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
	clear_hit_records()
	_is_runtime_ready = false


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




