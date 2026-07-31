class_name ProjectileDelivery
extends DeliveryBase

## Swept projectile. Target and blocker sweeps are evaluated independently so
## nearest distance and wall-first ties never depend on signal callback order.

signal blocker_contact(hit_position: Vector2)

@export var projectile_shape: Shape2D
@export_range(0.001, 1000000.0, 0.001, "or_greater") var speed: float = 600.0
@export_range(0.001, 1000000.0, 0.001, "or_greater") var max_distance: float = 1000.0
@export_flags_2d_physics var hurtbox_collision_mask: int = 1
@export_flags_2d_physics var blocking_collision_mask: int = 2
@export_range(0.0, 10.0, 0.001, "or_greater") var query_margin: float = 0.001
@export_range(0.0, 10.0, 0.001, "or_greater") var wall_tie_distance: float = 0.01
@export_range(1, 256, 1) var max_contact_results: int = 64
@export var hit_index: int = 0

var distance_travelled: float:
	get:
		return _distance_travelled

var _distance_travelled: float = 0.0


func _on_delivery_ready() -> void:
	if projectile_shape == null:
		_fail_configuration(&"missing_projectile_shape")
		return
	if not is_finite(speed) or speed <= 0.0:
		_fail_configuration(&"invalid_speed")
		return
	if not is_finite(max_distance) or max_distance <= 0.0:
		_fail_configuration(&"invalid_max_distance")
		return
	if hit_index < 0:
		_fail_configuration(&"invalid_hit_index")
		return
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not _runtime_is_ready() or not is_finite(delta) or delta <= 0.0:
		return
	var remaining := max_distance - _distance_travelled
	if remaining <= 0.000001:
		finish(FINISH_MAX_DISTANCE)
		return
	var step_distance := minf(speed * delta, remaining)
	if step_distance <= 0.0:
		return
	var motion := direction * step_distance
	var world := get_world_2d()
	if world == null:
		return
	var space := world.direct_space_state
	var blocker_hit := _cast_first(space, motion, blocking_collision_mask, false, true, false)
	var hurtbox_hit := _cast_first(space, motion, hurtbox_collision_mask, true, false, true)

	var has_blocker := not blocker_hit.is_empty()
	var has_hurtbox := not hurtbox_hit.is_empty()
	if has_blocker or has_hurtbox:
		var blocker_distance := INF
		var hurtbox_distance := INF
		if has_blocker:
			blocker_distance = step_distance * float(blocker_hit["fraction"])
		if has_hurtbox:
			hurtbox_distance = step_distance * float(hurtbox_hit["fraction"])
		if has_blocker and blocker_distance <= hurtbox_distance + wall_tie_distance:
			_move_fraction(motion, float(blocker_hit["fraction"]))
			var blocker_position: Vector2 = blocker_hit.get("point", global_position)
			blocker_contact.emit(blocker_position)
			finish(FINISH_BLOCKED)
			return
		if has_hurtbox:
			_move_fraction(motion, float(hurtbox_hit["fraction"]))
			var hurtbox: CombatHurtbox = hurtbox_hit["hurtbox"]
			var hit_position: Vector2 = hurtbox_hit.get(
				"point",
				hurtbox.get_hit_world_position(global_position)
			)
			_submit_hurtbox_hit(hurtbox, hit_index, hit_position, direction)
			finish(FINISH_HIT)
			return

	global_position += motion
	_distance_travelled += step_distance
	if _distance_travelled >= max_distance - 0.000001:
		finish(FINISH_MAX_DISTANCE)


func _on_delivery_cleanup() -> void:
	_distance_travelled = 0.0
	hit_index = 0
	_disconnect_owned_signal(&"blocker_contact")
	super()


func _move_fraction(motion: Vector2, fraction: float) -> void:
	var safe_fraction := clampf(fraction, 0.0, 1.0)
	global_position += motion * safe_fraction
	_distance_travelled += motion.length() * safe_fraction


func _cast_first(
		space: PhysicsDirectSpaceState2D,
		motion: Vector2,
		collision_mask: int,
		collide_with_areas: bool,
		collide_with_bodies: bool,
		require_hurtbox: bool
) -> Dictionary:
	if collision_mask == 0:
		return {}
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = projectile_shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = collide_with_bodies
	query.margin = query_margin

	var initial_hits := space.intersect_shape(query, max_contact_results)
	var initial := _select_stable_contact(initial_hits, require_hurtbox)
	if not initial.is_empty():
		initial["fraction"] = 0.0
		if require_hurtbox:
			var initial_hurtbox: CombatHurtbox = initial["hurtbox"]
			initial["point"] = initial_hurtbox.get_hit_world_position(global_position)
		else:
			initial["point"] = global_position
		return initial

	query.motion = motion
	var cast_result := space.cast_motion(query)
	if cast_result.size() < 2:
		return {}
	var unsafe_fraction := clampf(float(cast_result[1]), 0.0, 1.0)
	if unsafe_fraction >= 1.0:
		return {}

	var rest_info := space.get_rest_info(query)
	var probe_fraction := unsafe_fraction
	if motion.length() > 0.0:
		probe_fraction = minf(1.0, unsafe_fraction + maxf(query_margin, 0.001) / motion.length())
	var contact_query := PhysicsShapeQueryParameters2D.new()
	contact_query.shape = projectile_shape
	contact_query.transform = global_transform
	contact_query.transform.origin += motion * probe_fraction
	contact_query.collision_mask = collision_mask
	contact_query.collide_with_areas = collide_with_areas
	contact_query.collide_with_bodies = collide_with_bodies
	contact_query.margin = query_margin
	var contact_hits := space.intersect_shape(contact_query, max_contact_results)
	var selected := _select_stable_contact(contact_hits, require_hurtbox)
	if selected.is_empty() and not rest_info.is_empty():
		selected = _contact_from_result(rest_info, require_hurtbox)
	if selected.is_empty():
		return {}
	selected["fraction"] = unsafe_fraction
	if not rest_info.is_empty() and rest_info.has("point"):
		selected["point"] = rest_info["point"]
	elif require_hurtbox:
		var selected_hurtbox: CombatHurtbox = selected["hurtbox"]
		selected["point"] = selected_hurtbox.get_hit_world_position(
			global_position + motion * unsafe_fraction
		)
	else:
		selected["point"] = global_position + motion * unsafe_fraction
	return selected


func _select_stable_contact(raw_hits: Array[Dictionary], require_hurtbox: bool) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for raw_hit in raw_hits:
		var candidate := _contact_from_result(raw_hit, require_hurtbox)
		if not candidate.is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["stable_id"]) < int(b["stable_id"])
	)
	return candidates[0]


func _contact_from_result(raw_hit: Dictionary, require_hurtbox: bool) -> Dictionary:
	var collider: Variant = raw_hit.get("collider")
	if require_hurtbox:
		if not collider is CombatHurtbox:
			return {}
		var hurtbox := collider as CombatHurtbox
		var receiver := hurtbox.get_combat_receiver()
		if not _is_live_receiver(receiver):
			return {}
		return {
			"hurtbox": hurtbox,
			"stable_id": receiver.get_instance_id(),
		}
	if collider != null and is_instance_valid(collider):
		return {"collider": collider, "stable_id": collider.get_instance_id()}
	var rid: RID = raw_hit.get("rid", RID())
	if rid.is_valid():
		return {"rid": rid, "stable_id": rid.get_id()}
	return {}




