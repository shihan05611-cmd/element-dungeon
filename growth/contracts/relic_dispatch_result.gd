class_name RelicDispatchResult
extends RefCounted

var accepted: bool:
	get:
		return _accepted


var detail: StringName:
	get:
		return _detail

var triggered_relic_ids: Array[StringName]:
	get:
		return _triggered_relic_ids.duplicate()

var _accepted: bool
var _detail: StringName
var _triggered_relic_ids: Array[StringName] = []


func _init(
		p_accepted: bool,
		p_detail: StringName,
		p_triggered_relic_ids: Array[StringName] = []
) -> void:
	_accepted = p_accepted
	_detail = p_detail
	_triggered_relic_ids = p_triggered_relic_ids.duplicate()


static func success(p_triggered_relic_ids: Array[StringName] = []) -> RelicDispatchResult:
	return RelicDispatchResult.new(true, &"", p_triggered_relic_ids)




static func rejected(p_detail: StringName) -> RelicDispatchResult:
	return RelicDispatchResult.new(false, p_detail)
