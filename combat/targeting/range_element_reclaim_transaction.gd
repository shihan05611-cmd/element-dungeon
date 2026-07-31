class_name RangeElementReclaimTransaction
extends SkillExecutionCommitTransaction

var matched_element_amount: int:
	get:
		return _matched_element_amount

var theoretical_energy_restore: int:
	get:
		return _theoretical_energy_restore

var actual_energy_restore: int:
	get:
		return _actual_energy_restore

var target_count: int:
	get:
		return _target_plans.size()

var _energy_ref: WeakRef
var _energy_before: int
var _maximum_energy: int
var _target_plans: Array[ElementReclaimTargetPlan]
var _matched_element_amount: int = 0
var _theoretical_energy_restore: int = 0
var _expected_actual_energy_restore: int = 0
var _actual_energy_restore: int = 0
var _committed: bool = false
var _published: bool = false


func _init(
		energy: EnergyComponent,
		energy_before: int,
		maximum_energy: int,
		target_plans: Array[ElementReclaimTargetPlan]
) -> void:
	_energy_ref = weakref(energy)
	_energy_before = energy_before
	_maximum_energy = maximum_energy
	_target_plans = target_plans.duplicate()
	for target_plan: ElementReclaimTargetPlan in _target_plans:
		if target_plan != null and target_plan.consume_plan != null:
			_matched_element_amount += target_plan.consume_plan.consumed_amount
	_theoretical_energy_restore = _matched_element_amount * 5
	_expected_actual_energy_restore = mini(
		_theoretical_energy_restore,
		maxi(0, _maximum_energy - _energy_before)
	)


func validation_error() -> StringName:
	if _committed:
		return &""
	var energy := _energy_ref.get_ref() as EnergyComponent
	if (
		energy == null
		or not is_instance_valid(energy)
		or energy.is_queued_for_deletion()
	):
		return &"reclaim_energy_unavailable"
	if (
		energy.current_energy != _energy_before
		or energy.maximum != _maximum_energy
	):
		return &"reclaim_energy_snapshot_changed"
	if _energy_before >= _maximum_energy:
		return &"energy_already_full"
	if _target_plans.is_empty() or _matched_element_amount <= 0:
		return &"missing_reclaim_targets"
	var previous_identity: int = 0
	for target_plan: ElementReclaimTargetPlan in _target_plans:
		if target_plan == null:
			return &"missing_reclaim_target_plan"
		if target_plan.stable_identity <= previous_identity:
			return &"unstable_reclaim_target_order"
		previous_identity = target_plan.stable_identity
		var target_error := target_plan.validation_error()
		if not target_error.is_empty():
			return target_error
	return &""


func commit_silent() -> void:
	assert(not _committed, "reclaim transaction commits once")
	assert(validation_error().is_empty(), "reclaim transaction must validate before commit")
	for target_plan: ElementReclaimTargetPlan in _target_plans:
		target_plan.commit_silent()
	var energy := _energy_ref.get_ref() as EnergyComponent
	_actual_energy_restore = energy._restore_clamped_silent(_theoretical_energy_restore)
	assert(
		_actual_energy_restore == _expected_actual_energy_restore,
		"reclaim energy delta must match the locked snapshot"
	)
	_committed = true


func publish_committed() -> void:
	assert(_committed, "reclaim transaction publishes only after commit")
	assert(not _published, "reclaim transaction publishes once")
	for target_plan: ElementReclaimTargetPlan in _target_plans:
		target_plan.publish_committed()
	var energy := _energy_ref.get_ref() as EnergyComponent
	assert(energy != null and is_instance_valid(energy))
	energy._emit_committed_delta(_actual_energy_restore)
	_published = true
