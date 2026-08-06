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

var skill_inventory: SkillInventorySnapshot:
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

var rules: RunRulesSnapshot:
	get:
		return _rules

var economy: DreamDustSnapshot:
	get:
		return _economy

var shop: ShopSnapshot:
	get:
		return _shop

var observed_experience: int:
	get:
		return _observed_experience

var observed_relic_events: int:
	get:
		return _observed_relic_events

var node: RunNodeSnapshot:
	get:
		return _node

var result: RunResultSnapshot:
	get:
		return _result

var _progression: ProgressionSnapshot
var _skills: SkillInventorySnapshot
var _relics: RelicInventorySnapshot
var _loadout: RuntimeLoadoutSnapshot
var _route: RouteSnapshot
var _pending_reward: RewardOffer
var _pending_reward_claimed: bool
var _unlocked_form_ids: Array[StringName] = []
var _revision: int
var _rules: RunRulesSnapshot
var _economy: DreamDustSnapshot
var _shop: ShopSnapshot
var _observed_experience: int
var _observed_relic_events: int
var _node: RunNodeSnapshot
var _result: RunResultSnapshot


func _init(
		p_progression: ProgressionSnapshot,
		p_skills: SkillInventorySnapshot,
		p_relics: RelicInventorySnapshot,
		p_loadout: RuntimeLoadoutSnapshot,
		p_route: RouteSnapshot,
		p_pending_reward: RewardOffer = null,
		p_pending_reward_claimed: bool = false,
		p_unlocked_form_ids: Array[StringName] = [],
		p_revision: int = 0,
		p_rules: RunRulesSnapshot = null,
		p_economy: DreamDustSnapshot = null,
		p_shop: ShopSnapshot = null,
		p_observed_experience: int = 0,
		p_observed_relic_events: int = 0,
		p_node: RunNodeSnapshot = null,
		p_result: RunResultSnapshot = null
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
	_rules = p_rules.copy() if p_rules != null else RunRulesSnapshot.legacy_enabled()
	_economy = p_economy if p_economy != null else DreamDustSnapshot.new()
	_shop = p_shop
	_observed_experience = maxi(0, p_observed_experience)
	_observed_relic_events = maxi(0, p_observed_relic_events)
	_node = p_node
	_result = p_result
