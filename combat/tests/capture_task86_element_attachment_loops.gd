extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/run/enemies/boss_tide_ember.tscn")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task86"

var _room: Node2D
var _enemy: CombatEnemy
var _boss: BossTideEmber
var _coordinator: SkillVfxCoordinator


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR)) != OK:
		printerr("TASK 86 evidence directory creation failed")
		quit(1)
		return
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	root.size = Vector2i(1280, 720)
	await process_frame
	await physics_frame
	_enemy = _room.get_node("Orc") as CombatEnemy
	_enemy.set_physics_process(false)
	_enemy.ai_enabled = false
	_coordinator = _room.get_node("SkillVfxCoordinator") as SkillVfxCoordinator

	_set_elements(0, 2)
	await _capture("01_no_passive_fire_attachment.png")
	_set_elements(2, 0)
	await _capture("02_no_passive_water_attachment.png")
	_set_elements(2, 2)
	await _capture("03_no_passive_dual_attachment.png")
	_set_elements(0, 0)
	await _capture("04_elements_cleared.png")
	_boss = BOSS_SCENE.instantiate() as BossTideEmber
	_room.add_child(_boss)
	_boss.global_position = Vector2(930.0, 565.0)
	await physics_frame
	_boss.set_physics_process(false)
	_boss.ai_enabled = false
	_coordinator.set_enemies([_enemy, _boss])
	_set_boss_elements(0, 2)
	await _capture("05_boss_no_passive_fire_attachment.png")
	_set_boss_elements(2, 0)
	await _capture("06_boss_no_passive_water_attachment.png")
	_set_boss_elements(2, 2)
	await _capture("07_boss_no_passive_dual_attachment.png")
	_set_boss_elements(0, 0)
	await _capture("08_boss_elements_cleared.png")

	print("TASK 86 WINDOW CAPTURE COMPLETE: 8 screenshots")
	quit(0)


func _set_elements(water: int, fire: int) -> void:
	var before := _enemy.element_carrier.snapshot()
	if not _enemy.element_carrier.set_amounts_silent(water, fire):
		printerr("TASK 86 fixture element replacement rejected")
		quit(1)
		return
	_enemy.element_carrier.notify_changed(before)


func _set_boss_elements(water: int, fire: int) -> void:
	var before := _boss.element_carrier.snapshot()
	if not _boss.element_carrier.set_amounts_silent(water, fire):
		printerr("TASK 86 boss fixture element replacement rejected")
		quit(1)
		return
	_boss.element_carrier.notify_changed(before)


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s" % [EVIDENCE_DIR, file_name])
	if image.save_png(path) != OK:
		printerr("TASK 86 capture failed: " + path)
		quit(1)
		return
	print("CAPTURED " + path)
