class_name PrototypeSkillCaster
extends Node

signal prototype_skill_cast

@export var projectile_scene: PackedScene
@export var cooldown_seconds := 0.65
@export var spawn_offset := Vector2(46.0, -8.0)

var _cooldown_left := 0.0
var _aim_direction := 1.0


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var horizontal_input := float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) \
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if absf(horizontal_input) > 0.01:
		_aim_direction = signf(horizontal_input)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		_cast_prototype_skill()


func _cast_prototype_skill() -> void:
	if _cooldown_left > 0.0 or projectile_scene == null:
		return
	var host := get_parent() as Node2D
	var scene_root := get_tree().current_scene
	if host == null or scene_root == null:
		return

	_cooldown_left = cooldown_seconds
	var projectile := projectile_scene.instantiate() as Node2D
	scene_root.add_child(projectile)
	projectile.global_position = host.global_position + Vector2(absf(spawn_offset.x) * _aim_direction, spawn_offset.y)
	if projectile.has_method("configure"):
		projectile.configure(_aim_direction)
	prototype_skill_cast.emit()
