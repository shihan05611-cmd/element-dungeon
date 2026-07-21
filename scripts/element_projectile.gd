class_name ElementProjectile
extends ProjectileDelivery

@export var water_color := Color("58d9ff")
@export var fire_color := Color("ff754f")

var _element_color := Color.WHITE


func _on_delivery_ready() -> void:
	if payload != null and payload.element_id == ElementIds.WATER:
		_element_color = water_color
	elif payload != null and payload.element_id == ElementIds.FIRE:
		_element_color = fire_color
	else:
		_element_color = Color("f4f1df")
	queue_redraw()
	super()


func _draw() -> void:
	var trail_direction := -direction if not direction.is_zero_approx() else Vector2.LEFT
	draw_line(Vector2.ZERO, trail_direction * 14.0, Color(_element_color, 0.34), 5.0, true)
	draw_circle(Vector2.ZERO, 8.0, Color(0.02, 0.04, 0.08, 0.78))
	draw_circle(Vector2.ZERO, 5.5, _element_color)
	draw_circle(Vector2(-1.5, -1.5), 2.0, Color(1.0, 1.0, 1.0, 0.72))
	draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 20, Color(_element_color, 0.75), 1.5, true)
