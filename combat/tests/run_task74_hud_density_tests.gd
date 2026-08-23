extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _hud: CombatHUD
var _host: RunSessionHost
var _player: PlayerCharacter


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player = _room.get_node("Player") as PlayerCharacter
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_host.set_process(false)

	_run_test("icon_only_passives_and_compact_actives", _test_slot_density)
	_run_test("disabled_icons_keep_non_hue_cues", _test_disabled_icons)
	_run_test("status_panel_is_hp_sp_only", _test_status_panel)
	_run_test("status_is_stable_across_element_change_and_low_health", _test_status_stability)
	await _run_async_test("upgrade_refreshes_hover_level", _test_upgrade_refreshes_hover_level)

	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 74 HUD DENSITY TESTS"))


func _test_slot_density() -> void:
	for slot_id: StringName in SkillSlotIds.passive():
		var slot := _hud.visual_slot_panel(slot_id)
		_expect(slot.custom_minimum_size.x * slot.custom_minimum_size.y <= 1210.0, "%s area is <= 1210 px²" % String(slot_id))
		_expect(_hud.slot_visible_fields(slot_id) == [&"icon"], "%s is icon-only" % String(slot_id))
	for slot_id: StringName in SkillSlotIds.active():
		var fields := _hud.slot_visible_fields(slot_id)
		_expect(fields.has(&"icon") and not fields.has(&"cooldown"), "%s keeps its icon without availability copy" % String(slot_id))
		if _player.skill_controller.get_skill_for_slot(slot_id) != null:
			_expect(fields.has(&"key") and fields.has(&"cost"), "%s shows key and SP cost when equipped" % String(slot_id))


func _test_disabled_icons() -> void:
	var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	var icon := active.get_node("Margin/Body/Icon") as TextureRect
	_expect(icon.self_modulate == Color.WHITE, "ready active icon is full-color")
	_player.energy_component.set_current(0)
	_expect(_is_grayscale(icon), "energy shortage enables the grayscale shader")
	_player.energy_component.set_current(_player.energy_component.maximum)
	var exclusive_preview := SkillDefinition.new()
	exclusive_preview.skill_id = &"element_bolt"
	exclusive_preview.element_policy = SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
	exclusive_preview.required_element_id = ElementIds.FIRE
	_hud.call("_refresh_slot_view", (_hud.get("_slot_views") as Dictionary)[SkillSlotIds.ACTIVE_1], SkillSlotIds.ACTIVE_1, exclusive_preview, true)
	_expect(_is_grayscale(icon), "exclusive-element mismatch enables the same grayscale shader")
	_expect(active.tooltip_text.contains("元素不匹配") and active.tooltip_text.contains("需要火"), "hover retains a textual mismatch cue")
	_hud.call("_refresh_slot", SkillSlotIds.ACTIVE_1)


func _test_status_panel() -> void:
	var status := _hud.get_node("Root/StatusPanel/Margin/Status") as Control
	_expect(status.get_node_or_null("TitleRow") == null and status.get_node_or_null("CurrentElement") == null, "status panel has no legacy title or element UI")
	var health_value := _hud.get_node("Root/StatusPanel/Margin/Status/HealthRow/HealthBar/HealthValue") as Label
	var energy_value := _hud.get_node("Root/StatusPanel/Margin/Status/EnergyRow/EnergyBar/EnergyValue") as Label
	_expect(health_value != null and energy_value != null and _hud.low_health != null, "HP/SP values and low-health feedback remain")


func _test_status_stability() -> void:
	var before := _hud.status_panel.get_global_rect()
	var change := _player.request_element(ElementIds.FIRE)
	_expect(change.accepted and _hud.status_panel.get_global_rect().is_equal_approx(before), "fire element change leaves the HP/SP status geometry unchanged")
	var health := _player.damage_receiver
	var original := health.current_health
	_expect(health.replace_health_silent(20), "low-health fixture updates the player receiver")
	health.notify_health_changed(20 - original)
	_expect(_hud.low_health.visible and _hud.health_value.text.contains("20 /"), "low-health feedback and HP value still refresh in the HP/SP-only panel")
	_expect(health.replace_health_silent(original), "low-health fixture restores the player receiver")
	health.notify_health_changed(original - 20)
	change = _player.request_element(ElementIds.WATER)
	_expect(change.accepted and _hud.status_panel.get_global_rect().is_equal_approx(before), "water element change also leaves the HP/SP status geometry unchanged")


func _test_upgrade_refreshes_hover_level() -> void:
	_expect(await _reach_shop_with_dream_dust(), "legacy test session reaches a funded shop")
	var opened := _host.run_session.open_shop_draft()
	_expect(opened.accepted and opened.shop_snapshot != null, "shop snapshot opens")
	if not opened.accepted or opened.shop_snapshot == null:
		return
	var before := _host.run_session.snapshot()
	var active := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	_expect(active.tooltip_text.contains("Lv.1"), "hover starts at authoritative Lv1")
	var upgraded := _host.run_session.upgrade_active_skill(&"task74_upgrade", before.revision, opened.shop_snapshot.session_id, &"element_bolt")
	_expect(upgraded.accepted and upgraded.run_snapshot.skills.progress_for(&"element_bolt").level == 2, "authority upgrades element_bolt to Lv2")
	await process_frame
	_expect(active.tooltip_text.contains("Lv.2"), "snapshot signal refreshes hover to authoritative Lv2")


func _reach_shop_with_dream_dust() -> bool:
	var session := _host.run_session
	for room_number: int in range(1, 4):
		var room_id := session.snapshot().route.current_room_id
		if room_number > 1:
			room_id = StringName("task74_room_%d" % room_number)
			if not session.begin_combat_room(room_id).accepted:
				return false
		var dream_dust := 80 if room_number == 1 else 0
		if not session.handle_event(RoomCompletedEvent.new(StringName("task74_done_%d" % room_number), room_id, 0, 0, dream_dust)).accepted:
			return false
		var generated := session.generate_reward(RoomRewardContext.new(room_id, RewardType.SKILL, room_number == 1), 7400 + room_number)
		if not generated.accepted or not session.claim_reward(generated.reward_offer.offer_id, generated.reward_offer.options[0].option_id).accepted:
			return false
		var route_id := RunDirector.SKILL_ROUTE_ID if room_number < 3 else RunDirector.SHOP_ROUTE_ID
		if not session.choose_route(route_id).accepted:
			return false
	return session.snapshot().route.phase == RunPhase.SHOP


func _is_grayscale(icon: TextureRect) -> bool:
	var material := icon.material as ShaderMaterial
	return material != null and is_equal_approx(float(material.get_shader_parameter(&"disabled")), 1.0) and icon.self_modulate.a < 1.0


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _run_async_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
