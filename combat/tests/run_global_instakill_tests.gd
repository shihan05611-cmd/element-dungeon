extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_t_key_mapping()
	await _test_global_instakill_uses_combat_death_flow()
	if _failures.is_empty():
		print("GLOBAL INSTAKILL TESTS PASSED: %d assertions" % _assertions)
		quit(0)
		return
	printerr("GLOBAL INSTAKILL TESTS FAILED: %d assertions" % _assertions)
	for failure: String in _failures:
		printerr("  - " + failure)
	quit(1)


func _test_t_key_mapping() -> void:
	_expect(InputMap.has_action(&"global_instakill"), "global instakill action exists")
	var mapped_to_t := false
	for event: InputEvent in InputMap.action_get_events(&"global_instakill"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_T:
			mapped_to_t = true
	_expect(mapped_to_t, "global instakill action is mapped to physical T")


func _test_global_instakill_uses_combat_death_flow() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	var first := ENEMY_SCENE.instantiate() as CombatEnemy
	var second := ENEMY_SCENE.instantiate() as CombatEnemy
	arena.add_child(player)
	arena.add_child(first)
	arena.add_child(second)
	first.damage_receiver.configure_runtime(75, 75, 12.0)
	second.damage_receiver.configure_runtime(320, 320, 48.0)
	var defeated_signals := [0]
	first.enemy_defeated.connect(func() -> void: defeated_signals[0] += 1)
	second.enemy_defeated.connect(func() -> void: defeated_signals[0] += 1)
	await process_frame

	var defeated_count := player.release_global_instakill()
	_expect(defeated_count == 2, "one release defeats every active enemy")
	_expect(first.defeated and second.defeated, "enemy defeated state is committed")
	_expect(
		first.damage_receiver.current_health == 0 and second.damage_receiver.current_health == 0,
		"enemy health reaches zero through damage receivers"
	)
	_expect(defeated_signals[0] == 2, "normal enemy_defeated signals are emitted")

	var keyboard_target := ENEMY_SCENE.instantiate() as CombatEnemy
	arena.add_child(keyboard_target)
	keyboard_target.damage_receiver.configure_runtime(140, 140, 30.0)
	var t_press := InputEventKey.new()
	t_press.physical_keycode = KEY_T
	t_press.pressed = true
	player._unhandled_input(t_press)
	_expect(keyboard_target.defeated, "a physical T press releases global instakill")
	arena.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
