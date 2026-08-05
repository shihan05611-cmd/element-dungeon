class_name ShopSnapshot
extends RefCounted

var session_id: StringName:
	get:
		return _session_id

var offers: Array[ShopOfferSnapshot]:
	get:
		return _offers.duplicate()

var opened_run_revision: int:
	get:
		return _opened_run_revision

var configuration_error: StringName:
	get:
		return _configuration_error

var _session_id: StringName
var _offers: Array[ShopOfferSnapshot] = []
var _opened_run_revision: int
var _configuration_error: StringName = &""


func _init(
		p_session_id: StringName,
		p_offers: Array[ShopOfferSnapshot] = [],
		p_opened_run_revision: int = 0,
		p_configuration_error: StringName = &""
) -> void:
	_session_id = p_session_id
	_opened_run_revision = maxi(0, p_opened_run_revision)
	_configuration_error = p_configuration_error
	var seen_offer_ids: Array[StringName] = []
	for offer: ShopOfferSnapshot in p_offers:
		if offer == null or not offer.is_valid():
			_configuration_error = &"invalid_shop_offer"
			continue
		if seen_offer_ids.has(offer.offer_id):
			_configuration_error = &"duplicate_shop_offer_id"
			continue
		seen_offer_ids.append(offer.offer_id)
		_offers.append(offer)
	_offers.sort_custom(func(a: ShopOfferSnapshot, b: ShopOfferSnapshot) -> bool:
		return String(a.offer_id) < String(b.offer_id)
	)
	if _session_id.is_empty() and _configuration_error.is_empty():
		_configuration_error = &"missing_shop_session_id"


func is_valid() -> bool:
	return _configuration_error.is_empty()


func offer_for(offer_id: StringName) -> ShopOfferSnapshot:
	for offer: ShopOfferSnapshot in _offers:
		if offer.offer_id == offer_id:
			return offer
	return null
