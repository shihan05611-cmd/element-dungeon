class_name EnergyComponent
extends Node

## Per-actor integer energy. All notifications are emitted after the stored
## value is committed and include the actual (clamped) delta.

signal energy_changed(current: int, maximum: int, delta: int)

@export_range(0, 1000000, 1, "or_greater") var maximum_energy: int = 100
@export_range(0, 1000000, 1, "or_greater") var starting_energy: int = 100
@export_range(0.0, 1000000.0, 0.1, "or_greater") var regeneration_per_second: float = 5.0
@export_range(0.0, 3600.0, 0.05, "or_greater") var regeneration_delay_after_spend: float = 1.0
@export var regeneration_enabled: bool = true

var current_energy: int:
	get:
		return _current_energy

var maximum: int:
	get:
		return _maximum_energy

var regeneration_paused: bool:
	get:
		return _regeneration_paused

var _current_energy: int = 100
var _maximum_energy: int = 100
var _runtime_configured: bool = false
var _regeneration_paused: bool = false
var _regeneration_delay_remaining: float = 0.0
var _regeneration_accumulator: float = 0.0


func _ready() -> void:
	_sanitize_regeneration_configuration()
	if _runtime_configured:
		return
	_maximum_energy = maxi(0, maximum_energy)
	_current_energy = clampi(starting_energy, 0, _maximum_energy)
	_reset_regeneration_clock()


func _process(delta: float) -> void:
	advance_regeneration(delta)


func configure_runtime(p_maximum: int, p_current: int = -1) -> bool:
	if p_maximum < 0 or p_current < -1:
		return false
	var previous_current := _current_energy
	var previous_maximum := _maximum_energy
	_maximum_energy = p_maximum
	_current_energy = p_maximum if p_current == -1 else clampi(p_current, 0, p_maximum)
	maximum_energy = p_maximum
	starting_energy = _current_energy
	_runtime_configured = true
	_sanitize_regeneration_configuration()
	_reset_regeneration_clock()
	if _current_energy != previous_current or _maximum_energy != previous_maximum:
		energy_changed.emit(_current_energy, _maximum_energy, _current_energy - previous_current)
	return true


func can_spend(amount: int) -> bool:
	return amount >= 0 and _current_energy >= amount


func try_spend(amount: int) -> bool:
	if not _try_spend_silent(amount):
		return false
	_commit_spend_regeneration_delay(amount)
	_emit_committed_delta(-amount)
	return true


func restore(amount: int) -> bool:
	if amount < 0:
		return false
	var previous := _current_energy
	_current_energy = mini(_maximum_energy, _current_energy + amount)
	var actual_delta := _current_energy - previous
	if _current_energy >= _maximum_energy:
		_reset_regeneration_clock()
	_emit_committed_delta(actual_delta)
	return true


func set_current(p_current: int) -> bool:
	if p_current < 0 or p_current > _maximum_energy:
		return false
	var delta := p_current - _current_energy
	_current_energy = p_current
	if _current_energy >= _maximum_energy:
		_reset_regeneration_clock()
	_emit_committed_delta(delta)
	return true


func set_regeneration_paused(paused: bool) -> void:
	_regeneration_paused = paused


## Deterministic recovery clock for tests and integrations. The delay clock and
## fractional recovery both pause while regeneration is paused.
func advance_regeneration(delta: float) -> int:
	if not is_finite(delta) or delta <= 0.0:
		return 0
	if (
		not regeneration_enabled
		or _regeneration_paused
		or not is_finite(regeneration_per_second)
		or regeneration_per_second <= 0.0
	):
		return 0
	if _current_energy >= _maximum_energy:
		_reset_regeneration_clock()
		return 0

	var active_delta := delta
	if _regeneration_delay_remaining > 0.0:
		var consumed_delay := minf(_regeneration_delay_remaining, active_delta)
		_regeneration_delay_remaining = maxf(0.0, _regeneration_delay_remaining - consumed_delay)
		active_delta -= consumed_delay
	if active_delta <= 0.0:
		return 0

	_regeneration_accumulator += active_delta * regeneration_per_second
	var restored_amount := mini(
		floori(_regeneration_accumulator),
		_maximum_energy - _current_energy,
	)
	if restored_amount <= 0:
		return 0
	_current_energy += restored_amount
	_regeneration_accumulator -= restored_amount
	if _current_energy >= _maximum_energy:
		_reset_regeneration_clock()
	_emit_committed_delta(restored_amount)
	return restored_amount


## Internal transaction hook used by SkillExecutor so all accepted-cast state
## can be committed before observers are notified. Callers should use
## try_spend() unless coordinating the same synchronous transaction.
func _try_spend_silent(amount: int) -> bool:
	if not can_spend(amount):
		return false
	_current_energy -= amount
	return true


## Completes the non-value side effect of a silent spend only after its caller
## has committed the surrounding transaction.
func _commit_spend_regeneration_delay(amount: int) -> void:
	if amount <= 0:
		return
	_regeneration_delay_remaining = regeneration_delay_after_spend
	_regeneration_accumulator = 0.0


func _restore_silent(amount: int) -> bool:
	if amount < 0 or _current_energy + amount > _maximum_energy:
		return false
	_current_energy += amount
	if _current_energy >= _maximum_energy:
		_reset_regeneration_clock()
	return true


func _emit_committed_delta(delta: int) -> void:
	if delta == 0:
		return
	energy_changed.emit(_current_energy, _maximum_energy, delta)


func _sanitize_regeneration_configuration() -> void:
	if not is_finite(regeneration_per_second) or regeneration_per_second < 0.0:
		regeneration_per_second = 0.0
	if not is_finite(regeneration_delay_after_spend) or regeneration_delay_after_spend < 0.0:
		regeneration_delay_after_spend = 0.0


func _reset_regeneration_clock() -> void:
	_regeneration_delay_remaining = 0.0
	_regeneration_accumulator = 0.0
