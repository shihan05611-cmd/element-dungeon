extends SceneTree

const TestHarness := preload("res://combat/tests/test_harness.gd")
const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")

var _harness := TestHarness.new()
var _room: Node2D
var _hud: CombatHUD
var _player: PlayerCharacter
var _enemy: CombatEnemy
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
	_enemy = _room.get_node("Orc") as CombatEnemy
	_host = _room.get_node("RunSessionHost") as RunSessionHost
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)

	_run_test("input_map_and_default_visibility", _test_input_map_and_default_visibility)
	_run_test("only_skill_panels_toggle_and_echo_is_ignored", _test_only_skill_panels_toggle_and_echo_is_ignored)
	_run_test("hidden_hud_preserves_cast_and_cooldown", _test_hidden_hud_preserves_cast_and_cooldown)

	if is_instance_valid(_room):
		_room.queue_free()
	await process_frame
	quit(_harness.report("TASK 82 TOGGLE SKILL HUD TESTS"))


func _test_input_map_and_default_visibility() -> void:
	_expect(InputMap.has_action(&"toggle_skill_hud"), "toggle_skill_hud action exists")
	var has_physical_h := false
	for mapped_event: InputEvent in InputMap.action_get_events(&"toggle_skill_hud"):
		if mapped_event is InputEventKey and mapped_event.physical_keycode == KEY_H:
			has_physical_h = true
	_expect(has_physical_h, "toggle_skill_hud defaults to physical H")
	_expect(_hud.is_skill_hud_visible(), "a new HUD starts with skill belts visible")
	_expect(_hud.skill_panel.visible and _hud.passive_panel.visible, "both skill belts start visible")


func _test_only_skill_panels_toggle_and_echo_is_ignored() -> void:
	var unchanged := [
		_hud.status_panel.visible,
		(_hud.get_node("Root/BossPanel") as Control).visible,
		(_hud.get_node("Root/FeedbackPanel") as Control).visible,
		_hud.run_overlay.visible,
	]
	_hud._unhandled_input(_h_key_event(false))
	_expect(not _hud.is_skill_hud_visible(), "H hides the skill HUD")
	_expect(not _hud.skill_panel.visible and not _hud.passive_panel.visible, "H hides both and only both skill belts")
	_expect(_unchanged_regions_match(unchanged), "H leaves status, boss, feedback, and overlay visibility unchanged")
	_hud._unhandled_input(_h_key_event(true))
	_expect(not _hud.is_skill_hud_visible(), "H echo does not re-toggle the skill HUD")
	_hud._unhandled_input(_h_key_event(false))
	_expect(_hud.is_skill_hud_visible() and _hud.skill_panel.visible and _hud.passive_panel.visible, "second non-echo H restores both skill belts")


func _test_hidden_hud_preserves_cast_and_cooldown() -> void:
	_hud.set_skill_hud_visible(false)
	_equip_reclaim_for_cooldown_test()
	_enemy.element_carrier.set_amounts_silent(1, 0)
	_player.energy_component.set_current(50)
	_player.skill_executor.advance(10.0)
	var cooldown_skill := _player.skill_controller.get_skill_for_slot(SkillSlotIds.ACTIVE_1)
	_expect(cooldown_skill != null and cooldown_skill.skill_id == &"element_reclaim", "test fixture equips reclaim in active slot one")
	if cooldown_skill == null:
		return
	var attempt := _player.try_cast_slot(SkillSlotIds.ACTIVE_1)
	_expect(attempt.accepted, "active skill can still cast while HUD is hidden")
	var before := _player.skill_executor.get_cooldown_remaining(cooldown_skill.skill_id)
	_player.skill_executor.advance(0.25)
	var after := _player.skill_executor.get_cooldown_remaining(cooldown_skill.skill_id)
	_expect(after < before, "cooldown continues to advance while HUD is hidden")
	_hud.set_skill_hud_visible(true)
	_expect(_hud.skill_panel.visible and _hud.passive_panel.visible, "restoring HUD shows the live skill panels directly")


func _equip_reclaim_for_cooldown_test() -> void:
	var current := _host.runtime_loadout.snapshot()
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for slot_id: StringName in SkillSlotIds.all():
		entries.append(RuntimeLoadoutSlotSnapshot.new(slot_id, &"element_reclaim" if slot_id == SkillSlotIds.ACTIVE_1 else &""))
	var result := _host.runtime_loadout.try_replace_snapshot(RuntimeLoadoutSnapshot.new(entries, current.revision))
	_expect(result.accepted, "cooldown fixture updates through the runtime loadout")


func _h_key_event(is_echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_H
	event.echo = is_echo
	return event


func _unchanged_regions_match(expected: Array) -> bool:
	return expected == [
		_hud.status_panel.visible,
		(_hud.get_node("Root/BossPanel") as Control).visible,
		(_hud.get_node("Root/FeedbackPanel") as Control).visible,
		_hud.run_overlay.visible,
	]


func _run_test(name: String, callback: Callable) -> void:
	await _harness.run_test(name, callback)


func _expect(condition: bool, description: String) -> void:
	_harness.expect(condition, description)
