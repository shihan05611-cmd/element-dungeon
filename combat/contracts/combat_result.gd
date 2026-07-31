class_name CombatResult
extends RefCounted

## Immutable, presentation-facing summary of one receive_hit call.

var accepted: bool:
	get:
		return _accepted

var reject_reason: CombatStatus.RejectReason:
	get:
		return _reject_reason

var reject_code: StringName:
	get:
		return CombatStatus.reject_code(_reject_reason)

var reject_detail: StringName:
	get:
		return _reject_detail

var damage_status: CombatStatus.SubResult:
	get:
		return _damage_status

var element_status: CombatStatus.SubResult:
	get:
		return _element_status

var cast_id: int:
	get:
		return _cast_id

var delivery_id: int:
	get:
		return _delivery_id

var hit_index: int:
	get:
		return _hit_index

var root_owner_id: int:
	get:
		return _root_owner_id

var skill_id: StringName:
	get:
		return _skill_id

var source_team_id: StringName:
	get:
		return _source_team_id

var source_element_id: StringName:
	get:
		return _source_element_id

var hit_position: Vector2:
	get:
		return _hit_position

var hit_direction: Vector2:
	get:
		return _hit_direction

var effective_attack: float:
	get:
		return _effective_attack

var damage_multiplier: float:
	get:
		return _damage_multiplier

var fixed_damage_bonus: float:
	get:
		return _fixed_damage_bonus

var offensive_damage: float:
	get:
		return _offensive_damage

var reacted_damage: float:
	get:
		return _reacted_damage

var mitigated_damage: float:
	get:
		return _mitigated_damage

var final_damage: int:
	get:
		return _final_damage

var reaction_triggered: bool:
	get:
		return _reaction_consumed > 0

var reaction_consumed: int:
	get:
		return _reaction_consumed

var reaction_multiplier: float:
	get:
		return _reaction_multiplier

var water_delta: int:
	get:
		return _water_delta

var fire_delta: int:
	get:
		return _fire_delta

var current_health: int:
	get:
		return _current_health

var maximum_health: int:
	get:
		return _maximum_health

var health_delta: int:
	get:
		return _health_delta

var presentation_tags: PackedStringArray:
	get:
		return _presentation_tags.duplicate()

var _accepted: bool = false
var _reject_reason: CombatStatus.RejectReason = CombatStatus.RejectReason.NONE
var _reject_detail: StringName = &""
var _damage_status: CombatStatus.SubResult = CombatStatus.SubResult.NOT_PROCESSED
var _element_status: CombatStatus.SubResult = CombatStatus.SubResult.NOT_PROCESSED
var _cast_id: int = 0
var _delivery_id: int = 0
var _hit_index: int = -1
var _root_owner_id: int = 0
var _skill_id: StringName = &""
var _source_team_id: StringName = &""
var _source_element_id: StringName = ElementIds.NONE
var _hit_position: Vector2 = Vector2.ZERO
var _hit_direction: Vector2 = Vector2.ZERO
var _effective_attack: float = 0.0
var _damage_multiplier: float = 0.0
var _fixed_damage_bonus: float = 0.0
var _offensive_damage: float = 0.0
var _reacted_damage: float = 0.0
var _mitigated_damage: float = 0.0
var _final_damage: int = 0
var _reaction_consumed: int = 0
var _reaction_multiplier: float = 1.0
var _water_delta: int = 0
var _fire_delta: int = 0
var _current_health: int = 0
var _maximum_health: int = 0
var _health_delta: int = 0
var _presentation_tags: PackedStringArray = PackedStringArray()


static func rejected(
		request: HitRequest,
		reason: CombatStatus.RejectReason,
		detail: StringName = &""
) -> CombatResult:
	var result := CombatResult.new()
	result._reject_reason = reason
	result._reject_detail = detail
	result._copy_request_metadata(request)
	return result


static func from_plan(plan: CombatPlan) -> CombatResult:
	var result := CombatResult.new()
	result._accepted = true
	result._reject_reason = CombatStatus.RejectReason.NONE
	result._damage_status = plan.damage_status
	result._element_status = plan.element_status
	result._copy_request_metadata(plan.request)

	if plan.damage_resolution != null:
		result._copy_locked_damage_input(plan.request.payload)
		result._offensive_damage = plan.damage_resolution.offensive_damage
		result._reacted_damage = plan.damage_resolution.reacted_damage
		result._mitigated_damage = plan.damage_resolution.mitigated_damage
		result._final_damage = plan.damage_resolution.final_damage
		result._current_health = plan.health_after
		result._maximum_health = plan.maximum_health
		result._health_delta = plan.health_delta()
	else:
		result._copy_locked_damage_input(plan.request.payload)
		result._offensive_damage = plan.request.payload.offensive_damage

	if plan.element_resolution != null:
		result._reaction_consumed = plan.element_resolution.consumed_amount
		result._reaction_multiplier = plan.element_resolution.reaction_multiplier
		result._water_delta = plan.element_resolution.water_delta
		result._fire_delta = plan.element_resolution.fire_delta

	result._presentation_tags = plan.request.payload.presentation_tags
	result._append_tag_once("hit")
	if result._final_damage > 0:
		result._append_tag_once("damage")
	if result._element_status == CombatStatus.SubResult.APPLIED:
		result._append_tag_once(String(result._source_element_id))
	if result.reaction_triggered:
		result._append_tag_once("reaction")
	return result


func _copy_request_metadata(request: HitRequest) -> void:
	if request == null:
		return
	_delivery_id = request.delivery_id
	_hit_index = request.hit_index
	_hit_position = request.hit_position
	_hit_direction = request.hit_direction
	if request.payload != null:
		_source_element_id = request.payload.element_id
	if request.cast_snapshot == null:
		return
	_cast_id = request.cast_snapshot.cast_id
	_root_owner_id = request.cast_snapshot.root_owner_id
	_skill_id = request.cast_snapshot.skill_id
	_source_team_id = request.cast_snapshot.team_id


func _copy_locked_damage_input(payload: RuntimeAttackPayload) -> void:
	if payload == null:
		return
	_effective_attack = payload.effective_attack
	_damage_multiplier = payload.damage_multiplier
	_fixed_damage_bonus = payload.fixed_damage_bonus


func _append_tag_once(tag: String) -> void:
	if not _presentation_tags.has(tag):
		_presentation_tags.append(tag)
