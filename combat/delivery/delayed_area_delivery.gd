class_name DelayedAreaDelivery
extends MeleeDelivery

## One-shot delayed AOE. The immutable CastSnapshot and RuntimeAttackPayload
## are retained by DeliveryBase while waiting; no caster/current-element lookup
## occurs when the delay elapses.

signal delayed_triggered(cast_id: int, delivery_id: int)

const FINISH_ACTIVE_WINDOW_COMPLETE: StringName = &"active_window_complete"

enum Phase {
	WAITING,
	ACTIVE,
	COMPLETE,
}

@export_range(0.0, 60.0, 0.001, "or_greater") var trigger_delay: float = 0.25
@export_range(0.001, 60.0, 0.001, "or_greater") var active_duration: float = 0.1

var delayed_phase: Phase:
	get:
		return _delayed_phase

var delay_remaining: float:
	get:
		return _delay_remaining

var _delayed_phase: Phase = Phase.WAITING
var _delay_remaining: float = 0.0
var _active_remaining: float = 0.0


func _on_delivery_ready() -> void:
	if hit_shape == null:
		_fail_configuration(&"missing_hit_shape")
		return
	if not is_finite(trigger_delay) or trigger_delay < 0.0:
		_fail_configuration(&"invalid_trigger_delay")
		return
	if not is_finite(active_duration) or active_duration <= 0.0:
		_fail_configuration(&"invalid_active_duration")
		return
	_delayed_phase = Phase.WAITING
	_delay_remaining = trigger_delay
	_active_remaining = active_duration
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	advance_delayed(delta)


func advance_delayed(delta: float) -> void:
	if not _runtime_is_ready() or not is_finite(delta) or delta <= 0.0:
		return
	var active_delta := delta
	if _delayed_phase == Phase.WAITING:
		if active_delta < _delay_remaining:
			_delay_remaining -= active_delta
			return
		active_delta -= _delay_remaining
		_delay_remaining = 0.0
		_delayed_phase = Phase.ACTIVE
		if not open_hit_window(initial_hit_index):
			_fail_configuration(&"delayed_window_open_failed")
			return
		delayed_triggered.emit(cast_snapshot.cast_id, delivery_id)
		# Query on the trigger step even when delta lands exactly on the delay.
		super._physics_process(0.0)

	if _delayed_phase != Phase.ACTIVE:
		return
	if active_delta > 0.0:
		super._physics_process(active_delta)
		_active_remaining -= active_delta
	if _active_remaining <= 0.0:
		_delayed_phase = Phase.COMPLETE
		close_hit_window()
		finish(FINISH_ACTIVE_WINDOW_COMPLETE)


func _on_delivery_cleanup() -> void:
	_delayed_phase = Phase.COMPLETE
	_delay_remaining = 0.0
	_active_remaining = 0.0
	_disconnect_owned_signal(&"delayed_triggered")
	super()

