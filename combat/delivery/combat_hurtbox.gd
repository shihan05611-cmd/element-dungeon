class_name CombatHurtbox
extends Area2D

## Explicit collision-to-receiver bridge. It never searches arbitrary parents
## and contains no combat rules.

@export var receiver_path: NodePath
@export var hit_anchor_path: NodePath

var _receiver: CombatReceiver
var _hit_anchor: Node2D


func configure_receiver(receiver: CombatReceiver) -> bool:
	if receiver == null or not is_instance_valid(receiver):
		return false
	if is_inside_tree() and _receiver != null and _receiver != receiver:
		return false
	_receiver = receiver
	return true


func get_combat_receiver() -> CombatReceiver:
	if _is_live_receiver(_receiver):
		return _receiver
	_resolve_paths()
	return _receiver if _is_live_receiver(_receiver) else null


func get_hit_world_position(fallback: Vector2) -> Vector2:
	if _hit_anchor != null and is_instance_valid(_hit_anchor) and not _hit_anchor.is_queued_for_deletion():
		return _hit_anchor.global_position
	if is_inside_tree():
		return global_position
	return fallback


func _ready() -> void:
	_resolve_paths()


func _resolve_paths() -> void:
	if _receiver == null and not receiver_path.is_empty():
		var receiver_node := get_node_or_null(receiver_path)
		if receiver_node is CombatReceiver:
			_receiver = receiver_node
	if _hit_anchor == null and not hit_anchor_path.is_empty():
		var anchor_node := get_node_or_null(hit_anchor_path)
		if anchor_node is Node2D:
			_hit_anchor = anchor_node


static func _is_live_receiver(receiver: Variant) -> bool:
	return (
		is_instance_valid(receiver)
		and receiver is CombatReceiver
		and not receiver.is_queued_for_deletion()
	)




