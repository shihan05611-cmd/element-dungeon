class_name ChannelTickSnapshot
extends RefCounted

var channel_snapshot: ChannelExecutionSnapshot
var tick_index: int
var energy_before: int
var energy_spent: int
var payload: RuntimeAttackPayload
var validation_error: StringName = &""


func _init(
		p_channel_snapshot: ChannelExecutionSnapshot,
		p_tick_index: int,
		p_energy_before: int,
		p_energy_spent: int,
		p_payload: RuntimeAttackPayload
) -> void:
	channel_snapshot = p_channel_snapshot
	tick_index = p_tick_index
	energy_before = p_energy_before
	energy_spent = p_energy_spent
	payload = p_payload
	validation_error = _validate_values()


func is_valid() -> bool:
	return validation_error.is_empty()


func _validate_values() -> StringName:
	if channel_snapshot == null or not channel_snapshot.is_valid():
		return &"invalid_channel_snapshot"
	if tick_index <= 0:
		return &"invalid_tick_index"
	if energy_before < energy_spent or energy_spent <= 0:
		return &"invalid_tick_energy"
	if payload == null or not payload.is_valid():
		return &"invalid_tick_payload"
	return &""
