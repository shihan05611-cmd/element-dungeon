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

var active: bool:
	get:
		return _active

var _port: PassiveEffectPort
var _desired_bindings: Array[PassiveEffectBinding] = []
var _registered_runtimes: Array[PassiveEffectRuntime] = []
var _active: bool = true


func _init(port: PassiveEffectPort = null) -> void:
	_port = port if port != null else PassiveEffectPort.new()


func configure_port(port: PassiveEffectPort) -> bool:
	if port == null:
		return false
	var target_bindings := _desired_bindings if _active else _empty_bindings()
	var error := port.validation_error(target_bindings)
	if not error.is_empty():
		return false
	_port.commit_replace_effects(_empty_runtimes())
	_port = port
	_registered_runtimes = _port.build_runtimes(target_bindings)
	_port.commit_replace_effects(_registered_runtimes)
	return true


func validation_error(bindings: Array[PassiveEffectBinding]) -> StringName:
	var seen_skill_ids: Array[StringName] = []
	for binding: PassiveEffectBinding in bindings:
		if binding == null or not binding.is_valid():
			return &"invalid_passive_binding"
		if seen_skill_ids.has(binding.skill_id):
			return &"duplicate_passive_skill"
		seen_skill_ids.append(binding.skill_id)
	return _port.validation_error(bindings)


func commit_validated_replacement(bindings: Array[PassiveEffectBinding]) -> void:
	_desired_bindings = bindings.duplicate()
	_rebuild_registered_runtimes()


func deactivate() -> void:
	if not _active:
		return
	_active = false
	_port.commit_replace_effects(_empty_runtimes())
	_registered_runtimes.clear()


func reactivate() -> void:
	if _active:
		return
	_active = true
	_rebuild_registered_runtimes()


func rebuild() -> void:
	_rebuild_registered_runtimes()


func clear() -> void:
	_desired_bindings.clear()
	_port.commit_replace_effects(_empty_runtimes())
	_registered_runtimes.clear()


func has_registered_skill(skill_id: StringName) -> bool:
	return registered_skill_ids.has(skill_id)


func _rebuild_registered_runtimes() -> void:
	var target_bindings := _desired_bindings if _active else _empty_bindings()
	_registered_runtimes = _port.build_runtimes(target_bindings)
	_port.commit_replace_effects(_registered_runtimes)


static func _empty_bindings() -> Array[PassiveEffectBinding]:
	return []


static func _empty_runtimes() -> Array[PassiveEffectRuntime]:
	return []
