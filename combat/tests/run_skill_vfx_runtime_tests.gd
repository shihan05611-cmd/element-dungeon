extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const CATALOG: RunContentCatalog = preload(
	"res://resources/content/run_content_catalog.tres"
)
const PROJECTILE_SCENE: PackedScene = preload(
	"res://scenes/element_projectile.tscn"
)
const PROJECTILE_FRAMES: SpriteFrames = preload(
	"res://resources/animations/element_projectile_frames.tres"
)

var _tests: int = 0
var _assertions: int = 0
var _failures: Array[String] = []
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _host: RunSessionHost
var _coordinator: SkillVfxCoordinator


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_run_test("catalog_assets_and_pure_scenes", _test_catalog_assets_and_pure_scenes)
	_run_test("sprite_frame_contracts", _test_sprite_frame_contracts)
	_run_test("element_bolt_reuses_existing_runtime", _test_element_bolt_reuses_existing_runtime)

	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_coordinator = _room.get_node("SkillVfxCoordinator") as SkillVfxCoordinator
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_host.set_process(false)

	_run_test("coordinator_single_entry", _test_coordinator_single_entry)
	await _run_async_test("fury_authoritative_signal_and_lock", _test_fury_authoritative_signal_and_lock)
	await _run_async_test("laser_authoritative_ticks_and_cleanup", _test_laser_authoritative_ticks_and_cleanup)
	await _run_async_test("reclaim_success_only_and_trajectory", _test_reclaim_success_only_and_trajectory)
	await _run_async_test("burning_registration_layers_tick_cleanup", _test_burning_registration_layers_tick_cleanup)
	await _run_async_test("unending_registration_trigger_cleanup", _test_unending_registration_trigger_cleanup)

	for tween: Tween in get_processed_tweens():
		tween.kill()
	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 18 SKILL VFX RUNTIME TESTS PASSED: %d tests, %d assertions" % [
			_tests,
			_assertions,
		])
		quit(0)
	else:
		printerr("TASK 18 SKILL VFX RUNTIME TESTS FAILED: %d failures / %d assertions" % [
			_failures.size(),
			_assertions,
		])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)


func _test_catalog_assets_and_pure_scenes() -> void:
	var expected_icons: Dictionary[StringName, String] = {
		&"element_bolt": "res://assets/generated/vfx/element_bolt/icon.png",
		&"elemental_fury": "res://assets/generated/vfx/elemental_fury/icon.png",
		&"elemental_laser": "res://assets/generated/vfx/elemental_laser/icon.png",
		&"element_reclaim": "res://assets/generated/vfx/element_reclaim/icon.png",
		&"burning": "res://assets/generated/vfx/burning/icon.png",
		&"unending": "res://assets/generated/vfx/unending/icon.png",
	}
	var expected_presentations: Dictionary[StringName, String] = {
		&"elemental_fury": "res://scenes/vfx/elemental_fury_presentation.tscn",
		&"elemental_laser": "res://scenes/vfx/elemental_laser_presentation.tscn",
		&"element_reclaim": "res://scenes/vfx/element_reclaim_presentation.tscn",
		&"burning": "res://scenes/vfx/burning_presentation.tscn",
		&"unending": "res://scenes/vfx/unending_presentation.tscn",
	}
	for skill_id: StringName in expected_icons:
		var content := CATALOG.content_for(skill_id)
		_expect(content != null, "catalog content exists: %s" % String(skill_id))
		_expect(
			content.icon != null
			and content.icon.resource_path == expected_icons[skill_id],
			"stable icon path: %s" % String(skill_id)
		)
		if skill_id == &"element_bolt":
			_expect(
				content.presentation_scene == null,
				"element bolt intentionally has no duplicate presentation scene"
			)
			continue
		_expect(
			content.presentation_scene != null
			and content.presentation_scene.resource_path == expected_presentations[skill_id],
			"stable presentation path: %s" % String(skill_id)
		)
		var instance := content.presentation_scene.instantiate()
		_expect(instance != null, "presentation instantiates: %s" % String(skill_id))
		_expect(
			not _contains_gameplay_node(instance),
			"presentation is collision and gameplay free: %s" % String(skill_id)
		)
		instance.free()
	var base_fury := (
		CATALOG.content_for(&"elemental_fury").presentation_scene.instantiate()
		 as FuryVfxPresentation
	)
	root.add_child(base_fury)
	_expect(base_fury.play_burst(Vector2.ZERO, 96.0, ElementIds.WATER), "Fury accepts the frozen base radius")
	_expect(is_equal_approx(base_fury.scale.x, 2.25), "Fury base radius 96 scales to 144 visual diameter")
	base_fury.free()
	var slash := CATALOG.content_for(&"element_slash")
	_expect(
		slash != null and slash.icon == null and slash.presentation_scene == null,
		"fixed basic attack does not impersonate element bolt"
	)


func _test_sprite_frame_contracts() -> void:
	var frame_contracts: Array[Array] = [
		["res://resources/vfx/fury_burst_frames.tres", &"burst", 8, false],
		["res://resources/vfx/laser_tick_water_frames.tres", &"tick", 8, false],
		["res://resources/vfx/laser_tick_fire_frames.tres", &"tick", 8, false],
		["res://resources/vfx/reclaim_particle_water_frames.tres", &"travel", 8, true],
		["res://resources/vfx/reclaim_particle_fire_frames.tres", &"travel", 8, true],
		["res://resources/vfx/reclaim_extract_frames.tres", &"extract", 8, false],
		["res://resources/vfx/reclaim_arrival_frames.tres", &"arrival", 8, false],
		["res://resources/vfx/burning_loop_frames.tres", &"loop", 12, true],
		["res://resources/vfx/burning_tick_frames.tres", &"trigger", 8, false],
		["res://resources/vfx/unending_loop_frames.tres", &"loop", 12, true],
		["res://resources/vfx/unending_trigger_frames.tres", &"trigger", 8, false],
	]
	for contract: Array in frame_contracts:
		var frames := load(contract[0]) as SpriteFrames
		var animation_name := contract[1] as StringName
		_expect(frames != null, "SpriteFrames loads: %s" % contract[0])
		_expect(
			frames.has_animation(animation_name)
			and frames.get_frame_count(animation_name) == contract[2],
			"SpriteFrames count matches manifest: %s" % contract[0]
		)
		_expect(
			frames.get_animation_loop(animation_name) == contract[3],
			"SpriteFrames loop contract matches: %s" % contract[0]
		)


func _test_element_bolt_reuses_existing_runtime() -> void:
	var content := CATALOG.content_for(&"element_bolt")
	var execution := content.gameplay_definition.execution_definition as InstantDeliveryExecution
	_expect(content.presentation_scene == null, "element bolt presentation remains empty")
	_expect(
		execution != null and execution.delivery_scene == PROJECTILE_SCENE,
		"element bolt still points to the existing projectile scene"
	)
	_expect(
		PROJECTILE_FRAMES.has_animation(&"water")
		and PROJECTILE_FRAMES.has_animation(&"fire")
		and PROJECTILE_FRAMES.get_frame_count(&"water") == 4
		and PROJECTILE_FRAMES.get_frame_count(&"fire") == 4,
		"element bolt keeps the existing water/fire SpriteFrames"
	)


func _test_coordinator_single_entry() -> void:
	_expect(_coordinator != null and _coordinator.configured, "TestRoom configures one VFX coordinator")
	_expect(
		_room.find_children("*", "SkillVfxCoordinator", true, false).size() == 1,
		"TestRoom has exactly one VFX coordinator entry"
	)
	_expect(
		_coordinator.burning_loop_count == 0
		and _coordinator.unending_loop_count == 0,
		"no passive loop is shown without actual registration"
	)


func _test_fury_authoritative_signal_and_lock() -> void:
	_expect(_equip(&"elemental_fury"), "equip Fury")
	_expect(_set_element(ElementIds.WATER), "select water before Fury")
	_player.energy_component.set_current(20)
	var first_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(first_attempt.accepted, "minimum-energy Fury cast accepted")
	_player.skill_executor.advance(0.0)
	_expect(_set_element(ElementIds.FIRE), "live element can change after locked Fury commit")
	await process_frame
	var first := _find_fury_by_radius(115.2)
	_expect(first != null, "Fury signal creates the task-15 115.2-radius presentation")
	_expect(
		first != null
		and is_equal_approx(first.scale.x, 2.7)
		and first.locked_element_id == ElementIds.WATER,
		"Fury task-15 scale and cast element remain locked"
	)

	_player.energy_component.set_current(100)
	_expect(_set_element(ElementIds.FIRE), "select fire before maximum Fury")
	var second_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(second_attempt.accepted, "maximum-energy Fury cast accepted")
	_player.skill_executor.advance(0.0)
	await process_frame
	var second := _find_fury_by_radius(192.0)
	_expect(second != null, "Fury signal creates the 192-radius presentation")
	_expect(
		second != null
		and is_equal_approx(second.scale.x, 4.5)
		and second.locked_element_id == ElementIds.FIRE,
		"Fury 192 scale and fire lock match the authoritative cast"
	)
	_expect(_coordinator.fury_playback_count == 2, "one Fury signal produces one playback")


func _test_laser_authoritative_ticks_and_cleanup() -> void:
	_expect(_equip(&"elemental_laser"), "equip Laser")
	_player.energy_component.set_current(100)
	_expect(_set_element(ElementIds.WATER), "select water before Laser")
	_enemy.global_position = Vector2(520.0, _player.global_position.y)
	var attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(attempt.accepted, "Laser cast accepted")
	_player.skill_executor.advance(0.0)
	_expect(_coordinator.active_laser_count == 1, "Laser presentation starts with delivery")
	var laser := _find_laser()
	_expect(
		laser != null
		and laser.get_child_count() == 5
		and laser.visual_size() == Vector2(320.0, 24.0),
		"Laser is five 64x24 segments and reports 320x24"
	)
	_player.skill_executor.advance(0.49)
	_expect(_coordinator.laser_tick_count == 0, "0.49 seconds has no visual Tick")
	_player.skill_executor.advance(0.01)
	_expect(_coordinator.laser_tick_count == 1, "0.50 seconds responds to one authoritative Tick")
	_player.skill_executor.advance(0.50)
	_expect(_coordinator.laser_tick_count == 2, "1.00 seconds responds to two authoritative Ticks")
	_expect(
		laser != null and laser.locked_element_id == ElementIds.WATER,
		"Laser keeps its cast-time element"
	)
	_expect(
		_player.release_channel_for_slot(SkillSlotIds.ACTIVE_1),
		"Laser release closes the authoritative channel"
	)
	_expect(_coordinator.active_laser_count == 0, "Laser finish removes presentation immediately")
	_player.skill_executor.advance(0.0)


func _test_reclaim_success_only_and_trajectory() -> void:
	_enemy.global_position = Vector2(430.0, _player.global_position.y)
	await physics_frame
	_expect(_equip(&"element_reclaim"), "equip Reclaim")
	_expect(_set_element(ElementIds.WATER), "select water before Reclaim")
	var initial_count := _coordinator.reclaim_playback_count
	_player.energy_component.set_current(100)
	var full_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(not full_attempt.accepted, "full-energy Reclaim rejects")
	_expect(
		_coordinator.reclaim_playback_count == initial_count,
		"full-energy Reclaim has zero success VFX"
	)
	_player.energy_component.set_current(50)
	_set_enemy_elements(0, 0)
	var empty_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(not empty_attempt.accepted, "no-layer Reclaim rejects")
	_expect(
		_coordinator.reclaim_playback_count == initial_count,
		"no-layer Reclaim has zero success VFX"
	)
	_set_enemy_elements(2, 0)
	var success_attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(success_attempt.accepted, "valid atomic Reclaim commits: %s / %s" % [String(success_attempt.reason_name()), String(success_attempt.detail)])
	_expect(
		_coordinator.reclaim_playback_count == initial_count + 1,
		"only committed Reclaim publishes success VFX"
	)
	var reclaim := _find_reclaim()
	_expect(
		reclaim != null
		and reclaim.locked_element_id == ElementIds.WATER
		and reclaim.target_count == 1
		and reclaim.particle_count == 3,
		"Reclaim emits three locked-water particles for one committed target"
	)
	_expect(
		_enemy.element_carrier.snapshot().water_amount == 0,
		"Reclaim VFX wrapper leaves authoritative element consumption intact"
	)
	await process_frame


func _test_burning_registration_layers_tick_cleanup() -> void:
	_expect(_equip(&"burning"), "equip Burning")
	_set_enemy_elements(0, 2)
	await process_frame
	_expect(_coordinator.burning_loop_count == 1, "Burning loop requires registration and fire layers")
	_set_enemy_elements(0, 4)
	await process_frame
	_expect(_coordinator.burning_loop_count == 1, "Burning layer changes do not duplicate loops")
	var ticks_before := _coordinator.burning_tick_count
	_host.passive_adapter.advance(1.0)
	_expect(
		_coordinator.burning_tick_count == ticks_before + 1,
		"confirmed one-second Burning submission plays one trigger"
	)
	_set_enemy_elements(0, 0)
	_expect(_coordinator.burning_loop_count == 0, "Burning loop clears at zero fire layers")
	_expect(_equip(&"element_bolt"), "unequip Burning")
	_set_enemy_elements(0, 2)
	_expect(_coordinator.burning_loop_count == 0, "unregistered Burning remains hidden")


func _test_unending_registration_trigger_cleanup() -> void:
	_expect(_equip(&"unending"), "equip Unending")
	_set_enemy_elements(3, 0)
	await process_frame
	_expect(_coordinator.unending_loop_count == 1, "Unending loop requires registration and water layers")
	var target_id := _host_enemy_id(_enemy)
	var event := BasicAttackCommittedEvent.new(
		&"task18:unending:1",
		_player.get_instance_id(),
		target_id,
		_enemy.element_carrier.snapshot()
	)
	var triggers_before := _coordinator.unending_trigger_count
	_player.basic_attack_committed.emit(event)
	_expect(
		_coordinator.unending_trigger_count == triggers_before + 1,
		"successful fixed-basic-attack recovery event plays one Unending trigger"
	)
	_set_enemy_elements(0, 0)
	_expect(_coordinator.unending_loop_count == 0, "Unending loop clears at zero water layers")
	_set_enemy_elements(2, 0)
	_expect(_coordinator.unending_loop_count == 1, "Unending loop rebuilds once when water returns")
	_player.skill_controller.on_owner_died()
	_player.player_defeated.emit()
	_expect(
		_coordinator.unending_loop_count == 0
		and _coordinator.burning_loop_count == 0,
		"player death atomically clears passive presentations"
	)


func _equip(skill_id: StringName) -> bool:
	var current := _host.runtime_loadout.snapshot()
	var definition := CATALOG.gameplay_for(skill_id)
	if definition == null:
		return false
	var target_slot := (
		SkillSlotIds.PASSIVE_1
		if definition.is_passive_skill()
		else SkillSlotIds.ACTIVE_1
	)
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(
			slot_id,
			skill_id if slot_id == target_slot else &""
		))
	var result := _host.runtime_loadout.try_replace_snapshot(
		RuntimeLoadoutSnapshot.new(entries, current.revision)
	)
	return result.accepted


func _set_element(element_id: StringName) -> bool:
	if _player.current_element_controller.current_element_id == element_id:
		return true
	var result := _player.request_element(element_id)
	return result != null and result.accepted


func _set_enemy_elements(water: int, fire: int) -> void:
	var before := _enemy.element_carrier.snapshot()
	var replaced := _enemy.element_carrier.set_amounts_silent(water, fire)
	_expect(replaced, "test element state replacement validates")
	_enemy.element_carrier.notify_changed(before)


func _find_fury_by_radius(radius: float) -> FuryVfxPresentation:
	for child: Node in _coordinator.get_children():
		var fury := child as FuryVfxPresentation
		if fury != null and is_equal_approx(fury.authoritative_radius, radius):
			return fury
	return null


func _find_laser() -> LaserVfxPresentation:
	for child: Node in _coordinator.get_children():
		if child is LaserVfxPresentation:
			return child as LaserVfxPresentation
	return null


func _find_reclaim() -> ReclaimVfxPresentation:
	for child: Node in _coordinator.get_children():
		if child is ReclaimVfxPresentation:
			return child as ReclaimVfxPresentation
	return null


func _contains_gameplay_node(node: Node) -> bool:
	if node is CollisionObject2D or node is CollisionShape2D:
		return true
	var script := node.get_script() as Script
	if script != null:
		var path := script.resource_path
		if (
			path.begins_with("res://combat/")
			or path.begins_with("res://growth/")
			or path == "res://scripts/player.gd"
			or path == "res://scripts/enemy.gd"
		):
			return true
	for child: Node in node.get_children():
		if _contains_gameplay_node(child):
			return true
	return false


func _host_enemy_id(enemy: CombatEnemy) -> StringName:
	var identity := String(enemy.get_path())
	if identity.is_empty():
		identity = "instance_%d" % enemy.get_instance_id()
	return StringName("%s@%s" % [String(enemy.growth_enemy_id), identity])


func _run_test(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	test_callable.call()
	if _failures.size() == before:
		print("PASS ", test_name)


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var before := _failures.size()
	await test_callable.call()
	if _failures.size() == before:
		print("PASS ", test_name)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
