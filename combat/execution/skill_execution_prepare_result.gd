class_name SkillExecutionPrepareResult
extends RefCounted

var accepted: bool
var reject_reason: CastAttemptResult.RejectReason
var detail: StringName
var snapshot: SkillExecutionSnapshot
var runtime: SkillExecutionRuntime
var prepared_delivery: DeliveryBase
var commit_transaction: SkillExecutionCommitTransaction


func _init(
		p_accepted: bool,
		p_reject_reason: CastAttemptResult.RejectReason,
		p_detail: StringName = &"",
		p_snapshot: SkillExecutionSnapshot = null,
		p_runtime: SkillExecutionRuntime = null,
		p_prepared_delivery: DeliveryBase = null,
		p_commit_transaction: SkillExecutionCommitTransaction = null
) -> void:
	accepted = p_accepted
	reject_reason = p_reject_reason
	detail = p_detail
	snapshot = p_snapshot
	runtime = p_runtime
	prepared_delivery = p_prepared_delivery
	commit_transaction = p_commit_transaction


static func success(
		p_snapshot: SkillExecutionSnapshot,
		p_runtime: SkillExecutionRuntime,
		p_prepared_delivery: DeliveryBase = null,
		p_commit_transaction: SkillExecutionCommitTransaction = null
) -> SkillExecutionPrepareResult:
	return SkillExecutionPrepareResult.new(
		true,
		CastAttemptResult.RejectReason.NONE,
		&"",
		p_snapshot,
		p_runtime,
		p_prepared_delivery,
		p_commit_transaction
	)


static func rejected(
		reason: CastAttemptResult.RejectReason,
		p_detail: StringName = &""
) -> SkillExecutionPrepareResult:
	return SkillExecutionPrepareResult.new(false, reason, p_detail)
