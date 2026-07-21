class_name CastAttemptResult
extends RefCounted

## Immutable result of the synchronous cast transaction. Rejections never
## contain a partially-created CastSnapshot or RuntimeAttackPayload.

enum RejectReason {
	NONE,
	BUSY,
	INSUFFICIENT_ENERGY,
	COOLDOWN_ACTIVE,
	FORM_MISMATCH,
	EXTERNAL_GATE_REJECTED,
	INVALID_CONFIGURATION,
	SLOT_UNASSIGNED,
	MISSING_COMPONENT,
	DELIVERY_UNAVAILABLE,
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

var skill_id: StringName:
	get:
		return _skill_id

var cast_snapshot: CastSnapshot:
	get:
		return _cast_snapshot

var payload: RuntimeAttackPayload:
	get:
		return _payload

var cooldown_remaining: float:
	get:
		return _cooldown_remaining

var _accepted: bool
var _reject_reason: RejectReason
var _detail: StringName
var _skill_id: StringName
var _cast_snapshot: CastSnapshot
var _payload: RuntimeAttackPayload
var _cooldown_remaining: float


func _init(
		p_accepted: bool,
		p_reject_reason: RejectReason,
		p_skill_id: StringName = &"",
		p_cast_snapshot: CastSnapshot = null,
		p_payload: RuntimeAttackPayload = null,
		p_detail: StringName = &"",
		p_cooldown_remaining: float = 0.0
) -> void:
	_accepted = p_accepted
	_reject_reason = p_reject_reason
	_skill_id = p_skill_id
	_cast_snapshot = p_cast_snapshot
	_payload = p_payload
	_detail = p_detail
	_cooldown_remaining = maxf(0.0, p_cooldown_remaining)


static func success(
		p_skill_id: StringName,
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload
) -> CastAttemptResult:
	return CastAttemptResult.new(true, RejectReason.NONE, p_skill_id, p_cast_snapshot, p_payload)


static func rejected(
		reason: RejectReason,
		p_skill_id: StringName = &"",
		p_detail: StringName = &"",
		p_cooldown_remaining: float = 0.0
) -> CastAttemptResult:
	return CastAttemptResult.new(
		false,
		reason,
		p_skill_id,
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
		RejectReason.FORM_MISMATCH:
			return &"form_mismatch"
		RejectReason.EXTERNAL_GATE_REJECTED:
			return &"external_gate_rejected"
		RejectReason.INVALID_CONFIGURATION:
			return &"invalid_configuration"
		RejectReason.SLOT_UNASSIGNED:
			return &"slot_unassigned"
		RejectReason.MISSING_COMPONENT:
			return &"missing_component"
		RejectReason.DELIVERY_UNAVAILABLE:
			return &"delivery_unavailable"
		_:
			return &"unknown"
