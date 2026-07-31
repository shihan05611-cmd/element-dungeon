class_name ChannelExecutionRuntime
extends SkillExecutionRuntime

var _elapsed_to_tick: float = 0.0
var _tick_index: int = 0


func _init(p_snapshot: ChannelExecutionSnapshot) -> void:
	super(p_snapshot, 0.0)


func time_to_boundary() -> float:
	if _complete:
		return 0.0
	var channel := _snapshot as ChannelExecutionSnapshot
	return maxf(0.0, channel.tick_interval - _elapsed_to_tick)


func advance_time(delta: float) -> void:
	_elapsed_to_tick += maxf(0.0, delta)


func reach_boundary(energy: EnergyComponent) -> SkillExecutionBoundaryResult:
	if _complete:
		return SkillExecutionBoundaryResult.finished(_end_result)
	var channel := _snapshot as ChannelExecutionSnapshot
	_elapsed_to_tick = maxf(0.0, _elapsed_to_tick - channel.tick_interval)
	if energy == null or not energy.can_spend(channel.energy_per_tick):
		_complete = true
		_end_result = SkillExecutionEndResult.new(
			SkillExecutionEndResult.Reason.INSUFFICIENT_ENERGY,
			&"channel_tick_energy_unavailable"
		)
		return SkillExecutionBoundaryResult.finished(_end_result)
	var before := energy.current_energy
	energy._spend_silent(channel.energy_per_tick)
	energy._commit_spend_regeneration_delay(channel.energy_per_tick)
	_tick_index += 1
	var tick_payload := channel.build_tick_payload()
	var tick_snapshot := ChannelTickSnapshot.new(
		channel,
		_tick_index,
		before,
		channel.energy_per_tick,
		tick_payload
	)
	assert(tick_snapshot.is_valid(), "validated channel definition must create valid ticks")
	return SkillExecutionBoundaryResult.tick(tick_snapshot, channel.energy_per_tick)


func supports_release() -> bool:
	return true


func request_release() -> bool:
	if _complete:
		return false
	_complete = true
	_end_result = SkillExecutionEndResult.new(SkillExecutionEndResult.Reason.RELEASED)
	return true
