class_name CastAttemptResult
extends RefCounted

## Immutable result of the synchronous cast transaction. Rejections never
## contain partially-created snapshots, payloads, or resource commitments.

enum RejectReason {
	NONE,
	BUSY,
	INSUFFICIENT_ENERGY,
	COOLDOWN_ACTIVE,
	ELEMENT_UNAVAILABLE,
	EXTERNAL_GATE_REJECTED,
	INVALID_CONFIGURATION,
	SLOT_UNASSIGNED,
	NOT_CASTABLE,
	MISSING_COMPONENT,
	DELIVERY_UNAVAILABLE,
	NO_LEGAL_TARGET,
	NO_BENEFIT,
}

var accepted: bool:
	get:
		return _accepted

var reject_reason: RejectReason:
	get:
		return _reject_reason

var detail: StringName:
	get:
		return _detail

var slot_id: StringName:
	get:
		return _slot_id

var skill_id: StringName:
	get:
		return _skill_id

var cast_snapshot: CastSnapshot:
	get:
		return _cast_snapshot

var payload: RuntimeAttackPayload:
	get:
		return _payload

var execution_snapshot: SkillExecutionSnapshot:
	get:
		return _execution_snapshot

var cooldown_remaining: float:
	get:
		return _cooldown_remaining

var _accepted: bool
var _reject_reason: RejectReason
var _detail: StringName
var _slot_id: StringName
var _skill_id: StringName
var _cast_snapshot: CastSnapshot
var _payload: RuntimeAttackPayload
var _execution_snapshot: SkillExecutionSnapshot
var _cooldown_remaining: float


func _init(
		p_accepted: bool,
		p_reject_reason: RejectReason,
		p_slot_id: StringName = &"",
		p_skill_id: StringName = &"",
		p_cast_snapshot: CastSnapshot = null,
		p_payload: RuntimeAttackPayload = null,
		p_execution_snapshot: SkillExecutionSnapshot = null,
		p_detail: StringName = &"",
		p_cooldown_remaining: float = 0.0
) -> void:
	_accepted = p_accepted
	_reject_reason = p_reject_reason
	_slot_id = p_slot_id
	_skill_id = p_skill_id
	_cast_snapshot = p_cast_snapshot
	_payload = p_payload
	_execution_snapshot = p_execution_snapshot
	_detail = p_detail
	_cooldown_remaining = maxf(0.0, p_cooldown_remaining)


static func success(
		p_skill_id: StringName,
		p_cast_snapshot: CastSnapshot,
		p_execution_snapshot: SkillExecutionSnapshot,
		p_slot_id: StringName = &""
) -> CastAttemptResult:
	var runtime_payload := (
		p_execution_snapshot.runtime_payload()
		if p_execution_snapshot != null
		else null
	)
	return CastAttemptResult.new(
		true,
		RejectReason.NONE,
		p_slot_id,
		p_skill_id,
		p_cast_snapshot,
		runtime_payload,
		p_execution_snapshot
	)


static func rejected(
		reason: RejectReason,
		p_skill_id: StringName = &"",
		p_detail: StringName = &"",
		p_cooldown_remaining: float = 0.0,
		p_slot_id: StringName = &""
) -> CastAttemptResult:
	return CastAttemptResult.new(
		false,
		reason,
		p_slot_id,
		p_skill_id,
		null,
		null,
		null,
		p_detail,
		p_cooldown_remaining
	)


func reason_name() -> StringName:
	match _reject_reason:
		RejectReason.NONE:
			return &"none"
		RejectReason.BUSY:
			return &"busy"
		RejectReason.INSUFFICIENT_ENERGY:
			return &"insufficient_energy"
		RejectReason.COOLDOWN_ACTIVE:
			return &"cooldown_active"
		RejectReason.ELEMENT_UNAVAILABLE:
			return &"element_unavailable"
		RejectReason.EXTERNAL_GATE_REJECTED:
			return &"external_gate_rejected"
		RejectReason.INVALID_CONFIGURATION:
			return &"invalid_configuration"
		RejectReason.SLOT_UNASSIGNED:
			return &"slot_unassigned"
		RejectReason.NOT_CASTABLE:
			return &"not_castable"
		RejectReason.MISSING_COMPONENT:
			return &"missing_component"
		RejectReason.DELIVERY_UNAVAILABLE:
			return &"delivery_unavailable"
		RejectReason.NO_LEGAL_TARGET:
			return &"no_legal_target"
		RejectReason.NO_BENEFIT:
			return &"no_benefit"
		_:
			return &"unknown"
