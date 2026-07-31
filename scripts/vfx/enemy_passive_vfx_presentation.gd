class_name EnemyPassiveVfxPresentation
extends Node2D

@onready var loop_sprite: AnimatedSprite2D = $Loop
@onready var trigger_sprite: AnimatedSprite2D = $Trigger

var trigger_count: int = 0


func _ready() -> void:
	trigger_sprite.visible = false
	trigger_sprite.animation_finished.connect(_on_trigger_finished)
	loop_sprite.play(&"loop")


func play_trigger() -> void:
	trigger_count += 1
	trigger_sprite.visible = true
	trigger_sprite.frame = 0
	trigger_sprite.play(&"trigger")


func _on_trigger_finished() -> void:
	trigger_sprite.visible = false

