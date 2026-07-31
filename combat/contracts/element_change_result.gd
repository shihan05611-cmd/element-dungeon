class_name ElementChangeResult
extends RefCounted

var accepted: bool:
	get:
		return _accepted

var changed: bool:
	get:
		return _changed

var buffered: bool:
	get:
		return _buffered

var detail: StringName:
	get:
		return _detail

var previous_element_id: StringName:
	get:
		return _previous_element_id

var current_element_id: StringName:
	get:
		return _current_element_id

var source: FormChangedEvent.Source:
	get:
		return _source

var sequence: int:
	get:
		return _sequence

var timestamp_msec: int:
	get:
		return _timestamp_msec

var event: FormChangedEvent:
	get:
		return _event

var _accepted: bool
var _changed: bool
var _buffered: bool
var _detail: StringName
var _previous_element_id: StringName
var _current_element_id: StringName
var _source: FormChangedEvent.Source
var _sequence: int
var _timestamp_msec: int
var _event: FormChangedEvent


func _init(
		p_accepted: bool,
		p_changed: bool,
		p_buffered: bool,
		p_detail: StringName,
		p_previous_element_id: StringName,
		p_current_element_id: StringName,
		p_source: FormChangedEvent.Source,
		p_sequence: int = 0,
		p_timestamp_msec: int = 0,
		p_event: FormChangedEvent = null
) -> void:
	_accepted = p_accepted
	_changed = p_changed
	_buffered = p_buffered
	_detail = p_detail
	_previous_element_id = p_previous_element_id
	_current_element_id = p_current_element_id
	_source = p_source
	_sequence = maxi(0, p_sequence)
	_timestamp_msec = maxi(0, p_timestamp_msec)
	_event = p_event


static func rejected(
		detail: StringName,
		current: StringName,
		source_value: FormChangedEvent.Source = FormChangedEvent.Source.MANUAL
) -> ElementChangeResult:
	return ElementChangeResult.new(false, false, false, detail, current, current, source_value)


static func unchanged(
		current: StringName,
		source_value: FormChangedEvent.Source
) -> ElementChangeResult:
	return ElementChangeResult.new(true, false, false, &"", current, current, source_value)


static func queued(
		current: StringName,
		requested: StringName
) -> ElementChangeResult:
	return ElementChangeResult.new(
		true,
		false,
		true,
		&"",
		current,
		requested,
		FormChangedEvent.Source.MANUAL
	)


static func committed(
		previous: StringName,
		current: StringName,
		source_value: FormChangedEvent.Source,
		sequence_value: int,
		timestamp_value: int,
		change_event: FormChangedEvent
) -> ElementChangeResult:
	return ElementChangeResult.new(
		true,
		true,
		false,
		&"",
		previous,
		current,
		source_value,
		sequence_value,
		timestamp_value,
		change_event
	)
