class_name AllocatedStatsSnapshot
extends RefCounted

## Immutable, explicitly-fielded allocated-stat view.

var attack_points: int:
	get:
		return _attack_points

var vitality_points: int:
	get:
		return _vitality_points

var energy_points: int:
	get:
		return _energy_points

var total_points: int:
	get:
		return _attack_points + _vitality_points + _energy_points

var attack_multiplier: float:
	get:
		return 1.0 + float(_attack_points) * 0.05

var maximum_health_bonus: int:
	get:
		return _vitality_points * 10

var maximum_energy_bonus: int:
	get:
		return _energy_points * 5

var _attack_points: int
var _vitality_points: int
var _energy_points: int


func _init(p_attack_points: int = 0, p_vitality_points: int = 0, p_energy_points: int = 0) -> void:
	_attack_points = maxi(0, p_attack_points)
	_vitality_points = maxi(0, p_vitality_points)
	_energy_points = maxi(0, p_energy_points)


func points_for(stat_id: StringName) -> int:
	match stat_id:
		GrowthStatIds.ATTACK:
			return _attack_points
		GrowthStatIds.VITALITY:
			return _vitality_points
		GrowthStatIds.ENERGY:
			return _energy_points
		_:
			return -1


func equals(other: AllocatedStatsSnapshot) -> bool:
	return (
		other != null
		and _attack_points == other.attack_points
		and _vitality_points == other.vitality_points
		and _energy_points == other.energy_points
	)
