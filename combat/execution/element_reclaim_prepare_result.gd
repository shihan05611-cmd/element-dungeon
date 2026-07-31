class_name ElementReclaimPrepareResult
extends RefCounted

var accepted: bool
var reject_reason: CastAttemptResult.RejectReason
var detail: StringName
var matched_element_amount: int
var theoretical_energy_restore: int
var transaction: SkillExecutionCommitTransaction


func _init(
		p_accepted: bool,
		p_reject_reason: CastAttemptResult.RejectReason,
		p_detail: StringName = &"",
		p_matched_element_amount: int = 0,
		p_theoretical_energy_restore: int = 0,
		p_transaction: SkillExecutionCommitTransaction = null
) -> void:
	accepted = p_accepted
	reject_reason = p_reject_reason
	detail = p_detail
	matched_element_amount = p_matched_element_amount
	theoretical_energy_restore = p_theoretical_energy_restore
	transaction = p_transaction


static func success(
		p_matched_element_amount: int,
		p_theoretical_energy_restore: int,
		p_transaction: SkillExecutionCommitTransaction
) -> ElementReclaimPrepareResult:
	return ElementReclaimPrepareResult.new(
		true,
		CastAttemptResult.RejectReason.NONE,
		&"",
		p_matched_element_amount,
		p_theoretical_energy_restore,
		p_transaction
	)


static func rejected(
		reason: CastAttemptResult.RejectReason,
		p_detail: StringName = &""
) -> ElementReclaimPrepareResult:
	return ElementReclaimPrepareResult.new(false, reason, p_detail)
