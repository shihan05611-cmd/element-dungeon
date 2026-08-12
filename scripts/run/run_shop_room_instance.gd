class_name RunShopRoomInstance
extends Node2D

var exit_portal: RunWorldInteractable:
	get:
		return $ExitPortal as RunWorldInteractable


func player_spawn_global_position() -> Vector2:
	return ($PlayerSpawn as Marker2D).global_position


func interaction_target_at(player_position: Vector2) -> RunWorldInteractable:
	var portal := exit_portal
	return portal if portal.can_interact(player_position) else null


func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true


func deactivate() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
