extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const OUTPUT_DIR := "res://docs/agent_tasks/evidence/task89/screenshots"

var _failures: Array[String] = []
var _room: Node2D
var _player: PlayerCharacter
var _enemy: CombatEnemy
var _boss: CombatEnemy
var _hud: CombatHUD
var _vfx: SkillVfxCoordinator


func _initialize() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await _settle()
	_player = _room.get_node("Player") as PlayerCharacter
	_enemy = _room.get_node("Orc") as CombatEnemy
	_hud = _room.get_node("CombatHUD") as CombatHUD
	_vfx = _room.get_node("SkillVfxCoordinator") as SkillVfxCoordinator
	_player.set_physics_process(false)
	_player.skill_executor.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_enemy.global_position = Vector2(740.0, 470.0)
	_boss = BOSS_SCENE.instantiate() as CombatEnemy
	_room.add_child(_boss)
	_boss.global_position = Vector2(740.0, 500.0)
	_boss.set_physics_process(false)
	_boss.ai_enabled = false
	await process_frame
	_expect(_vfx.set_enemies([_enemy, _boss]), "VFX coordinator observes boss and normal enemy")

	_hud.call("_hide_feedback")
	var switch_result := _player.request_element(ElementIds.FIRE)
	_expect(switch_result.accepted and switch_result.changed, "window capture uses a real manual element switch")
	_expect(not (_hud.get_node("Root/FeedbackPanel") as Control).visible, "manual element switch has no FeedbackPanel")

	_enemy.visible = false
	_set_layers(_boss, 2, 2)
	await _settle()
	_play_boss_triggers()
	await create_timer(0.08).timeout
	await _save("01_boss_fire_water_trigger_1280x720.png")

	_boss.visible = false
	_enemy.visible = true
	_set_layers(_enemy, 2, 2)
	await _settle()
	await _save("02_normal_fire_water_control_1280x720.png")

	_boss.visible = true
	_enemy.visible = false
	_set_layers(_boss, 0, 0)
	await _settle()
	await _save("03_boss_cleared_control_1280x720.png")
	_expect(_vfx.burning_loop_count == 1 and _vfx.unending_loop_count == 1, "only normal control retains its two loops after boss clear")

	_room.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TASK 89 WINDOW CAPTURE PASSED: 3 same-camera screenshots")
		quit(0)
		return
	for failure: String in _failures:
		printerr("TASK 89 WINDOW CAPTURE FAILED: " + failure)
	quit(1)


func _set_layers(enemy: CombatEnemy, water: int, fire: int) -> void:
	var before := enemy.element_carrier.snapshot()
	_expect(enemy.element_carrier.set_amounts_silent(water, fire), "element layers apply")
	enemy.element_carrier.notify_changed(before)


func _play_boss_triggers() -> void:
	for storage_name: StringName in [&"_burning_loops", &"_unending_loops"]:
		var storage := _vfx.get(storage_name) as Dictionary
		var loop := (storage.get(_boss.get_instance_id()) as WeakRef).get_ref() as EnemyPassiveVfxPresentation
		_expect(loop != null and loop.get_parent().name == "ElementAttachmentAnchor", "Boss trigger uses the shared visual anchor")
		if loop != null:
			loop.play_trigger()


func _settle() -> void:
	for _frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image != null, file_name + " has a real Viewport image")
	if image == null:
		return
	if image.get_size() != Vector2i(1280, 720):
		image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	_expect(image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))) == OK, "saved " + file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
