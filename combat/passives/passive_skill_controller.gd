class_name PassiveSkillController
extends RefCounted

var registered_skill_ids: Array[StringName]:
	get:
		var result: Array[StringName] = []
		for runtime: PassiveEffectRuntime in _registered_runtimes:
			result.append(runtime.skill_id)
		return result

var registered_runtimes: Array[PassiveEffectRuntime]:
	get:
		return _registered_runtimes.duplicate()

var registered_slot_ids: Array[StringName]:
	get:
		return _registered_slot_ids.duplicate()

var active: bool:
	get:
		return _active

var registration_commit_count: int:
	get:
		return _registration_commit_count

var unregistration_commit_count: int:
	get:
		return _unregistration_commit_count

var _port: PassiveEffectPort
var _desired_bindings: Array[PassiveEffectBinding] = []
var _desired_slot_ids: Array[StringName] = []
var _registered_runtimes: Array[PassiveEffectRuntime] = []
var _registered_slot_ids: Array[StringName] = []
var _active: bool = true
var _run_ended: bool = false
var _registration_commit_count: int = 0
var _unregistration_commit_count: int = 0


func _init(port: PassiveEffectPort = null) -> void:
	_port = port if port != null else PassiveEffectPort.new()


func configure_port(port: PassiveEffectPort) -> bool:
	if port == null:
		return false
	var target_bindings := _desired_bindings if _active and not _run_ended else _empty_bindings()
	var error := port.validation_error(target_bindings)
	if not error.is_empty():
		return false
	var previous_runtimes := _registered_runtimes.duplicate()
	if not previous_runtimes.is_empty():
		_port.commit_replace_effects(_empty_runtimes())
		_unregistration_commit_count += 1
	_port = port
	_registered_runtimes = _port.build_runtimes(target_bindings)
	if target_bindings.is_empty():
		_registered_slot_ids.clear()
	else:
		_registered_slot_ids = _desired_slot_ids.duplicate()
	if not _registered_runtimes.is_empty():
		_port.commit_replace_effects(_registered_runtimes)
		_registration_commit_count += 1
	return true


func validation_error(
		bindings: Array[PassiveEffectBinding],
		slot_ids: Array[StringName] = []
) -> StringName:
	var normalized_slots := _normalized_slot_ids(bindings, slot_ids)
	if normalized_slots.size() != bindings.size():
		return &"passive_slot_binding_count_mismatch"
	var seen_skill_ids: Array[StringName] = []
	var seen_slot_ids: Array[StringName] = []
	for index in bindings.size():
		var binding := bindings[index]
		if binding == null or not binding.is_valid():
			return &"invalid_passive_binding"
		var slot_id := normalized_slots[index]
		if not SkillSlotIds.is_passive(slot_id):
			return &"passive_binding_requires_passive_slot"
		if seen_slot_ids.has(slot_id):
			return &"duplicate_passive_slot_binding"
		seen_slot_ids.append(slot_id)
		if seen_skill_ids.has(binding.skill_id):
			return &"duplicate_passive_skill"
		seen_skill_ids.append(binding.skill_id)
	return _port.validation_error(bindings)


func commit_validated_replacement(
		bindings: Array[PassiveEffectBinding],
		slot_ids: Array[StringName] = []
) -> void:
	var normalized_slots := _normalized_slot_ids(bindings, slot_ids)
	assert(validation_error(bindings, normalized_slots).is_empty(), "passive replacement must be validated")
	if (
		not _run_ended
		and _same_binding_sequence(_desired_bindings, bindings)
		and _desired_slot_ids == normalized_slots
	):
		return
	_desired_bindings = bindings.duplicate()
	_desired_slot_ids = normalized_slots
	_run_ended = false
	_rebuild_registered_runtimes(true)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	if not _registered_runtimes.is_empty():
		_port.commit_replace_effects(_empty_runtimes())
		_unregistration_commit_count += 1
	_registered_runtimes.clear()
	_registered_slot_ids.clear()


func reactivate() -> void:
	if _active or _run_ended:
		return
	_active = true
	_rebuild_registered_runtimes(false)


func rebuild() -> void:
	_rebuild_registered_runtimes(false)


func clear() -> void:
	if _run_ended and _desired_bindings.is_empty() and _registered_runtimes.is_empty():
		return
	_desired_bindings.clear()
	_desired_slot_ids.clear()
	_run_ended = true
	_active = false
	if not _registered_runtimes.is_empty():
		_port.commit_replace_effects(_empty_runtimes())
		_unregistration_commit_count += 1
	_registered_runtimes.clear()
	_registered_slot_ids.clear()


func has_registered_skill(skill_id: StringName) -> bool:
	return registered_skill_ids.has(skill_id)


func runtime_for_slot(slot_id: StringName) -> PassiveEffectRuntime:
	var index := _registered_slot_ids.find(slot_id)
	return _registered_runtimes[index] if index >= 0 else null


func _rebuild_registered_runtimes(reuse_unchanged: bool) -> void:
	var target_bindings := _desired_bindings if _active and not _run_ended else _empty_bindings()
	var previous_runtimes := _registered_runtimes.duplicate()
	var next_runtimes: Array[PassiveEffectRuntime] = []
	if reuse_unchanged:
		for binding: PassiveEffectBinding in target_bindings:
			var retained := _runtime_for_binding(previous_runtimes, binding)
			if retained != null:
				next_runtimes.append(retained)
			else:
				var single_binding: Array[PassiveEffectBinding] = [binding]
				var created := _port.build_runtimes(single_binding)
				assert(created.size() == 1, "one passive binding must build one runtime")
				next_runtimes.append(created[0])
	else:
		next_runtimes = _port.build_runtimes(target_bindings)
	var removed_runtime := previous_runtimes.any(func(runtime: PassiveEffectRuntime) -> bool:
		return not next_runtimes.has(runtime)
	)
	var added_runtime := next_runtimes.any(func(runtime: PassiveEffectRuntime) -> bool:
		return not previous_runtimes.has(runtime)
	)
	_registered_runtimes = next_runtimes
	if target_bindings.is_empty():
		_registered_slot_ids.clear()
	else:
		_registered_slot_ids = _desired_slot_ids.duplicate()
	if not _registered_runtimes.is_empty():
		_port.commit_replace_effects(_registered_runtimes)
		if removed_runtime:
			_unregistration_commit_count += 1
		if added_runtime:
			_registration_commit_count += 1
	elif not previous_runtimes.is_empty():
		_port.commit_replace_effects(_empty_runtimes())
		_unregistration_commit_count += 1


static func _runtime_for_binding(
		runtimes: Array[PassiveEffectRuntime],
		binding: PassiveEffectBinding
) -> PassiveEffectRuntime:
	for runtime: PassiveEffectRuntime in runtimes:
		if runtime.skill_id == binding.skill_id and runtime.definition == binding.definition:
			return runtime
	return null


static func _same_binding_sequence(
		left: Array[PassiveEffectBinding],
		right: Array[PassiveEffectBinding]
) -> bool:
	if left.size() != right.size():
		return false
	for index in left.size():
		var left_binding := left[index]
		var right_binding := right[index]
		if (
			left_binding == null
			or right_binding == null
			or left_binding.skill_id != right_binding.skill_id
			or left_binding.definition != right_binding.definition
			or left_binding.element_policy != right_binding.element_policy
			or left_binding.required_element_id != right_binding.required_element_id
		):
			return false
	return true


static func _normalized_slot_ids(
		bindings: Array[PassiveEffectBinding],
		slot_ids: Array[StringName]
) -> Array[StringName]:
	if not slot_ids.is_empty():
		return slot_ids.duplicate()
	var result: Array[StringName] = []
	for index in bindings.size():
		if index >= SkillSlotIds.passive().size():
			return []
		result.append(SkillSlotIds.passive()[index])
	return result


static func _empty_bindings() -> Array[PassiveEffectBinding]:
	return []


static func _empty_runtimes() -> Array[PassiveEffectRuntime]:
	return []
