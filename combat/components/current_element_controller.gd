class_name CurrentElementController
extends Node

## The actor's single authoritative element state.

signal element_changed(result: ElementChangeResult)

@export var available_element_ids: Array[StringName] = [ElementIds.WATER, ElementIds.FIRE]
@export var initial_element_id: StringName = ElementIds.WATER
@export var event_room_id: StringName = &"runtime"

var current_element_id: StringName:
	get:
		return _current_element_id

var ordered_available_elements: Array[StringName]:
	get:
		return available_element_ids.duplicate()

var _current_element_id: StringName = ElementIds.WATER
var _change_sequence: int = 0
var _last_manual_request_sequence: int = 0
var _runtime_configured: bool = false


func _ready() -> void:
	if _runtime_configured:
		return
	if not _set_available_elements_internal(available_element_ids):
		available_element_ids = [ElementIds.WATER, ElementIds.FIRE]
	_current_element_id = (
		initial_element_id
		if available_element_ids.has(initial_element_id)
		else available_element_ids[0]
	)


func configure_runtime(
		element_id: StringName,
		p_available_element_ids: Array[StringName] = []
) -> bool:
	var requested_available := (
		p_available_element_ids
		if not p_available_element_ids.is_empty()
		else available_element_ids
	)
	if not _set_available_elements_internal(requested_available):
		return false
	if not available_element_ids.has(element_id):
		return false
	_runtime_configured = true
	initial_element_id = element_id
	_current_element_id = element_id
	return true


func set_available_elements(p_available_element_ids: Array[StringName]) -> bool:
	if not _set_available_elements_internal(p_available_element_ids):
		return false
	if not available_element_ids.has(_current_element_id):
		_current_element_id = available_element_ids[0]
	return true


func set_event_room_id(room_id: StringName) -> bool:
	if room_id.is_empty():
		return false
	event_room_id = room_id
	return true


func request_element(
		element_id: StringName,
		source: FormChangedEvent.Source = FormChangedEvent.Source.MANUAL,
		request_sequence: int = 0
) -> ElementChangeResult:
	if not _is_known_source(source):
		return ElementChangeResult.rejected(&"invalid_change_source", _current_element_id, source)
	if not available_element_ids.has(element_id):
		return ElementChangeResult.rejected(&"element_unavailable", _current_element_id, source)
	if source == FormChangedEvent.Source.MANUAL and request_sequence > 0:
		if request_sequence <= _last_manual_request_sequence:
			return ElementChangeResult.rejected(
				&"duplicate_request_sequence",
				_current_element_id,
				source
			)
		_last_manual_request_sequence = request_sequence
	var result := _commit_element_silent(element_id, source)
	_publish_committed_change(result)
	return result


func cycle_next(
		source: FormChangedEvent.Source = FormChangedEvent.Source.MANUAL,
		request_sequence: int = 0
) -> ElementChangeResult:
	if available_element_ids.is_empty():
		return ElementChangeResult.rejected(&"no_available_elements", _current_element_id, source)
	var current_index := available_element_ids.find(_current_element_id)
	if current_index < 0:
		return ElementChangeResult.rejected(&"current_element_unavailable", _current_element_id, source)
	var next_index := (current_index + 1) % available_element_ids.size()
	return request_element(available_element_ids[next_index], source, request_sequence)


func is_element_available(element_id: StringName) -> bool:
	return available_element_ids.has(element_id)


func is_valid() -> bool:
	return not available_element_ids.is_empty() and available_element_ids.has(_current_element_id)


func reset_request_deduplication() -> void:
	_last_manual_request_sequence = 0


## Transaction-only hook. It commits state and builds the event but emits
## nothing; SkillExecutor publishes only after the rest of the cast is committed.
func _commit_element_silent(
		element_id: StringName,
		source: FormChangedEvent.Source
) -> ElementChangeResult:
	if not _is_known_source(source):
		return ElementChangeResult.rejected(&"invalid_change_source", _current_element_id, source)
	if not available_element_ids.has(element_id):
		return ElementChangeResult.rejected(&"element_unavailable", _current_element_id, source)
	if element_id == _current_element_id:
		return ElementChangeResult.unchanged(_current_element_id, source)
	var previous := _current_element_id
	_current_element_id = element_id
	_change_sequence += 1
	var timestamp := _now_msec()
	var room_id := event_room_id if not event_room_id.is_empty() else StringName("runtime")
	var event := FormChangedEvent.new(
		StringName("form_changed_%d" % _change_sequence),
		room_id,
		previous,
		_current_element_id,
		source,
		_change_sequence,
		timestamp
	)
	return ElementChangeResult.committed(
		previous,
		_current_element_id,
		source,
		_change_sequence,
		timestamp,
		event
	)


func _publish_committed_change(result: ElementChangeResult) -> bool:
	if result == null or not result.accepted or not result.changed:
		return false
	if result.sequence != _change_sequence or result.current_element_id != _current_element_id:
		return false
	element_changed.emit(result)
	return true


func _set_available_elements_internal(elements: Array[StringName]) -> bool:
	if elements.is_empty():
		return false
	var sanitized: Array[StringName] = []
	for element_id: StringName in elements:
		if element_id.is_empty() or element_id == ElementIds.NONE or sanitized.has(element_id):
			return false
		sanitized.append(element_id)
	available_element_ids = sanitized
	return true


func _now_msec() -> int:
	return maxi(0, Time.get_ticks_msec())


static func _is_known_source(source: FormChangedEvent.Source) -> bool:
	return source == FormChangedEvent.Source.MANUAL or source == FormChangedEvent.Source.SKILL_AUTO
