class_name RuntimeLoadoutChangeResult
extends RefCounted

## Result used by the Agent B-owned mutable Runtime Loadout implementation.

var accepted: bool:
	get:
		return _accepted

var detail: StringName:
	get:
		return _detail

var snapshot: RuntimeLoadoutSnapshot:
	get:
		return _snapshot

var _accepted: bool
var _detail: StringName
var _snapshot: RuntimeLoadoutSnapshot


func _init(p_accepted: bool, p_detail: StringName, p_snapshot: RuntimeLoadoutSnapshot) -> void:
	_accepted = p_accepted
	_detail = p_detail
	_snapshot = p_snapshot


static func success(p_snapshot: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
	return RuntimeLoadoutChangeResult.new(true, &"", p_snapshot)


static func rejected(p_detail: StringName, p_snapshot: RuntimeLoadoutSnapshot) -> RuntimeLoadoutChangeResult:
	return RuntimeLoadoutChangeResult.new(false, p_detail, p_snapshot)
