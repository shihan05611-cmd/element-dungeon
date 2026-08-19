extends SceneTree

## Task 61 §3.2 required real measurement: how long (in simulated seconds)
## does it take to land 15 counter-element hits on the Boss using the
## player's real elemental laser (element_amount=1, tick_interval=0.5s per
## combat/tests/run_task27_skill_level_effect_tests.gd:131-132 and
## run_skill_execution_contract_tests.gd:297-300), and does the Boss's own
## ranged attack still fire (interrupting the laser channel) while being hit
## by it. Reuses scenes/test_room.tscn's proven Player/RunSessionHost/HUD
## wiring, swapping its placeholder "Orc" for a real BossTideEmber.

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var room := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame

	var player := room.get_node("Player") as PlayerCharacter
	var host := room.get_node("RunSessionHost") as RunSessionHost
	var old_orc := room.get_node("Orc") as CombatEnemy
	old_orc.queue_free()
	await process_frame

	var boss := BOSS_SCENE.instantiate() as BossTideEmber
	boss.position = Vector2(700.0, 470.0)
	room.add_child(boss)
	boss.ai_enabled = false
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	host.set_process(false)
	await physics_frame

	print("boss form=%s countered_by=%s counter_hit_threshold=%d" % [
		String(boss.current_form_id),
		String(boss.current_form.countered_by),
		boss.tuning.counter_hit_threshold,
	])

	_equip(host, &"elemental_laser")
	player.energy_component.set_current(999999)
	_set_element(player, ElementIds.WATER)
	player.global_position = Vector2(boss.global_position.x - 220.0, boss.global_position.y)
	player.facing = 1.0

	var attempt := player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	print("laser cast accepted=%s" % [attempt.accepted])
	player.skill_executor.advance(0.0)

	var elapsed := 0.0
	var tick_step := 0.5
	var last_counter := boss.counter_hits
	while boss.current_form_id == &"ember" and elapsed < 60.0:
		player.skill_executor.advance(tick_step)
		elapsed += tick_step
		if boss.counter_hits != last_counter:
			last_counter = boss.counter_hits
	print("RESULT elapsed_seconds=%.2f final_form=%s counter_hits_now=%d total_switch_count=%d" % [
		elapsed,
		String(boss.current_form_id),
		boss.counter_hits,
		boss.total_switch_count,
	])
	player.release_channel_for_slot(SkillSlotIds.ACTIVE_1)

	# Now demonstrate the Boss's ranged attack still fires while being hit by
	# the laser (§3.8's "Boss远程受击可释放" requirement) using a fresh Boss.
	boss.queue_free()
	await process_frame
	var boss2 := BOSS_SCENE.instantiate() as BossTideEmber
	boss2.position = Vector2(700.0, 470.0)
	room.add_child(boss2)
	boss2.ai_enabled = true
	player.global_position = Vector2(boss2.global_position.x - 450.0, boss2.global_position.y)
	boss2.player = player
	boss2._boss_projectile_cooldown = 0.0
	await physics_frame

	var telegraph_started := false
	var fired_while_hit := false
	var hits_during_telegraph := 0
	var frames := 0
	while frames < 300:
		await physics_frame
		frames += 1
		if boss2._telegraph_active:
			telegraph_started = true
			var before_shots := boss2.boss_projectiles_fired
			var cast := CastSnapshot.new(9_500_000 + frames, &"laser_interrupt_probe", 1, 1, &"player", ElementIds.WATER, CombatStatSnapshot.new())
			var payload := RuntimeAttackPayload.new(2.0, 2.0, ElementIds.WATER, 1)
			boss2.combat_receiver.receive_hit(HitRequest.new(cast, payload, 9_500_000 + frames, 0, boss2.global_position, Vector2.RIGHT))
			hits_during_telegraph += 1
			if not boss2._telegraph_active and boss2.boss_projectiles_fired > before_shots:
				fired_while_hit = true
		if telegraph_started and not boss2._telegraph_active and boss2.boss_projectiles_fired > 0:
			fired_while_hit = true
			break
	print("RESULT telegraph_started=%s hits_during_telegraph=%d fired_while_hit=%s shots_fired=%d" % [
		telegraph_started,
		hits_during_telegraph,
		fired_while_hit,
		boss2.boss_projectiles_fired,
	])

	# End-to-end proof: Boss fires despite being hit -> the projectile
	# actually reaches and damages the player -> the PRE-EXISTING (untouched,
	# frozen) scripts/player.gd:720 skill_controller.cancel_current_cast("hit",
	# ...) fires and tears down whatever the player is channeling. Task 61
	# does not need to (and per the frozen-file rule, must not) add this --
	# it only had to make sure the Boss's own ranged attack survives being
	# hit long enough to actually launch. This block captures that full
	# chain as real, physically-simulated evidence.
	boss2.queue_free()
	room.queue_free()
	await process_frame

	var room3 := ROOM_SCENE.instantiate() as Node2D
	root.add_child(room3)
	current_scene = room3
	await process_frame
	await physics_frame
	var player3 := room3.get_node("Player") as PlayerCharacter
	var host3 := room3.get_node("RunSessionHost") as RunSessionHost
	(room3.get_node("Orc") as CombatEnemy).queue_free()
	await process_frame

	var boss3 := BOSS_SCENE.instantiate() as BossTideEmber
	boss3.position = Vector2(700.0, 470.0)
	room3.add_child(boss3)
	boss3.ai_enabled = true
	boss3._boss_projectile_cooldown = 0.0
	player3.global_position = Vector2(boss3.global_position.x - 260.0, boss3.global_position.y)
	player3.facing = 1.0
	boss3.player = player3
	_equip(host3, &"elemental_laser")
	player3.energy_component.set_current(999999)
	_set_element(player3, ElementIds.WATER)
	await physics_frame
	var cast2 := player3.try_cast_slot(SkillSlotIds.ACTIVE_1)
	print("second laser cast accepted=%s" % [cast2.accepted])
	var health_before := player3.damage_receiver.current_health
	var interrupted := false
	var boss_fired := false
	var frames3 := 0
	while frames3 < 360:
		await physics_frame
		frames3 += 1
		if boss3.boss_projectiles_fired > 0:
			boss_fired = true
		if player3.damage_receiver.current_health < health_before and player3.skill_executor.current_slot_id != SkillSlotIds.ACTIVE_1:
			interrupted = true
			break
	print("RESULT boss_fired=%s player_health_before=%d player_health_after=%d laser_interrupted_by_hit=%s" % [
		boss_fired,
		health_before,
		player3.damage_receiver.current_health,
		interrupted,
	])

	room3.queue_free()
	await process_frame
	quit(0)


func _equip(host: RunSessionHost, skill_id: StringName) -> bool:
	var current := host.runtime_loadout.snapshot()
	var definition := CATALOG.gameplay_for(skill_id)
	if definition == null:
		return false
	var target_slot := SkillSlotIds.PASSIVE_1 if definition.is_passive_skill() else SkillSlotIds.ACTIVE_1
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(slot_id, skill_id if slot_id == target_slot else &""))
	var result := host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	return result.accepted


func _set_element(player: PlayerCharacter, element_id: StringName) -> bool:
	if player.current_element_controller.current_element_id == element_id:
		return true
	var result := player.request_element(element_id)
	return result != null and result.accepted
