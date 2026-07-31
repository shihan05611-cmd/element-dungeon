class_name MeleeDelivery
extends DeliveryBase

## Deterministic active-window melee query. No overlap cache or signal ordering
## is used: the shape is queried explicitly once per physics step.

@export var hit_shape: Shape2D
@export_flags_2d_physics var hurtbox_collision_mask: int = 1
@export var query_offset: Vector2 = Vector2.ZERO
@export var query_rotation: float = 0.0
@export_range(1, 256, 1) var max_query_results: int = 64
@export var active_on_ready: bool = false
@export var initial_hit_index: int = 0

var active: bool:
	get:
		return _active

var _active: bool = false
var _active_hit_index: int = 0
var _active_query_transform: Transform2D = Transform2D.IDENTITY
var _pending_open: bool = false
var _pending_hit_index: int = 0


func open_hit_window(hit_index: int = 0) -> bool:
	if not is_initialized or is_finished or hit_index < 0:
		return false
	if not _runtime_is_ready():
		_pending_open = true
		_pending_hit_index = hit_index
		return true
	if hit_shape == null:
		return false

	clear_hit_records()
	_active_hit_index = hit_index
	_active_query_transform = _build_query_transform()
	_active = true
	set_physics_process(true)
	return true


func close_hit_window() -> void:
	_pending_open = false
	_active = false
	set_physics_process(false)
	clear_hit_records()


func _on_delivery_ready() -> void:
	if hit_shape == null:
		_fail_configuration(&"missing_hit_shape")
		return
	if _pending_open:
		var pending_index := _pending_hit_index
		_pending_open = false
		open_hit_window(pending_index)
	elif active_on_ready:
		open_hit_window(initial_hit_index)


func _physics_process(_delta: float) -> void:
	if not _active or not _runtime_is_ready():
		return
	var world := get_world_2d()
	if world == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hit_shape
	query.transform = _active_query_transform
	query.collision_mask = hurtbox_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var raw_hits := world.direct_space_state.intersect_shape(query, max_query_results)
	var candidates: Array[Dictionary] = []
	for raw_hit in raw_hits:
		var collider: Variant = raw_hit.get("collider")
		if not collider is CombatHurtbox:
			continue
		var hurtbox := collider as CombatHurtbox
		var receiver := hurtbox.get_combat_receiver()
		if not _is_live_receiver(receiver):
			continue
		candidates.append({"hurtbox": hurtbox, "receiver": receiver})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_receiver: CombatReceiver = a["receiver"]
		var b_receiver: CombatReceiver = b["receiver"]
		var a_receiver_id := a_receiver.get_instance_id()
		var b_receiver_id := b_receiver.get_instance_id()
		if a_receiver_id != b_receiver_id:
			return a_receiver_id < b_receiver_id
		var a_hurtbox: CombatHurtbox = a["hurtbox"]
		var b_hurtbox: CombatHurtbox = b["hurtbox"]
		return a_hurtbox.get_instance_id() < b_hurtbox.get_instance_id()
	)

	for candidate in candidates:
		var hurtbox: CombatHurtbox = candidate["hurtbox"]
		_submit_hurtbox_hit(
			hurtbox,
			_active_hit_index,
			hurtbox.get_hit_world_position(_active_query_transform.origin),
			direction
		)


func _on_delivery_cleanup() -> void:
	_active = false
	_pending_open = false
	_active_hit_index = -1
	_pending_hit_index = -1
	# initial_hit_index is mutable per-use configuration. Reset it so a pooled
	# Melee/DelayedArea instance cannot inherit the previous generation's segment.
	initial_hit_index = 0
	_active_query_transform = Transform2D.IDENTITY
	super()


func _build_query_transform() -> Transform2D:
	var facing_angle := direction.angle()
	var query_origin := global_position + query_offset.rotated(facing_angle)
	return Transform2D(facing_angle + query_rotation, query_origin)






