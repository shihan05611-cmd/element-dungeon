class_name IgnitionPrepareResult
extends RefCounted

var accepted: bool
var reject_reason: CastAttemptResult.RejectReason
var detail: StringName
var matched_element_amount: int
var transaction: SkillExecutionCommitTransaction


static func success(
		amount: int,
		commit_transaction: SkillExecutionCommitTransaction
) -> IgnitionPrepareResult:
	var result := IgnitionPrepareResult.new()
	result.accepted = true
	result.matched_element_amount = amount
	result.transaction = commit_transaction
	return result


static func rejected(
		reason: CastAttemptResult.RejectReason,
		p_detail: StringName
) -> IgnitionPrepareResult:
	var result := IgnitionPrepareResult.new()
	result.accepted = false
	result.reject_reason = reason
	result.detail = p_detail
	return result
