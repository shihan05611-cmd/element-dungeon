class_name ElementFormController
extends Node

## Per-actor water/fire form state. Casts read this only when their transaction
## is accepted; later switches cannot mutate an existing CastSnapshot.

signal form_changed(current_form_id: StringName, previous_form_id: StringName)

@export var initial_form_id: StringName = ElementIds.WATER

var current_form_id: StringName:
	get:
		return _current_form_id

var _current_form_id: StringName = ElementIds.WATER
var _runtime_configured: bool = false


func _ready() -> void:
	if _runtime_configured:
		return
	_current_form_id = initial_form_id if ElementIds.is_combat_element(initial_form_id) else ElementIds.WATER


func configure_runtime(form_id: StringName) -> bool:
	if not ElementIds.is_combat_element(form_id):
		return false
	_runtime_configured = true
	initial_form_id = form_id
	return request_form(form_id)


func request_form(form_id: StringName) -> bool:
	if not ElementIds.is_combat_element(form_id):
		return false
	if form_id == _current_form_id:
		return true
	var previous := _current_form_id
	_current_form_id = form_id
	form_changed.emit(_current_form_id, previous)
	return true


func toggle_form() -> bool:
	if _current_form_id == ElementIds.WATER:
		return request_form(ElementIds.FIRE)
	if _current_form_id == ElementIds.FIRE:
		return request_form(ElementIds.WATER)
	return false


func is_valid() -> bool:
	return ElementIds.is_combat_element(_current_form_id)
