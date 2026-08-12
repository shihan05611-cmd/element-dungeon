class_name CombatTargetQuery2D
extends RefCounted

## Deterministic spatial query shared by special deliveries and non-damage
## target ports. Results are accepted only through CombatHurtbox.


static func query_circle(
		source: Node2D,
		radius: float,
		collision_mask: int,
		max_results: int,
		source_team_id: StringName,
		deduplicate_receivers: bool = false
) -> Array[CombatTargetCandidate2D]:
	if (
		not _is_live_source(source)
		or not is_finite(radius)
		or radius <= 0.0
		or collision_mask <= 0
		or max_results <= 0
	):
		return []
	var shape := CircleShape2D.new()
	shape.radius = radius
	return query_shape(
		source.get_world_2d(),
		shape,
		Transform2D(0.0, source.global_position),
		collision_mask,
		max_results,
		source_team_id,
		deduplicate_receivers
	)


static func query_visible_world_rect(
		source: Node2D,
		collision_mask: int,
		max_results: int,
		source_team_id: StringName,
		deduplicate_receivers: bool = false
) -> Array[CombatTargetCandidate2D]:
	if not _is_live_source(source):
		return []
	var viewport := source.get_viewport()
	if viewport == null:
		return []
	var visible_rect := viewport.get_visible_rect()
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return []
	var inverse_canvas := source.get_canvas_transform().affine_inverse()
	var world_rect := Rect2(inverse_canvas * visible_rect.position, Vector2.ZERO)
	world_rect = world_rect.expand(inverse_canvas * visible_rect.end)
	world_rect = world_rect.expand(
		inverse_canvas * Vector2(visible_rect.end.x, visible_rect.position.y)
	)
	world_rect = world_rect.expand(
		inverse_canvas * Vector2(visible_rect.position.x, visible_rect.end.y)
	)
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return []
	var shape := RectangleShape2D.new()
	shape.size = world_rect.size
	return query_shape(
		source.get_world_2d(),
		shape,
		Transform2D(0.0, world_rect.get_center()),
		collision_mask,
		max_results,
		source_team_id,
		deduplicate_receivers
	)


static func query_beam(
		source: Node2D,
		length: float,
		width: float,
		collision_mask: int,
		max_results: int,
		source_team_id: StringName,
		direction: Vector2,
		deduplicate_receivers: bool = false
) -> Array[CombatTargetCandidate2D]:
	if (
		not _is_live_source(source)
		or not is_finite(length)
		or length <= 0.0
		or not is_finite(width)
		or width <= 0.0
		or not _is_finite_vector(direction)
		or direction.is_zero_approx()
	):
		return []
	var normalized_direction := direction.normalized()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, width)
	var center := source.global_position + normalized_direction * length * 0.5
	return query_shape(
		source.get_world_2d(),
		shape,
		Transform2D(normalized_direction.angle(), center),
		collision_mask,
		max_results,
		source_team_id,
		deduplicate_receivers
	)


static func query_shape(
		world: World2D,
		shape: Shape2D,
		query_transform: Transform2D,
		collision_mask: int,
		max_results: int,
		source_team_id: StringName,
		deduplicate_receivers: bool = false
) -> Array[CombatTargetCandidate2D]:
	var candidates: Array[CombatTargetCandidate2D] = []
	if (
		world == null
		or shape == null
		or collision_mask <= 0
		or max_results <= 0
		or source_team_id.is_empty()
	):
		return candidates
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = query_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var raw_hits := world.direct_space_state.intersect_shape(query, max_results)
	for raw_hit: Dictionary in raw_hits:
		var collider: Variant = raw_hit.get("collider")
		if not collider is CombatHurtbox:
			continue
		var hurtbox := collider as CombatHurtbox
		var receiver := hurtbox.get_combat_receiver()
		if not _is_legal_enemy_receiver(receiver, source_team_id):
			continue
		candidates.append(CombatTargetCandidate2D.new(
			hurtbox,
			receiver,
			hurtbox.get_hit_world_position(query_transform.origin)
		))
	candidates.sort_custom(_candidate_less)
	if not deduplicate_receivers:
		return candidates
	var unique_candidates: Array[CombatTargetCandidate2D] = []
	var previous_receiver_id: int = 0
	for candidate: CombatTargetCandidate2D in candidates:
		if candidate.stable_identity == previous_receiver_id:
			continue
		previous_receiver_id = candidate.stable_identity
		unique_candidates.append(candidate)
	return unique_candidates


static func is_world_blocked(
		world: World2D,
		from: Vector2,
		to: Vector2,
		blocking_collision_mask: int
) -> bool:
	if (
		world == null
		or blocking_collision_mask <= 0
		or not _is_finite_vector(from)
		or not _is_finite_vector(to)
		or from.is_equal_approx(to)
	):
		return false
	var query := PhysicsRayQueryParameters2D.create(from, to, blocking_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not world.direct_space_state.intersect_ray(query).is_empty()


static func _candidate_less(a: CombatTargetCandidate2D, b: CombatTargetCandidate2D) -> bool:
	if a.stable_identity != b.stable_identity:
		return a.stable_identity < b.stable_identity
	return a.hurtbox.get_instance_id() < b.hurtbox.get_instance_id()


static func _is_legal_enemy_receiver(
		receiver: CombatReceiver,
		source_team_id: StringName
) -> bool:
	return (
		receiver != null
		and is_instance_valid(receiver)
		and not receiver.is_queued_for_deletion()
		and receiver.accepting_hits
		and not receiver.target_team_id.is_empty()
		and receiver.target_team_id != source_team_id
	)


static func _is_live_source(source: Node2D) -> bool:
	return (
		source != null
		and is_instance_valid(source)
		and not source.is_queued_for_deletion()
		and source.is_inside_tree()
		and source.get_world_2d() != null
	)


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
