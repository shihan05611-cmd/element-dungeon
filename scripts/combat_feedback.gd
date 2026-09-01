class_name CombatFeedback
extends Node2D

const UI := preload("res://scripts/ui/combat_ui_tokens.gd")
const REACTION_VISUAL_SCENE: PackedScene = preload("res://combat/presentation/element_reaction_visual.tscn")
const PIXEL_FONT: Font = preload("res://assets/ui/fonts/fusion_pixel_12px/fusion-pixel-12px-proportional-zh_hans.otf")

signal result_observed(result: CombatResult, receiver: CombatReceiver)

const MAX_ACTIVE_LABELS := 28
const MAX_ACTIVE_REACTION_VISUALS := 16
const MAX_SHOWN_KEYS := 128
const PLAYER_DAMAGE_COLOR := Color("ff9aaa")

@export var reduced_motion: bool = false

var _active_labels: Array[Control] = []
var _active_reaction_visuals: Array[Node2D] = []
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
	_prune_labels()
	while _active_labels.size() >= MAX_ACTIVE_LABELS:
		var oldest: Control = _active_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	_spawn_serial += 1
	var group := VBoxContainer.new()
	group.name = "DamageFeedback_%d" % _spawn_serial
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
	number.add_theme_font_override(&"font", PIXEL_FONT)
	number.add_theme_font_size_override(&"font_size", 28 if result.reaction_triggered else 22)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.text = "-%d" % result.final_damage if targets_player else str(result.final_damage)
	group.add_child(number)
	if result.reaction_triggered:
		var cue := Label.new()
		cue.name = "ReactionCue"
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cue.add_theme_constant_override(&"outline_size", 4)
		cue.add_theme_color_override(&"font_outline_color", Color("10131c"))
		cue.add_theme_color_override(&"font_color", UI.WARNING)
		cue.add_theme_font_override(&"font", PIXEL_FONT)
		cue.add_theme_font_size_override(&"font_size", 16)
		cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cue.text = "反应"
		group.add_child(cue)
	add_child(group)
	var stack_offset := float(_spawn_serial % 5) * 5.0
	group.global_position = result.hit_position + Vector2(-42.0 + stack_offset, -52.0 - stack_offset)
	_active_labels.append(group)
	if result.reaction_triggered:
		_spawn_reaction_visual(result, receiver)
	_animate_label(group, targets_player, result.reaction_triggered)


func presentation_text(result: CombatResult, targets_player: bool = false) -> PackedStringArray:
	if result == null or not result.accepted or result.final_damage <= 0:
		return PackedStringArray()
	var lines := PackedStringArray(["-%d" % result.final_damage if targets_player else str(result.final_damage)])
	if result.reaction_triggered:
		lines.append("反应")
	return lines


func semantic_damage_summary(result: CombatResult) -> String:
	if result == null or not result.accepted:
		return ""
	return "基础 %.1f · 反应倍率 %.1f · 消耗 %d 层 · 反应后 %.1f · 最终 %d" % [
		result.offensive_damage,
		result.reaction_multiplier,
		result.reaction_consumed,
		result.reacted_damage,
		result.final_damage,
	]


func active_reaction_visual_count() -> int:
	_prune_reaction_visuals()
	return _active_reaction_visuals.size()


func _spawn_reaction_visual(result: CombatResult, receiver: CombatReceiver = null) -> void:
	_prune_reaction_visuals()
	while _active_reaction_visuals.size() >= MAX_ACTIVE_REACTION_VISUALS:
		var oldest: Node2D = _active_reaction_visuals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var visual := REACTION_VISUAL_SCENE.instantiate() as Node2D
	visual.name = "ReactionComposition_%d" % _spawn_serial
	add_child(visual)
	visual.global_position = result.hit_position
	var target := _reaction_visual_target(receiver)
	if target != null:
		var local_hit_offset := target.to_local(result.hit_position)
		visual.call(&"follow_target", target, local_hit_offset)
	_active_reaction_visuals.append(visual)
	visual.tree_exited.connect(_on_reaction_visual_exited.bind(visual))
	visual.call(&"configure", result.source_element_id, result.reaction_consumed, reduced_motion)


func _reaction_visual_target(receiver: CombatReceiver) -> Node2D:
	if receiver == null or not is_instance_valid(receiver) or receiver.is_queued_for_deletion():
		return null
	var target := receiver.get_parent() as Node2D
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree():
		return null
	return target


func _on_reaction_visual_exited(visual: Node2D) -> void:
	_active_reaction_visuals.erase(visual)


func _prune_reaction_visuals() -> void:
	for index: int in range(_active_reaction_visuals.size() - 1, -1, -1):
		if not is_instance_valid(_active_reaction_visuals[index]) or _active_reaction_visuals[index].is_queued_for_deletion():
			_active_reaction_visuals.remove_at(index)


func _animate_label(group: Control, targets_player: bool, is_reaction: bool) -> void:
	if reduced_motion:
		var static_tween := create_tween()
		static_tween.tween_interval(0.26 if is_reaction else 0.60)
		static_tween.tween_property(group, "modulate:a", 0.0, 0.12)
		static_tween.tween_callback(_release_label.bind(group))
		return
	group.modulate.a = 0.0
	group.scale = Vector2.ONE * (1.06 if is_reaction else 0.96)
	var entrance := create_tween().set_parallel(true)
	var entrance_duration := 0.07 if is_reaction else 0.10
	entrance.tween_property(group, "modulate:a", 1.0, entrance_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(group, "scale", Vector2.ONE, entrance_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.chain().tween_callback(_animate_label_exit.bind(group, targets_player, is_reaction))


func _animate_label_exit(group: Control, targets_player: bool, is_reaction: bool) -> void:
	if not is_instance_valid(group):
		return
	var drift := Vector2(0.0, -22.0) if is_reaction else Vector2(-10.0, -28.0) if targets_player else Vector2(10.0, -34.0)
	var exit_duration := 0.30 if is_reaction else 0.64
	var exit_tween := create_tween().set_parallel(true)
	exit_tween.tween_property(group, "position", group.position + drift, exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit_tween.tween_property(group, "modulate:a", 0.0, exit_duration).set_delay(0.0 if is_reaction else 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.chain().tween_callback(_release_label.bind(group))


func _release_label(group: Control) -> void:
	_active_labels.erase(group)
	if is_instance_valid(group):
		group.queue_free()


func _prune_labels() -> void:
	for index: int in range(_active_labels.size() - 1, -1, -1):
		if not is_instance_valid(_active_labels[index]) or _active_labels[index].is_queued_for_deletion():
			_active_labels.remove_at(index)


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
