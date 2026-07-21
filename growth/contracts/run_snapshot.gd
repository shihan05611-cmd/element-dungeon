class_name RunSnapshot
extends RefCounted

## Immutable aggregate view. Every child object is immutable and every
## collection getter returns a copy.

var progression: ProgressionSnapshot:
	get:
		return _progression

var skills: SkillInventorySnapshot:
	get:
		return _skills

var relics: RelicInventorySnapshot:
	get:
		return _relics

var loadout: RuntimeLoadoutSnapshot:
	get:
		return _loadout

var route: RouteSnapshot:
	get:
		return _route

var pending_reward: RewardOffer:
	get:
		return _pending_reward

var pending_reward_claimed: bool:
	get:
		return _pending_reward_claimed

var unlocked_form_ids: Array[StringName]:
	get:
		return _unlocked_form_ids.duplicate()

var revision: int:
	get:
		return _revision

var _progression: ProgressionSnapshot
var _skills: SkillInventorySnapshot
var _relics: RelicInventorySnapshot
var _loadout: RuntimeLoadoutSnapshot
var _route: RouteSnapshot
var _pending_reward: RewardOffer
var _pending_reward_claimed: bool
var _unlocked_form_ids: Array[StringName] = []
var _revision: int


func _init(
		p_progression: ProgressionSnapshot,
		p_skills: SkillInventorySnapshot,
		p_relics: RelicInventorySnapshot,
		p_loadout: RuntimeLoadoutSnapshot,
		p_route: RouteSnapshot,
		p_pending_reward: RewardOffer = null,
		p_pending_reward_claimed: bool = false,
		p_unlocked_form_ids: Array[StringName] = [],
		p_revision: int = 0
) -> void:
	_progression = p_progression
	_skills = p_skills
	_relics = p_relics
	_loadout = p_loadout
	_route = p_route
	_pending_reward = p_pending_reward
	_pending_reward_claimed = p_pending_reward_claimed
	_unlocked_form_ids = p_unlocked_form_ids.duplicate()
	_revision = maxi(0, p_revision)
