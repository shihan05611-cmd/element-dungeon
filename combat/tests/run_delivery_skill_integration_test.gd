extends SceneTree

## One focused Agent B -> Agent C protocol smoke test using the production
## ProjectileDelivery PackedScene.

const PROJECTILE_SCENE: PackedScene = preload("res://combat/delivery/projectile_delivery.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var delivery_parent := Node2D.new()
	root.add_child(delivery_parent)

	var target := Node2D.new()
	target.position = Vector2(40.0, 0.0)
	var receiver := CombatReceiver.new()
	var damage := DamageReceiver.new()
	damage.configure_runtime(100, 100)
	receiver.add_child(damage)
	receiver.configure_components(null, damage)
	target.add_child(receiver)
	var hurtbox := CombatHurtbox.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.configure_receiver(receiver)
	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4.0, 24.0)
	collision_shape.shape = rectangle
	hurtbox.add_child(collision_shape)
	target.add_child(hurtbox)
	root.add_child(target)

	var host := Node2D.new()
	var energy := EnergyComponent.new()
	energy.configure_runtime(100, 100)
	host.add_child(energy)
	var form := CurrentElementController.new()
	form.configure_runtime(ElementIds.WATER)
	host.add_child(form)
	var executor := SkillExecutor.new()
	executor.configure_dependencies(energy, form, delivery_parent)
	executor.configure_cast_identity(9001, 9002, &"player")
	executor.set_spawn_snapshot_provider(func(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
		return DeliverySpawnSnapshot.new(Transform2D.IDENTITY, Vector2.RIGHT)
	)
	host.add_child(executor)
	executor.set_process(false)
	root.add_child(host)

	var payload_definition := AttackPayloadDefinition.new()
	payload_definition.damage_multiplier = 1.0
	payload_definition.element_mode = AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
	payload_definition.element_amount = 1
	var execution := InstantDeliveryExecution.new()
	execution.active_time = 0.2
	execution.delivery_scene = PROJECTILE_SCENE
	execution.payload = payload_definition
	var skill := SkillDefinition.new()
	skill.skill_id = &"integration_projectile"
	skill.startup_time = 0.01
	skill.recovery_time = 0.1
	skill.execution_definition = execution

	var spawn_observation := {"valid": false}
	executor.delivery_spawned.connect(func(
			cast_id: int,
			delivery_id: int,
			delivery: Node
	) -> void:
		spawn_observation.valid = (
			delivery is ProjectileDelivery
			and delivery.is_initialized
			and delivery.cast_snapshot.cast_id == cast_id
			and delivery.delivery_id == delivery_id
			and delivery.payload.element_id == ElementIds.WATER
			and delivery.global_position.is_equal_approx(Vector2.ZERO)
		)
	)

	await physics_frame
	var attempt := executor._try_cast_configured(skill)
	if not attempt.accepted:
		_failures.append("SkillExecutor rejected valid production Delivery scene")
	if not executor.advance(0.02):
		_failures.append("SkillExecutor did not enter ACTIVE")
	if not spawn_observation.valid:
		_failures.append("production Delivery did not observe pre-tree initialization")
	for _index in range(8):
		await physics_frame
	if damage.current_health != 90:
		_failures.append("spawned production projectile did not hit through CombatHurtbox")

	if _failures.is_empty():
		print("DELIVERY/SKILL INTEGRATION TEST PASSED: 1 test, 4 assertions")
		quit(0)
	else:
		printerr("DELIVERY/SKILL INTEGRATION TEST FAILED")
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)
