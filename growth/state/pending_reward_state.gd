class_name PendingRewardState
extends RefCounted

var offer: RewardOffer:
	get:
		return _offer

var claimed: bool:
	get:
		return _claimed

var claimed_option_id: StringName:
	get:
		return _claimed_option_id

var _offer: RewardOffer
var _claimed: bool = false
var _claimed_option_id: StringName = &""


func install(new_offer: RewardOffer) -> RunCommandResult:
	if new_offer == null or not new_offer.valid:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.CONFIGURATION_ERROR, &"invalid_reward_offer")
	if _offer != null and not _claimed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"unclaimed_offer_already_pending")
	_offer = new_offer
	_claimed = false
	_claimed_option_id = &""
	return RunCommandResult.success()


func validate_claim(offer_id: StringName, option_id: StringName) -> RunCommandResult:
	if _offer == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.NO_PENDING_REWARD, &"no_pending_reward")
	if _claimed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_CLAIMED, &"reward_already_claimed")
	if offer_id != _offer.offer_id:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.OFFER_MISMATCH, &"offer_id_mismatch")
	if _offer.find_option(option_id) == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.OPTION_NOT_FOUND, &"reward_option_not_found")
	return RunCommandResult.success()


func mark_claimed(option_id: StringName) -> void:
	_claimed = true
	_claimed_option_id = option_id
