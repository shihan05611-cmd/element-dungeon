class_name CombatStatus
extends RefCounted

## Shared result states. Overall rejection and per-subsystem processing are
## intentionally separate so callers never have to infer element handling from
## one `accepted` flag.

enum SubResult {
	NOT_AVAILABLE,
	NOT_PROCESSED,
	PROCESSED_NO_CHANGE,
	APPLIED,
}

enum RejectReason {
	NONE,
	INVALID_REQUEST,
	TARGET_UNAVAILABLE,
	NO_RECEIVERS,
	FRIENDLY_FIRE,
	INVULNERABLE,
	BLOCKED,
	DODGED,
	DUPLICATE_HIT,
	REENTRANT,
	INVALID_TARGET_STATE,
	COMMIT_VALIDATION_FAILED,
}


static func reject_code(reason: RejectReason) -> StringName:
	match reason:
		RejectReason.NONE:
			return &"none"
		RejectReason.INVALID_REQUEST:
			return &"invalid_request"
		RejectReason.TARGET_UNAVAILABLE:
			return &"target_unavailable"
		RejectReason.NO_RECEIVERS:
			return &"no_receivers"
		RejectReason.FRIENDLY_FIRE:
			return &"friendly_fire"
		RejectReason.INVULNERABLE:
			return &"invulnerable"
		RejectReason.BLOCKED:
			return &"blocked"
		RejectReason.DODGED:
			return &"dodged"
		RejectReason.DUPLICATE_HIT:
			return &"duplicate_hit"
		RejectReason.REENTRANT:
			return &"reentrant"
		RejectReason.INVALID_TARGET_STATE:
			return &"invalid_target_state"
		RejectReason.COMMIT_VALIDATION_FAILED:
			return &"commit_validation_failed"
		_:
			return &"unknown_rejection"
