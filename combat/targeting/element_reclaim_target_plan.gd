class_name ElementReclaimTargetPlan
extends RefCounted

## Weakly-bound carrier mutation. The receiver remains the explicit authority
## that proves the carrier still belongs to the queried legal target.

var stable_identity: int:
	get:
		return _stable_identity

var consume_plan: ElementLayerConsumePlan:
	get:
		return _consume_plan

var _receiver_ref: WeakRef
var _carrier_ref: WeakRef
var _source_team_id: StringName
var _stable_identity: int
var _consume_plan: ElementLayerConsumePlan


func _init(
		receiver: CombatReceiver,
		carrier: ElementCarrier,
		source_team_id: StringName,
		plan: ElementLayerConsumePlan
) -> void:
	_receiver_ref = weakref(receiver)
	_carrier_ref = weakref(carrier)
	_source_team_id = source_team_id
	_stable_identity = receiver.get_instance_id() if receiver != null else 0
	_consume_plan = plan


func validation_error() -> StringName:
	var receiver := _receiver_ref.get_ref() as CombatReceiver
	var carrier := _carrier_ref.get_ref() as ElementCarrier
	if (
		receiver == null
		or not is_instance_valid(receiver)
		or receiver.is_queued_for_deletion()
		or not receiver.accepting_hits
		or receiver.target_team_id.is_empty()
		or receiver.target_team_id == _source_team_id
		or receiver.get_instance_id() != _stable_identity
	):
		return &"reclaim_target_unavailable"
	if (
		carrier == null
		or not is_instance_valid(carrier)
		or carrier.is_queued_for_deletion()
		or receiver.get_element_carrier() != carrier
	):
		return &"reclaim_carrier_unavailable"
	if _consume_plan == null or not _consume_plan.is_valid():
		return &"invalid_element_consume_plan"
	if not carrier.can_commit_element_consume(_consume_plan):
		return &"reclaim_carrier_snapshot_changed"
	return &""


func commit_silent() -> void:
	var carrier := _carrier_ref.get_ref() as ElementCarrier
	assert(carrier != null and carrier.can_commit_element_consume(_consume_plan))
	carrier.commit_element_consume_silent(_consume_plan)


func publish_committed() -> void:
	var carrier := _carrier_ref.get_ref() as ElementCarrier
	assert(carrier != null and is_instance_valid(carrier))
	carrier.publish_element_consume(_consume_plan)
