class_name PhysicsProjectileSweepQuery2D
extends ProjectileSweepQueryPort2D

## Per-consumer adapter with four role-fixed Physics query objects.
## The trusted flag is private to an already-ready ProjectileDelivery; public
## requests (including Fury) always execute full context validation.

const _PACKED_METRIC_SHIFT: int = 21
const _PACKED_METRIC_MASK: int = (1 << _PACKED_METRIC_SHIFT) - 1
const _QUERY_CAST_REDUCTION_SHIFT: int = 8
const _QUERY_ADJUSTMENT_MASK: int = 255

var _blocker_overlap_query: PhysicsShapeQueryParameters2D
var _blocker_cast_query: PhysicsShapeQueryParameters2D
var _hurtbox_overlap_query: PhysicsShapeQueryParameters2D
var _hurtbox_cast_query: PhysicsShapeQueryParameters2D
var _empty_exclude: Array[RID] = []
var _profile: ProjectileSweepProfile2D
var _source_team_id: StringName
var _require_legal_enemy: bool = false
var _has_blocker_role: bool = false
var _has_hurtbox_role: bool = false
var _wall_tie_distance: float = 0.0
var _query_margin: float = 0.0
var _max_contact_results: int = 0

var _blocker_point: Vector2
var _blocker_stable_id: int = 0
var _hurtbox_point: Vector2
var _hurtbox_stable_id: int = 0
var _hurtbox: CombatHurtbox
var _receiver: CombatReceiver
var _last_status: int = ProjectileSweepResult2D.Status.NO_CONTACT
var _last_fraction: float = 1.0
var _last_distance: float = 0.0
var _last_detail: StringName = &""
var _query_metric_adjustments: int = 0
var _base_query_metric_delta: int = 1

var _packed_query_metrics: int = 0
var _parameter_build_count: int = 0
var _rest_probe_count: int = 0
var _candidate_scan_count: int = 0
var _sort_comparison_count: int = 0
var _metrics_enabled: bool = false


func query_first_contact(request: ProjectileSweepRequest2D) -> ProjectileSweepResult2D:
	_last_status = ProjectileSweepResult2D.Status.NO_CONTACT
	if request == null:
		_record_query_without_physics()
		return ProjectileSweepResult2D.invalid_context(&"missing_sweep_request")
	var request_error := request.validation_error()
	if not request_error.is_empty():
		_record_query_without_physics()
		return ProjectileSweepResult2D.invalid_context(request_error)
	if not configure_consumer(request.profile, request.source_team_id, request.require_legal_enemy):
		_record_query_without_physics()
		return ProjectileSweepResult2D.invalid_context(&"invalid_projectile_sweep_consumer")
	var result_status: int
	if _metrics_enabled:
		result_status = _query_first_contact_status_with_metrics(
			request.world.direct_space_state,
			request.start_transform,
			request.direction * request.distance,
			request.distance
		)
	else:
		result_status = _query_first_contact_status(
			request.world.direct_space_state,
			request.start_transform,
			request.direction * request.distance,
			request.distance
		)
	return _public_result(result_status)


func configure_consumer(
		profile: ProjectileSweepProfile2D,
		source_team_id: StringName,
		require_legal_enemy: bool
) -> bool:
	if profile == null or not profile.is_valid():
		return false
	_profile = profile
	_source_team_id = source_team_id
	_require_legal_enemy = require_legal_enemy
	_has_blocker_role = profile.blocking_collision_mask != 0
	_has_hurtbox_role = profile.hurtbox_collision_mask != 0
	_wall_tie_distance = profile.wall_tie_distance
	_query_margin = profile.query_margin
	_max_contact_results = profile.max_contact_results
	_ensure_scratch()
	_configure_role(_blocker_overlap_query, profile, profile.blocking_collision_mask, false)
	_configure_role(_blocker_cast_query, profile, profile.blocking_collision_mask, false)
	_configure_role(_hurtbox_overlap_query, profile, profile.hurtbox_collision_mask, true)
	_configure_role(_hurtbox_cast_query, profile, profile.hurtbox_collision_mask, true)
	var active_query_roles := int(_has_blocker_role) + int(_has_hurtbox_role)
	_base_query_metric_delta = (
		1
		+ (active_query_roles << _PACKED_METRIC_SHIFT)
		+ (active_query_roles << (_PACKED_METRIC_SHIFT * 2))
	)
	return true


func set_metrics_enabled(enabled: bool) -> void:
	_metrics_enabled = enabled
	reset_metrics()


func query_first_contact_for_ready_delivery(
		space: PhysicsDirectSpaceState2D,
		start_transform: Transform2D,
		motion: Vector2,
		distance: float
) -> int:
	_last_status = ProjectileSweepResult2D.Status.NO_CONTACT
	if _metrics_enabled:
		return _query_first_contact_status_with_metrics(
			space, start_transform, motion, distance
		)
	return _query_first_contact_status(space, start_transform, motion, distance)


func ready_delivery_contact_point() -> Vector2:
	return _blocker_point if _last_status == ProjectileSweepResult2D.Status.BLOCKER_CONTACT else _hurtbox_point


func ready_delivery_contact_fraction() -> float:
	return _last_fraction


func ready_delivery_contact_hurtbox() -> CombatHurtbox:
	return _hurtbox


func _query_first_contact_status(
		space: PhysicsDirectSpaceState2D,
		start_transform: Transform2D,
		motion: Vector2,
		distance: float
) -> int:
	if space == null or _profile == null:
		_last_status = ProjectileSweepResult2D.Status.INVALID_CONTEXT
		_last_detail = &"missing_sweep_world"
		return _last_status
	var blocker_fraction := 1.0
	if _has_blocker_role:
		blocker_fraction = _cast_fraction(
			space, start_transform, motion, false,
			_blocker_overlap_query, _blocker_cast_query
		)
	var hurtbox_fraction := 1.0
	if _has_hurtbox_role:
		hurtbox_fraction = _cast_fraction(
			space, start_transform, motion, true,
			_hurtbox_overlap_query, _hurtbox_cast_query
		)
	if blocker_fraction < 0.0 or hurtbox_fraction < 0.0:
		_last_status = ProjectileSweepResult2D.Status.QUERY_FAILED
		_last_detail = &"physics_sweep_query_failed"
		return _last_status
	var has_blocker := blocker_fraction < 1.0
	var has_hurtbox := hurtbox_fraction < 1.0
	if not has_blocker and not has_hurtbox:
		return _last_status
	var blocker_distance := distance * blocker_fraction if has_blocker else INF
	var hurtbox_distance := distance * hurtbox_fraction if has_hurtbox else INF
	if has_blocker and blocker_distance <= hurtbox_distance + _wall_tie_distance:
		_last_status = ProjectileSweepResult2D.Status.BLOCKER_CONTACT
		_last_fraction = blocker_fraction
		_last_distance = blocker_distance
		return _last_status
	_last_status = ProjectileSweepResult2D.Status.ENEMY_CONTACT
	_last_fraction = hurtbox_fraction
	_last_distance = hurtbox_distance
	return _last_status


func _query_first_contact_status_with_metrics(
		space: PhysicsDirectSpaceState2D,
		start_transform: Transform2D,
		motion: Vector2,
		distance: float
) -> int:
	if space == null or _profile == null:
		_packed_query_metrics += 1
		return _query_first_contact_status(space, start_transform, motion, distance)
	_query_metric_adjustments = 0
	var result_status := _query_first_contact_status(
		space, start_transform, motion, distance
	)
	_record_completed_query_metrics()
	return result_status


func _public_result(result_status: int) -> ProjectileSweepResult2D:
	match result_status:
		ProjectileSweepResult2D.Status.ENEMY_CONTACT:
			return ProjectileSweepResult2D.enemy_contact(
				_hurtbox_point,
				_last_fraction,
				_last_distance,
				_hurtbox,
				_receiver,
				_hurtbox_stable_id
			)
		ProjectileSweepResult2D.Status.BLOCKER_CONTACT:
			return ProjectileSweepResult2D.blocker_contact(
				_blocker_point,
				_last_fraction,
				_last_distance,
				_blocker_stable_id
			)
		ProjectileSweepResult2D.Status.NO_CONTACT:
			return ProjectileSweepResult2D.no_contact()
		ProjectileSweepResult2D.Status.INVALID_CONTEXT:
			return ProjectileSweepResult2D.invalid_context(_last_detail)
		ProjectileSweepResult2D.Status.QUERY_FAILED:
			return ProjectileSweepResult2D.query_failed(_last_detail)
	return ProjectileSweepResult2D.query_failed(&"unknown_projectile_sweep_status")


func metrics_snapshot() -> Dictionary:
	return {
		&"query_calls": _packed_query_metrics & _PACKED_METRIC_MASK,
		&"parameter_build_count": _parameter_build_count,
		&"intersect_shape_count": (
			_packed_query_metrics >> _PACKED_METRIC_SHIFT
		) & _PACKED_METRIC_MASK,
		&"cast_motion_count": (
			_packed_query_metrics >> (_PACKED_METRIC_SHIFT * 2)
		) & _PACKED_METRIC_MASK,
		&"rest_info_count": _rest_probe_count,
		&"probe_count": _rest_probe_count,
		&"candidate_scan_count": _candidate_scan_count,
		&"sort_comparison_count": _sort_comparison_count,
		&"scratch_parameter_count": (
			int(_blocker_overlap_query != null)
			+ int(_blocker_cast_query != null)
			+ int(_hurtbox_overlap_query != null)
			+ int(_hurtbox_cast_query != null)
		),
	}


func reset_metrics() -> void:
	_packed_query_metrics = 0
	_parameter_build_count = 0
	_rest_probe_count = 0
	_candidate_scan_count = 0
	_sort_comparison_count = 0


func release_scratch() -> void:
	_blocker_overlap_query = null
	_blocker_cast_query = null
	_hurtbox_overlap_query = null
	_hurtbox_cast_query = null
	_profile = null
	_source_team_id = &""
	_require_legal_enemy = false
	_has_blocker_role = false
	_has_hurtbox_role = false
	_wall_tie_distance = 0.0
	_query_margin = 0.0
	_max_contact_results = 0
	_clear_contact_scratch()


func _record_query_without_physics() -> void:
	if _metrics_enabled:
		_packed_query_metrics += 1


func _record_completed_query_metrics() -> void:
	_packed_query_metrics += _base_query_metric_delta
	if _query_metric_adjustments == 0:
		return
	var rest_probe_calls := _query_metric_adjustments & _QUERY_ADJUSTMENT_MASK
	var cast_reductions := (
		_query_metric_adjustments >> _QUERY_CAST_REDUCTION_SHIFT
	) & _QUERY_ADJUSTMENT_MASK
	if rest_probe_calls > 0:
		_packed_query_metrics += rest_probe_calls << _PACKED_METRIC_SHIFT
		_rest_probe_count += rest_probe_calls
	if cast_reductions > 0:
		_packed_query_metrics -= cast_reductions << (_PACKED_METRIC_SHIFT * 2)


func _clear_contact_scratch() -> void:
	_blocker_point = Vector2.ZERO
	_blocker_stable_id = 0
	_hurtbox_point = Vector2.ZERO
	_hurtbox_stable_id = 0
	_hurtbox = null
	_receiver = null
	_last_status = ProjectileSweepResult2D.Status.NO_CONTACT
	_last_fraction = 1.0
	_last_distance = 0.0
	_last_detail = &""


func _ensure_scratch() -> void:
	if _blocker_overlap_query == null:
		_blocker_overlap_query = PhysicsShapeQueryParameters2D.new()
		_parameter_build_count += 1
	if _blocker_cast_query == null:
		_blocker_cast_query = PhysicsShapeQueryParameters2D.new()
		_parameter_build_count += 1
	if _hurtbox_overlap_query == null:
		_hurtbox_overlap_query = PhysicsShapeQueryParameters2D.new()
		_parameter_build_count += 1
	if _hurtbox_cast_query == null:
		_hurtbox_cast_query = PhysicsShapeQueryParameters2D.new()
		_parameter_build_count += 1


func _configure_role(
		query: PhysicsShapeQueryParameters2D,
		profile: ProjectileSweepProfile2D,
		collision_mask: int,
		require_hurtbox: bool
) -> void:
	query.shape = profile.shape
	query.transform = Transform2D.IDENTITY
	query.motion = Vector2.ZERO
	query.collision_mask = collision_mask
	query.collide_with_areas = require_hurtbox
	query.collide_with_bodies = not require_hurtbox
	query.margin = profile.query_margin
	query.exclude = _empty_exclude


func _cast_fraction(
		space: PhysicsDirectSpaceState2D,
		start_transform: Transform2D,
		motion: Vector2,
		require_hurtbox: bool,
		overlap_query: PhysicsShapeQueryParameters2D,
		cast_query: PhysicsShapeQueryParameters2D
) -> float:
	overlap_query.transform = start_transform
	var initial_hits := space.intersect_shape(overlap_query, _max_contact_results)
	if not initial_hits.is_empty():
		var initial := _select_stable_contact(
			initial_hits, require_hurtbox, _source_team_id, _require_legal_enemy
		)
		if not initial.is_empty():
			var initial_point := start_transform.origin
			if require_hurtbox:
				var initial_hurtbox := initial[&"hurtbox"] as CombatHurtbox
				initial_point = initial_hurtbox.get_hit_world_position(start_transform.origin)
			_store_contact(initial, initial_point, require_hurtbox)
			if _metrics_enabled:
				_query_metric_adjustments += 1 << _QUERY_CAST_REDUCTION_SHIFT
			return 0.0

	cast_query.transform = start_transform
	cast_query.motion = motion
	var cast_result := space.cast_motion(cast_query)
	if cast_result.size() < 2:
		return -1.0
	var unsafe_fraction := clampf(float(cast_result[1]), 0.0, 1.0)
	if unsafe_fraction >= 1.0:
		return 1.0

	if _metrics_enabled:
		_query_metric_adjustments += 1
	var rest_info := space.get_rest_info(cast_query)
	var probe_fraction := unsafe_fraction
	if motion.length_squared() > 0.0:
		probe_fraction = minf(
			1.0,
			unsafe_fraction + maxf(_query_margin, 0.001) / motion.length()
		)
	var probe_transform := start_transform
	probe_transform.origin += motion * probe_fraction
	overlap_query.transform = probe_transform
	var contact_hits := space.intersect_shape(overlap_query, _max_contact_results)
	var selected: Dictionary = {}
	if not contact_hits.is_empty():
		selected = _select_stable_contact(
			contact_hits, require_hurtbox, _source_team_id, _require_legal_enemy
		)
	if selected.is_empty() and not rest_info.is_empty():
		if _metrics_enabled:
			_candidate_scan_count += 1
		selected = _contact_from_result(
			rest_info, require_hurtbox, _source_team_id, _require_legal_enemy
		)
	if selected.is_empty():
		return 1.0
	var point := start_transform.origin + motion * unsafe_fraction
	if not rest_info.is_empty() and rest_info.has(&"point"):
		point = rest_info[&"point"]
	elif require_hurtbox:
		var selected_hurtbox := selected[&"hurtbox"] as CombatHurtbox
		point = selected_hurtbox.get_hit_world_position(point)
	_store_contact(selected, point, require_hurtbox)
	return unsafe_fraction


func _store_contact(contact: Dictionary, point: Vector2, require_hurtbox: bool) -> void:
	if require_hurtbox:
		_hurtbox = contact[&"hurtbox"] as CombatHurtbox
		_receiver = contact[&"receiver"] as CombatReceiver
		_hurtbox_stable_id = int(contact[&"stable_id"])
		_hurtbox_point = point
	else:
		_blocker_stable_id = int(contact[&"stable_id"])
		_blocker_point = point


func _select_stable_contact(
		raw_hits: Array[Dictionary],
		require_hurtbox: bool,
		source_team_id: StringName,
		require_legal_enemy: bool
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for raw_hit in raw_hits:
		if _metrics_enabled:
			_candidate_scan_count += 1
		var candidate := _contact_from_result(
			raw_hit, require_hurtbox, source_team_id, require_legal_enemy
		)
		if not candidate.is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return {}
	var selected := candidates[0]
	for index in range(1, candidates.size()):
		if _metrics_enabled:
			_sort_comparison_count += 1
		var candidate := candidates[index]
		if int(candidate[&"stable_id"]) < int(selected[&"stable_id"]):
			selected = candidate
	return selected


func _contact_from_result(
		raw_hit: Dictionary,
		require_hurtbox: bool,
		source_team_id: StringName,
		require_legal_enemy: bool
) -> Dictionary:
	var collider: Variant = raw_hit.get(&"collider")
	if require_hurtbox:
		if not collider is CombatHurtbox:
			return {}
		var hurtbox := collider as CombatHurtbox
		var receiver := hurtbox.get_combat_receiver()
		if not _is_live_receiver(receiver):
			return {}
		if require_legal_enemy and not _is_legal_enemy(receiver, source_team_id):
			return {}
		return {
			&"hurtbox": hurtbox,
			&"receiver": receiver,
			&"stable_id": receiver.get_instance_id(),
		}
	if collider != null and is_instance_valid(collider):
		return {&"collider": collider, &"stable_id": collider.get_instance_id()}
	var rid: RID = raw_hit.get(&"rid", RID())
	if rid.is_valid():
		return {&"rid": rid, &"stable_id": rid.get_id()}
	return {}


static func _is_live_receiver(receiver: CombatReceiver) -> bool:
	return receiver != null and is_instance_valid(receiver) and not receiver.is_queued_for_deletion()


static func _is_legal_enemy(receiver: CombatReceiver, source_team_id: StringName) -> bool:
	return (
		_is_live_receiver(receiver)
		and receiver.accepting_hits
		and not receiver.target_team_id.is_empty()
		and receiver.target_team_id != source_team_id
	)
