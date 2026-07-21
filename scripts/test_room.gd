extends Node2D

@onready var player: PlayerCharacter = $Player
@onready var target: CombatEnemy = $Orc
@onready var feedback: CombatFeedback = $WorldFeedbackLayer
@onready var hud: CombatHUD = $CombatHUD


func _ready() -> void:
	feedback.observe_receiver(player.combat_receiver)
	feedback.observe_receiver(target.combat_receiver)
	player.delivery_created.connect(_on_delivery_created)
	target.delivery_created.connect(_on_delivery_created)
	hud.configure(player, target, feedback)
	hud.reduced_motion_changed.connect(feedback.set_reduced_motion)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_combat_test"):
		get_viewport().set_input_as_handled()
		call_deferred(&"_reload_room")


func _on_delivery_created(delivery: Node) -> void:
	feedback.observe_delivery(delivery)


func _reload_room() -> void:
	get_tree().reload_current_scene()


func _draw() -> void:
	# Side-view dungeon backdrop.
	draw_rect(Rect2(0, 0, 1152, 648), Color("0c0f18"))
	draw_rect(Rect2(48, 48, 1056, 520), Color("1b2130"))

	# Back-wall masonry.
	for row in range(1, 10):
		var y := 62.0 + row * 46.0
		var offset := 24.0 if row % 2 == 0 else 0.0
		for column in range(23):
			var x := 52.0 + column * 48.0 - offset
			draw_rect(Rect2(x, y, 46, 44), Color("242c3b"), true)
			draw_line(Vector2(x, y + 44), Vector2(x + 46, y + 44), Color("151b27"), 2.0)

	# Recessed arches suggest exits without adding gameplay doors yet.
	for center_x in [160.0, 992.0]:
		draw_circle(Vector2(center_x, 245), 76.0, Color("111722"))
		draw_rect(Rect2(center_x - 76, 245, 152, 271), Color("111722"))
		draw_arc(Vector2(center_x, 245), 84.0, PI, TAU, 32, Color("394357"), 9.0)
		draw_line(Vector2(center_x - 84, 245), Vector2(center_x - 84, 516), Color("394357"), 9.0)
		draw_line(Vector2(center_x + 84, 245), Vector2(center_x + 84, 516), Color("394357"), 9.0)

	# Pillars and hanging chains create readable vertical depth.
	for x in [286.0, 576.0, 866.0]:
		draw_rect(Rect2(x - 13, 76, 26, 440), Color("30394b"))
		draw_rect(Rect2(x - 19, 76, 38, 18), Color("465168"))
		draw_rect(Rect2(x - 20, 496, 40, 20), Color("465168"))
	for x in [430.0, 722.0]:
		for y in range(92, 230, 18):
			draw_circle(Vector2(x, y), 6.0, Color("50596c"), false, 3.0)

	# Torches.
	for point in [Vector2(338, 176), Vector2(814, 176)]:
		draw_rect(Rect2(point.x - 4, point.y, 8, 34), Color("614131"))
		draw_circle(point, 16.0, Color("d85b3e"))
		draw_circle(point + Vector2(0, -4), 9.0, Color("ffd166"))

	# Foreground vignette strips.
	draw_rect(Rect2(0, 0, 1152, 48), Color("090c13"))
	draw_rect(Rect2(0, 600, 1152, 48), Color("090c13"))
