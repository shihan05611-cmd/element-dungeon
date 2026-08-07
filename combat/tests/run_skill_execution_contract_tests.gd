extends SceneTree

const RECORDING_DELIVERY: PackedScene = preload("res://combat/tests/recording_skill_delivery.tscn")
const SWEEP_PROFILE: ProjectileSweepProfile2D = preload(
	"res://resources/combat/element_projectile_sweep_profile.tres"
)


class RecordingReclaimTransaction:
	extends SkillExecutionCommitTransaction

	var commit_count: int = 0
	var publish_count: int = 0

	func commit_silent() -> void:
		commit_count += 1

	func publish_committed() -> void:
		publish_count += 1


class RecordingReclaimPort:
	extends ElementReclaimPort

	var has_target: bool = true
	var prepare_count: int = 0
	var transaction := RecordingReclaimTransaction.new()

	func prepare(_request: ElementReclaimRequest) -> ElementReclaimPrepareResult:
		prepare_count += 1
		if not has_target:
			return ElementReclaimPrepareResult.rejected(
				CastAttemptResult.RejectReason.NO_LEGAL_TARGET,
				&"no_matching_element"
			)
		return ElementReclaimPrepareResult.success(3, 15, transaction)


class FixedEnemySweepPort:
	extends ProjectileSweepQueryPort2D

	func query_first_contact(request: ProjectileSweepRequest2D) -> ProjectileSweepResult2D:
		return ProjectileSweepResult2D.enemy_contact(
			request.start_transform.origin + request.direction * 40.0,
			40.0 / request.distance,
			40.0,
			null,
			null,
			1
		)


class TestBurstDeliveryPreparePort:
	extends SkillDeliveryPreparePort

	var parent: Node

	func _init(p_parent: Node) -> void:
		parent = p_parent

	func prepare(
			snapshot: SkillExecutionSnapshot,
			spawn_snapshot: DeliverySpawnSnapshot
	) -> PreparedSkillDeliveryTransaction:
		var rage := ElementRageDelivery.new()
		rage.trigger_on_ready = false
		if not rage.initialize_burst(
			snapshot as AllEnergyBurstExecutionSnapshot,
			1,
			spawn_snapshot.initial_transform,
			spawn_snapshot.direction
		):
			rage.free()
			return null
		return PreparedSkillDeliveryTransaction.new(rage, parent)


class Rig:
	extends RefCounted

	var host: Node2D
	var delivery_parent: Node2D
	var energy: EnergyComponent
	var element: CurrentElementController
	var executor: SkillExecutor

	func cleanup() -> void:
		if is_instance_valid(host):
			host.free()


var _failures: Array[String] = []
var _tests: int = 0
var _assertions: int = 0


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	_run("damage_multiplier_contract", _test_damage_multiplier_contract)
	_run("all_energy_burst_rejects_19", _test_all_energy_burst_rejects_19)
	_run("all_energy_burst_20_snapshot", _test_all_energy_burst_20_snapshot)
	_run("all_energy_burst_100_snapshot", _test_all_energy_burst_100_snapshot)
	_run("all_energy_burst_200_snapshot", _test_all_energy_burst_200_snapshot)
	_run("all_energy_burst_220_caps_element_amount", _test_all_energy_burst_220_caps_element_amount)
	_run("channel_rejects_four_atomically", _test_channel_rejects_four_atomically)
	_run("channel_accepts_five_and_spends_first_tick", _test_channel_accepts_five_and_spends_first_tick)
	_run("channel_boundary_and_release", _test_channel_boundary_and_release)
	_run("channel_large_delta", _test_channel_large_delta)
	_run("channel_energy_exhaustion", _test_channel_energy_exhaustion)
	_run("channel_cancel_tail_and_reentry", _test_channel_cancel_tail_and_reentry)
	_run("reclaim_full_energy_rejects_before_query", _test_reclaim_full_energy_rejects_before_query)
	_run("reclaim_no_target_is_atomic", _test_reclaim_no_target_is_atomic)
	_run("reclaim_prepared_transaction_commits_once", _test_reclaim_prepared_transaction_commits_once)
	_run("runtime_catalog_validates_typed_definitions", _test_runtime_catalog_validates_typed_definitions)

	if _failures.is_empty():
		print("TASK 14 EXECUTION TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("TASK 14 EXECUTION TESTS FAILED: %d/%d tests, %d assertions" % [
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
	else:
		for index in range(before, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _test_damage_multiplier_contract() -> void:
	var base := CombatStatSnapshot.new()
	_expect_float(base.effective_attack, 10.0, "base effective attack is ten")
	_expect_float(base.calculate_offensive_damage(0.5), 5.0, "50 percent")
	_expect_float(base.calculate_offensive_damage(1.0), 10.0, "100 percent")
	_expect_float(base.calculate_offensive_damage(8.0), 80.0, "800 percent")
	var grown := CombatStatSnapshot.new(1.5, 2.0)
	var payload := RuntimeAttackPayload.from_locked_stats(
		grown,
		0.5,
		ElementIds.WATER,
		1
	)
	_expect_float(payload.effective_attack, 15.0, "growth locks effective attack")
	_expect_float(payload.damage_multiplier, 0.5, "skill multiplier locks independently")
	_expect_float(payload.fixed_damage_bonus, 2.0, "flat bonus locks independently")
	_expect_float(payload.offensive_damage, 9.5, "locked formula uses all three inputs")


func _test_all_energy_burst_rejects_19() -> void:
	var skill := _burst_skill()
	var rig := _make_rig(100, 19)
	var result := rig.executor._try_cast_configured(skill)
	_expect(not result.accepted, "19 energy is rejected")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, "typed rejection")
	_expect_eq(rig.energy.current_energy, 19, "rejection spends nothing")
	_expect(not rig.executor.is_skill_on_cooldown(skill.skill_id), "rejection starts no cooldown")
	rig.cleanup()


func _test_all_energy_burst_20_snapshot() -> void:
	var rig := _make_rig(100, 20)
	var result := rig.executor._try_cast_configured(_burst_skill())
	var snapshot := result.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(result.accepted and snapshot != null, "20 energy accepts typed burst")
	_expect_eq(snapshot.energy_spent, 20, "all current energy locks")
	_expect_float(snapshot.payload.damage_multiplier, 1.6, "20 energy is 160 percent")
	_expect_float(snapshot.payload.offensive_damage, 16.0, "160 percent of ten")
	_expect_eq(snapshot.payload.element_amount, 1, "20 energy applies one layer")
	_expect_float(snapshot.radius_scale, 1.2, "20 of 100 produces two radius steps")
	_expect_eq(rig.energy.current_energy, 0, "all energy commits atomically")
	rig.cleanup()


func _test_all_energy_burst_100_snapshot() -> void:
	var rig := _make_rig(100, 100)
	var result := rig.executor._try_cast_configured(_burst_skill())
	var snapshot := result.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(result.accepted and snapshot != null, "100 energy accepts typed burst")
	_expect_eq(snapshot.energy_spent, 100, "100 energy locks")
	_expect_float(snapshot.payload.damage_multiplier, 8.0, "100 energy is 800 percent")
	_expect_float(snapshot.payload.offensive_damage, 80.0, "800 percent of ten")
	_expect_eq(snapshot.payload.element_amount, 5, "100 energy applies five layers")
	_expect_float(snapshot.radius_scale, 2.0, "maximum energy doubles radius")
	var locked_element := snapshot.cast_element_id
	rig.element.request_element(ElementIds.FIRE)
	rig.energy.configure_runtime(200, 200)
	_expect_eq(snapshot.cast_element_id, locked_element, "later element change cannot mutate burst")
	_expect_eq(snapshot.maximum_energy, 100, "later maximum energy cannot mutate burst")
	_expect_float(snapshot.payload.offensive_damage, 80.0, "later stats cannot mutate payload")
	rig.cleanup()


func _test_all_energy_burst_200_snapshot() -> void:
	var rig := _make_rig(220, 200)
	var result := rig.executor._try_cast_configured(_burst_skill())
	var snapshot := result.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(result.accepted and snapshot != null, "200 of 220 energy accepts typed burst")
	_expect_eq(snapshot.energy_spent, 200, "200 energy locks and spends all current energy")
	_expect_float(snapshot.payload.damage_multiplier, 16.0, "200 energy keeps uncapped damage multiplier")
	_expect_float(snapshot.payload.offensive_damage, 160.0, "200 energy damage remains formula driven")
	_expect_eq(snapshot.payload.element_amount, 10, "200 energy reaches ten layer cap")
	_expect_float(snapshot.radius_scale, 1.9, "200 of 220 keeps uncapped radius formula")
	_expect_eq(rig.energy.current_energy, 0, "200 energy commits atomically")
	rig.cleanup()


func _test_all_energy_burst_220_caps_element_amount() -> void:
	var rig := _make_rig(220, 220)
	var result := rig.executor._try_cast_configured(_burst_skill())
	var snapshot := result.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(result.accepted and snapshot != null, "220 energy is not an invalid configuration")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.NONE, "220 energy has no rejection")
	_expect_eq(snapshot.energy_spent, 220, "220 energy locks and spends all current energy")
	_expect_float(snapshot.payload.damage_multiplier, 17.6, "220 energy keeps uncapped damage multiplier")
	_expect_float(snapshot.payload.offensive_damage, 176.0, "220 energy damage remains formula driven")
	_expect_eq(snapshot.payload.element_amount, 10, "220 energy clamps attachment to ten")
	_expect_float(snapshot.radius_scale, 2.0, "220 of 220 keeps radius formula")
	_expect_eq(rig.energy.current_energy, 0, "220 energy commits atomically")
	rig.cleanup()


func _test_channel_rejects_four_atomically() -> void:
	var skill := _channel_skill()
	var execution := skill.execution_definition as ChannelExecution
	var rig := _make_rig(100, 4)
	var success_events := {"cast": 0, "execution": 0}
	rig.executor.cast_started.connect(func(
			_cast: CastSnapshot,
			_payload: RuntimeAttackPayload
	) -> void:
		success_events.cast += 1
	)
	rig.executor.execution_started.connect(func(_snapshot: SkillExecutionSnapshot) -> void:
		success_events.execution += 1
	)
	var element_before := rig.element.current_element_id
	var result := rig.executor._try_cast_configured(skill)
	_expect_eq(execution.minimum_energy_required(), 5, "channel minimum equals one tick cost")
	_expect(not result.accepted, "four energy is rejected")
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY, "four energy has typed rejection")
	_expect_eq(rig.energy.current_energy, 4, "rejection spends nothing")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "rejection never enters execution state")
	_expect(not rig.executor.is_skill_on_cooldown(skill.skill_id), "rejection starts no cooldown")
	_expect_eq(rig.element.current_element_id, element_before, "rejection preserves current element")
	_expect_eq(success_events.cast, 0, "rejection publishes no cast success")
	_expect_eq(success_events.execution, 0, "rejection publishes no execution success")
	rig.cleanup()


func _test_channel_accepts_five_and_spends_first_tick() -> void:
	var rig := _make_rig(100, 5)
	var ticks: Array[ChannelTickSnapshot] = []
	rig.executor.execution_tick_generated.connect(func(tick: ChannelTickSnapshot) -> void:
		ticks.append(tick)
	)
	var result := rig.executor._try_cast_configured(_channel_skill())
	_expect(result.accepted, "five energy accepts channel")
	_expect_eq(rig.energy.current_energy, 5, "acceptance does not pre-spend tick energy")
	rig.executor.advance(0.49)
	_expect_eq(ticks.size(), 0, "five energy still waits for a complete interval")
	_expect_eq(rig.energy.current_energy, 5, "partial interval spends nothing")
	rig.executor.advance(0.01)
	_expect_eq(ticks.size(), 1, "first complete interval emits one tick")
	_expect_eq(rig.energy.current_energy, 0, "first tick spends the exact five energy")
	rig.cleanup()


func _test_channel_boundary_and_release() -> void:
	var skill := _channel_skill()
	var rig := _make_rig(100, 20)
	var ticks: Array[ChannelTickSnapshot] = []
	rig.executor.execution_tick_generated.connect(func(tick: ChannelTickSnapshot) -> void:
		ticks.append(tick)
	)
	var result := rig.executor._try_cast_configured(skill)
	_expect(result.accepted, "channel accepted")
	_expect_eq(result.execution_snapshot.movement_policy, SkillExecutionSnapshot.MovementPolicy.ALLOW_MOVEMENT, "channel explicitly allows movement")
	rig.executor.advance(0.0)
	rig.executor.advance(0.49)
	_expect_eq(ticks.size(), 0, "0.49 has no tick")
	_expect_eq(rig.energy.current_energy, 20, "partial tail spends nothing")
	rig.executor.advance(0.01)
	_expect_eq(ticks.size(), 1, "first full interval ticks")
	_expect_eq(rig.energy.current_energy, 15, "first tick spends five")
	_expect_float(ticks[0].payload.offensive_damage, 5.0, "tick locks 50 percent damage")
	_expect_eq(ticks[0].payload.element_amount, 1, "tick locks one layer")
	_expect(rig.executor.request_channel_release(result.cast_snapshot.cast_id), "release accepted")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.RECOVERY, "release ends active runtime")
	rig.executor.advance(10.0)
	_expect_eq(ticks.size(), 1, "release cannot create a trailing tick")
	_expect_eq(rig.energy.current_energy, 15, "release cannot overcharge")
	rig.cleanup()


func _test_channel_large_delta() -> void:
	var rig := _make_rig(100, 20)
	var ticks: Array[ChannelTickSnapshot] = []
	rig.executor.execution_tick_generated.connect(func(tick: ChannelTickSnapshot) -> void:
		ticks.append(tick)
	)
	rig.executor._try_cast_configured(_channel_skill())
	rig.executor.advance(1.5)
	_expect_eq(ticks.size(), 3, "large delta emits every complete tick")
	_expect_eq(ticks[0].tick_index, 1, "first tick identity")
	_expect_eq(ticks[2].tick_index, 3, "third tick identity")
	_expect_eq(rig.energy.current_energy, 5, "three ticks spend fifteen")
	rig.cleanup()


func _test_channel_energy_exhaustion() -> void:
	var rig := _make_rig(100, 7)
	var ticks := {"count": 0, "end": -1}
	rig.executor.execution_tick_generated.connect(func(_tick: ChannelTickSnapshot) -> void:
		ticks.count += 1
	)
	rig.executor.execution_ended.connect(func(_snapshot: SkillExecutionSnapshot, end: SkillExecutionEndResult) -> void:
		ticks.end = end.reason
	)
	rig.executor._try_cast_configured(_channel_skill())
	rig.executor.advance(1.0)
	_expect_eq(ticks.count, 1, "only affordable tick emits")
	_expect_eq(rig.energy.current_energy, 2, "insufficient boundary does not spend")
	_expect_eq(ticks.end, SkillExecutionEndResult.Reason.INSUFFICIENT_ENERGY, "typed energy end reason")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "zero recovery completes")
	rig.cleanup()


func _test_channel_cancel_tail_and_reentry() -> void:
	var skill := _channel_skill()
	var rig := _make_rig(100, 20)
	var observations := {"ticks": 0, "nested": null}
	rig.executor.execution_tick_generated.connect(func(_tick: ChannelTickSnapshot) -> void:
		observations.ticks += 1
		observations.nested = rig.executor._try_cast_configured(skill)
	)
	var accepted := rig.executor._try_cast_configured(skill)
	rig.executor.advance(0.5)
	_expect_eq(observations.ticks, 1, "one boundary tick")
	_expect(observations.nested != null, "tick observer attempted reentry")
	_expect_eq(observations.nested.reject_reason, CastAttemptResult.RejectReason.BUSY, "tick reentry is guarded")
	var before_cancel := rig.energy.current_energy
	rig.executor.advance(0.49)
	_expect(rig.executor.cancel_current_cast(&"hit", accepted.cast_snapshot.cast_id), "channel cancels safely")
	_expect_eq(observations.ticks, 1, "cancelled tail never ticks")
	_expect_eq(rig.energy.current_energy, before_cancel, "cancelled tail never spends")
	rig.cleanup()


func _test_reclaim_full_energy_rejects_before_query() -> void:
	var port := RecordingReclaimPort.new()
	var services := SkillExecutionServices.new(port)
	var rig := _make_rig(100, 100, services)
	var skill := _reclaim_skill()
	var result := rig.executor._try_cast_configured(skill)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.NO_BENEFIT, "full energy has typed rejection")
	_expect_eq(result.detail, &"energy_already_full", "full energy detail")
	_expect_eq(port.prepare_count, 0, "full energy rejects before spatial query")
	_expect(not rig.executor.is_skill_on_cooldown(skill.skill_id), "full rejection starts no cooldown")
	rig.cleanup()


func _test_reclaim_no_target_is_atomic() -> void:
	var port := RecordingReclaimPort.new()
	port.has_target = false
	var rig := _make_rig(100, 50, SkillExecutionServices.new(port))
	var skill := _reclaim_skill()
	var result := rig.executor._try_cast_configured(skill)
	_expect_eq(result.reject_reason, CastAttemptResult.RejectReason.NO_LEGAL_TARGET, "no target typed rejection")
	_expect_eq(port.prepare_count, 1, "query runs once")
	_expect_eq(rig.energy.current_energy, 50, "failed reclaim preserves energy")
	_expect(not rig.executor.is_skill_on_cooldown(skill.skill_id), "failed reclaim starts no cooldown")
	_expect_eq(port.transaction.commit_count, 0, "failed reclaim commits nothing")
	rig.cleanup()


func _test_reclaim_prepared_transaction_commits_once() -> void:
	var port := RecordingReclaimPort.new()
	var rig := _make_rig(100, 50, SkillExecutionServices.new(port))
	var skill := _reclaim_skill()
	var result := rig.executor._try_cast_configured(skill)
	var snapshot := result.execution_snapshot as ElementReclaimExecutionSnapshot
	_expect(result.accepted and snapshot != null, "prepared reclaim accepts")
	_expect_eq(snapshot.matched_element_amount, 3, "matched amount locks")
	_expect_eq(snapshot.theoretical_energy_restore, 15, "theoretical restore locks")
	_expect_eq(port.transaction.commit_count, 1, "external mutation commits once")
	_expect_eq(port.transaction.publish_count, 1, "external notification publishes once")
	_expect(rig.executor.is_skill_on_cooldown(skill.skill_id), "successful reclaim commits cooldown")
	rig.cleanup()


func _test_runtime_catalog_validates_typed_definitions() -> void:
	var missing := SkillDefinition.new()
	missing.skill_id = &"missing_execution"
	var invalid_catalog := RuntimeSkillLoadout.new([missing])
	_expect_eq(invalid_catalog.configuration_error, &"invalid_skill_catalog_entry", "missing execution rejected at catalog")
	var burst := _burst_skill()
	var valid_catalog := RuntimeSkillLoadout.new([burst])
	_expect_eq(valid_catalog.configuration_error, &"", "typed burst accepted without delivery guessing")
	_expect(valid_catalog.get_skill(burst.skill_id) == burst, "typed definition is catalog authority")


func _make_rig(
		maximum_energy: int,
		current_energy: int,
		services: SkillExecutionServices = null
) -> Rig:
	var rig := Rig.new()
	rig.host = Node2D.new()
	rig.delivery_parent = Node2D.new()
	rig.host.add_child(rig.delivery_parent)
	rig.energy = EnergyComponent.new()
	rig.energy.configure_runtime(maximum_energy, current_energy)
	rig.host.add_child(rig.energy)
	rig.element = CurrentElementController.new()
	rig.element.configure_runtime(ElementIds.WATER, [ElementIds.WATER, ElementIds.FIRE])
	rig.host.add_child(rig.element)
	rig.executor = SkillExecutor.new()
	rig.executor.configure_dependencies(rig.energy, rig.element, rig.delivery_parent)
	rig.executor.configure_cast_identity(1001, 1002, &"player")
	rig.host.add_child(rig.executor)
	root.add_child(rig.host)
	var configured_services := services if services != null else SkillExecutionServices.new()
	if configured_services.projectile_sweep_query_port == null:
		configured_services.set_projectile_sweep_query_port(FixedEnemySweepPort.new())
	if configured_services.skill_delivery_prepare_port == null:
		configured_services.set_skill_delivery_prepare_port(
			TestBurstDeliveryPreparePort.new(rig.delivery_parent)
		)
	configured_services.set_projectile_source(rig.host)
	rig.executor.set_execution_services(configured_services)
	rig.executor.set_process(false)
	rig.energy.set_process(false)
	return rig


func _burst_skill() -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_id = &"test_burst"
	var execution := AllEnergyBurstExecution.new()
	execution.projectile_sweep_profile = SWEEP_PROFILE
	skill.execution_definition = execution
	return skill


func _channel_skill() -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_id = &"test_channel"
	skill.execution_definition = ChannelExecution.new()
	return skill


func _reclaim_skill() -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_id = &"test_reclaim"
	skill.cooldown = 5.0
	skill.execution_definition = ElementReclaimExecution.new()
	return skill


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (expected=%s, actual=%s)" % [message, expected, actual])
