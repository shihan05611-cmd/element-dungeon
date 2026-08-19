extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _identity: int = 48_000


func _initialize() -> void:
	call_deferred(&"_run_all")


func _run_all() -> void:
	await _run_async("open_ground_direction_duration_cooldown", _test_open_ground_direction_duration_cooldown)
	await _run_async("damage_rejection_enemy_pass_and_world_wall", _test_damage_enemy_and_wall_contract)
	await _run_async("action_gates_and_post_dodge_recovery", _test_action_gates_and_recovery)
	await _run_async("interrupt_death_respawn_and_exit_cleanup", _test_interrupt_cleanup)
	_test_source_and_input_contracts()
	_finish()


func _test_open_ground_direction_duration_cooldown() -> void:
	var rig := await _make_room()
	var player := rig.player as PlayerCharacter
	var enemy := rig.enemy as CombatEnemy
	enemy.global_position = Vector2(900.0, player.global_position.y)
	player.global_position.x = 560.0
	player.facing = -1.0
	player.sprite.flip_h = false
	player.collision_mask = 7
	player.velocity = Vector2.ZERO
	await _settle_floor(player)
	player.set_physics_process(false)
	var start := player.global_position
	var expected_distance := player.body_collision.shape.get_rect().size.x * player.body_collision.global_transform.x.length() * PlayerCharacter.DODGE_DISTANCE_IN_BODY_WIDTHS
	_expect(bool(player.call(&"_try_start_dodge")), "grounded idle player starts dodge")
	_expect(bool(player.get("_dodging")) and player.combat_receiver.dodging, "receiver dodging is set before movement")
	_expect(not player.get_collision_mask_value(2) and player.get_collision_mask_value(3), "dodge disables only enemy body contact while preserving world blockers")
	_expect_eq(player.collision_mask, 5, "all unrelated collision mask bits remain intact during dodge")
	_expect_eq(player.get("_dodge_direction"), -1.0, "zero horizontal input uses last facing")
	for _step: int in 5:
		player.call(&"_advance_dodge", 0.03)
	_expect(bool(player.get("_dodging")), "dodge remains active before 0.18 seconds")
	_expect(player.combat_receiver.dodging, "damage rejection spans the full pre-final frame")
	player.call(&"_advance_dodge", 0.03)
	var distance := absf(player.global_position.x - start.x)
	_expect(not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "dodge ends exactly after 0.18 seconds")
	_expect(absf(distance - expected_distance) <= expected_distance * 0.02, "open ground travels 5.0 body widths")
	_expect_eq(player.collision_mask, 7, "natural completion restores the exact original collision mask")
	_expect(not bool(player.call(&"_try_start_dodge")), "cooldown blocks an immediate second dodge")
	player.call(&"_physics_process", 0.54)
	_expect(not bool(player.call(&"_try_start_dodge")), "cooldown is still active before 0.55 seconds after completion")
	player.call(&"_physics_process", 0.02)
	_expect(bool(player.call(&"_try_start_dodge")), "cooldown expires after 0.55 seconds from completion")
	player.call(&"_finish_dodge", false, false)
	await _dispose_room(rig.room)


func _test_damage_enemy_and_wall_contract() -> void:
	var rig := await _make_room()
	var player := rig.player as PlayerCharacter
	var enemy := rig.enemy as CombatEnemy
	player.global_position.x = 500.0
	await _settle_floor(player)
	player.set_physics_process(false)
	enemy.global_position = player.global_position + Vector2(35.0, 0.0)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	var start := player.global_position
	var expected_distance := float(player.call(&"_dodge_body_world_width")) * PlayerCharacter.DODGE_DISTANCE_IN_BODY_WIDTHS
	Input.action_press(&"move_right")
	_expect(bool(player.call(&"_try_start_dodge")), "right input starts a rightward dodge")
	Input.action_release(&"move_right")
	var health_before := player.damage_receiver.current_health
	var rejected := player.combat_receiver.receive_hit(_enemy_hit(player))
	_expect(not rejected.accepted and rejected.reject_reason == CombatStatus.RejectReason.DODGED, "full dodge window rejects damage through CombatReceiver DODGED")
	_expect_eq(player.damage_receiver.current_health, health_before, "dodged hit commits no health change")
	for _step: int in 6:
		player.call(&"_advance_dodge", 0.03)
	_expect(absf(player.global_position.x - start.x - expected_distance) <= expected_distance * 0.02, "enemy body layer does not truncate real dodge motion")
	_expect(player.global_position.x > enemy.global_position.x, "completed five-body-width dodge ends beyond the enemy center")

	player.global_position = Vector2(1035.0, start.y)
	player.velocity = Vector2.ZERO
	player.call(&"_physics_process", 0.60)
	var wall_start := player.global_position
	Input.action_press(&"move_right")
	_expect(bool(player.call(&"_try_start_dodge")), "wall case starts after cooldown")
	Input.action_release(&"move_right")
	for _step: int in 6:
		if not bool(player.get("_dodging")):
			break
		player.call(&"_advance_dodge", 0.03)
	var wall_distance := player.global_position.x - wall_start.x
	_expect(wall_distance >= 0.0 and wall_distance < expected_distance * 0.75, "world wall truncates dodge before the open-ground target")
	_expect(not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "wall collision ends dodge and clears invulnerability state")
	_expect_eq(player.collision_mask, 6, "wall interruption restores the original formal mask")
	await _dispose_room(rig.room)


func _test_action_gates_and_recovery() -> void:
	var rig := await _make_room()
	var player := rig.player as PlayerCharacter
	var enemy := rig.enemy as CombatEnemy
	enemy.global_position = Vector2(900.0, player.global_position.y)
	await _settle_floor(player)
	player.set_physics_process(false)
	player.hurt_time = 0.1
	_expect(not bool(player.call(&"_try_start_dodge")), "hurt state rejects dodge startup")
	player.hurt_time = 0.0
	player.defeated = true
	_expect(not bool(player.call(&"_try_start_dodge")), "death state rejects dodge startup")
	player.defeated = false
	player.global_position.y -= 100.0
	player.set_collision_mask_value(3, false)
	player.velocity = Vector2(0.0, 10.0)
	player.move_and_slide()
	_expect(not player.is_on_floor(), "fixture is airborne before the air-dodge check")
	_expect(bool(player.call(&"_try_start_dodge")), "airborne state now allows a dodge start (air dash)")
	player.call(&"_finish_dodge", false, false)
	player.set_collision_mask_value(3, true)
	player.global_position = Vector2(420.0, 470.0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await _settle_floor(player)
	player.set_physics_process(false)
	player.skill_executor.advance(2.0)
	var cast := player.try_basic_attack()
	_expect(cast.accepted, "formal basic attack starts for cast-state gate")
	_expect(not bool(player.call(&"_try_start_dodge")), "active cast rejects dodge startup")
	player.skill_executor.advance(2.0)
	_expect(bool(player.call(&"_try_start_dodge")), "idle grounded player starts after cast completion")
	var element_before := player.current_element_controller.current_element_id
	var blocked_cast := player.try_basic_attack()
	var blocked_element := player.cycle_next()
	var jump_event := InputEventAction.new()
	jump_event.action = &"jump"
	jump_event.pressed = true
	player.call(&"_unhandled_input", jump_event)
	_expect(not blocked_cast.accepted, "dodge locks skill starts")
	_expect(not blocked_element.accepted and player.current_element_controller.current_element_id == element_before, "dodge locks element switching")
	_expect(not player.jump_requested, "dodge does not buffer jump input")
	player.call(&"_finish_dodge", false, true)
	player.skill_executor.advance(2.0)
	_expect(player.try_basic_attack().accepted, "skills recover after dodge cleanup")
	player.skill_executor.advance(2.0)
	_expect(player.cycle_next().accepted, "element switching recovers after dodge cleanup")
	player.call(&"_unhandled_input", jump_event)
	_expect(player.jump_requested, "jump input recovers after dodge cleanup")
	await _dispose_room(rig.room)


func _test_interrupt_cleanup() -> void:
	var rig := await _make_room()
	var player := rig.player as PlayerCharacter
	var enemy := rig.enemy as CombatEnemy
	enemy.global_position = Vector2(900.0, player.global_position.y)
	await _settle_floor(player)
	player.set_physics_process(false)
	player.collision_mask = 7
	player.velocity = Vector2(73.0, 0.0)
	var original_visual := player.sprite.modulate
	_expect(bool(player.call(&"_try_start_dodge")), "interrupt fixture starts dodge")
	player.combat_receiver.invulnerable = true
	player.call(&"_on_health_state_changed", 90, 100, -10, CombatResult.new())
	_expect(not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "health interruption clears dodge state idempotently")
	_expect(player.combat_receiver.invulnerable, "dodge cleanup does not overwrite another invulnerable source")
	_expect_eq(player.collision_mask, 7, "health interruption restores exact mask")
	_expect(player.sprite.modulate.is_equal_approx(original_visual), "health interruption restores the pre-dodge visual before hit feedback")
	player.combat_receiver.invulnerable = false
	player.hurt_time = 0.0
	for tween: Tween in get_processed_tweens():
		tween.kill()
	player.sprite.modulate = Color(player.get("_base_sprite_modulate"))
	player.global_position = Vector2(500.0, 470.0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await _settle_floor(player)
	player.set_physics_process(false)
	player.set("_dodge_cooldown_remaining", 0.0)
	player.velocity = Vector2(73.0, 0.0)
	_expect(bool(player.call(&"_try_start_dodge")), "death fixture starts dodge")
	player.call(&"_on_death_candidate", CombatResult.new())
	_expect(player.defeated and not bool(player.get("_dodging")) and not player.combat_receiver.dodging, "death clears dodge and receiver state")
	_expect_eq(player.collision_mask, 7, "death restores exact mask")
	_expect_eq(player.velocity, Vector2(73.0, 0.0), "death interruption restores saved velocity")
	player.respawn()
	_expect(not player.defeated and player.velocity == Vector2.ZERO and player.collision_mask == 7, "respawn resets speed while preserving the restored mask")
	await _dispose_room(rig.room)

	var exit_rig := await _make_room()
	var exiting := exit_rig.player as PlayerCharacter
	await _settle_floor(exiting)
	exiting.set_physics_process(false)
	exiting.collision_mask = 7
	_expect(bool(exiting.call(&"_try_start_dodge")), "exit fixture starts dodge")
	(exit_rig.room as Node).remove_child(exiting)
	_expect(not bool(exiting.get("_dodging")) and not exiting.combat_receiver.dodging, "tree exit clears dodge and receiver state")
	_expect_eq(exiting.collision_mask, 7, "tree exit restores exact mask")
	_expect(exiting.sprite.modulate.is_equal_approx(Color(exiting.get("_base_sprite_modulate"))), "tree exit restores visual state")
	exiting.free()
	await _dispose_room(exit_rig.room)


func _test_source_and_input_contracts() -> void:
	_harness.tests += 1
	var source := FileAccess.get_file_as_string("res://scripts/player.gd")
	var dodge_source := source.substr(source.find("func _try_start_dodge"), source.find("func _idle_animation_name") - source.find("func _try_start_dodge"))
	_expect(InputMap.has_action(&"dodge"), "dodge input action is registered")
	var shift_bound := false
	for event: InputEvent in InputMap.action_get_events(&"dodge"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SHIFT:
			shift_bound = true
	_expect(shift_bound, "dodge action uses physical Shift")
	_expect(dodge_source.contains("move_and_collide"), "dodge implementation uses real collision movement")
	_expect(not dodge_source.contains("test_only"), "dodge implementation never uses test-only motion")
	_expect(not dodge_source.contains("global_position =") and not dodge_source.contains("global_position +="), "dodge implementation never teleports the player")
	_expect(not dodge_source.contains("invulnerable"), "dodge implementation does not read or write other invulnerability sources")
	_expect(not dodge_source.contains("collision_mask = 0"), "dodge implementation never disables all collision")
	print("PASS: source_and_input_contracts")


func _make_room() -> Dictionary:
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var player := room.get_node("Player") as PlayerCharacter
	var enemy := room.get_node("Orc") as CombatEnemy
	enemy.ai_enabled = false
	enemy.set_physics_process(false)
	return {"room": room, "player": player, "enemy": enemy}


func _settle_floor(player: PlayerCharacter) -> void:
	player.set_physics_process(true)
	for _frame: int in 30:
		await physics_frame
		if player.is_on_floor():
			return
	_expect(false, "player settles on a real world-layer floor")


func _enemy_hit(player: PlayerCharacter) -> HitRequest:
	_identity += 1
	var cast := CastSnapshot.new(_identity, &"task48_enemy_hit", 48, 48, &"enemy", ElementIds.NONE, CombatStatSnapshot.new())
	return HitRequest.new(cast, RuntimeAttackPayload.new(10.0, 10.0, ElementIds.NONE, 0), _identity, 0, player.global_position, Vector2.LEFT)


func _dispose_room(room: Node) -> void:
	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(room):
		room.queue_free()
	await process_frame


func _run_async(name: String, callable: Callable) -> void:
	await _harness.run_test(name, callable)


func _expect(condition: bool, message: String) -> void:
	_harness.expect(condition, message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_harness.expect_eq(actual, expected, message)


func _finish() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	quit(_harness.report("TASK 48 DODGE INTEGRATION TESTS"))
