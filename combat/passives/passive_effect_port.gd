class_name PassiveEffectPort
extends RefCounted

## Integration boundary for gameplay passive runtimes. Validation is pure;
## build_runtimes is called only after validation and creates one fresh runtime
## per equipped passive. commit_replace_effects must not fail.

var runtime_context: PassiveRuntimeContext:
	get:
		return _runtime_context

var _runtime_context: PassiveRuntimeContext


func _init(context: PassiveRuntimeContext = null) -> void:
	_runtime_context = context if context != null else PassiveRuntimeContext.new()


func set_runtime_context(context: PassiveRuntimeContext) -> bool:
	if context == null:
		return false
	_runtime_context = context
	return true


func validation_error(bindings: Array[PassiveEffectBinding]) -> StringName:
	for binding: PassiveEffectBinding in bindings:
		if binding == null or not binding.is_valid():
			return &"invalid_passive_binding"
		var runtime_error := binding.definition.runtime_validation_error(_runtime_context)
		if not runtime_error.is_empty():
			return runtime_error
	return &""


func build_runtimes(bindings: Array[PassiveEffectBinding]) -> Array[PassiveEffectRuntime]:
	var result: Array[PassiveEffectRuntime] = []
	for binding: PassiveEffectBinding in bindings:
		var runtime := binding.definition.create_runtime(binding.skill_id, _runtime_context)
		assert(runtime != null and runtime.is_valid(), "validated passive definition must build a valid runtime")
		result.append(runtime)
	return result


func commit_replace_effects(_runtimes: Array[PassiveEffectRuntime]) -> void:
	pass
