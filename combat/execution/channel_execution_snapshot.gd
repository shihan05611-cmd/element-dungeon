class_name ChannelExecutionSnapshot
extends SkillExecutionSnapshot

var tick_interval: float:
	get:
		return _tick_interval

var energy_per_tick: int:
	get:
		return _energy_per_tick

var damage_multiplier: float:
	get:
		return _damage_multiplier

var element_amount: int:
	get:
		return _element_amount

var presentation_tags: PackedStringArray:
	get:
		return _presentation_tags.duplicate()

var _tick_interval: float
var _energy_per_tick: int
var _damage_multiplier: float
var _element_amount: int
var _presentation_tags: PackedStringArray


func _init(
		p_cast_snapshot: CastSnapshot,
		p_energy_before: int,
		p_maximum_energy: int,
		p_movement_policy: MovementPolicy,
		p_tick_interval: float,
		p_energy_per_tick: int,
		p_damage_multiplier: float,
		p_element_amount: int,
		p_presentation_tags: PackedStringArray = PackedStringArray()
) -> void:
	super(
		p_cast_snapshot,
		p_energy_before,
		p_maximum_energy,
		0,
		p_movement_policy
	)
	_tick_interval = p_tick_interval
	_energy_per_tick = p_energy_per_tick
	_damage_multiplier = p_damage_multiplier
	_element_amount = p_element_amount
	_presentation_tags = p_presentation_tags.duplicate()
	if _validation_error.is_empty():
		if not is_finite(_tick_interval) or _tick_interval <= 0.0:
			_validation_error = &"invalid_tick_interval"
		elif _energy_per_tick <= 0:
			_validation_error = &"invalid_energy_per_tick"
		elif not is_finite(_damage_multiplier) or _damage_multiplier < 0.0:
			_validation_error = &"invalid_damage_multiplier"
		elif _element_amount <= 0 or _element_amount > 10:
			_validation_error = &"invalid_element_amount"


func build_tick_payload() -> RuntimeAttackPayload:
	if not is_valid():
		return RuntimeAttackPayload.invalid(validation_error)
	return RuntimeAttackPayload.from_locked_stats(
		stat_snapshot,
		_damage_multiplier,
		cast_element_id,
		_element_amount,
		_presentation_tags
	)
