class_name ShopDraftOpenResult
extends RefCounted

var accepted: bool:
	get:
		return _accepted

var reject_reason: RunCommandResult.RejectReason:
	get:
		return _reject_reason

var detail: StringName:
	get:
		return _detail

var draft: ShopDraft:
	get:
		return _draft

var shop_snapshot: ShopSnapshot:
	get:
		return _shop_snapshot

var _accepted: bool
var _reject_reason: RunCommandResult.RejectReason
var _detail: StringName
var _draft: ShopDraft
var _shop_snapshot: ShopSnapshot


func _init(
		p_accepted: bool,
		p_reject_reason: RunCommandResult.RejectReason,
		p_detail: StringName,
		p_draft: ShopDraft,
		p_shop_snapshot: ShopSnapshot = null
) -> void:
	_accepted = p_accepted
	_reject_reason = p_reject_reason
	_detail = p_detail
	_draft = p_draft
	_shop_snapshot = p_shop_snapshot


static func success(p_draft: ShopDraft, p_shop_snapshot: ShopSnapshot = null) -> ShopDraftOpenResult:
	return ShopDraftOpenResult.new(
		true,
		RunCommandResult.RejectReason.NONE,
		&"",
		p_draft,
		p_shop_snapshot
	)


static func rejected(reason: RunCommandResult.RejectReason, p_detail: StringName) -> ShopDraftOpenResult:
	return ShopDraftOpenResult.new(false, reason, p_detail, null)
