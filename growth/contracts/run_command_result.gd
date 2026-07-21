class_name RunCommandResult
extends RefCounted

## Structured synchronous result. Optional result fields are explicitly typed;
## callers never need to inspect an arbitrary Dictionary payload.

enum RejectReason {
	NONE,
	INVALID_ARGUMENT,
	INVALID_STATE,
	INVALID_TRANSITION,
	INVALID_EVENT,
	DUPLICATE_EVENT,
	DUPLICATE_ROOM,
	NEGATIVE_EXPERIENCE,
	UNKNOWN_STAT,
	NEGATIVE_ALLOCATION,
	INSUFFICIENT_STAT_POINTS,
	STALE_DRAFT,
	ALREADY_CONFIRMED,
	LOADOUT_REJECTED,
	CONFIGURATION_ERROR,
	NO_PENDING_REWARD,
	OFFER_MISMATCH,
	OPTION_NOT_FOUND,
	ALREADY_CLAIMED,
	ALREADY_OWNED,
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

var run_snapshot: RunSnapshot:
	get:
		return _run_snapshot

var reward_offer: RewardOffer:
	get:
		return _reward_offer

var reward_option: RewardOption:
	get:
		return _reward_option

var shop_commit: ShopCommitSummary:
	get:
		return _shop_commit

var _accepted: bool
var _reject_reason: RejectReason
var _detail: StringName
var _run_snapshot: RunSnapshot
var _reward_offer: RewardOffer
var _reward_option: RewardOption
var _shop_commit: ShopCommitSummary


func _init(
		p_accepted: bool,
		p_reject_reason: RejectReason,
		p_detail: StringName = &"",
		p_run_snapshot: RunSnapshot = null,
		p_reward_offer: RewardOffer = null,
		p_reward_option: RewardOption = null,
		p_shop_commit: ShopCommitSummary = null
) -> void:
	_accepted = p_accepted
	_reject_reason = p_reject_reason
	_detail = p_detail
	_run_snapshot = p_run_snapshot
	_reward_offer = p_reward_offer
	_reward_option = p_reward_option
	_shop_commit = p_shop_commit


static func success(
		p_run_snapshot: RunSnapshot = null,
		p_reward_offer: RewardOffer = null,
		p_reward_option: RewardOption = null,
		p_shop_commit: ShopCommitSummary = null
) -> RunCommandResult:
	return RunCommandResult.new(
		true,
		RejectReason.NONE,
		&"",
		p_run_snapshot,
		p_reward_offer,
		p_reward_option,
		p_shop_commit
	)


static func rejected(reason: RejectReason, p_detail: StringName = &"") -> RunCommandResult:
	return RunCommandResult.new(false, reason, p_detail)
