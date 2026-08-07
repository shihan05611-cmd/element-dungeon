class_name AllEnergyBurstExecutionSnapshot
extends SkillExecutionSnapshot

var payload: RuntimeAttackPayload:
	get:
		return _payload

var radius_scale: float:
	get:
		return _radius_scale

var impact_position: Vector2:
	get:
		return _impact_position

var _payload: RuntimeAttackPayload
var _radius_scale: float
var _impact_position: Vector2


func _init(
		p_cast_snapshot: CastSnapshot,
		p_energy_before: int,
		p_maximum_energy: int,
		p_movement_policy: MovementPolicy,
		p_payload: RuntimeAttackPayload,
		p_radius_scale: float,
		p_impact_position: Vector2
) -> void:
	super(
		p_cast_snapshot,
		p_energy_before,
		p_maximum_energy,
		p_energy_before,
		p_movement_policy
	)
	_payload = p_payload
	_radius_scale = p_radius_scale
	_impact_position = p_impact_position
	if _validation_error.is_empty():
		if _payload == null or not _payload.is_valid():
			_validation_error = &"invalid_payload"
		elif not is_finite(_radius_scale) or _radius_scale < 1.0:
			_validation_error = &"invalid_radius_scale"
		elif not _is_finite_vector(_impact_position):
			_validation_error = &"invalid_impact_position"


func runtime_payload() -> RuntimeAttackPayload:
	return _payload


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
