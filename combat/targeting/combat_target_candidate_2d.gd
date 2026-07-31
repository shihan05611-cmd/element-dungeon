class_name CombatTargetCandidate2D
extends RefCounted

## Typed result produced only from an explicit CombatHurtbox bridge.

var hurtbox: CombatHurtbox:
	get:
		return _hurtbox

var receiver: CombatReceiver:
	get:
		return _receiver

var stable_identity: int:
	get:
		return _stable_identity

var hit_position: Vector2:
	get:
		return _hit_position

var _hurtbox: CombatHurtbox
var _receiver: CombatReceiver
var _stable_identity: int
var _hit_position: Vector2


func _init(
		p_hurtbox: CombatHurtbox,
		p_receiver: CombatReceiver,
		p_hit_position: Vector2
) -> void:
	_hurtbox = p_hurtbox
	_receiver = p_receiver
	_stable_identity = p_receiver.get_instance_id() if p_receiver != null else 0
	_hit_position = p_hit_position


func is_valid() -> bool:
	return (
		_hurtbox != null
		and is_instance_valid(_hurtbox)
		and not _hurtbox.is_queued_for_deletion()
		and _receiver != null
		and is_instance_valid(_receiver)
		and not _receiver.is_queued_for_deletion()
		and _hurtbox.get_combat_receiver() == _receiver
		and _stable_identity == _receiver.get_instance_id()
		and is_finite(_hit_position.x)
		and is_finite(_hit_position.y)
	)
