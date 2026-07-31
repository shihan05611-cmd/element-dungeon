class_name InstantDeliveryExecutionSnapshot
extends SkillExecutionSnapshot

var payload: RuntimeAttackPayload:
	get:
		return _payload

var spawn_snapshot: DeliverySpawnSnapshot:
	get:
		return _spawn_snapshot

var _payload: RuntimeAttackPayload
var _spawn_snapshot: DeliverySpawnSnapshot


func _init(
		p_cast_snapshot: CastSnapshot,
		p_energy_before: int,
		p_maximum_energy: int,
		p_energy_spent: int,
		p_movement_policy: MovementPolicy,
		p_payload: RuntimeAttackPayload,
		p_spawn_snapshot: DeliverySpawnSnapshot
) -> void:
	super(
		p_cast_snapshot,
		p_energy_before,
		p_maximum_energy,
		p_energy_spent,
		p_movement_policy
	)
	_payload = p_payload
	_spawn_snapshot = p_spawn_snapshot
	if _validation_error.is_empty():
		if _payload == null or not _payload.is_valid():
			_validation_error = &"invalid_payload"
		elif _spawn_snapshot == null or not _spawn_snapshot.is_valid():
			_validation_error = &"invalid_spawn_snapshot"


func runtime_payload() -> RuntimeAttackPayload:
	return _payload
