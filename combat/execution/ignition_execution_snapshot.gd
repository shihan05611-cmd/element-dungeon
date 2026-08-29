class_name IgnitionExecutionSnapshot
extends SkillExecutionSnapshot

var absorbed_fire_layers: int
var ignition_multiplier: float


func _init(
		p_cast_snapshot: CastSnapshot,
		p_energy_before: int,
		p_maximum_energy: int,
		p_movement_policy: MovementPolicy,
		p_absorbed_fire_layers: int
) -> void:
	super(p_cast_snapshot, p_energy_before, p_maximum_energy, 0, p_movement_policy)
	absorbed_fire_layers = p_absorbed_fire_layers
	ignition_multiplier = IgnitionState.multiplier_for(
		absorbed_fire_layers,
		p_cast_snapshot.level_effect.damage_scale
	)
	if _validation_error.is_empty() and absorbed_fire_layers <= 0:
		_validation_error = &"missing_ignition_fire_layers"
