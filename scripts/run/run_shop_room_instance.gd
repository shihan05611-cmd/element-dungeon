class_name RunShopRoomInstance
extends Node2D

@export var exit_transition_zone: Rect2 = Rect2()

var exit_transition: RunWorldInteractable:
	get:
		return $ExitTransitionZone as RunWorldInteractable

var wishing_crown: RunWorldInteractable:
	get:
		return $WishingCrown as RunWorldInteractable


func player_spawn_global_position() -> Vector2:
	return ($PlayerSpawn as Marker2D).global_position


func _ready() -> void:
	exit_transition.set_interaction_region(exit_transition_zone)


func interaction_target_at(player_position: Vector2) -> RunWorldInteractable:
	var crown := wishing_crown
	if crown.can_interact(player_position):
		return crown
	var transition := exit_transition
	return transition if transition.can_interact(player_position) else null


func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true


func deactivate() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
