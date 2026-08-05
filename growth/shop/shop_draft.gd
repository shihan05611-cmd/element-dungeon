class_name ShopDraft
extends RefCounted

## Mutable preview isolated from committed RunSession state.

var baseline_run_revision: int:
	get:
		return _baseline_run_revision

var baseline_progression: ProgressionSnapshot:
	get:
		return _baseline_progression

var baseline_loadout: RuntimeLoadoutSnapshot:
	get:
		return _baseline_loadout

var confirmed: bool:
	get:
		return _confirmed

var shop_session_id: StringName:
	get:
		return _shop_session_id

var _baseline_run_revision: int
var _baseline_progression: ProgressionSnapshot
var _baseline_loadout: RuntimeLoadoutSnapshot
var _pending_attack: int = 0
var _pending_vitality: int = 0
var _pending_energy: int = 0
var _working_entries: Array[RuntimeLoadoutSlotSnapshot] = []
var _confirmed: bool = false
var _progression_allocation_enabled: bool = true
var _shop_session_id: StringName = &""


func _init(
		p_baseline_run_revision: int,
		p_baseline_progression: ProgressionSnapshot,
		p_baseline_loadout: RuntimeLoadoutSnapshot,
		p_progression_allocation_enabled: bool = true,
		p_shop_session_id: StringName = &""
) -> void:
	_baseline_run_revision = p_baseline_run_revision
	_baseline_progression = p_baseline_progression
	_baseline_loadout = p_baseline_loadout
	_progression_allocation_enabled = p_progression_allocation_enabled
	_shop_session_id = p_shop_session_id
	_working_entries = p_baseline_loadout.entries if p_baseline_loadout != null else []


func pending_allocation() -> AllocatedStatsSnapshot:
	return AllocatedStatsSnapshot.new(_pending_attack, _pending_vitality, _pending_energy)


func preview_progression() -> ProgressionSnapshot:
	var allocated := _baseline_progression.allocated_stats
	return ProgressionSnapshot.new(
		_baseline_progression.level,
		_baseline_progression.experience,
		_baseline_progression.experience_required_for_next_level,
		_baseline_progression.unspent_stat_points - pending_allocation().total_points,
		AllocatedStatsSnapshot.new(
			allocated.attack_points + _pending_attack,
			allocated.vitality_points + _pending_vitality,
			allocated.energy_points + _pending_energy
		),
		_baseline_progression.revision
	)


func preview_loadout() -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new(_working_entries, _baseline_loadout.revision)


func try_allocate(stat_id: StringName, additional_points: int) -> RunCommandResult:
	if _confirmed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_CONFIRMED, &"shop_draft_already_confirmed")
	if not _progression_allocation_enabled:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.FEATURE_DISABLED,
			&"progression_allocation_disabled"
		)
	if not GrowthStatIds.is_valid(stat_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.UNKNOWN_STAT, &"unknown_stat_id")
	if additional_points < 0:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.NEGATIVE_ALLOCATION, &"negative_allocation")
	if pending_allocation().total_points + additional_points > _baseline_progression.unspent_stat_points:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INSUFFICIENT_STAT_POINTS,
			&"allocation_exceeds_unspent_points"
		)
	match stat_id:
		GrowthStatIds.ATTACK:
			_pending_attack += additional_points
		GrowthStatIds.VITALITY:
			_pending_vitality += additional_points
		GrowthStatIds.ENERGY:
			_pending_energy += additional_points
	return RunCommandResult.success()


func try_set_allocation(stat_id: StringName, points: int) -> RunCommandResult:
	if _confirmed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_CONFIRMED, &"shop_draft_already_confirmed")
	if not _progression_allocation_enabled:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.FEATURE_DISABLED,
			&"progression_allocation_disabled"
		)
	if not GrowthStatIds.is_valid(stat_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.UNKNOWN_STAT, &"unknown_stat_id")
	if points < 0:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.NEGATIVE_ALLOCATION, &"negative_allocation")
	var previous := _points_for(stat_id)
	var proposed_total := pending_allocation().total_points - previous + points
	if proposed_total > _baseline_progression.unspent_stat_points:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INSUFFICIENT_STAT_POINTS,
			&"allocation_exceeds_unspent_points"
		)
	_set_points(stat_id, points)
	return RunCommandResult.success()


func try_assign_slot(slot_id: StringName, skill_id: StringName) -> RunCommandResult:
	if _confirmed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_CONFIRMED, &"shop_draft_already_confirmed")
	for index in _working_entries.size():
		var entry := _working_entries[index]
		if entry.slot_id == slot_id:
			_working_entries[index] = RuntimeLoadoutSlotSnapshot.new(slot_id, skill_id)
			return RunCommandResult.success()
	return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"unknown_loadout_slot")


func reset() -> RunCommandResult:
	if _confirmed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_CONFIRMED, &"shop_draft_already_confirmed")
	_pending_attack = 0
	_pending_vitality = 0
	_pending_energy = 0
	_working_entries = _baseline_loadout.entries
	return RunCommandResult.success()


func validate_baseline(
		current_run_revision: int,
		current_progression: ProgressionSnapshot,
		current_loadout: RuntimeLoadoutSnapshot
) -> RunCommandResult:
	if _confirmed:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_CONFIRMED, &"shop_draft_already_confirmed")
	if current_run_revision != _baseline_run_revision:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.STALE_DRAFT, &"run_changed_since_draft_opened")
	if current_progression == null or current_progression.revision != _baseline_progression.revision:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.STALE_DRAFT, &"progression_changed_since_draft_opened")
	if current_loadout == null or current_loadout.revision != _baseline_loadout.revision:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.STALE_DRAFT, &"loadout_changed_since_draft_opened")
	if not current_loadout.same_mapping(_baseline_loadout):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.STALE_DRAFT, &"loadout_mapping_changed_since_draft_opened")
	return RunCommandResult.success()


func rebase_after_immediate_loadout(
		current_run_revision: int,
		current_progression: ProgressionSnapshot,
		committed_loadout: RuntimeLoadoutSnapshot
) -> void:
	# RunSession calls this only after the RuntimeLoadout replacement succeeds.
	# Updating these four fields cannot reject and deliberately leaves the three
	# pending stat counters unchanged.
	_baseline_run_revision = current_run_revision
	_baseline_progression = current_progression
	_baseline_loadout = committed_loadout
	_working_entries = committed_loadout.entries


func rebase_after_authoritative_shop_transaction(
		current_run_revision: int,
		current_progression: ProgressionSnapshot,
		current_loadout: RuntimeLoadoutSnapshot
) -> void:
	# Purchase/upgrade/reset never own draft balances, prices or skill progress.
	# They only advance the authority baseline so pending Task25 loadout/stat UI
	# state cannot become stale after a successful economy command.
	_baseline_run_revision = current_run_revision
	_baseline_progression = current_progression
	_baseline_loadout = current_loadout
	_working_entries = current_loadout.entries


func mark_confirmed() -> void:
	_confirmed = true


func _points_for(stat_id: StringName) -> int:
	match stat_id:
		GrowthStatIds.ATTACK:
			return _pending_attack
		GrowthStatIds.VITALITY:
			return _pending_vitality
		GrowthStatIds.ENERGY:
			return _pending_energy
		_:
			return -1


func _set_points(stat_id: StringName, points: int) -> void:
	match stat_id:
		GrowthStatIds.ATTACK:
			_pending_attack = points
		GrowthStatIds.VITALITY:
			_pending_vitality = points
		GrowthStatIds.ENERGY:
			_pending_energy = points
