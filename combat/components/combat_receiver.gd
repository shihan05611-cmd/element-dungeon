class_name CombatReceiver
extends Node

## Synchronous target-side transaction coordinator. Resolver work is pure;
## target components are silently committed only after the full plan validates;
## all signals are then emitted while re-entry remains guarded.

signal hit_resolved(result: CombatResult)
signal reaction_triggered(result: CombatResult)
signal element_state_changed(result: CombatResult)
signal health_state_changed(current_health: int, maximum_health: int, delta: int, result: CombatResult)
signal death_candidate(result: CombatResult)
signal presentation_requested(result: CombatResult)

@export var target_team_id: StringName = &"enemy"
@export var accepting_hits: bool = true
@export var invulnerable: bool = false
@export var blocking: bool = false
@export var dodging: bool = false
@export_range(1, 256, 1) var recent_hit_capacity: int = 64
@export var element_carrier_path: NodePath
@export var damage_receiver_path: NodePath

var _element_carrier: ElementCarrier
var _damage_receiver: DamageReceiver
var _is_processing: bool = false
var _recent_hit_set: Dictionary = {}
var _recent_hit_order: Array[String] = []


func _ready() -> void:
	_resolve_configured_components()


func configure_components(carrier: ElementCarrier, damage: DamageReceiver) -> void:
	_element_carrier = carrier
	_damage_receiver = damage


func get_element_carrier() -> ElementCarrier:
	if _is_live_node(_element_carrier):
		return _element_carrier
	_resolve_configured_components()
	return _element_carrier if _is_live_node(_element_carrier) else null


func get_damage_receiver() -> DamageReceiver:
	if _is_live_node(_damage_receiver):
		return _damage_receiver
	_resolve_configured_components()
	return _damage_receiver if _is_live_node(_damage_receiver) else null


func receive_hit(request: HitRequest) -> CombatResult:
	if _is_processing:
		return CombatResult.rejected(request, CombatStatus.RejectReason.REENTRANT)
	if request == null or not request.is_valid():
		var detail := &"missing_request" if request == null else request.validation_error
		return CombatResult.rejected(request, CombatStatus.RejectReason.INVALID_REQUEST, detail)
	if is_queued_for_deletion() or not accepting_hits:
		return CombatResult.rejected(request, CombatStatus.RejectReason.TARGET_UNAVAILABLE)
	if target_team_id.is_empty():
		return CombatResult.rejected(request, CombatStatus.RejectReason.INVALID_TARGET_STATE, &"missing_target_team")
	if request.cast_snapshot.team_id == target_team_id:
		return CombatResult.rejected(request, CombatStatus.RejectReason.FRIENDLY_FIRE)
	if invulnerable:
		return CombatResult.rejected(request, CombatStatus.RejectReason.INVULNERABLE)
	if blocking:
		return CombatResult.rejected(request, CombatStatus.RejectReason.BLOCKED)
	if dodging:
		return CombatResult.rejected(request, CombatStatus.RejectReason.DODGED)
	if _recent_hit_set.has(request.identity_key()):
		return CombatResult.rejected(request, CombatStatus.RejectReason.DUPLICATE_HIT)

	var carrier := get_element_carrier()
	var damage := get_damage_receiver()
	if carrier == null and damage == null:
		return CombatResult.rejected(request, CombatStatus.RejectReason.NO_RECEIVERS)
	if damage != null and not damage.is_runtime_valid():
		return CombatResult.rejected(
			request,
			CombatStatus.RejectReason.INVALID_TARGET_STATE,
			&"invalid_damage_receiver"
		)

	_is_processing = true
	var plan := _build_plan(request, carrier, damage)
	if not plan.is_valid():
		_is_processing = false
		return CombatResult.rejected(
			request,
			CombatStatus.RejectReason.COMMIT_VALIDATION_FAILED,
			plan.validation_error
		)
	if not _can_commit(plan, carrier, damage):
		_is_processing = false
		return CombatResult.rejected(
			request,
			CombatStatus.RejectReason.COMMIT_VALIDATION_FAILED,
			&"target_changed_before_commit"
		)

	_commit_silent(plan, carrier, damage)
	var result := CombatResult.from_plan(plan)
	_remember_hit(request.identity_key())
	_emit_post_commit_notifications(plan, result, carrier, damage)
	_is_processing = false
	return result


func clear_recent_hits() -> void:
	_recent_hit_set.clear()
	_recent_hit_order.clear()


func _build_plan(
		request: HitRequest,
		carrier: ElementCarrier,
		damage: DamageReceiver
) -> CombatPlan:
	var plan := CombatPlan.new(request)
	var reaction_multiplier := 1.0

	if carrier != null:
		var carrier_snapshot := carrier.snapshot()
		plan.element_resolution = WaterFireResolver.resolve(
			request.payload,
			carrier_snapshot,
			carrier.allow_element_attachment,
			carrier.allow_cross_element_reactions
		)
		plan.element_status = plan.element_resolution.status
		reaction_multiplier = plan.element_resolution.reaction_multiplier

	if damage != null:
		plan.damage_resolution = DamageResolver.resolve(
			request.payload.offensive_damage,
			reaction_multiplier,
			damage.defense_flat
		)
		plan.health_before = damage.current_health
		plan.maximum_health = damage.maximum_health
		plan.health_after = damage.preview_health_after_damage(plan.damage_resolution.final_damage)
		plan.damage_status = CombatStatus.SubResult.PROCESSED_NO_CHANGE
		if plan.health_after < plan.health_before:
			plan.damage_status = CombatStatus.SubResult.APPLIED

	return plan


func _can_commit(
		plan: CombatPlan,
		carrier: ElementCarrier,
		damage: DamageReceiver
) -> bool:
	if carrier != null:
		if not _is_live_node(carrier) or not carrier.can_replace(plan.element_resolution.after):
			return false
	if damage != null:
		if not _is_live_node(damage) or not damage.can_replace_health(plan.health_after):
			return false
	return true


func _commit_silent(
		plan: CombatPlan,
		carrier: ElementCarrier,
		damage: DamageReceiver
) -> void:
	if carrier != null:
		carrier.replace_silent(plan.element_resolution.after)
	if damage != null:
		damage.replace_health_silent(plan.health_after)


func _emit_post_commit_notifications(
		plan: CombatPlan,
		result: CombatResult,
		carrier: ElementCarrier,
		damage: DamageReceiver
) -> void:
	# Order is frozen for integration: hit -> reaction -> element -> health ->
	# death candidate -> presentation. Every observer sees both components final.
	hit_resolved.emit(result)
	if result.reaction_triggered:
		reaction_triggered.emit(result)
	if carrier != null and plan.element_status == CombatStatus.SubResult.APPLIED:
		carrier.notify_changed(plan.element_resolution.before)
		element_state_changed.emit(result)
	if damage != null:
		damage.notify_health_changed(plan.health_delta())
		health_state_changed.emit(
			plan.health_after,
			plan.maximum_health,
			plan.health_delta(),
			result
		)
	if damage != null and plan.health_before > 0 and plan.health_after == 0:
		death_candidate.emit(result)
	presentation_requested.emit(result)


func _remember_hit(key: String) -> void:
	_recent_hit_set[key] = true
	_recent_hit_order.append(key)
	var capacity := maxi(1, recent_hit_capacity)
	while _recent_hit_order.size() > capacity:
		var expired: String = _recent_hit_order.pop_front()
		_recent_hit_set.erase(expired)


func _resolve_configured_components() -> void:
	if not element_carrier_path.is_empty():
		var carrier_node := get_node_or_null(element_carrier_path)
		if carrier_node is ElementCarrier:
			_element_carrier = carrier_node
	if not damage_receiver_path.is_empty():
		var damage_node := get_node_or_null(damage_receiver_path)
		if damage_node is DamageReceiver:
			_damage_receiver = damage_node


static func _is_live_node(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


func _exit_tree() -> void:
	clear_recent_hits()
