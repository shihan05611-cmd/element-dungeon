class_name ShopCommitSummary
extends RefCounted

## Immutable summary emitted only after the whole shop transaction commits.

enum TransactionKind {
	LEGACY_SHOP_EXIT,
	PURCHASE_SKILL,
	UPGRADE_ACTIVE_SKILL,
	RESET_ACTIVE_SKILL,
}

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

var transaction_kind: TransactionKind:
	get:
		return _transaction_kind

var skill_id: StringName:
	get:
		return _skill_id

var dream_dust_before: DreamDustSnapshot:
	get:
		return _dream_dust_before

var dream_dust_after: DreamDustSnapshot:
	get:
		return _dream_dust_after

var skill_before: SkillProgressSnapshot:
	get:
		return _skill_before

var skill_after: SkillProgressSnapshot:
	get:
		return _skill_after

var charged_dream_dust: int:
	get:
		return _charged_dream_dust

var refunded_dream_dust: int:
	get:
		return _refunded_dream_dust

var cause: StringName:
	get:
		return _cause

var _progression_before: ProgressionSnapshot
var _progression_after: ProgressionSnapshot
var _loadout_before: RuntimeLoadoutSnapshot
var _loadout_after: RuntimeLoadoutSnapshot
var _transaction_kind: TransactionKind
var _skill_id: StringName
var _dream_dust_before: DreamDustSnapshot
var _dream_dust_after: DreamDustSnapshot
var _skill_before: SkillProgressSnapshot
var _skill_after: SkillProgressSnapshot
var _charged_dream_dust: int
var _refunded_dream_dust: int
var _cause: StringName


func _init(
		p_progression_before: ProgressionSnapshot,
		p_progression_after: ProgressionSnapshot,
		p_loadout_before: RuntimeLoadoutSnapshot,
		p_loadout_after: RuntimeLoadoutSnapshot,
		p_transaction_kind: TransactionKind = TransactionKind.LEGACY_SHOP_EXIT,
		p_skill_id: StringName = &"",
		p_dream_dust_before: DreamDustSnapshot = null,
		p_dream_dust_after: DreamDustSnapshot = null,
		p_skill_before: SkillProgressSnapshot = null,
		p_skill_after: SkillProgressSnapshot = null,
		p_charged_dream_dust: int = 0,
		p_refunded_dream_dust: int = 0,
		p_cause: StringName = &"shop_confirmed"
) -> void:
	_progression_before = p_progression_before
	_progression_after = p_progression_after
	_loadout_before = p_loadout_before
	_loadout_after = p_loadout_after
	_transaction_kind = p_transaction_kind
	_skill_id = p_skill_id
	_dream_dust_before = p_dream_dust_before
	_dream_dust_after = p_dream_dust_after
	_skill_before = p_skill_before
	_skill_after = p_skill_after
	_charged_dream_dust = maxi(0, p_charged_dream_dust)
	_refunded_dream_dust = maxi(0, p_refunded_dream_dust)
	_cause = p_cause


static func economy_transaction(
		p_transaction_kind: TransactionKind,
		p_skill_id: StringName,
		p_dream_dust_before: DreamDustSnapshot,
		p_dream_dust_after: DreamDustSnapshot,
		p_skill_before: SkillProgressSnapshot,
		p_skill_after: SkillProgressSnapshot,
		p_charged_dream_dust: int,
		p_refunded_dream_dust: int,
		p_cause: StringName
) -> ShopCommitSummary:
	return ShopCommitSummary.new(
		null,
		null,
		null,
		null,
		p_transaction_kind,
		p_skill_id,
		p_dream_dust_before,
		p_dream_dust_after,
		p_skill_before,
		p_skill_after,
		p_charged_dream_dust,
		p_refunded_dream_dust,
		p_cause
	)
