class_name ElementBeamDelivery
extends DeliveryBase

## Geometry-only Channel consumer. It owns no timer and accepts only ordered
## ChannelTickSnapshot values produced by task 14's runtime.

signal tick_submitted(tick_index: int, target_count: int)

const FINISH_CHANNEL_CLOSED: StringName = &"channel_closed"

@export_range(0.001, 100000.0, 0.1, "or_greater") var beam_length: float = 320.0
@export_range(0.001, 100000.0, 0.1, "or_greater") var beam_width: float = 24.0
@export_flags_2d_physics var hurtbox_collision_mask: int = 8
@export_range(1, 4096, 1) var max_query_results: int = 256
@export var active_on_ready: bool = true

var channel_active: bool:
	get:
		return _channel_active

var last_tick_index: int:
	get:
		return _last_tick_index

var _channel_snapshot: ChannelExecutionSnapshot
var _channel_active: bool = false
var _last_tick_index: int = 0


func initialize_channel(
		snapshot: ChannelExecutionSnapshot,
		p_delivery_id: int,
		p_start_world_transform: Transform2D,
		p_direction: Vector2
) -> bool:
	if (
		snapshot == null
		or not snapshot.is_valid()
		or snapshot.movement_policy != SkillExecutionSnapshot.MovementPolicy.ALLOW_MOVEMENT
	):
		return false
	var initial_payload := snapshot.build_tick_payload()
	if not initial_payload.is_valid():
		return false
	if not initialize_delivery(
		snapshot.cast_snapshot,
		initial_payload,
		p_delivery_id,
		p_start_world_transform,
		p_direction
	):
		return false
	_channel_snapshot = snapshot
	return true


func submit_tick(tick: ChannelTickSnapshot) -> bool:
	if (
		not _runtime_is_ready()
		or not _channel_active
		or tick == null
		or not tick.is_valid()
		or tick.channel_snapshot != _channel_snapshot
		or tick.tick_index != _last_tick_index + 1
		or not _payload_matches_locked_tick(tick.payload)
	):
		return false
	# Keep only the current tick's receiver set. Cross-tick identity remains
	# distinct through hit_index and CombatReceiver's standard ledger.
	clear_hit_records()
	_last_tick_index = tick.tick_index
	var candidates := CombatTargetQuery2D.query_beam(
		self,
		beam_length,
		beam_width,
		hurtbox_collision_mask,
		max_query_results,
		cast_snapshot.team_id,
		direction,
		false
	)
	for candidate: CombatTargetCandidate2D in candidates:
		if not candidate.is_valid():
			continue
		_submit_hurtbox_hit_with_payload(
			candidate.hurtbox,
			tick.tick_index,
			candidate.hit_position,
			direction,
			tick.payload
		)
	var target_count := get_recorded_target_count(tick.tick_index)
	tick_submitted.emit(tick.tick_index, target_count)
	return true


func close_hit_window() -> void:
	_channel_active = false
	clear_hit_records()
	if _runtime_is_ready() and not is_finished:
		finish(FINISH_CHANNEL_CLOSED)


func _on_delivery_ready() -> void:
	if _channel_snapshot == null or not _channel_snapshot.is_valid():
		_fail_configuration(&"invalid_channel_snapshot")
		return
	if (
		not is_finite(beam_length)
		or beam_length <= 0.0
		or not is_finite(beam_width)
		or beam_width <= 0.0
		or hurtbox_collision_mask <= 0
		or max_query_results <= 0
	):
		_fail_configuration(&"invalid_beam_query_configuration")
		return
	_channel_active = active_on_ready


func _on_delivery_cleanup() -> void:
	_channel_active = false
	_last_tick_index = 0
	_channel_snapshot = null
	_disconnect_owned_signal(&"tick_submitted")
	super()


func _payload_matches_locked_tick(tick_payload: RuntimeAttackPayload) -> bool:
	if tick_payload == null or not tick_payload.is_valid() or payload == null:
		return false
	return (
		is_equal_approx(tick_payload.effective_attack, payload.effective_attack)
		and is_equal_approx(tick_payload.damage_multiplier, payload.damage_multiplier)
		and is_equal_approx(tick_payload.fixed_damage_bonus, payload.fixed_damage_bonus)
		and is_equal_approx(tick_payload.offensive_damage, payload.offensive_damage)
		and tick_payload.element_id == payload.element_id
		and tick_payload.element_amount == payload.element_amount
		and tick_payload.presentation_tags == payload.presentation_tags
	)
