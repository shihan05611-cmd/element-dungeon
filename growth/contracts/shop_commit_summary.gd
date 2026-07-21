class_name ShopCommitSummary
extends RefCounted

## Immutable summary emitted only after the whole shop transaction commits.

var progression_before: ProgressionSnapshot:
	get:
		return _progression_before

var progression_after: ProgressionSnapshot:
	get:
		return _progression_after

var loadout_before: RuntimeLoadoutSnapshot:
	get:
		return _loadout_before

var loadout_after: RuntimeLoadoutSnapshot:
	get:
		return _loadout_after

var _progression_before: ProgressionSnapshot
var _progression_after: ProgressionSnapshot
var _loadout_before: RuntimeLoadoutSnapshot
var _loadout_after: RuntimeLoadoutSnapshot


func _init(
		p_progression_before: ProgressionSnapshot,
		p_progression_after: ProgressionSnapshot,
		p_loadout_before: RuntimeLoadoutSnapshot,
		p_loadout_after: RuntimeLoadoutSnapshot
) -> void:
	_progression_before = p_progression_before
	_progression_after = p_progression_after
	_loadout_before = p_loadout_before
	_loadout_after = p_loadout_after
