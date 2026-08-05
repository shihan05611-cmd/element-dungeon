class_name SkillExecutionContext
extends RefCounted

var skill: SkillDefinition
var cast_snapshot: CastSnapshot
var spawn_snapshot: DeliverySpawnSnapshot
var energy_before: int
var maximum_energy: int

var level_effect: ActiveSkillLevelEffectSnapshot:
	get:
		return (
			cast_snapshot.level_effect
			if cast_snapshot != null
			else ActiveSkillLevelEffectSnapshot.neutral()
		)


func _init(
		p_skill: SkillDefinition,
		p_cast_snapshot: CastSnapshot,
		p_spawn_snapshot: DeliverySpawnSnapshot,
		p_energy_before: int,
		p_maximum_energy: int
) -> void:
	skill = p_skill
	cast_snapshot = p_cast_snapshot
	spawn_snapshot = p_spawn_snapshot
	energy_before = p_energy_before
	maximum_energy = p_maximum_energy


func is_valid() -> bool:
	return (
		skill != null
		and cast_snapshot != null
		and cast_snapshot.is_valid()
		and energy_before >= 0
		and maximum_energy >= energy_before
	)
