extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _failures: Array[String] = []
var _assertions: int = 0
var _room: Node2D
var _player: PlayerCharacter
var _target: CombatEnemy
var _hud: CombatHUD
var _feedback: CombatFeedback


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame

	_player = _room.get_node("Player") as PlayerCharacter
	_target = _room.get_node("Orc") as CombatEnemy
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_feedback = _room.get_node("WorldFeedbackLayer") as CombatFeedback
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_target.set_physics_process(false)
	_target.ai_enabled = false

	_test_scene_contracts()
	await _test_neutral_melee()
	await _test_water_hit_and_hud()
	await _test_reaction_and_remaining_element()
	await _test_form_snapshot_locking()
	await _test_startup_cancel_no_refund()
	await _test_energy_recovery_pause_mapping()
	await _test_enemy_delivery_hits_player()
	await _test_layout_and_reduced_motion()

	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("AGENT D INTEGRATION TESTS PASSED: 9 tests, %d assertions" % _assertions)
		quit(0)
	else:
		printerr("AGENT D INTEGRATION TESTS FAILED: %d failures / %d assertions" % [
			_failures.size(),
			_assertions,
		])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _test_scene_contracts() -> void:
	_expect(_player != null and _target != null and _hud != null, "formal room nodes load")
	var hud_root := _hud.get_node("Root")
	var player_title := _hud.get_node("Root/StatusPanel/Margin/Status/TitleRow/Title") as Label
	_expect(player_title.text == "法雅雅", "player panel displays Faya's name")
	_expect(_hud.skill_panel.get_parent() == hud_root, "skill panel is a root-level HUD sibling")
	_expect(_hud.get_node_or_null("Root/StatusPanel/Margin/Status/SkillTitle") == null, "player panel excludes skill controls")
	_expect(_player.get_node_or_null("PrototypeSkillCaster") == null, "prototype caster detached")
	_expect(_player.get_node_or_null("InteractionHitbox") == null, "legacy overlap hitbox removed")
	_expect(_player.combat_receiver.get_damage_receiver() == _player.damage_receiver, "player receiver wired")
	_expect(_target.combat_receiver.get_damage_receiver() == _target.damage_receiver, "enemy damage wired")
	_expect(_target.combat_receiver.get_element_carrier() == _target.element_carrier, "enemy carrier wired")
	_expect(_player.get_node("CombatHurtbox").collision_layer == 16, "player hurtbox uses formal layer")
	_expect(_target.get_node("CombatHurtbox").collision_layer == 8, "enemy hurtbox uses formal layer")
	_expect(_player.skill_controller.water_loadout.is_valid(), "water loadout valid")
	_expect(_player.skill_controller.fire_loadout.is_valid(), "fire loadout valid")
	_expect(_player.water_definition.is_valid() and _player.fire_definition.is_valid(), "element definitions valid")
	_expect(InputMap.has_action(&"cast_primary") and InputMap.has_action(&"switch_element"), "combat input actions registered")
	_expect(ProjectSettings.get_setting("layer_names/2d_physics/layer_4") == "EnemyHurtbox", "collision layer names registered")
	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	var enemy_source := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	_expect(not player_source.contains("receive_interaction"), "player legacy receiver path removed")
	_expect(not enemy_source.contains("receive_interaction"), "enemy legacy receiver path removed")
	print("PASS agent_d_scene_contracts")


func _test_neutral_melee() -> void:
	_reset_target_state()
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(370.0, 470.0)
	_player.facing = 1.0
	_player.request_form(ElementIds.WATER)
	_player.energy_component.set_current(100)
	_player.skill_executor.advance(2.0)
	_target.element_carrier.set_amounts_silent(0, 2)

	var committed: Array[CombatResult] = []
	var capture: Callable = func(result: CombatResult) -> void:
		committed.append(result)
	_target.combat_receiver.hit_resolved.connect(capture)
	var attempt: CastAttemptResult = _player.try_cast_slot(&"melee")
	_expect(attempt.accepted, "neutral melee cast accepted")
	_player.skill_executor.advance(0.09)
	await _wait_physics(3)

	_expect(_target.damage_receiver.current_health == 235, "neutral melee deals five damage")
	_expect(_target.element_carrier.get_amount(ElementIds.FIRE) == 2, "neutral melee preserves existing fire")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 0, "neutral melee adds no water")
	_expect(committed.size() == 1, "neutral melee commits one result")
	if not committed.is_empty():
		_expect(committed[0].final_damage == 5 and committed[0].source_element_id == ElementIds.NONE, "neutral result records five damage and no source element")
		_expect(not committed[0].reaction_triggered, "neutral melee triggers no reaction")
	_target.combat_receiver.hit_resolved.disconnect(capture)
	_player.skill_executor.advance(1.0)
	print("PASS agent_d_neutral_melee")


func _test_water_hit_and_hud() -> void:
	_reset_target_state()
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(430.0, 470.0)
	_player.request_form(ElementIds.WATER)
	_player.energy_component.set_current(100)
	_player.skill_executor.advance(2.0)
	var feedback_count_before := _feedback.get_child_count()

	var committed: Array[CombatResult] = []
	var capture: Callable = func(result: CombatResult) -> void:
		committed.append(result)
	_target.combat_receiver.hit_resolved.connect(capture)
	var attempt: CastAttemptResult = _player.try_cast_slot(&"primary")
	_expect(attempt.accepted, "water projectile cast accepted")
	_expect(_player.energy_component.current_energy == 80, "energy committed on cast acceptance")
	_expect(int(_hud.energy_bar.value) == 80, "HUD energy reads component value")
	_player.skill_executor.advance(0.13)
	await _wait_physics(10)

	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 3, "water projectile attaches three layers")
	_expect(_target.damage_receiver.current_health == 230, "projectile damage uses defense pipeline")
	_expect(committed.size() == 1 and committed[0].final_damage == 10, "one committed result with final damage")
	_expect(_feedback.get_child_count() == feedback_count_before + 1, "one damage number spawned from committed result")
	_target.combat_receiver.hit_resolved.disconnect(capture)
	_player.skill_executor.advance(1.0)
	print("PASS agent_d_water_hit_and_hud")


func _test_reaction_and_remaining_element() -> void:
	_reset_target_state()
	_target.element_carrier.set_amounts_silent(0, 2)
	_player.request_form(ElementIds.WATER)
	_player.energy_component.set_current(100)
	_player.skill_executor.advance(1.0)
	var committed: Array[CombatResult] = []
	var capture: Callable = func(result: CombatResult) -> void:
		committed.append(result)
	_target.combat_receiver.hit_resolved.connect(capture)
	var attempt: CastAttemptResult = _player.try_cast_slot(&"primary")
	_expect(attempt.accepted, "reaction cast accepted")
	_player.skill_executor.advance(0.13)
	await _wait_physics(10)

	_expect(_target.element_carrier.get_amount(ElementIds.FIRE) == 0, "opposite fire consumed")
	_expect(_target.element_carrier.get_amount(ElementIds.WATER) == 1, "unconsumed incoming water remains")
	_expect(committed.size() == 1 and committed[0].reaction_triggered, "reaction reported once")
	if not committed.is_empty():
		_expect(committed[0].reaction_consumed == 2, "reaction consumes one to one")
		_expect(is_equal_approx(committed[0].reaction_multiplier, 1.6), "reaction multiplier is 1.6")
		_expect(committed[0].final_damage == 16, "reaction final damage rounds once after defense")
	_target.combat_receiver.hit_resolved.disconnect(capture)
	_player.skill_executor.advance(1.0)
	print("PASS agent_d_reaction_and_remaining")


func _test_form_snapshot_locking() -> void:
	_reset_target_state()
	_target.global_position = Vector2(1000.0, 470.0)
	_player.energy_component.set_current(100)
	_player.request_form(ElementIds.WATER)
	_player.skill_executor.advance(1.0)
	var spawned: Array[Node] = []
	var capture: Callable = func(delivery: Node) -> void:
		spawned.append(delivery)
	_player.delivery_created.connect(capture)

	var water_attempt: CastAttemptResult = _player.try_cast_slot(&"primary")
	_expect(water_attempt.accepted, "water snapshot cast accepted")
	_player.skill_executor.advance(0.13)
	_expect(spawned.size() == 1, "water delivery spawned exactly once")
	_player.toggle_form()
	if not spawned.is_empty():
		var water_delivery: ElementProjectile = spawned[0] as ElementProjectile
		_expect(water_delivery != null and water_delivery.payload.element_id == ElementIds.WATER, "flight payload remains water after switch")
	_player.skill_executor.advance(1.0)

	var fire_attempt: CastAttemptResult = _player.try_cast_slot(&"primary")
	_expect(fire_attempt.accepted, "next fire snapshot cast accepted")
	_player.skill_executor.advance(0.13)
	_expect(spawned.size() == 2, "fire delivery spawned exactly once")
	if spawned.size() >= 2:
		var fire_delivery: ElementProjectile = spawned[1] as ElementProjectile
		_expect(fire_delivery != null and fire_delivery.payload.element_id == ElementIds.FIRE, "next cast locks fire payload")
	for delivery: Node in spawned:
		if is_instance_valid(delivery) and not delivery.is_queued_for_deletion():
			delivery.call(&"cancel")
	_player.delivery_created.disconnect(capture)
	_player.skill_executor.advance(1.0)
	print("PASS agent_d_form_snapshot_locking")


func _test_startup_cancel_no_refund() -> void:
	_player.request_form(ElementIds.WATER)
	_player.energy_component.set_current(100)
	_player.skill_executor.advance(1.0)
	var spawn_count: Array[int] = [0]
	var capture: Callable = func(_delivery: Node) -> void:
		spawn_count[0] += 1
	_player.delivery_created.connect(capture)
	var attempt: CastAttemptResult = _player.try_cast_slot(&"primary")
	_expect(attempt.accepted, "startup cast accepted before cancel")
	var cast_id := _player.skill_executor.current_cast_id
	_expect(_player.skill_controller.cancel_current_cast(&"integration_hit", cast_id), "startup cancel accepted")
	_player.skill_executor.advance(1.0)
	await _wait_physics(2)
	_expect(_player.energy_component.current_energy == 80, "startup cancel does not refund energy")
	_expect(spawn_count[0] == 0, "cancelled startup creates no late delivery")
	_expect(_player.skill_executor.current_phase == SkillExecutor.Phase.IDLE, "cancel returns executor to idle")
	_player.delivery_created.disconnect(capture)
	print("PASS agent_d_startup_cancel")


func _test_energy_recovery_pause_mapping() -> void:
	_player.defeated = false
	_player.hurt_time = 0.0
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(1000.0, 470.0)
	_player.request_form(ElementIds.WATER)
	_player.skill_executor.advance(1.0)
	_player.energy_component.set_current(100)
	var attempt: CastAttemptResult = _player.try_cast_slot(&"primary")
	_expect(attempt.accepted, "recovery mapping cast accepted")
	_expect(_player.energy_component.regeneration_paused, "startup pauses energy recovery")
	_expect(_player.energy_component.advance_regeneration(10.0) == 0, "startup pause freezes recovery delay")
	_player.skill_executor.advance(0.12)
	_expect(_player.skill_executor.current_phase == SkillExecutor.Phase.ACTIVE, "cast enters active")
	_expect(_player.energy_component.regeneration_paused, "active keeps energy recovery paused")
	_player.skill_executor.advance(0.08)
	_expect(_player.skill_executor.current_phase == SkillExecutor.Phase.RECOVERY, "cast enters recovery")
	_expect(not _player.energy_component.regeneration_paused, "recovery resumes energy clock")
	_expect(_player.energy_component.advance_regeneration(1.0) == 0, "one-second post-spend delay is preserved")
	_expect(_player.energy_component.advance_regeneration(1.0) == 5, "recovery grants default five energy per second")
	_expect(_player.energy_component.current_energy == 85, "recovered energy commits to component")
	_player.hurt_time = PlayerCharacter.HURT_DURATION
	_player.call(&"_update_energy_regeneration_pause")
	_expect(_player.energy_component.regeneration_paused, "hurt state pauses energy recovery")
	_expect(_player.energy_component.advance_regeneration(10.0) == 0, "hurt pause freezes recovery")
	_player.hurt_time = 0.0
	_player.call(&"_update_energy_regeneration_pause")
	_expect(not _player.energy_component.regeneration_paused, "ending hurt resumes recovery")
	_player.defeated = true
	_player.call(&"_update_energy_regeneration_pause")
	_expect(_player.energy_component.regeneration_paused, "defeat pauses energy recovery")
	_player.defeated = false
	_player.call(&"_update_energy_regeneration_pause")
	_player.skill_executor.advance(0.22)
	print("PASS agent_d_energy_recovery_pause_mapping")

func _test_enemy_delivery_hits_player() -> void:
	_player.damage_receiver.restore_full(false)
	_player.combat_receiver.accepting_hits = true
	_player.defeated = false
	_player.hurt_time = 0.0
	_player.global_position = Vector2(310.0, 470.0)
	_target.global_position = Vector2(360.0, 470.0)
	_target.player = _player
	_target.facing = -1.0
	_target.defeated = false
	_target.combat_receiver.accepting_hits = true
	_target._spawn_melee_delivery()
	await _wait_physics(3)
	_expect(_player.damage_receiver.current_health == 92, "enemy melee Delivery damages player Receiver")
	_expect(int(_hud.health_bar.value) == 92, "HUD health matches committed player damage")
	_expect(_player.get_node_or_null("ElementCarrier") == null, "MVP player has no positive element carrier")
	print("PASS agent_d_enemy_delivery_hits_player")


func _test_layout_and_reduced_motion() -> void:
	root.size = Vector2i(900, 540)
	await process_frame
	var root_control := _hud.get_node("Root") as Control
	var status_rect: Rect2 = _hud.status_panel.get_global_rect()
	var skill_rect: Rect2 = _hud.skill_panel.get_global_rect()
	var help_rect: Rect2 = (_hud.get_node("Root/HelpPanel") as Control).get_global_rect()
	_expect(status_rect.position.x >= 0.0 and status_rect.end.x <= root_control.size.x, "status HUD remains inside resized viewport")
	_expect(not status_rect.intersects(skill_rect) and skill_rect.end.y <= root_control.size.y, "independent skill HUD remains visible without overlapping status")
	_expect(help_rect.position.y >= 0.0 and help_rect.end.y <= root_control.size.y, "help HUD remains inside resized viewport")
	_hud.reduced_motion = true
	_feedback.set_reduced_motion(true)
	_expect(_hud.reduced_motion and _feedback.reduced_motion, "reduced motion is presentation-only and shared")
	_hud.debug_panel.visible = true
	_hud.call(&"_refresh_debug")
	_expect(_hud.debug_target.text.contains("水") and _hud.debug_target.text.contains("火"), "debug overlay exposes target element amounts")
	root.size = Vector2i(1152, 648)
	print("PASS agent_d_layout_and_reduced_motion")


func _reset_target_state() -> void:
	_target.global_position = Vector2(430.0, 470.0)
	_target.defeated = false
	_target.hurt_time = 0.0
	_target.attack_time = 0.0
	_target.combat_receiver.accepting_hits = true
	_target.combat_receiver.clear_recent_hits()
	_target.damage_receiver.restore_full(false)
	_target.element_carrier.clear_all(false)


func _wait_physics(frame_count: int) -> void:
	for _index in range(frame_count):
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)

