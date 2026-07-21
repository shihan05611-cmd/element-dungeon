class_name CombatFeedback
extends Node2D

signal result_observed(result: CombatResult, receiver: CombatReceiver)

const MAX_ACTIVE_LABELS := 28
const MAX_SHOWN_KEYS := 128
const WATER_COLOR := Color("6ae4ff")
const FIRE_COLOR := Color("ff8968")
const NEUTRAL_COLOR := Color("fff4cf")
const PLAYER_DAMAGE_COLOR := Color("ff9aaa")

@export var reduced_motion: bool = false

var _active_labels: Array[Label] = []
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
	var key := "%d:%d:%d:%d" % [
		result.cast_id,
		result.delivery_id,
		result.hit_index,
		receiver.get_instance_id(),
	]
	if _shown_keys.has(key):
		return
	_remember_shown_key(key)
	_spawn_damage_number(result, receiver)


func _on_delivery_submission(
		result: CombatResult,
		receiver: CombatReceiver,
		_hurtbox: CombatHurtbox
) -> void:
	if result != null and not result.accepted:
		result_observed.emit(result, receiver)


func _on_delivery_exited(delivery_id: int) -> void:
	_observed_deliveries.erase(delivery_id)


func _spawn_damage_number(result: CombatResult, receiver: CombatReceiver) -> void:
	while _active_labels.size() >= MAX_ACTIVE_LABELS:
		var oldest: Label = _active_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	_spawn_serial += 1
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 60
	label.add_theme_constant_override(&"outline_size", 5)
	label.add_theme_color_override(&"font_outline_color", Color("10131c"))
	var targets_player := receiver.target_team_id == &"player"
	var color := _color_for_result(result, targets_player)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", 28 if result.reaction_triggered else 22)
	if result.reaction_triggered:
		label.text = "反应 %d" % result.final_damage
	elif targets_player:
		label.text = "-%d" % result.final_damage
	else:
		label.text = str(result.final_damage)
	add_child(label)

	var stack_offset := float(_spawn_serial % 5) * 5.0
	label.global_position = result.hit_position + Vector2(-24.0 + stack_offset, -42.0 - stack_offset)
	_active_labels.append(label)
	_animate_label(label, targets_player, result.reaction_triggered)


func _animate_label(label: Label, targets_player: bool, is_reaction: bool) -> void:
	if reduced_motion:
		var static_tween := create_tween()
		static_tween.tween_interval(0.58)
		static_tween.tween_property(label, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		static_tween.tween_callback(_release_label.bind(label))
		return

	label.modulate.a = 0.0
	label.scale = Vector2.ONE * (1.08 if is_reaction else 0.94)
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(label, "modulate:a", 1.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(label, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await entrance.finished
	if not is_instance_valid(label):
		return
	var drift := Vector2(-12.0, -30.0) if targets_player else Vector2(12.0, -38.0)
	var exit_tween := create_tween().set_parallel(true)
	exit_tween.tween_property(label, "position", label.position + drift, 0.68).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit_tween.tween_property(label, "modulate:a", 0.0, 0.68).set_delay(0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.chain().tween_callback(_release_label.bind(label))


func _release_label(label: Label) -> void:
	_active_labels.erase(label)
	if is_instance_valid(label):
		label.queue_free()


func _color_for_result(result: CombatResult, targets_player: bool) -> Color:
	if targets_player:
		return PLAYER_DAMAGE_COLOR
	if result.source_element_id == ElementIds.WATER:
		return WATER_COLOR
	if result.source_element_id == ElementIds.FIRE:
		return FIRE_COLOR
	return NEUTRAL_COLOR


func _remember_shown_key(key: String) -> void:
	_shown_keys[key] = true
	_shown_order.append(key)
	while _shown_order.size() > MAX_SHOWN_KEYS:
		var expired: String = _shown_order.pop_front()
		_shown_keys.erase(expired)

