class_name ElementReclaimExecutionSnapshot
extends SkillExecutionSnapshot

var matched_element_amount: int
var theoretical_energy_restore: int


func _init(
		p_cast_snapshot: CastSnapshot,
		p_energy_before: int,
		p_maximum_energy: int,
		p_movement_policy: MovementPolicy,
		p_matched_element_amount: int,
		p_theoretical_energy_restore: int
) -> void:
	super(
		p_cast_snapshot,
		p_energy_before,
		p_maximum_energy,
		0,
		p_movement_policy
	)
	matched_element_amount = p_matched_element_amount
	theoretical_energy_restore = p_theoretical_energy_restore
	if _validation_error.is_empty():
		if matched_element_amount <= 0:
			_validation_error = &"missing_reclaim_amount"
		elif theoretical_energy_restore <= 0:
			_validation_error = &"invalid_theoretical_restore"
