extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _hud: CombatHUD
var _player: PlayerCharacter
var _host: RunSessionHost


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_player = _room.get_node("Player") as PlayerCharacter
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)

	await _run_async_test("layout_anchor_and_safe_margin_matrix", _test_layout_anchor_and_safe_margin_matrix)
	_run_test("single_active_frame_and_seven_slots", _test_single_active_frame_and_seven_slots)
	_run_test("dynamic_key_cost_and_empty_active", _test_dynamic_key_cost_and_empty_active)
	_run_test("bottom_anchored_cooldown_and_disabled_grayscale", _test_bottom_anchored_cooldown_and_disabled_grayscale)
	_run_test("passive_empty_lock_equipped_and_pulse", _test_passive_empty_lock_equipped_and_pulse)
	_run_test("h_visibility_and_compatibility_contract", _test_h_visibility_and_compatibility_contract)

	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 95 SKILL HUD TESTS"))


func _test_layout_anchor_and_safe_margin_matrix() -> void:
	for viewport_size: Vector2i in [Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var bounds := (_hud.get_node("Root") as Control).get_global_rect()
		var active := _hud.skill_panel.get_global_rect()
		var passive := _hud.passive_panel.get_global_rect()
		_expect(active.size.is_equal_approx(CombatHUD.SKILL_STRIP_SIZE), "active frame keeps source-derived logical size at %s" % viewport_size)
		_expect(passive.size.is_equal_approx(CombatHUD.PASSIVE_STRIP_SIZE), "passive frame keeps source-derived logical size at %s" % viewport_size)
		_expect(absf(active.get_center().x - bounds.get_center().x) <= 0.2, "active frame remains bottom-center at %s" % viewport_size)
		_expect(absf(bounds.end.x - passive.end.x - 51.0) <= 0.2, "passive frame keeps 51px right safe margin at %s" % viewport_size)
		_expect(absf(bounds.end.y - passive.end.y - 18.0) <= 0.2, "passive frame keeps 18px bottom safe margin at %s" % viewport_size)
		_expect(not active.intersects(passive), "active and passive frames never overlap at %s" % viewport_size)
	root.size = Vector2i(1152, 648)


func _test_single_active_frame_and_seven_slots() -> void:
	var active_frame := _hud.get_node("Root/SkillPanel/StaticFrame") as TextureRect
	var passive_frame := _hud.get_node("Root/PassivePanel/StaticFrame") as TextureRect
	var active_fill := _hud.get_node("Root/SkillPanel/SourceFill") as ColorRect
	var passive_fill := _hud.get_node("Root/PassivePanel/SourceFill") as ColorRect
	_expect(active_frame.texture.get_size() == CombatHUD.SKILL_STRIP_SIZE, "active static texture is the exact 324x85 extraction")
	_expect(passive_frame.texture.get_size() == CombatHUD.PASSIVE_STRIP_SIZE, "passive static texture is the exact 249x70 extraction")
	_expect(active_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "active extracted frame uses nearest filtering")
	_expect(passive_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "passive extracted frame uses nearest filtering")
	_expect(active_fill.color == Color8(13, 17, 23, 255), "active interior uses the exact Task94 clean source sample")
	_expect(passive_fill.color == Color8(16, 20, 28, 255), "passive interior uses the exact Task94 clean source sample")
	var active_row := _hud.get_node("Root/SkillPanel/Margin/Skills/SlotRow") as HBoxContainer
	var passive_row := _hud.get_node("Root/PassivePanel/Margin/SlotRow") as HBoxContainer
	_expect(active_row.get_child_count() == 3, "active frame contains exactly three logical slots")
	_expect(passive_row.get_child_count() == 4, "passive frame contains exactly four logical slots")
	_expect(active_row.get_theme_constant(&"separation") == 0, "active slots share one uninterrupted frame with no gaps")
	for slot_id: StringName in SkillSlotIds.active():
		var panel := _hud.visual_slot_panel(slot_id)
		_expect(panel.get_theme_stylebox(&"panel") is StyleBoxEmpty, "%s has no independently drawn closed slot frame" % slot_id)
	for seam_x: int in [108, 216]:
		var divider_alpha := active_frame.texture.get_image().get_pixel(seam_x, 42).a
		_expect(divider_alpha > 0.0, "continuous active frame contains divider at x=%d" % seam_x)


func _test_dynamic_key_cost_and_empty_active() -> void:
	_replace_loadout()
	var first := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	var empty := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_2)
	_expect((first.get_node("Margin/Body/Key/Text") as Label).text == "1", "slot one key digit is a runtime label")
	_expect((first.get_node("Margin/Body/Cost") as Label).text.begins_with("SP "), "equipped active SP is runtime text")
	_expect((empty.get_node("Margin/Body/Key") as Control).visible, "empty active slot keeps its key tab")
	_expect((empty.get_node("Margin/Body/Key/Text") as Label).text == "2", "empty active key digit remains dynamic")
	_expect((empty.get_node("Margin/Body/Icon") as TextureRect).texture == null, "empty active slot has no icon")
	_expect((empty.get_node("Margin/Body/Cost") as Label).text.is_empty(), "empty active slot has no SP text")
	_expect(not (empty.get_node("Margin/Body/CooldownLabel") as Label).visible, "empty active slot has no cooldown readout")


func _test_bottom_anchored_cooldown_and_disabled_grayscale() -> void:
	var disabled_panel := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_3)
	var disabled_icon := disabled_panel.get_node("Margin/Body/Icon") as TextureRect
	_player.energy_component.set_current(0)
	_expect(_disabled_amount(disabled_icon) == 1.0, "energy shortage keeps the existing grayscale disable semantic")
	_player.energy_component.set_current(_player.energy_component.maximum)
	var panel := _hud.visual_slot_panel(SkillSlotIds.ACTIVE_1)
	var icon := panel.get_node("Margin/Body/Icon") as TextureRect
	var skill := _player.skill_controller.get_skill_for_slot(SkillSlotIds.ACTIVE_1)
	var cooldowns = _player.skill_executor.get("_cooldowns")
	cooldowns.start(skill.skill_id, skill.cooldown)
	cooldowns.advance(skill.cooldown * 0.4)
	_hud.call("_refresh_skill_status")
	var mask := panel.get_node("Margin/Body/CooldownMask") as ColorRect
	var countdown := panel.get_node("Margin/Body/CooldownLabel") as Label
	_expect(mask.visible and countdown.visible and not countdown.text.is_empty(), "cooldown shade and centered seconds are dynamic")
	_expect(absf(mask.position.y + mask.size.y - (icon.position.y + icon.size.y)) <= 0.01, "cooldown shade stays bottom-anchored while wiping upward")
	_expect(mask.size.y > 0.0 and mask.size.y < icon.size.y, "partial cooldown occupies a partial vertical height")
	_expect(countdown.position.is_equal_approx(icon.position) and countdown.size.is_equal_approx(icon.size), "cooldown seconds remain centered over the icon")
	cooldowns.advance(skill.cooldown)
	_hud.call("_refresh_skill_status")
	_expect(not mask.visible and not countdown.visible, "cooldown completion fully restores the icon")


func _test_passive_empty_lock_equipped_and_pulse() -> void:
	var equipped := _hud.visual_slot_panel(SkillSlotIds.PASSIVE_1)
	var empty := _hud.visual_slot_panel(SkillSlotIds.PASSIVE_2)
	_expect((equipped.get_node("Margin/Body/Icon") as TextureRect).texture != null, "equipped passive displays its real runtime icon")
	_expect((empty.get_node("Margin/Body/EmptyInset") as TextureRect).visible, "empty passive displays the extracted inset dash")
	_expect(empty.get_node_or_null("Margin/Body/Key") == null and empty.get_node_or_null("Margin/Body/Cost") == null, "passive slot has no key or SP controls")
	_expect((_hud.get("_passive_lock_visual_fixtures") as Dictionary).is_empty(), "normal runtime flow fabricates no passive locks")
	_hud.set_passive_slot_locked_fixture(SkillSlotIds.PASSIVE_2, true)
	_expect((empty.get_node("Margin/Body/LockFixture") as TextureRect).visible, "fixture can display the reusable extracted lock")
	_expect(not (empty.get_node("Margin/Body/EmptyInset") as TextureRect).visible, "lock fixture replaces rather than overlaps the empty inset")
	_hud.set_passive_slot_locked_fixture(SkillSlotIds.PASSIVE_2, false)
	_hud.call("_set_slot_transient", SkillSlotIds.PASSIVE_1, "触发", &"passive")
	_hud.call("_refresh_slot", SkillSlotIds.PASSIVE_1)
	var pulse := equipped.get_node("Margin/Body/PulseBorder") as TextureRect
	_expect(pulse.visible, "passive trigger maps to the extracted thin bright border")
	_expect(pulse.scale.is_equal_approx(Vector2.ONE) and pulse.position.is_equal_approx(Vector2.ZERO), "passive pulse never scales or shifts the slot")


func _test_h_visibility_and_compatibility_contract() -> void:
	for slot_id: StringName in SkillSlotIds.all():
		_expect(_hud.visual_slot_panel(slot_id) != null, "visual slot remains addressable: %s" % slot_id)
		_expect(_hud.slot_panel(slot_id) != null, "compatibility slot remains addressable: %s" % slot_id)
	_hud.set_skill_hud_visible(false)
	_expect(not _hud.skill_panel.visible and not _hud.passive_panel.visible, "H visibility API hides both separated regions")
	_hud.set_skill_hud_visible(true)
	_expect(_hud.skill_panel.visible and _hud.passive_panel.visible, "H visibility API restores both separated regions")


func _replace_loadout() -> void:
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = [
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1, &"element_reclaim"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2, &""),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3, &"element_bolt"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, &"burning"),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, &""),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3, &""),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4, &""),
	]
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	_expect(result.accepted, "Task95 mixed equipped/empty fixture is accepted by runtime loadout")
	_hud.call("_refresh_skill_status")


func _disabled_amount(icon: TextureRect) -> float:
	var material := icon.material as ShaderMaterial
	return float(material.get_shader_parameter(&"disabled")) if material != null else -1.0


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _run_async_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
