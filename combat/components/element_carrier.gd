class_name ElementCarrier
extends Node

## Target-owned runtime element state. All mutation methods validate a complete
## replacement; CombatReceiver uses the silent path and emits only after every
## component has committed.

signal elements_changed(current: ElementSnapshot, water_delta: int, fire_delta: int)

@export var allow_element_attachment: bool = true
@export var allow_cross_element_reactions: bool = true
@export_range(1, 10, 1) var per_element_capacity: int = 10

var _water_amount: int = 0
var _fire_amount: int = 0


func get_amount(element_id: StringName) -> int:
	match element_id:
		ElementIds.WATER:
			return _water_amount
		ElementIds.FIRE:
			return _fire_amount
		_:
			return 0


func snapshot() -> ElementSnapshot:
	return ElementSnapshot.new(_water_amount, _fire_amount, per_element_capacity)


func can_replace(next: ElementSnapshot) -> bool:
	return (
		next != null
		and next.is_valid()
		and next.capacity == per_element_capacity
	)


func replace_silent(next: ElementSnapshot) -> bool:
	if not can_replace(next):
		return false
	_water_amount = next.water_amount
	_fire_amount = next.fire_amount
	return true


func set_amounts_silent(water: int, fire: int) -> bool:
	return replace_silent(ElementSnapshot.new(water, fire, per_element_capacity))


func prepare_consume_all(element_id: StringName) -> ElementLayerConsumePlan:
	if not ElementIds.is_combat_element(element_id):
		return null
	var before := snapshot()
	if before.get_amount(element_id) <= 0:
		return null
	var after := ElementSnapshot.new(
		0 if element_id == ElementIds.WATER else before.water_amount,
		0 if element_id == ElementIds.FIRE else before.fire_amount,
		per_element_capacity
	)
	var plan := ElementLayerConsumePlan.new(element_id, before, after)
	return plan if plan.is_valid() else null


func can_commit_element_consume(plan: ElementLayerConsumePlan) -> bool:
	return (
		plan != null
		and plan.is_valid()
		and plan.before.capacity == per_element_capacity
		and snapshot().equals(plan.before)
		and can_replace(plan.after)
	)


func commit_element_consume_silent(plan: ElementLayerConsumePlan) -> void:
	assert(
		can_commit_element_consume(plan),
		"element consume plan must match the current complete snapshot"
	)
	var replaced := replace_silent(plan.after)
	assert(replaced, "validated element consume replacement must commit")


func publish_element_consume(plan: ElementLayerConsumePlan) -> void:
	assert(plan != null and plan.is_valid())
	notify_changed(plan.before)


func notify_changed(previous: ElementSnapshot) -> void:
	if previous == null or not previous.is_valid():
		return
	var current := snapshot()
	elements_changed.emit(
		current,
		current.water_amount - previous.water_amount,
		current.fire_amount - previous.fire_amount
	)


func clear_all(emit_notification: bool = true) -> void:
	var previous := snapshot()
	_water_amount = 0
	_fire_amount = 0
	if emit_notification and (previous.water_amount != 0 or previous.fire_amount != 0):
		notify_changed(previous)


func _exit_tree() -> void:
	# Leaving the room clears attachment without broadcasting into a tearing-down
	# scene tree.
	clear_all(false)
