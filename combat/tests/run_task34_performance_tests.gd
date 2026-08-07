extends SceneTree

## Dual-compatible perf_projectile_cast_v1 runner. This file deliberately has
## no static references to Task34-only classes so the exact bytes parse on HEAD.

const SEED: int = 4107
const PROJECTILE_COUNT: int = 200
const PROJECTILE_STEPS: int = 60
const FURY_CASE_ITERATIONS: int = 1000

var _sample: int = 0
var _phase: String = "measured"
var _fixture: String = "projectile"


func _initialize() -> void:
	_parse_arguments()
	call_deferred(&"_run")


func _run() -> void:
	var report: Dictionary
	if _fixture == "fury":
		report = await _run_fury_atomic_batch()
	else:
		report = await _run_projectile_step_reuse()
	report["runner"] = "perf_projectile_cast_v1"
	report["seed"] = SEED
	report["phase"] = _phase
	report["sample"] = _sample
	report["fixture"] = _fixture
	print("TASK34_PERF_JSON=" + JSON.stringify(report))
	quit(0 if bool(report.get("valid", false)) else 2)


func _run_projectile_step_reuse() -> Dictionary:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var targets: Array[Dictionary] = []
	for index in PROJECTILE_COUNT:
		targets.append(_make_target(world, Vector2(600.0, float(index) * 32.0)))
	await physics_frame

	var projectiles: Array[ProjectileDelivery] = []
	var reports: Array[Dictionary] = []
	for index in PROJECTILE_COUNT:
		var projectile := ProjectileDelivery.new()
		projectile.queue_free_on_finish = false
		var shape := CircleShape2D.new()
		shape.radius = 2.0
		projectile.projectile_shape = shape
		projectile.speed = 10.0
		projectile.max_distance = 600.0
		projectile.hurtbox_collision_mask = 8
		projectile.blocking_collision_mask = 4
		projectile.query_margin = 0.01
		projectile.wall_tie_distance = 0.02
		var initialized := projectile.initialize_delivery(
			_cast_snapshot(index + 1),
			RuntimeAttackPayload.new(1.0, 1.0, ElementIds.WATER, 1),
			index + 1,
			Transform2D(0.0, Vector2(0.0, float(index) * 32.0)),
			Vector2.RIGHT
		)
		if not initialized:
			return {"valid": false, "error": "projectile_initialization_failed"}
		var item := {
			"reason": StringName(),
			"distance": 0.0,
			"metrics": {},
		}
		projectile.delivery_finished.connect(func(reason: StringName) -> void:
			item.reason = reason
			item.distance = projectile.distance_travelled
			if projectile.has_method("sweep_metrics_snapshot"):
				item.metrics = projectile.call("sweep_metrics_snapshot")
		)
		world.add_child(projectile)
		projectile.set_physics_process(false)
		projectiles.append(projectile)
		reports.append(item)

	var order: Array[int] = []
	for index in PROJECTILE_COUNT:
		order.append(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index in range(order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := order[index]
		order[index] = order[swap_index]
		order[swap_index] = held

	var started := Time.get_ticks_usec()
	for _step in PROJECTILE_STEPS:
		for index in order:
			projectiles[index].advance(1.0)
	var elapsed_usec := Time.get_ticks_usec() - started

	var totals := _empty_query_metrics()
	var trace_parts: PackedStringArray = PackedStringArray()
	var valid := true
	var hit_count := 0
	var health_match_count := 0
	var reason_counts: Dictionary = {}
	var after_api := projectiles[0].has_method("sweep_metrics_snapshot")
	for index in PROJECTILE_COUNT:
		var item: Dictionary = reports[index]
		var target: Dictionary = targets[index]
		var reason_key := str(item.reason)
		reason_counts[reason_key] = int(reason_counts.get(reason_key, 0)) + 1
		if item.reason == DeliveryBase.FINISH_HIT:
			hit_count += 1
		if target.damage.current_health == 999999:
			health_match_count += 1
		valid = valid and item.reason == DeliveryBase.FINISH_HIT
		valid = valid and target.damage.current_health == 999999
		trace_parts.append("%d:%s:%.6f:%d" % [
			index,
			str(item.reason),
			float(item.distance),
			int(target.damage.current_health),
		])
	if after_api:
		valid = valid and _replay_projectile_metrics(projectiles, reports, world)
		for item in reports:
			_add_metrics(totals, item.metrics)
	else:
		for _index in PROJECTILE_COUNT:
			# HEAD creates one initial parameter per nonzero mask and one extra
			# contact probe parameter for the terminal hurtbox sweep.
			totals.parameter_build_count += PROJECTILE_STEPS * 2 + 1
			totals.intersect_shape_count += PROJECTILE_STEPS * 2 + 1
			totals.cast_motion_count += PROJECTILE_STEPS * 2
			totals.rest_info_count += 1
			totals.probe_count += 1
			totals.candidate_scan_count += 1
			totals.query_calls += PROJECTILE_STEPS
	var expected_parameter_builds := (
		PROJECTILE_COUNT * 4
		if after_api
		else PROJECTILE_COUNT * (PROJECTILE_STEPS * 2 + 1)
	)
	valid = (
		valid
		and int(totals.query_calls) == PROJECTILE_COUNT * PROJECTILE_STEPS
		and int(totals.intersect_shape_count) == PROJECTILE_COUNT * PROJECTILE_STEPS * 2 + hit_count
		and int(totals.cast_motion_count) == PROJECTILE_COUNT * PROJECTILE_STEPS * 2
		and int(totals.rest_info_count) == hit_count
		and int(totals.probe_count) == hit_count
		and int(totals.candidate_scan_count) == hit_count
		and int(totals.sort_comparison_count) == 0
		and int(totals.parameter_build_count) == expected_parameter_builds
	)
	var trace := "|".join(trace_parts)
	return {
		"valid": valid,
		"implementation": "after_scratch" if after_api else "before_head",
		"counter_source": "adapter_instrumentation_replay" if after_api else "legacy_code_formula",
		"projectile_count": PROJECTILE_COUNT,
		"steps_per_projectile": PROJECTILE_STEPS,
		"total_steps": PROJECTILE_COUNT * PROJECTILE_STEPS,
		"elapsed_usec": elapsed_usec,
		"trace_sha256": trace.sha256_text(),
		"trace_terminal_hits": hit_count,
		"health_match_count": health_match_count,
		"reason_counts": reason_counts,
		"node_instantiate_count": PROJECTILE_COUNT,
		"node_add_count": PROJECTILE_COUNT,
		"node_free_count_in_measurement": 0,
		"metrics": totals,
	}


func _run_fury_atomic_batch() -> Dictionary:
	var request_path := "res://combat/contracts/projectile_sweep_request_2d.gd"
	var query_path := "res://combat/targeting/physics_projectile_sweep_query_2d.gd"
	var adapter_path := "res://scripts/combat_skill_delivery_adapter.gd"
	if (
		not FileAccess.file_exists(request_path)
		or not FileAccess.file_exists(query_path)
		or not FileAccess.file_exists(adapter_path)
	):
		return {
			"valid": true,
			"implementation": "before_head",
			"supported": false,
			"elapsed_usec": 0,
			"trace_sha256": "unsupported_before_head".sha256_text(),
		}

	var profile: Resource = load("res://resources/combat/element_projectile_sweep_profile.tres")
	var catalog: Resource = load("res://resources/content/run_content_catalog.tres")
	var request_script: Script = load(request_path)
	var query_script: Script = load(query_path)
	var adapter_script: Script = load(adapter_path)
	var snapshot_script: Script = load("res://combat/execution/all_energy_burst_execution_snapshot.gd")
	if profile == null or catalog == null or request_script == null or query_script == null or adapter_script == null:
		return {"valid": false, "error": "task34_dynamic_contract_load_failed"}

	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var sources: Array[Node2D] = []
	for index in 4:
		var source := Node2D.new()
		source.position = Vector2(0.0, float(index) * 300.0)
		world.add_child(source)
		sources.append(source)
	_make_target(world, Vector2(100.0, 0.0))
	_make_target(world, Vector2(200.0, 300.0))
	_make_wall(world, Vector2(100.0, 300.0))
	var tie_first := _make_target(world, Vector2(100.0, 900.0))
	_make_target(world, Vector2(100.0, 900.0))
	await physics_frame

	var query: Variant = query_script.new()
	query.call("set_metrics_enabled", true)
	var delivery_adapter: Variant = adapter_script.new(sources[0], catalog)
	var requests: Array[Variant] = []
	for source in sources:
		requests.append(request_script.new(
			source,
			source.get_world_2d(),
			source.global_transform,
			Vector2.RIGHT,
			float(profile.get("max_distance")),
			profile,
			&"player",
			true
		))
	var pre_enemy: Variant = query.call("query_first_contact", requests[0])
	var pre_tie: Variant = query.call("query_first_contact", requests[3])
	var payload := RuntimeAttackPayload.new(10.0, 16.0, ElementIds.WATER, 1)
	var enemy_snapshot: Variant = snapshot_script.new(
		_cast_snapshot(5001, &"elemental_fury"), 20, 100,
		SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT,
		payload, 1.2, pre_enemy.get("point")
	)
	var tie_snapshot: Variant = snapshot_script.new(
		_cast_snapshot(5002, &"elemental_fury"), 20, 100,
		SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT,
		payload, 1.2, pre_tie.get("point")
	)
	var enemy_transform := sources[0].global_transform
	enemy_transform.origin = pre_enemy.get("point")
	var tie_transform := sources[3].global_transform
	tie_transform.origin = pre_tie.get("point")
	var spawns: Array[DeliverySpawnSnapshot] = [
		DeliverySpawnSnapshot.new(enemy_transform, Vector2.RIGHT),
		DeliverySpawnSnapshot.new(tie_transform, Vector2.RIGHT),
	]
	query.call("release_scratch")
	query.call("reset_metrics")
	delivery_adapter.call("reset_metrics")

	var counts := {"enemy": 0, "blocker": 0, "miss": 0, "invalid": 0, "failed": 0}
	var transactions := 0
	var rejected_delivery_count := 0
	var tie_stable := true
	var started := Time.get_ticks_usec()
	for _iteration in FURY_CASE_ITERATIONS:
		for case_index in 4:
			var result: Variant = query.call("query_first_contact", requests[case_index])
			var status := int(result.get("status"))
			if status == 0:
				counts.enemy += 1
				if case_index == 3:
					tie_stable = tie_stable and result.get("receiver") == tie_first.receiver
				var snapshot: Variant = enemy_snapshot if case_index == 0 else tie_snapshot
				var spawn: DeliverySpawnSnapshot = spawns[0] if case_index == 0 else spawns[1]
				var transaction: Variant = delivery_adapter.call("prepare", snapshot, spawn)
				if transaction == null:
					return {"valid": false, "error": "fury_prepare_failed"}
				transactions += 1
				transaction.call("commit_silent")
				transaction.call("publish_committed")
				if not bool(transaction.call("activate_prepared_delivery")):
					return {"valid": false, "error": "fury_activation_failed"}
				var delivery: Variant = transaction.get("prepared_delivery")
				if is_instance_valid(delivery):
					delivery.free()
			elif status == 1:
				counts.blocker += 1
				rejected_delivery_count += _count_rage_children(world)
			elif status == 2:
				counts.miss += 1
				rejected_delivery_count += _count_rage_children(world)
			elif status == 3:
				counts.invalid += 1
			else:
				counts.failed += 1
	var elapsed_usec := Time.get_ticks_usec() - started
	var query_metrics: Dictionary = query.call("metrics_snapshot")
	var delivery_metrics: Dictionary = delivery_adapter.call("metrics_snapshot")
	var trace := "%s|%s|%d|%s" % [
		JSON.stringify(counts),
		JSON.stringify(query_metrics),
		transactions,
		str(tie_stable),
	]
	var valid: bool = (
		counts.enemy == FURY_CASE_ITERATIONS * 2
		and counts.blocker == FURY_CASE_ITERATIONS
		and counts.miss == FURY_CASE_ITERATIONS
		and transactions == FURY_CASE_ITERATIONS * 2
		and rejected_delivery_count == 0
		and tie_stable
		and int(delivery_metrics.get("node_instantiate_count", -1)) == transactions
		and int(delivery_metrics.get("node_add_count", -1)) == transactions
		and int(query_metrics.get("query_calls", -1)) == FURY_CASE_ITERATIONS * 4
		and int(query_metrics.get("parameter_build_count", -1)) == 4
		and int(query_metrics.get("intersect_shape_count", -1)) == FURY_CASE_ITERATIONS * 12
		and int(query_metrics.get("cast_motion_count", -1)) == FURY_CASE_ITERATIONS * 8
		and int(query_metrics.get("rest_info_count", -1)) == FURY_CASE_ITERATIONS * 4
		and int(query_metrics.get("probe_count", -1)) == FURY_CASE_ITERATIONS * 4
		and int(query_metrics.get("candidate_scan_count", -1)) == FURY_CASE_ITERATIONS * 5
		and int(query_metrics.get("sort_comparison_count", -1)) == FURY_CASE_ITERATIONS
	)
	return {
		"valid": valid,
		"implementation": "after_transaction",
		"supported": true,
		"case_iterations": FURY_CASE_ITERATIONS,
		"total_queries": FURY_CASE_ITERATIONS * 4,
		"elapsed_usec": elapsed_usec,
		"trace_sha256": trace.sha256_text(),
		"status_counts": counts,
		"transaction_count": transactions,
		"rejected_delivery_count": rejected_delivery_count,
		"tie_stable": tie_stable,
		"query_metrics": query_metrics,
		"delivery_metrics": delivery_metrics,
	}


func _empty_query_metrics() -> Dictionary:
	return {
		"query_calls": 0,
		"parameter_build_count": 0,
		"intersect_shape_count": 0,
		"cast_motion_count": 0,
		"rest_info_count": 0,
		"probe_count": 0,
		"candidate_scan_count": 0,
		"sort_comparison_count": 0,
		"scratch_parameter_count": 0,
	}


func _replay_projectile_metrics(
		projectiles: Array[ProjectileDelivery],
		reports: Array[Dictionary],
		world: Node2D
) -> bool:
	for index in PROJECTILE_COUNT:
		var projectile := projectiles[index]
		world.remove_child(projectile)
		if not projectile.prepare_for_reuse():
			return false
		if not bool(projectile.call("set_sweep_metrics_enabled", true)):
			return false
		var item: Dictionary = reports[index]
		item.reason = StringName()
		item.distance = 0.0
		item.metrics = {}
		projectile.delivery_finished.connect(func(reason: StringName) -> void:
			item.reason = reason
			item.distance = projectile.distance_travelled
			item.metrics = projectile.call("sweep_metrics_snapshot")
		)
		if not projectile.initialize_delivery(
			_cast_snapshot(10000 + index),
			RuntimeAttackPayload.new(1.0, 1.0, ElementIds.WATER, 1),
			10000 + index,
			Transform2D(0.0, Vector2(0.0, float(index) * 32.0)),
			Vector2.RIGHT
		):
			return false
		world.add_child(projectile)
		projectile.set_physics_process(false)
	for _step in PROJECTILE_STEPS:
		for projectile in projectiles:
			projectile.advance(1.0)
	return true


func _add_metrics(total: Dictionary, item: Dictionary) -> void:
	for key in total.keys():
		if key == "scratch_parameter_count":
			total[key] += int(item.get(key, 0))
		else:
			total[key] += int(item.get(key, 0))


func _make_target(parent: Node2D, position: Vector2) -> Dictionary:
	var host := Node2D.new()
	host.position = position
	var receiver := CombatReceiver.new()
	receiver.target_team_id = &"enemy"
	var damage := DamageReceiver.new()
	damage.configure_runtime(1000000, 1000000)
	receiver.add_child(damage)
	receiver.configure_components(null, damage)
	host.add_child(receiver)
	var hurtbox := CombatHurtbox.new()
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.configure_receiver(receiver)
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4.0, 20.0)
	collision_shape.shape = rectangle
	hurtbox.add_child(collision_shape)
	host.add_child(hurtbox)
	parent.add_child(host)
	return {"receiver": receiver, "damage": damage, "hurtbox": hurtbox}


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


func _count_rage_children(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("element_rage_delivery.gd"):
			count += 1
	return count


func _cast_snapshot(
		cast_id: int,
		skill_id: StringName = &"task34_perf_fury"
) -> CastSnapshot:
	return CastSnapshot.new(
		cast_id,
		skill_id,
		8001,
		8002,
		&"player",
		ElementIds.WATER,
		CombatStatSnapshot.new()
	)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sample="):
			_sample = int(argument.trim_prefix("--sample="))
		elif argument.begins_with("--phase="):
			_phase = argument.trim_prefix("--phase=")
		elif argument.begins_with("--fixture="):
			_fixture = argument.trim_prefix("--fixture=")
