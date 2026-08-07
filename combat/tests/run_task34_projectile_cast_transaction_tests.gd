extends SceneTree

const PROFILE: ProjectileSweepProfile2D = preload(
	"res://resources/combat/element_projectile_sweep_profile.tres"
)
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")


class FakeSweepPort:
	extends ProjectileSweepQueryPort2D

	var mode: StringName = &"enemy"
	var impact_position: Vector2 = Vector2(120.0, 0.0)
	var query_count: int = 0
	var last_request: ProjectileSweepRequest2D

	func query_first_contact(request: ProjectileSweepRequest2D) -> ProjectileSweepResult2D:
		query_count += 1
		last_request = request
		match mode:
			&"enemy":
				return ProjectileSweepResult2D.enemy_contact(
					impact_position,
					0.25,
					PROFILE.max_distance * 0.25,
					null,
					null,
					41
				)
			&"wall":
				return ProjectileSweepResult2D.blocker_contact(
					Vector2(80.0, 0.0), 0.2, PROFILE.max_distance * 0.2, 51
				)
			&"miss":
				return ProjectileSweepResult2D.no_contact()
			&"invalid":
				var detail := request.validation_error() if request != null else &"missing_request"
				return ProjectileSweepResult2D.invalid_context(detail)
			&"failure":
				return ProjectileSweepResult2D.query_failed(&"injected_query_failure")
			_:
				return null


class SwitchableFailingPhysicsSweepPort:
	extends PhysicsProjectileSweepQuery2D

	var fail_queries: bool = false

	func _cast_fraction(
			space: PhysicsDirectSpaceState2D,
			start_transform: Transform2D,
			motion: Vector2,
			require_hurtbox: bool,
			overlap_query: PhysicsShapeQueryParameters2D,
			cast_query: PhysicsShapeQueryParameters2D
	) -> float:
		if fail_queries:
			return -1.0
		return super._cast_fraction(
			space,
			start_transform,
			motion,
			require_hurtbox,
			overlap_query,
			cast_query
		)


class FakeDeliveryPreparePort:
	extends SkillDeliveryPreparePort

	var parent: Node
	var fail_prepare: bool = false
	var prepare_count: int = 0
	var instantiate_count: int = 0
	var burst_count: int = 0
	var last_spawn_snapshot: DeliverySpawnSnapshot
	var last_delivery: ElementRageDelivery

	func _init(p_parent: Node) -> void:
		parent = p_parent

	func prepare(
			snapshot: SkillExecutionSnapshot,
			spawn_snapshot: DeliverySpawnSnapshot
	) -> PreparedSkillDeliveryTransaction:
		prepare_count += 1
		last_spawn_snapshot = spawn_snapshot
		if fail_prepare:
			return null
		var rage := ElementRageDelivery.new()
		instantiate_count += 1
		rage.queue_free_on_finish = false
		rage.trigger_on_ready = false
		if not rage.initialize_burst(
			snapshot as AllEnergyBurstExecutionSnapshot,
			1,
			spawn_snapshot.initial_transform,
			spawn_snapshot.direction
		):
			rage.free()
			return null
		rage.burst_submitted.connect(func(
				_origin: Vector2,
				_radius: float,
				_target_count: int
		) -> void:
			burst_count += 1
		)
		last_delivery = rage
		return PreparedSkillDeliveryTransaction.new(rage, parent)


class DummyReclaimPort:
	extends ElementReclaimPort


class FuryRig:
	extends RefCounted

	var host: Node2D
	var source: Node2D
	var energy: EnergyComponent
	var element: CurrentElementController
	var executor: SkillExecutor
	var query: FakeSweepPort
	var prepare: FakeDeliveryPreparePort
	var services: SkillExecutionServices
	var skill: SkillDefinition
	var detached_parent: Node2D

	func cleanup(tree: SceneTree) -> void:
		if tree.current_scene == host:
			tree.current_scene = null
		if is_instance_valid(host):
			host.free()
		if is_instance_valid(detached_parent):
			detached_parent.free()


var _failures: Array[String] = []
var _tests: int = 0
var _assertions: int = 0


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	await _run_test("fake_enemy_commits_once_at_locked_impact", _test_fake_enemy_commits_once_at_locked_impact)
	await _run_test("fake_wall_miss_invalid_and_query_failure_are_atomic", _test_fake_rejection_matrix)
	await _run_test("delivery_prepare_and_parent_failures_are_atomic", _test_prepare_failure_matrix)
	await _run_test("nested_cast_is_busy_during_commit", _test_nested_cast_is_busy)
	await _run_test("execution_services_narrow_updates_preserve_ports", _test_services_preserve_ports)
	await _run_test("production_callers_use_public_try_cast", _test_public_try_cast_scan)
	await _run_test("formal_profile_is_shared_and_exact", _test_formal_profile_shared)
	await _run_test("real_physics_wall_tie_and_stable_enemy_order", _test_real_query_ordering)
	await _run_test("retained_public_results_are_stable_and_contactless_states_are_clean", _test_retained_results)
	await _run_test("ordinary_projectile_friend_signal_and_cleanup_semantics", _test_projectile_legacy_semantics)
	await _run_test("real_fury_hits_once_without_flight_node", _test_real_fury_transaction)

	if _failures.is_empty():
		print("TASK 34 PROJECTILE CAST TRANSACTION TESTS PASSED: %d tests, %d assertions" % [
			_tests,
			_assertions,
		])
		quit(0)
	else:
		printerr("TASK 34 PROJECTILE CAST TRANSACTION TESTS FAILED: %d/%d tests, %d assertions" % [
			_failures.size(),
			_tests,
			_assertions,
		])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _run_test(test_name: String, callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await callable.call()
	if _failures.size() == before:
		print("PASS " + test_name)
	else:
		for index in range(before, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _test_fake_enemy_commits_once_at_locked_impact() -> void:
	var rig := _make_fake_rig()
	var events := _connect_success_counters(rig.executor)
	var result := rig.executor.try_cast(rig.skill, SkillSlotIds.ACTIVE_1)
	_expect(result.accepted, "enemy contact accepts")
	_expect_eq(rig.query.query_count, 1, "one synchronous sweep")
	_expect_eq(rig.prepare.prepare_count, 1, "one delivery prepare")
	_expect_eq(rig.prepare.instantiate_count, 1, "one burst node instantiated")
	_expect_eq(rig.prepare.burst_count, 1, "one prepared burst activates")
	_expect_eq(rig.energy.current_energy, 0, "success spends all SP")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, "success preserves locked current element")
	_expect_eq(rig.prepare.last_spawn_snapshot.initial_transform.origin, rig.query.impact_position, "impact is locked into spawn")
	var snapshot := result.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(snapshot != null and snapshot.impact_position == rig.query.impact_position, "execution snapshot owns impact")
	_expect_eq(snapshot.payload.element_amount, 1, "minimum Fury attachment is unchanged")
	_expect_float(snapshot.payload.damage_multiplier, 1.6, "minimum Fury multiplier is unchanged")
	_expect_float(snapshot.radius_scale, 1.2, "minimum Fury radius scale is unchanged")
	_expect_eq(events.cast_started, 1, "one cast_started event")
	_expect_eq(events.execution_started, 1, "one execution_started event")
	_expect_eq(events.execution_activated, 1, "one execution_activated event")
	_expect_eq(events.delivery_spawned, 1, "one delivery_spawned event")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.ACTIVE, "prepared zero-startup Fury activates synchronously")
	_expect(rig.executor.advance(0.0), "zero active duration advances cleanly")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, "zero recovery returns idle")
	rig.cleanup(self)


func _test_fake_rejection_matrix() -> void:
	var cases: Array[Dictionary] = [
		{&"mode": &"wall", &"reason": CastAttemptResult.RejectReason.NO_LEGAL_TARGET, &"detail": &"projectile_blocked"},
		{&"mode": &"miss", &"reason": CastAttemptResult.RejectReason.NO_LEGAL_TARGET, &"detail": &"projectile_no_contact"},
		{&"mode": &"invalid", &"reason": CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE, &"detail": &"invalid_sweep_source"},
		{&"mode": &"failure", &"reason": CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE, &"detail": &"injected_query_failure"},
	]
	for item in cases:
		var rig := _make_fake_rig()
		rig.query.mode = item[&"mode"]
		if rig.query.mode == &"invalid":
			rig.services.set_projectile_source(null)
		var events := _connect_success_counters(rig.executor)
		var result := rig.executor.try_cast(rig.skill, SkillSlotIds.ACTIVE_1)
		_expect(not result.accepted, "%s rejects" % rig.query.mode)
		_expect_eq(result.reject_reason, item[&"reason"], "%s typed reason" % rig.query.mode)
		_expect_eq(result.detail, item[&"detail"], "%s structured detail" % rig.query.mode)
		_assert_rejection_unchanged(rig, events, "%s rejection" % rig.query.mode)
		_expect_eq(rig.prepare.prepare_count, 0, "%s creates no delivery" % rig.query.mode)
		rig.cleanup(self)


func _test_prepare_failure_matrix() -> void:
	var failed := _make_fake_rig()
	failed.prepare.fail_prepare = true
	var failed_events := _connect_success_counters(failed.executor)
	var failed_result := failed.executor.try_cast(failed.skill, SkillSlotIds.ACTIVE_1)
	_expect_eq(failed_result.reject_reason, CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE, "prepare failure typed rejection")
	_expect_eq(failed_result.detail, &"delivery_prepare_failed", "prepare failure detail")
	_assert_rejection_unchanged(failed, failed_events, "prepare failure")
	_expect_eq(failed.prepare.instantiate_count, 0, "prepare failure creates no node")
	failed.cleanup(self)

	var invalid_parent := _make_fake_rig()
	invalid_parent.detached_parent = Node2D.new()
	invalid_parent.prepare.parent = invalid_parent.detached_parent
	var invalid_events := _connect_success_counters(invalid_parent.executor)
	var invalid_result := invalid_parent.executor.try_cast(invalid_parent.skill, SkillSlotIds.ACTIVE_1)
	_expect_eq(invalid_result.reject_reason, CastAttemptResult.RejectReason.DELIVERY_UNAVAILABLE, "invalid parent typed rejection")
	_expect_eq(invalid_result.detail, &"prepared_delivery_parent_unavailable", "invalid parent detail")
	_assert_rejection_unchanged(invalid_parent, invalid_events, "invalid parent")
	_expect_eq(invalid_parent.prepare.instantiate_count, 1, "invalid parent only creates one off-tree candidate")
	_expect(invalid_parent.prepare.last_delivery == null or not is_instance_valid(invalid_parent.prepare.last_delivery), "invalid parent candidate is freed")
	invalid_parent.cleanup(self)


func _test_nested_cast_is_busy() -> void:
	var rig := _make_fake_rig()
	var observation := {&"nested": null}
	rig.executor.cast_started.connect(func(
			_cast: CastSnapshot,
			_payload: RuntimeAttackPayload
	) -> void:
		observation.nested = rig.executor.try_cast(rig.skill, SkillSlotIds.ACTIVE_1)
	)
	var result := rig.executor.try_cast(rig.skill, SkillSlotIds.ACTIVE_1)
	_expect(result.accepted, "outer Fury accepts")
	var nested := observation.nested as CastAttemptResult
	_expect(nested != null, "nested attempt is observed")
	_expect_eq(
		nested.reject_reason if nested != null else CastAttemptResult.RejectReason.NONE,
		CastAttemptResult.RejectReason.BUSY,
		"nested attempt is guarded"
	)
	_expect_eq(rig.prepare.instantiate_count, 1, "nested rejection adds no node")
	_expect_eq(rig.prepare.burst_count, 1, "outer cast still bursts once")
	rig.cleanup(self)


func _test_services_preserve_ports() -> void:
	var services := SkillExecutionServices.new()
	var query := FakeSweepPort.new()
	var parent := Node2D.new()
	var prepare := FakeDeliveryPreparePort.new(parent)
	var reclaim := DummyReclaimPort.new()
	services.set_projectile_sweep_query_port(query)
	services.set_skill_delivery_prepare_port(prepare)
	services.set_reclaim_port(reclaim)
	_expect(services.projectile_sweep_query_port == query, "reclaim update preserves query port")
	_expect(services.skill_delivery_prepare_port == prepare, "reclaim update preserves prepare port")
	var replacement := DummyReclaimPort.new()
	var copy := services.copy_with_reclaim_port(replacement)
	_expect(copy.reclaim_port == replacement, "copy replaces only reclaim port")
	_expect(copy.projectile_sweep_query_port == query, "copy preserves query port")
	_expect(copy.skill_delivery_prepare_port == prepare, "copy preserves prepare port")
	parent.free()


func _test_public_try_cast_scan() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	var controller_source := FileAccess.get_file_as_string("res://combat/components/skill_controller.gd")
	_expect(not player_source.contains("._try_cast_configured"), "Player has no private executor call")
	_expect(not controller_source.contains("._try_cast_configured"), "SkillController has no private executor call")
	_expect(player_source.contains("skill_executor.try_cast("), "Player basic attack uses public try_cast")
	_expect(controller_source.contains("_executor.try_cast("), "SkillController uses public try_cast")


func _test_formal_profile_shared() -> void:
	var projectile_scene := load("res://scenes/element_projectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate() as ProjectileDelivery
	var fury := CATALOG.gameplay_for(&"elemental_fury")
	var execution := fury.execution_definition as AllEnergyBurstExecution
	_expect(projectile.sweep_profile == PROFILE, "formal projectile references shared profile")
	_expect(execution.projectile_sweep_profile == PROFILE, "Fury references the same profile resource")
	_expect(PROFILE.shape is CircleShape2D, "profile shape is circular")
	_expect_float((PROFILE.shape as CircleShape2D).radius, 6.0, "profile radius is six")
	_expect_float(PROFILE.speed, 720.0, "profile speed is exact")
	_expect_float(PROFILE.max_distance, 850.0, "profile max distance is exact")
	_expect_eq(PROFILE.hurtbox_collision_mask, 8, "profile hurtbox mask is exact")
	_expect_eq(PROFILE.blocking_collision_mask, 4, "profile blocker mask is exact")
	_expect_float(PROFILE.query_margin, 0.01, "profile margin is exact")
	_expect_float(PROFILE.wall_tie_distance, 0.02, "profile wall tie is exact")
	projectile.free()


func _test_real_query_ordering() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var source := Node2D.new()
	host.add_child(source)
	var first := _make_target(host, Vector2(100.0, 0.0), &"enemy")
	var second := _make_target(host, Vector2(100.0, 0.0), &"enemy")
	var wall := _make_wall(host, Vector2(100.0, 0.0))
	await physics_frame
	var adapter := PhysicsProjectileSweepQuery2D.new()
	adapter.set_metrics_enabled(true)
	var request := ProjectileSweepRequest2D.new(
		source, source.get_world_2d(), source.global_transform, Vector2.RIGHT,
		PROFILE.max_distance, PROFILE, &"player", true
	)
	var blocked := adapter.query_first_contact(request)
	_expect_eq(blocked.status, ProjectileSweepResult2D.Status.BLOCKER_CONTACT, "equal-distance wall wins")
	wall.free()
	await physics_frame
	var enemy := adapter.query_first_contact(request)
	_expect_eq(enemy.status, ProjectileSweepResult2D.Status.ENEMY_CONTACT, "enemy is selected after wall removal")
	_expect_eq(enemy.receiver.get_instance_id(), mini(first.receiver.get_instance_id(), second.receiver.get_instance_id()), "equal-distance enemies use stable receiver id")
	var metrics := adapter.metrics_snapshot()
	_expect_eq(metrics.parameter_build_count, 4, "adapter builds four bounded role scratch objects")
	_expect_eq(metrics.scratch_parameter_count, 4, "adapter retains at most four private scratch objects")
	adapter.release_scratch()
	_expect_eq(adapter.metrics_snapshot().scratch_parameter_count, 0, "adapter releases scratch explicitly")
	current_scene = null
	host.free()


func _test_retained_results() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var source := Node2D.new()
	host.add_child(source)
	var target := _make_target(host, Vector2(100.0, 0.0), &"enemy")
	var wall := _make_wall(host, Vector2(100.0, 0.0))
	await physics_frame
	var adapter := SwitchableFailingPhysicsSweepPort.new()
	adapter.set_metrics_enabled(true)
	var request := ProjectileSweepRequest2D.new(
		source, source.get_world_2d(), source.global_transform, Vector2.RIGHT,
		PROFILE.max_distance, PROFILE, &"player", true
	)
	var retained_blocker := adapter.query_first_contact(request)
	var blocker_values := [
		retained_blocker.status,
		retained_blocker.point,
		retained_blocker.fraction,
		retained_blocker.distance,
		retained_blocker.hurtbox,
		retained_blocker.receiver,
		retained_blocker.stable_id,
		retained_blocker.detail,
	]
	wall.free()
	await physics_frame
	var retained_enemy := adapter.query_first_contact(request)
	_expect(retained_blocker != retained_enemy, "public queries return distinct Result objects")
	_expect_eq(retained_blocker.status, blocker_values[0], "retained blocker status is stable")
	_expect_eq(retained_blocker.point, blocker_values[1], "retained blocker point is stable")
	_expect_eq(retained_blocker.fraction, blocker_values[2], "retained blocker fraction is stable")
	_expect_eq(retained_blocker.distance, blocker_values[3], "retained blocker distance is stable")
	_expect_eq(retained_blocker.hurtbox, blocker_values[4], "retained blocker hurtbox is stable")
	_expect_eq(retained_blocker.receiver, blocker_values[5], "retained blocker receiver is stable")
	_expect_eq(retained_blocker.stable_id, blocker_values[6], "retained blocker stable id is stable")
	_expect_eq(retained_blocker.detail, blocker_values[7], "retained blocker detail is stable")
	_expect_eq(retained_enemy.status, ProjectileSweepResult2D.Status.ENEMY_CONTACT, "second query reaches enemy")
	_expect(retained_enemy.receiver == target.receiver, "enemy result owns the selected receiver")
	var enemy_values := [
		retained_enemy.status,
		retained_enemy.point,
		retained_enemy.fraction,
		retained_enemy.distance,
		retained_enemy.hurtbox,
		retained_enemy.receiver,
		retained_enemy.stable_id,
		retained_enemy.detail,
	]
	var miss_request := ProjectileSweepRequest2D.new(
		source, source.get_world_2d(), source.global_transform, Vector2.LEFT,
		PROFILE.max_distance, PROFILE, &"player", true
	)
	var no_contact := adapter.query_first_contact(miss_request)
	_assert_contactless_result(
		no_contact, ProjectileSweepResult2D.Status.NO_CONTACT, &"", "enemy then no-contact"
	)
	var invalid := adapter.query_first_contact(null)
	_assert_contactless_result(
		invalid,
		ProjectileSweepResult2D.Status.INVALID_CONTEXT,
		&"missing_sweep_request",
		"enemy then invalid"
	)
	adapter.fail_queries = true
	var failed := adapter.query_first_contact(request)
	_assert_contactless_result(
		failed,
		ProjectileSweepResult2D.Status.QUERY_FAILED,
		&"physics_sweep_query_failed",
		"enemy then query-failed"
	)
	_expect_eq(retained_enemy.status, enemy_values[0], "retained enemy status is stable")
	_expect_eq(retained_enemy.point, enemy_values[1], "retained enemy point is stable")
	_expect_eq(retained_enemy.fraction, enemy_values[2], "retained enemy fraction is stable")
	_expect_eq(retained_enemy.distance, enemy_values[3], "retained enemy distance is stable")
	_expect_eq(retained_enemy.hurtbox, enemy_values[4], "retained enemy hurtbox is stable")
	_expect_eq(retained_enemy.receiver, enemy_values[5], "retained enemy receiver is stable")
	_expect_eq(retained_enemy.stable_id, enemy_values[6], "retained enemy stable id is stable")
	_expect_eq(retained_enemy.detail, enemy_values[7], "retained enemy detail is stable")
	var result_source := FileAccess.get_file_as_string(
		"res://combat/contracts/projectile_sweep_result_2d.gd"
	)
	_expect(not result_source.contains("func set_enemy_contact"), "public Result has no mutable enemy setter")
	_expect(not result_source.contains("func set_no_contact"), "public Result has no mutable contactless setter")
	_expect(not result_source.contains("\n\tset:"), "public Result properties are getter-only")
	adapter.release_scratch()
	current_scene = null
	host.free()


func _assert_contactless_result(
		result: ProjectileSweepResult2D,
		expected_status: ProjectileSweepResult2D.Status,
		expected_detail: StringName,
		label: String
) -> void:
	_expect_eq(result.status, expected_status, label + " status")
	_expect_eq(result.point, Vector2.ZERO, label + " clears point")
	_expect_float(result.fraction, 1.0, label + " resets fraction")
	_expect_float(result.distance, 0.0, label + " resets distance")
	_expect(result.hurtbox == null, label + " clears hurtbox")
	_expect(result.receiver == null, label + " clears receiver")
	_expect_eq(result.stable_id, 0, label + " clears stable id")
	_expect_eq(result.detail, expected_detail, label + " keeps only legal detail")


func _test_projectile_legacy_semantics() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var friendly := _make_target(host, Vector2(50.0, 0.0), &"player")
	await physics_frame
	var projectile := _make_projectile(host)
	var observation := {&"reason": StringName(), &"metrics": {}}
	projectile.delivery_finished.connect(func(value: StringName) -> void:
		observation.reason = value
		observation.metrics = projectile.sweep_metrics_snapshot()
	)
	projectile.advance(1.0)
	_expect_eq(observation.reason, DeliveryBase.FINISH_HIT, "friendly receiver contact keeps legacy projectile finish")
	_expect_eq(friendly.damage.current_health, 1000, "friendly receiver still rejects damage")
	var captured_metrics: Dictionary = observation.metrics
	_expect_eq(captured_metrics.get(&"parameter_build_count", -1), 4, "one projectile constructs four bounded query parameters")
	_expect_eq(captured_metrics.get(&"scratch_parameter_count", -1), 4, "role scratch exists until cleanup boundary")
	_expect_eq(projectile.sweep_metrics_snapshot().scratch_parameter_count, 0, "finish cleanup releases scratch")
	_expect_float(projectile.distance_travelled, 0.0, "finish cleanup resets distance")
	host.remove_child(projectile)
	_expect(projectile.prepare_for_reuse(), "finished projectile prepares for reuse")
	_expect(projectile.initialize_delivery(
		_cast_snapshot(2), _payload(), 2, Transform2D.IDENTITY, Vector2.RIGHT
	), "reused projectile initializes again")
	host.add_child(projectile)
	projectile.set_physics_process(false)
	var reuse_observation := {&"metrics": {}}
	projectile.delivery_finished.connect(func(_value: StringName) -> void:
		reuse_observation.metrics = projectile.sweep_metrics_snapshot()
	)
	projectile.advance(1.0)
	var reused_metrics: Dictionary = reuse_observation.metrics
	_expect_eq(reused_metrics.get(&"parameter_build_count", -1), 4, "reused run owns fresh bounded scratch")
	_expect_eq(projectile.sweep_metrics_snapshot().scratch_parameter_count, 0, "reused cleanup leaves no scratch")
	projectile.free()

	var wall := _make_wall(host, Vector2(45.0, 40.0))
	await physics_frame
	var blocked_projectile := _make_projectile(host, Vector2(0.0, 40.0))
	var order: Array[StringName] = []
	blocked_projectile.blocker_contact.connect(func(_point: Vector2) -> void:
		order.append(&"blocker")
	)
	blocked_projectile.delivery_finished.connect(func(_value: StringName) -> void:
		order.append(&"finished")
	)
	blocked_projectile.advance(1.0)
	_expect_eq(order, [&"blocker", &"finished"], "blocker signal still precedes finish")
	wall.free()

	var frame_target := _make_target(host, Vector2(90.0, 80.0), &"player")
	await physics_frame
	var frame_projectile := _make_projectile(host, Vector2(0.0, 80.0), 30.0)
	var frame_reason := {&"value": StringName()}
	frame_projectile.delivery_finished.connect(func(value: StringName) -> void:
		frame_reason.value = value
	)
	frame_projectile.advance(1.0)
	await physics_frame
	frame_projectile.advance(1.0)
	await physics_frame
	frame_projectile.advance(1.0)
	_expect_eq(frame_reason.value, DeliveryBase.FINISH_HIT, "cached space state remains valid across physics frames")
	_expect_eq(frame_target.damage.current_health, 1000, "cross-frame friendly contact keeps legacy rejection")
	frame_projectile.free()
	current_scene = null
	host.free()


func _test_real_fury_transaction() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var source := Node2D.new()
	source.name = "Caster"
	host.add_child(source)
	var target := _make_target(host, Vector2(120.0, 0.0), &"enemy", true)
	var energy := EnergyComponent.new()
	energy.configure_runtime(100, 20)
	energy.set_process(false)
	host.add_child(energy)
	var element := CurrentElementController.new()
	element.configure_runtime(ElementIds.WATER, [ElementIds.WATER, ElementIds.FIRE])
	host.add_child(element)
	var executor := SkillExecutor.new()
	executor.configure_dependencies(energy, element, host)
	executor.configure_cast_identity(9001, 9002, &"player")
	executor.set_spawn_snapshot_provider(func(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
		return DeliverySpawnSnapshot.new(source.global_transform, Vector2.RIGHT)
	)
	host.add_child(executor)
	executor.set_process(false)
	var physics_query := PhysicsProjectileSweepQuery2D.new()
	physics_query.set_metrics_enabled(true)
	var delivery_adapter := CombatSkillDeliveryAdapter.new(source, CATALOG)
	var services := SkillExecutionServices.new(null, physics_query, delivery_adapter, source)
	executor.set_execution_services(services)
	var observations := {&"deliveries": 0, &"bursts": 0, &"origin": Vector2.ZERO, &"radius": 0.0, &"targets": -1}
	executor.delivery_spawned.connect(func(
			_cast_id: int,
			_delivery_id: int,
			delivery: DeliveryBase
	) -> void:
		observations.deliveries += 1
		if delivery is ElementRageDelivery:
			delivery.burst_submitted.connect(func(origin: Vector2, radius: float, count: int) -> void:
				observations.bursts += 1
				observations.origin = origin
				observations.radius = radius
				observations.targets = count
			)
	)
	await physics_frame
	await physics_frame
	var result := executor.try_cast(CATALOG.gameplay_for(&"elemental_fury"), SkillSlotIds.ACTIVE_1)
	_expect(result.accepted, "real enemy-first Fury accepts")
	_expect_eq(energy.current_energy, 0, "real Fury spends all SP")
	_expect_eq(observations.deliveries, 1, "real Fury creates one burst Delivery")
	_expect_eq(observations.bursts, 1, "real Fury opens one burst window")
	_expect_eq(observations.targets, 1, "real Fury burst reaches legal contacted enemy")
	_expect_float(observations.radius, 115.2, "real Fury radius remains base times scale")
	var snapshot := result.execution_snapshot as AllEnergyBurstExecutionSnapshot
	_expect(
		snapshot != null and observations.origin.is_equal_approx(snapshot.impact_position),
		"burst origin equals locked contact point"
	)
	_expect_eq(target.damage.current_health, 984, "real Fury keeps sixteen minimum damage")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 1, "real Fury keeps one water attachment")
	var hidden_projectiles := 0
	for node in host.find_children("*", "ProjectileDelivery", true, false):
		if node is ProjectileDelivery:
			hidden_projectiles += 1
	_expect_eq(hidden_projectiles, 0, "Fury creates no flying projectile Node")
	var query_metrics := physics_query.metrics_snapshot()
	_expect_eq(query_metrics.parameter_build_count, 4, "Fury query reuses four bounded service scratch parameters")
	var delivery_metrics := delivery_adapter.metrics_snapshot()
	_expect_eq(delivery_metrics.node_instantiate_count, 1, "real success instantiates one node")
	_expect_eq(delivery_metrics.node_add_count, 1, "real success adds one node")
	_expect_eq(delivery_metrics.prepare_reject_count, 0, "real success has no prepare rejection")
	current_scene = null
	host.free()


func _make_fake_rig() -> FuryRig:
	var rig := FuryRig.new()
	rig.host = Node2D.new()
	rig.host.name = "Task34FakeRig"
	rig.source = Node2D.new()
	rig.source.name = "Caster"
	rig.host.add_child(rig.source)
	rig.energy = EnergyComponent.new()
	rig.energy.configure_runtime(100, 20)
	rig.energy.set_process(false)
	rig.host.add_child(rig.energy)
	rig.element = CurrentElementController.new()
	rig.element.configure_runtime(ElementIds.WATER, [ElementIds.WATER, ElementIds.FIRE])
	rig.host.add_child(rig.element)
	rig.executor = SkillExecutor.new()
	rig.executor.configure_dependencies(rig.energy, rig.element, rig.host)
	rig.executor.configure_cast_identity(7001, 7002, &"player")
	rig.executor.set_spawn_snapshot_provider(func(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
		return DeliverySpawnSnapshot.new(rig.source.global_transform, Vector2.RIGHT)
	)
	rig.host.add_child(rig.executor)
	root.add_child(rig.host)
	rig.executor.set_process(false)
	rig.query = FakeSweepPort.new()
	rig.prepare = FakeDeliveryPreparePort.new(rig.host)
	rig.services = SkillExecutionServices.new(null, rig.query, rig.prepare, rig.source)
	rig.executor.set_execution_services(rig.services)
	var execution := AllEnergyBurstExecution.new()
	execution.projectile_sweep_profile = PROFILE
	rig.skill = SkillDefinition.new()
	rig.skill.skill_id = &"task34_fury"
	rig.skill.cooldown = 3.0
	rig.skill.execution_definition = execution
	return rig


func _connect_success_counters(executor: SkillExecutor) -> Dictionary:
	var events := {&"cast_started": 0, &"execution_started": 0, &"execution_activated": 0, &"delivery_spawned": 0, &"phase_changed": 0}
	executor.cast_started.connect(func(_cast: CastSnapshot, _payload_value: RuntimeAttackPayload) -> void:
		events.cast_started += 1
	)
	executor.execution_started.connect(func(_snapshot: SkillExecutionSnapshot) -> void:
		events.execution_started += 1
	)
	executor.execution_activated.connect(func(_snapshot: SkillExecutionSnapshot) -> void:
		events.execution_activated += 1
	)
	executor.delivery_spawned.connect(func(_cast_id: int, _delivery_id: int, _delivery: DeliveryBase) -> void:
		events.delivery_spawned += 1
	)
	executor.phase_changed.connect(func(_cast_id: int, _previous: SkillExecutor.Phase, _current: SkillExecutor.Phase) -> void:
		events.phase_changed += 1
	)
	return events


func _assert_rejection_unchanged(rig: FuryRig, events: Dictionary, label: String) -> void:
	_expect_eq(rig.energy.current_energy, 20, label + " preserves SP")
	_expect_eq(rig.element.current_element_id, ElementIds.WATER, label + " preserves element")
	_expect_float(rig.executor.get_cooldown_remaining(rig.skill.skill_id), 0.0, label + " starts no cooldown")
	_expect_eq(rig.executor.current_phase, SkillExecutor.Phase.IDLE, label + " preserves idle phase")
	_expect_eq(events.cast_started, 0, label + " emits no cast_started")
	_expect_eq(events.execution_started, 0, label + " emits no execution_started")
	_expect_eq(events.execution_activated, 0, label + " emits no execution_activated")
	_expect_eq(events.delivery_spawned, 0, label + " emits no delivery_spawned")
	_expect_eq(events.phase_changed, 0, label + " emits no phase event")
	var rage_count := 0
	for child in rig.host.get_children():
		if child is ElementRageDelivery:
			rage_count += 1
	_expect_eq(rage_count, 0, label + " leaves no burst node")


func _make_target(
		parent: Node2D,
		position: Vector2,
		team_id: StringName,
		with_carrier: bool = false
) -> Dictionary:
	var host := Node2D.new()
	host.position = position
	var receiver := CombatReceiver.new()
	receiver.target_team_id = team_id
	var damage := DamageReceiver.new()
	damage.configure_runtime(1000, 1000)
	receiver.add_child(damage)
	var carrier: ElementCarrier
	if with_carrier:
		carrier = ElementCarrier.new()
		receiver.add_child(carrier)
	receiver.configure_components(carrier, damage)
	host.add_child(receiver)
	var hurtbox := CombatHurtbox.new()
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.configure_receiver(receiver)
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4.0, 24.0)
	collision_shape.shape = rectangle
	hurtbox.add_child(collision_shape)
	host.add_child(hurtbox)
	parent.add_child(host)
	return {&"host": host, &"receiver": receiver, &"damage": damage, &"carrier": carrier, &"hurtbox": hurtbox}


func _make_wall(parent: Node2D, position: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = 4
	wall.collision_mask = 0
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4.0, 40.0)
	collision_shape.shape = rectangle
	wall.add_child(collision_shape)
	parent.add_child(wall)
	return wall


func _make_projectile(
		parent: Node2D,
		origin: Vector2 = Vector2.ZERO,
		speed_value: float = 100.0
) -> ProjectileDelivery:
	var projectile := ProjectileDelivery.new()
	projectile.queue_free_on_finish = false
	var shape := CircleShape2D.new()
	shape.radius = 2.0
	projectile.projectile_shape = shape
	projectile.speed = speed_value
	projectile.max_distance = 100.0
	projectile.hurtbox_collision_mask = 8
	projectile.blocking_collision_mask = 4
	projectile.query_margin = 0.01
	projectile.wall_tie_distance = 0.02
	_expect(projectile.set_sweep_metrics_enabled(true), "projectile enables real sweep metrics")
	_expect(projectile.initialize_delivery(
		_cast_snapshot(1), _payload(), 1, Transform2D(0.0, origin), Vector2.RIGHT
	), "projectile initializes")
	parent.add_child(projectile)
	projectile.set_physics_process(false)
	return projectile


func _cast_snapshot(cast_id: int) -> CastSnapshot:
	return CastSnapshot.new(
		cast_id, &"task34_projectile", 1001, 1002, &"player",
		ElementIds.WATER, CombatStatSnapshot.new()
	)


func _payload() -> RuntimeAttackPayload:
	return RuntimeAttackPayload.new(1.0, 1.0, ElementIds.WATER, 1)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (expected %.6f, got %.6f)" % [message, expected, actual])
