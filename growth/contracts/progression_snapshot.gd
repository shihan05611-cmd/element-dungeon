class_name ProgressionSnapshot
extends RefCounted

## Immutable character-level and stat-allocation snapshot.

var level: int:
	get:
		return _level

var experience: int:
	get:
		return _experience

var experience_required_for_next_level: int:
	get:
		return _experience_required_for_next_level

var unspent_stat_points: int:
	get:
		return _unspent_stat_points

var allocated_stats: AllocatedStatsSnapshot:
	get:
		return _allocated_stats

var revision: int:
	get:
		return _revision

var _level: int
var _experience: int
var _experience_required_for_next_level: int
var _unspent_stat_points: int
var _allocated_stats: AllocatedStatsSnapshot
var _revision: int


func _init(
		p_level: int = 1,
		p_experience: int = 0,
		p_experience_required_for_next_level: int = 100,
		p_unspent_stat_points: int = 0,
		p_allocated_stats: AllocatedStatsSnapshot = null,
		p_revision: int = 0
) -> void:
	_level = maxi(1, p_level)
	_experience = maxi(0, p_experience)
	_experience_required_for_next_level = maxi(1, p_experience_required_for_next_level)
	_unspent_stat_points = maxi(0, p_unspent_stat_points)
	_allocated_stats = p_allocated_stats if p_allocated_stats != null else AllocatedStatsSnapshot.new()
	_revision = maxi(0, p_revision)
