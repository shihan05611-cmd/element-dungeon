class_name ProgressionState
extends RefCounted

## Per-run mutable progression aggregate. It never emits during a mutation;
## RunSession publishes only after the whole command commits.

var _level: int = 1
var _experience: int = 0
var _unspent_stat_points: int = 0
var _attack_points: int = 0
var _vitality_points: int = 0
var _energy_points: int = 0
var _revision: int = 0


func snapshot() -> ProgressionSnapshot:
	return ProgressionSnapshot.new(
		_level,
		_experience,
		ExperienceService.requirement_for_level(_level),
		_unspent_stat_points,
		AllocatedStatsSnapshot.new(_attack_points, _vitality_points, _energy_points),
		_revision
	)


func try_add_experience(amount: int) -> RunCommandResult:
	if amount < 0:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.NEGATIVE_EXPERIENCE, &"negative_experience")
	var plan := ExperienceService.plan_gain(snapshot(), amount)
	if not plan.valid:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, plan.error)
	var levels_gained := plan.levels_gained
	_level = plan.level_after
	_experience = plan.experience_after
	_unspent_stat_points += levels_gained
	if amount > 0:
		_revision += 1
	return RunCommandResult.success()


func validate_allocation(delta: AllocatedStatsSnapshot) -> RunCommandResult:
	if delta == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"missing_allocation")
	if delta.attack_points < 0 or delta.vitality_points < 0 or delta.energy_points < 0:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.NEGATIVE_ALLOCATION, &"negative_allocation")
	if delta.total_points > _unspent_stat_points:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INSUFFICIENT_STAT_POINTS,
			&"allocation_exceeds_unspent_points"
		)
	return RunCommandResult.success()


func commit_allocation(delta: AllocatedStatsSnapshot) -> RunCommandResult:
	var validation := validate_allocation(delta)
	if not validation.accepted:
		return validation
	_attack_points += delta.attack_points
	_vitality_points += delta.vitality_points
	_energy_points += delta.energy_points
	_unspent_stat_points -= delta.total_points
	if delta.total_points > 0:
		_revision += 1
	return RunCommandResult.success()
