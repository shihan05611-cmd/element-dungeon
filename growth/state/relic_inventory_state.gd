class_name RelicInventoryState
extends RefCounted

## Owns stable IDs and a read-only static catalog reference per ID. Runtime
## counters live in RelicController, never on the Resource.

var _owned_relic_ids: Array[StringName] = []
var _catalog: Dictionary = {}


func _init(catalog: Array[RelicDefinition] = []) -> void:
	for definition in catalog:
		if definition != null and definition.is_valid() and not _catalog.has(definition.relic_id):
			_catalog[definition.relic_id] = definition


func owns(relic_id: StringName) -> bool:
	return _owned_relic_ids.has(relic_id)


func definition_for(relic_id: StringName) -> RelicDefinition:
	return _catalog.get(relic_id) as RelicDefinition


func try_add(relic_id: StringName) -> RunCommandResult:
	if relic_id.is_empty() or not _catalog.has(relic_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"unknown_relic_id")
	if owns(relic_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_OWNED, &"relic_already_owned")
	_owned_relic_ids.append(relic_id)
	return RunCommandResult.success()


func owned_ids() -> Array[StringName]:
	return _owned_relic_ids.duplicate()
