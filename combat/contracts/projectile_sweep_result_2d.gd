class_name ProjectileSweepResult2D
extends RefCounted

enum Status {
	ENEMY_CONTACT,
	BLOCKER_CONTACT,
	NO_CONTACT,
	INVALID_CONTEXT,
	QUERY_FAILED,
}

var status: Status:
	get:
		return _status

var point: Vector2:
	get:
		return _point

var fraction: float:
	get:
		return _fraction

var distance: float:
	get:
		return _distance

var hurtbox: CombatHurtbox:
	get:
		return _hurtbox

var receiver: CombatReceiver:
	get:
		return _receiver

var stable_id: int:
	get:
		return _stable_id

var detail: StringName:
	get:
		return _detail

var _status: Status
var _point: Vector2 = Vector2.ZERO
var _fraction: float = 1.0
var _distance: float = 0.0
var _hurtbox: CombatHurtbox
var _receiver: CombatReceiver
var _stable_id: int = 0
var _detail: StringName = &""


func _init(
		p_status: Status,
		p_point: Vector2 = Vector2.ZERO,
		p_fraction: float = 1.0,
		p_distance: float = 0.0,
		p_hurtbox: CombatHurtbox = null,
		p_receiver: CombatReceiver = null,
		p_stable_id: int = 0,
		p_detail: StringName = &""
) -> void:
	_status = p_status
	match _status:
		Status.ENEMY_CONTACT:
			_point = p_point
			_fraction = clampf(p_fraction, 0.0, 1.0)
			_distance = maxf(0.0, p_distance)
			_hurtbox = p_hurtbox
			_receiver = p_receiver
			_stable_id = maxi(0, p_stable_id)
		Status.BLOCKER_CONTACT:
			_point = p_point
			_fraction = clampf(p_fraction, 0.0, 1.0)
			_distance = maxf(0.0, p_distance)
			_stable_id = maxi(0, p_stable_id)
		Status.INVALID_CONTEXT, Status.QUERY_FAILED:
			_detail = p_detail


static func enemy_contact(
		p_point: Vector2,
		p_fraction: float,
		p_distance: float,
		p_hurtbox: CombatHurtbox,
		p_receiver: CombatReceiver,
		p_stable_id: int
) -> ProjectileSweepResult2D:
	return ProjectileSweepResult2D.new(
		Status.ENEMY_CONTACT,
		p_point,
		p_fraction,
		p_distance,
		p_hurtbox,
		p_receiver,
		p_stable_id
	)


static func blocker_contact(
		p_point: Vector2,
		p_fraction: float,
		p_distance: float,
		p_stable_id: int
) -> ProjectileSweepResult2D:
	return ProjectileSweepResult2D.new(
		Status.BLOCKER_CONTACT,
		p_point,
		p_fraction,
		p_distance,
		null,
		null,
		p_stable_id
	)


static func no_contact() -> ProjectileSweepResult2D:
	return ProjectileSweepResult2D.new(Status.NO_CONTACT)


static func invalid_context(p_detail: StringName) -> ProjectileSweepResult2D:
	return ProjectileSweepResult2D.new(Status.INVALID_CONTEXT, Vector2.ZERO, 1.0, 0.0, null, null, 0, p_detail)


static func query_failed(p_detail: StringName) -> ProjectileSweepResult2D:
	return ProjectileSweepResult2D.new(Status.QUERY_FAILED, Vector2.ZERO, 1.0, 0.0, null, null, 0, p_detail)
