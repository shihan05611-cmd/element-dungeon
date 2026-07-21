class_name WaterFireResolver
extends RefCounted

## Stateless MVP rule: symmetric water/fire 1:1 consumption with the reaction
## multiplier in its own damage partition.


static func resolve(
		incoming: RuntimeAttackPayload,
		carrier_snapshot: ElementSnapshot,
		allow_attachment: bool = true,
		allow_cross_element_reactions: bool = true
) -> ElementResolution:
	if incoming == null or not incoming.is_valid():
		return _invalid_resolution(carrier_snapshot, &"invalid_payload")
	if carrier_snapshot == null or not carrier_snapshot.is_valid():
		return _invalid_resolution(carrier_snapshot, &"invalid_carrier_snapshot")

	var incoming_element := incoming.element_id
	var incoming_amount := incoming.element_amount
	if (
		incoming_amount == 0
		or incoming_element == ElementIds.NONE
		or not allow_attachment
	):
		return ElementResolution.new(
			CombatStatus.SubResult.PROCESSED_NO_CHANGE,
			carrier_snapshot,
			carrier_snapshot,
			incoming_element,
			incoming_amount,
			0,
			incoming_amount,
			1.0
		)

	var water := carrier_snapshot.water_amount
	var fire := carrier_snapshot.fire_amount
	var opposite := ElementIds.opposite_of(incoming_element)
	var opposite_amount := carrier_snapshot.get_amount(opposite)
	var consumed := mini(opposite_amount, incoming_amount) if allow_cross_element_reactions else 0
	var remaining := incoming_amount - consumed

	if incoming_element == ElementIds.WATER:
		fire -= consumed
		water = mini(carrier_snapshot.capacity, water + remaining)
	else:
		water -= consumed
		fire = mini(carrier_snapshot.capacity, fire + remaining)

	var after := ElementSnapshot.new(water, fire, carrier_snapshot.capacity)
	var status := CombatStatus.SubResult.APPLIED
	if after.equals(carrier_snapshot):
		status = CombatStatus.SubResult.PROCESSED_NO_CHANGE
	return ElementResolution.new(
		status,
		carrier_snapshot,
		after,
		incoming_element,
		incoming_amount,
		consumed,
		remaining,
		1.0 + 0.3 * float(consumed)
	)


static func _invalid_resolution(snapshot: ElementSnapshot, error: StringName) -> ElementResolution:
	var safe_snapshot := snapshot
	if safe_snapshot == null or not safe_snapshot.is_valid():
		safe_snapshot = ElementSnapshot.new()
	return ElementResolution.new(
		CombatStatus.SubResult.NOT_PROCESSED,
		safe_snapshot,
		safe_snapshot,
		ElementIds.NONE,
		0,
		0,
		0,
		1.0,
		error
	)
