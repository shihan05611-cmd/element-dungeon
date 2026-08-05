class_name ShopOfferSnapshot
extends RefCounted

var offer_id: StringName:
	get:
		return _offer_id

var skill_id: StringName:
	get:
		return _skill_id

var activation_kind: SkillDefinition.ActivationKind:
	get:
		return _activation_kind

var purchase_price: int:
	get:
		return _purchase_price

var validation_error: StringName:
	get:
		return _validation_error

var _offer_id: StringName
var _skill_id: StringName
var _activation_kind: SkillDefinition.ActivationKind
var _purchase_price: int
var _validation_error: StringName = &""


func _init(
		p_offer_id: StringName,
		p_skill_id: StringName,
		p_activation_kind: SkillDefinition.ActivationKind,
		p_purchase_price: int
) -> void:
	_offer_id = p_offer_id
	_skill_id = p_skill_id
	_activation_kind = p_activation_kind
	_purchase_price = p_purchase_price
	_validation_error = _validate_values()


func is_valid() -> bool:
	return _validation_error.is_empty()


func _validate_values() -> StringName:
	if _offer_id.is_empty() or _skill_id.is_empty():
		return &"missing_shop_offer_identity"
	if _activation_kind not in [
		SkillDefinition.ActivationKind.ACTIVE,
		SkillDefinition.ActivationKind.PASSIVE,
	]:
		return &"invalid_shop_offer_activation_kind"
	if _purchase_price <= 0:
		return &"invalid_shop_purchase_price"
	return &""
