class_name RecordingSkillDelivery
extends DeliveryBase

## Typed test double for the DeliveryBase protocol used by SkillExecutor tests.

@export var reject_initialization: bool = false

var close_count: int = 0


func close_hit_window() -> void:
	close_count += 1


func initialize_delivery(
		p_cast_snapshot: CastSnapshot,
		p_payload: RuntimeAttackPayload,
		p_delivery_id: int,
		p_start_world_transform: Transform2D,
		p_direction: Vector2
) -> bool:
	if reject_initialization:
		return false
	return initialize(
		p_cast_snapshot,
		p_payload,
		p_delivery_id,
		p_start_world_transform,
		p_direction
	)