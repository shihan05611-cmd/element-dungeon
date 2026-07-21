class_name PrototypeElementBolt
extends Area2D

@export var travel_speed := 470.0
@export var max_distance := 620.0

@onready var core: Node2D = $Core
@onready var glow: PointLight2D = $Glow
@onready var trail: Line2D = $Trail
@onready var trail_particles: CPUParticles2D = $TrailParticles
@onready var impact_particles: CPUParticles2D = $ImpactParticles

var _direction := 1.0
var _distance_travelled := 0.0
var _active := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	trail.clear_points()
	_update_directional_effects()


func configure(direction: float) -> void:
	_direction = signf(direction)
	if _direction == 0.0:
		_direction = 1.0
	_update_directional_effects()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var step := Vector2(_direction * travel_speed * delta, 0.0)
	global_position += step
	_distance_travelled += absf(step.x)
	trail.add_point(global_position)
	while trail.get_point_count() > 13:
		trail.remove_point(0)
	if _distance_travelled >= max_distance:
		_burst(null)


func _update_directional_effects() -> void:
	if not is_node_ready():
		return
	trail_particles.direction = Vector2(-_direction, 0.0)


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	_burst(body)


func _burst(body: Node) -> void:
	_active = false
	set_deferred("monitoring", false)
	trail_particles.emitting = false
	core.visible = false
	if body != null and body.has_method("receive_interaction"):
		body.receive_interaction(global_position - Vector2(_direction * 16.0, 0.0))
	impact_particles.emitting = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(glow, "energy", 0.0, 0.30)
	tween.tween_property(trail, "width", 0.0, 0.24)
	tween.chain().tween_callback(queue_free)
