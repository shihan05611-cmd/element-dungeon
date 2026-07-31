class_name CombatFeedback
extends Node2D

const UI := preload("res://scripts/ui/combat_ui_tokens.gd")

signal result_observed(result: CombatResult, receiver: CombatReceiver)

const MAX_ACTIVE_LABELS := 28
const MAX_SHOWN_KEYS := 128
const PLAYER_DAMAGE_COLOR := Color("ff9aaa")

@export var reduced_motion: bool = false

var _active_labels: Array[Control] = []
var _observed_receivers: Dictionary = {}
var _observed_deliveries: Dictionary = {}
var _shown_keys: Dictionary = {}
var _shown_order: Array[String] = []
var _spawn_serial: int = 0


func observe_receiver(receiver: CombatReceiver) -> void:
	if receiver == null or not is_instance_valid(receiver):
		return
	var receiver_id := receiver.get_instance_id()
	if _observed_receivers.has(receiver_id):
		return
	_observed_receivers[receiver_id] = weakref(receiver)
	receiver.presentation_requested.connect(_on_committed_result.bind(receiver))


func observe_delivery(delivery: Node) -> void:
	if delivery == null or not is_instance_valid(delivery) or not delivery.has_signal(&"hit_submitted"):
		return
	var delivery_id := delivery.get_instance_id()
	if _observed_deliveries.has(delivery_id):
		return
	_observed_deliveries[delivery_id] = weakref(delivery)
	delivery.hit_submitted.connect(_on_delivery_submission)
	delivery.tree_exited.connect(_on_delivery_exited.bind(delivery_id))


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


func _on_committed_result(result: CombatResult, receiver: CombatReceiver) -> void:
	if result == null or receiver == null:
		return
	result_observed.emit(result, receiver)
	if not result.accepted or result.final_damage <= 0:
		return
	var key := "%d:%d:%d:%d" % [result.cast_id, result.delivery_id, result.hit_index, receiver.get_instance_id()]
	if _shown_keys.has(key):
		return
	_remember_shown_key(key)
	_spawn_damage_number(result, receiver)


func _on_delivery_submission(result: CombatResult, receiver: CombatReceiver, _hurtbox: CombatHurtbox) -> void:
	if result != null and not result.accepted:
		result_observed.emit(result, receiver)


func _on_delivery_exited(delivery_id: int) -> void:
	_observed_deliveries.erase(delivery_id)


func _spawn_damage_number(result: CombatResult, receiver: CombatReceiver) -> void:
	while _active_labels.size() >= MAX_ACTIVE_LABELS:
		var oldest: Control = _active_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	_spawn_serial += 1
	var group := VBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.z_index = 60
	group.add_theme_constant_override(&"separation", -2)
	var targets_player := receiver.target_team_id == &"player"
	var number := Label.new()
	number.name = "FinalDamage"
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_constant_override(&"outline_size", 5)
	number.add_theme_color_override(&"font_outline_color", Color("10131c"))
	number.add_theme_color_override(&"font_color", _color_for_result(result, targets_player))
	number.add_theme_font_size_override(&"font_size", 28 if result.reaction_triggered else 22)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.text = "-%d" % result.final_damage if targets_player else str(result.final_damage)
	group.add_child(number)
	if result.reaction_triggered:
		var detail := Label.new()
		detail.name = "ReactionDetail"
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_theme_constant_override(&"outline_size", 4)
		detail.add_theme_color_override(&"font_outline_color", Color("10131c"))
		detail.add_theme_color_override(&"font_color", UI.WARNING)
		detail.add_theme_font_size_override(&"font_size", 13)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.text = "反应 ×%.1f · 消耗 %d 层" % [result.reaction_multiplier, result.reaction_consumed]
		group.add_child(detail)
	add_child(group)
	var stack_offset := float(_spawn_serial % 5) * 5.0
	group.global_position = result.hit_position + Vector2(-42.0 + stack_offset, -52.0 - stack_offset)
	_active_labels.append(group)
	_animate_label(group, targets_player, result.reaction_triggered)


func presentation_text(result: CombatResult, targets_player: bool = false) -> PackedStringArray:
	if result == null or not result.accepted or result.final_damage <= 0:
		return PackedStringArray()
	var lines := PackedStringArray(["-%d" % result.final_damage if targets_player else str(result.final_damage)])
	if result.reaction_triggered:
		lines.append("反应 ×%.1f · 消耗 %d 层" % [result.reaction_multiplier, result.reaction_consumed])
	return lines


func semantic_damage_summary(result: CombatResult) -> String:
	if result == null or not result.accepted:
		return ""
	return "基础 %.1f · 反应后 %.1f · 最终 %d" % [result.offensive_damage, result.reacted_damage, result.final_damage]


func _animate_label(group: Control, targets_player: bool, is_reaction: bool) -> void:
	if reduced_motion:
		var static_tween := create_tween()
		static_tween.tween_interval(0.72)
		static_tween.tween_callback(_release_label.bind(group))
		return
	group.modulate.a = 0.0
	group.scale = Vector2.ONE * (1.06 if is_reaction else 0.96)
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(group, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(group, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.chain().tween_callback(_animate_label_exit.bind(group, targets_player))


func _animate_label_exit(group: Control, targets_player: bool) -> void:
	if not is_instance_valid(group):
		return
	var drift := Vector2(-10.0, -28.0) if targets_player else Vector2(10.0, -34.0)
	var exit_tween := create_tween().set_parallel(true)
	exit_tween.tween_property(group, "position", group.position + drift, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit_tween.tween_property(group, "modulate:a", 0.0, 0.64).set_delay(0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.chain().tween_callback(_release_label.bind(group))


func _release_label(group: Control) -> void:
	_active_labels.erase(group)
	if is_instance_valid(group):
		group.queue_free()


func _color_for_result(result: CombatResult, targets_player: bool) -> Color:
	if targets_player:
		return PLAYER_DAMAGE_COLOR
	if result.source_element_id == ElementIds.WATER:
		return UI.WATER
	if result.source_element_id == ElementIds.FIRE:
		return UI.FIRE
	return UI.NEUTRAL


func _remember_shown_key(key: String) -> void:
	_shown_keys[key] = true
	_shown_order.append(key)
	while _shown_order.size() > MAX_SHOWN_KEYS:
		var expired: String = _shown_order.pop_front()
		_shown_keys.erase(expired)
