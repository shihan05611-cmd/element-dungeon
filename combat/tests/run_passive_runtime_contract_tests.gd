extends SceneTree


class RecordingOwnerPort:
	extends PassiveOwnerPort

	var stats := CombatStatSnapshot.new()
	var capture_count: int = 0
	var heals: Array[int] = []
	var heal_sources: Array[StringName] = []
	var heal_events: Array[StringName] = []
	var energy_restores: Array[int] = []
	var energy_sources: Array[StringName] = []
	var energy_events: Array[StringName] = []

	func capture_attack_stats() -> CombatStatSnapshot:
		capture_count += 1
		return stats

	func restore_health(amount: int, source_skill_id: StringName, event_id: StringName) -> bool:
		heals.append(amount)
		heal_sources.append(source_skill_id)
		heal_events.append(event_id)
		return true

	func restore_energy(amount: int, source_skill_id: StringName, event_id: StringName) -> bool:
		energy_restores.append(amount)
		energy_sources.append(source_skill_id)
		energy_events.append(event_id)
		return true


class RecordingTargetPort:
	extends PassiveTargetPort

	var targets: Array[PassiveTargetSnapshot] = []
	var observed_elements: Array[StringName] = []
	var requests: Array[PassiveDamageRequest] = []

	func query_targets(observed_element_id: StringName) -> Array[PassiveTargetSnapshot]:
		observed_elements.append(observed_element_id)
		return targets.duplicate()

	func submit_damage(request: PassiveDamageRequest) -> bool:
		requests.append(request)
		return true


var _failures: Array[String] = []
var _tests: int = 0
var _assertions: int = 0


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	_run("burning_exact_tick_and_fire_layers", _test_burning_exact_tick_and_fire_layers)
	_run("burning_large_delta", _test_burning_large_delta)
	_run("unending_typed_basic_attack_event", _test_unending_typed_basic_attack_event)
	_run("reaction_energy_committed_result", _test_reaction_energy_committed_result)
	_run("passive_runtime_lifecycle", _test_passive_runtime_lifecycle)
	_run("formal_stat_passive_resources", _test_formal_stat_passive_resources)

	if _failures.is_empty():
		print("TASK 14 PASSIVE TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 14 PASSIVE TESTS FAILED: %d/%d tests, %d assertions" % [
			_failures.size(),
			_tests,
			_assertions,
		])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _run(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	callable.call()
	if _failures.size() == before:
		print("PASS: " + test_name)


func _test_burning_exact_tick_and_fire_layers() -> void:
	var owner := RecordingOwnerPort.new()
	var targets := RecordingTargetPort.new()
	var locked_elements := ElementSnapshot.new(7, 3)
	targets.targets.append(PassiveTargetSnapshot.new(&"target-b", locked_elements))
	var definition := BurningPassiveEffectDefinition.new()
	var runtime := definition.create_runtime(
		&"passive_burning",
		PassiveRuntimeContext.new(owner, targets)
	)
	_expect(runtime.is_valid(), "burning runtime valid")
	_expect(not runtime.advance(0.99), "partial second does not tick")
	_expect_eq(targets.requests.size(), 0, "partial second creates no damage")
	_expect(runtime.advance(0.01), "exact one second ticks")
	_expect_eq(targets.requests.size(), 1, "one complete interval submits once")
	_expect_eq(targets.observed_elements[0], ElementIds.FIRE, "burning always queries fire")
	var request := targets.requests[0]
	_expect_float(request.payload.damage_multiplier, 0.15, "three fire layers use fifteen percent")
	_expect_float(request.payload.offensive_damage, 1.5, "base attack ten produces one point five")
	_expect_eq(request.payload.element_id, ElementIds.NONE, "burning damage applies no element")
	_expect_eq(request.payload.element_amount, 0, "burning consumes or applies no layers")
	_expect_eq(locked_elements.fire_amount, 3, "locked target fire layers remain unchanged")
	_expect_eq(locked_elements.water_amount, 7, "unrelated water layers remain unchanged")
	_expect_eq(owner.capture_count, 1, "attack stats captured once for the tick")


func _test_burning_large_delta() -> void:
	var owner := RecordingOwnerPort.new()
	var targets := RecordingTargetPort.new()
	targets.targets.append(PassiveTargetSnapshot.new(&"target-a", ElementSnapshot.new(0, 2)))
	var definition := BurningPassiveEffectDefinition.new()
	var runtime := definition.create_runtime(
		&"passive_burning",
		PassiveRuntimeContext.new(owner, targets)
	)
	_expect(runtime.advance(2.0), "large delta triggers complete ticks")
	_expect_eq(targets.requests.size(), 2, "two seconds submit two requests")
	_expect_eq(owner.capture_count, 2, "each tick locks a fresh stat snapshot")
	_expect(targets.requests[0].event_id != targets.requests[1].event_id, "tick event identities are unique")


func _test_unending_typed_basic_attack_event() -> void:
	var owner := RecordingOwnerPort.new()
	var definition := UnendingPassiveEffectDefinition.new()
	var runtime := definition.create_runtime(
		&"passive_unending",
		PassiveRuntimeContext.new(owner, null)
	)
	var committed := BasicAttackCommittedEvent.new(
		&"basic:1",
		1,
		&"target-a",
		ElementSnapshot.new(4, 5)
	)
	_expect(runtime.on_basic_attack_committed(committed), "typed committed basic attack is handled")
	_expect_eq(owner.heals.size(), 1, "one committed event heals once")
	_expect_eq(owner.heals[0], 4, "four water layers restore four health")
	_expect_eq(owner.heal_sources[0], &"passive_unending", "heal preserves passive source")
	_expect_eq(owner.heal_events[0], &"basic:1", "heal preserves committed event identity")
	var no_water := BasicAttackCommittedEvent.new(
		&"basic:2",
		1,
		&"target-a",
		ElementSnapshot.new(0, 5)
	)
	_expect(not runtime.on_basic_attack_committed(no_water), "zero water layers do not heal")
	_expect_eq(owner.heals.size(), 1, "ignored events cannot duplicate healing")


func _test_reaction_energy_committed_result() -> void:
	var owner := RecordingOwnerPort.new()
	var definition := ReactionEnergyPassiveEffectDefinition.new()
	var runtime := definition.create_runtime(
		&"passive_reaction_energy",
		PassiveRuntimeContext.new(owner, null)
	)
	var reaction := _combat_result(71, 81, 0, 901, true)
	_expect(runtime.on_combat_result(reaction, &"enemy-a", false, 901), "player reaction restores energy")
	_expect_eq(owner.energy_restores, [10], "reaction restores the fixed ten energy once")
	_expect_eq(owner.energy_sources, [&"passive_reaction_energy"], "energy restore preserves passive source")
	_expect_eq(owner.energy_events, [&"reaction_energy:71:81:0:enemy-a"], "energy restore identity uses cast delivery hit and target")
	_expect(not runtime.on_combat_result(reaction, &"enemy-a", false, 901), "same settlement cannot restore twice")
	_expect_eq(owner.energy_restores.size(), 1, "duplicate result leaves one restore")
	_expect(not runtime.on_combat_result(_combat_result(72, 82, 0, 901, false), &"enemy-a", false, 901), "non-reaction is ignored")
	_expect(not runtime.on_combat_result(_combat_result(73, 83, 0, 902, true), &"player", true, 901), "enemy reaction against player is ignored")
	_expect(not runtime.on_combat_result(CombatResult.rejected(null, CombatStatus.RejectReason.INVALID_REQUEST), &"enemy-a", false, 901), "rejected result is ignored")
	_expect_eq(owner.energy_restores.size(), 1, "ignored results restore no energy")


func _combat_result(
		cast_id: int,
		delivery_id: int,
		hit_index: int,
		root_owner_id: int,
		reaction: bool
) -> CombatResult:
	var receiver := CombatReceiver.new()
	receiver.target_team_id = &"enemy"
	var carrier := ElementCarrier.new()
	carrier.set_amounts_silent(1 if reaction else 0, 0)
	receiver.configure_components(carrier, null)
	var cast := CastSnapshot.new(
		cast_id,
		&"test_reaction_source",
		root_owner_id,
		root_owner_id,
		&"player",
		ElementIds.FIRE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.from_locked_stats(
		cast.stat_snapshot,
		1.0,
		ElementIds.FIRE,
		1
	)
	var result := receiver.receive_hit(HitRequest.new(
		cast,
		payload,
		delivery_id,
		hit_index,
		Vector2.ZERO,
		Vector2.RIGHT
	))
	receiver.free()
	carrier.free()
	return result


func _test_passive_runtime_lifecycle() -> void:
	var definition := StatModifierPassiveEffectDefinition.new()
	definition.maximum_health_bonus = 20
	var binding := PassiveEffectBinding.new(
		&"passive_vitality",
		definition,
		SkillDefinition.ElementPolicy.NEUTRAL,
		ElementIds.NONE
	)
	var bindings: Array[PassiveEffectBinding] = [binding]
	var controller := PassiveSkillController.new()
	_expect_eq(controller.validation_error(bindings), &"", "typed stat passive validates")
	controller.commit_validated_replacement(bindings)
	_expect_eq(controller.registered_runtimes.size(), 1, "activation creates one runtime")
	var first := controller.registered_runtimes[0]
	controller.rebuild()
	var rebuilt := controller.registered_runtimes[0]
	_expect(first != rebuilt, "rebuild creates a fresh runtime")
	controller.deactivate()
	_expect_eq(controller.registered_runtimes.size(), 0, "deactivation removes runtime")
	controller.reactivate()
	_expect_eq(controller.registered_runtimes.size(), 1, "reactivation restores runtime")
	_expect(controller.registered_runtimes[0] != rebuilt, "reactivation creates another fresh runtime")
	controller.clear()
	_expect_eq(controller.registered_runtimes.size(), 0, "clear removes all runtimes")


func _test_formal_stat_passive_resources() -> void:
	var cases: Array[Dictionary] = [
		{"path": "res://resources/skills/passive_vitality.tres", "health": 20, "energy": 0, "attack": 1.0},
		{"path": "res://resources/skills/passive_energy.tres", "health": 0, "energy": 10, "attack": 1.0},
		{"path": "res://resources/skills/passive_focus.tres", "health": 0, "energy": 0, "attack": 1.1},
		{"path": "res://resources/skills/passive_balance.tres", "health": 10, "energy": 5, "attack": 1.05},
	]
	for entry: Dictionary in cases:
		var skill := load(entry.path) as SkillDefinition
		_expect(skill != null and skill.is_valid(), "%s loads as a valid skill" % entry.path)
		_expect(skill.execution_definition == null, "%s has no active execution" % entry.path)
		var definition := skill.passive_effect_definition as StatModifierPassiveEffectDefinition
		_expect(definition != null, "%s uses typed stat modifier definition" % entry.path)
		if definition == null:
			continue
		var runtime := definition.create_runtime(skill.skill_id, PassiveRuntimeContext.new())
		var modifier := runtime.stat_modifier_snapshot()
		_expect_eq(modifier.maximum_health_bonus, entry.health, "%s health bonus" % entry.path)
		_expect_eq(modifier.maximum_energy_bonus, entry.energy, "%s energy bonus" % entry.path)
		_expect_float(modifier.attack_multiplier, entry.attack, "%s attack multiplier" % entry.path)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertions += 1
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])
