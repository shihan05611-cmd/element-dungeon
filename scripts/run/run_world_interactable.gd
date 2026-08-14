class_name RunWorldInteractable
extends Node2D

enum Kind {
	CHEST,
	PORTAL,
	SHOP_EXIT,
	SHOP_CROWN,
}

@export var kind: Kind = Kind.CHEST
@export_range(24.0, 240.0, 1.0) var interaction_distance: float = 96.0
@export var enabled: bool = true
@export var locked: bool = false
@export var prompt_text: String = "按 F 交互"
@export var locked_text: String = "尚未解锁"
@export var locked_texture: Texture2D
@export var active_texture: Texture2D

var consumed: bool:
	get:
		return _consumed

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Label = $Prompt

var _consumed: bool = false


func _ready() -> void:
	_refresh_visual_state()
	_refresh_prompt()


func can_interact(player_position: Vector2) -> bool:
	return enabled and not locked and not _consumed and global_position.distance_to(player_position) <= interaction_distance


func set_locked(value: bool, reason: String = "") -> void:
	locked = value
	if not reason.is_empty():
		locked_text = reason
	_refresh_visual_state()
	_refresh_prompt()


func set_enabled(value: bool) -> void:
	enabled = value
	_refresh_prompt()


func mark_consumed(copy: String = "已使用") -> void:
	_consumed = true
	enabled = false
	prompt_text = copy
	_refresh_prompt()


func open_chest(open_texture: Texture2D, reward_copy: String) -> void:
	if open_texture != null:
		sprite.texture = open_texture
	mark_consumed(reward_copy)
	prompt.visible = true


func _refresh_visual_state() -> void:
	if sprite == null:
		return
	var state_texture := locked_texture if locked else active_texture
	if state_texture != null:
		sprite.texture = state_texture


func _refresh_prompt() -> void:
	if prompt == null:
		return
	prompt.text = "F · %s" % (locked_text if locked else prompt_text)
	prompt.modulate = Color(0.72, 0.72, 0.78) if locked else Color(1.0, 0.9, 0.45)
	prompt.visible = visible and (enabled or _consumed or locked)
