class_name RelicController
extends RefCounted

## Owns one session's strategies and runtime states. Definitions may be shared
## by many sessions without sharing cooldowns, counters or event history.

var _effect_port: GrowthEffectPort
var _owned_definitions: Dictionary = {}
var _runtime_states: Dictionary = {}


func _init(effect_port: GrowthEffectPort = null) -> void:
	_effect_port = effect_port


func register_owned_relic(definition: RelicDefinition) -> RunCommandResult:
	if definition == null or not definition.is_valid():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.CONFIGURATION_ERROR, &"invalid_relic_definition")
	if _owned_definitions.has(definition.relic_id):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_OWNED, &"relic_already_registered")
	_owned_definitions[definition.relic_id] = definition
	_runtime_states[definition.relic_id] = RelicRuntimeState.new()
	return RunCommandResult.success()


func handle_event(event: RunEvent) -> RelicDispatchResult:
	if event == null or not event.is_valid():
		return RelicDispatchResult.rejected(&"invalid_run_event")

	var triggered: Array[StringName] = []
	var relic_ids: Array[StringName] = []
	for relic_id_variant in _owned_definitions.keys():
		relic_ids.append(relic_id_variant as StringName)
	relic_ids.sort()
	for relic_id in relic_ids:
		var definition: RelicDefinition = _owned_definitions[relic_id]
		var runtime: RelicRuntimeState = _runtime_states[relic_id]
		runtime.prepare_room(event.room_id)
		if not runtime.can_trigger(definition):
			continue
		var effect := RelicEffectRegistry.create_effect(definition.effect_kind)
		if effect != null and effect.try_apply(definition, event, _effect_port):
			runtime.record_trigger(definition)
			triggered.append(relic_id)
	return RelicDispatchResult.success(triggered)


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	var changed := false
	for state_variant in _runtime_states.values():
		var state := state_variant as RelicRuntimeState
		changed = state.advance(delta) or changed
	return changed


func snapshot(inventory: RelicInventoryState) -> RelicInventorySnapshot:
	if inventory == null:
		return RelicInventorySnapshot.new()
	var ids := inventory.owned_ids()
	ids.sort()
	var display_states: Array[RelicDisplayState] = []
	for relic_id in ids:
		var definition := inventory.definition_for(relic_id)
		var runtime: RelicRuntimeState = _runtime_states.get(relic_id) as RelicRuntimeState
		if definition == null:
			continue
		display_states.append(RelicDisplayState.new(
			relic_id,
			definition.display_name,
			definition.description,
			runtime.cooldown_remaining if runtime != null else 0.0,
			runtime.triggers_this_room if runtime != null else 0
		))
	return RelicInventorySnapshot.new(ids, display_states)
