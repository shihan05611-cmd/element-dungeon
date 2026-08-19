class_name EnemyProjectileProfile
extends Resource

## Data-only authority for one enemy ranged attack: which scene to spawn, how
## it aims, whether it telegraphs first, and the shared launch mechanics used
## by every ranged CombatEnemy (Boss branch, Tidal Sentry). Mirrors the
## Resource + validation_error() shape of growth/flow/enemy_spawn_definition.gd.

enum AimMode {
	HORIZONTAL_ONLY,
	AIM_AT_PLAYER,
}

const VERTICAL_ALIGNMENT_DEADZONE_PX := 1.0

@export var projectile_scene: PackedScene
@export_range(0.001, 1000000.0, 0.001, "or_greater") var speed: float = 600.0
@export_range(0.001, 1000000.0, 0.001, "or_greater") var max_distance: float = 1000.0
@export_range(0.0, 1000000.0, 0.001, "or_greater") var damage: float = 8.0
@export var element_id: StringName = &"none"
@export_range(0, 10, 1) var element_amount: int = 0
@export_flags_2d_physics var hurtbox_collision_mask: int = 16
@export_flags_2d_physics var blocking_collision_mask: int = 4
@export_range(0.0, 10.0, 0.001, "or_greater") var telegraph_duration: float = 0.0
@export var aim_mode: AimMode = AimMode.HORIZONTAL_ONLY
@export_range(1.0, 90.0, 0.001, "or_greater") var aim_angle_limit_degrees: float = 60.0
@export_range(1, 32, 1) var spread_count: int = 1
@export_range(0.0, 180.0, 0.001, "or_greater") var spread_angle_degrees: float = 0.0
@export_range(0.0, 1000000.0, 0.001, "or_greater") var spawn_offset_distance: float = 58.0
## Extra rotation (degrees) applied on top of direction.angle() so the sprite's
## drawn-in "forward" lines up with the flight direction. The current
## boss_arc_projectile.png placeholder is left-facing, so this is 180; a
## right-facing texture (Task 60) uses 0.
@export_range(-180.0, 180.0, 0.001, "or_greater") var texture_forward_offset_degrees: float = 180.0
@export_range(0.001, 1000000.0, 0.001, "or_greater") var attack_interval: float = 1.9
## Regular enemies default to true (a hit interrupts the telegraph). Boss
## policy is decided by Task 61; this task only exposes the switch.
@export var cancel_telegraph_on_hurt: bool = true
@export var presentation_tags: PackedStringArray = PackedStringArray()


func validation_error() -> StringName:
	if projectile_scene == null or not projectile_scene.can_instantiate():
		return &"missing_projectile_scene"
	if not is_finite(speed) or speed <= 0.0:
		return &"invalid_speed"
	if not is_finite(max_distance) or max_distance <= 0.0:
		return &"invalid_max_distance"
	if not is_finite(damage) or damage < 0.0:
		return &"invalid_damage"
	if not ElementIds.is_valid_payload_element(element_id):
		return &"invalid_element_id"
	if element_amount < 0 or element_amount > 10:
		return &"invalid_element_amount"
	if element_id == ElementIds.NONE and element_amount != 0:
		return &"none_element_has_amount"
	if hurtbox_collision_mask < 0:
		return &"invalid_hurtbox_collision_mask"
	if blocking_collision_mask < 0:
		return &"invalid_blocking_collision_mask"
	if not is_finite(telegraph_duration) or telegraph_duration < 0.0:
		return &"invalid_telegraph_duration"
	if aim_mode != AimMode.HORIZONTAL_ONLY and aim_mode != AimMode.AIM_AT_PLAYER:
		return &"invalid_aim_mode"
	if not is_finite(aim_angle_limit_degrees) or aim_angle_limit_degrees <= 0.0 or aim_angle_limit_degrees > 90.0:
		return &"invalid_aim_angle_limit"
	if spread_count < 1:
		return &"invalid_spread_count"
	if spread_count > 1 and (not is_finite(spread_angle_degrees) or spread_angle_degrees < 0.0):
		return &"invalid_spread_angle"
	if not is_finite(spawn_offset_distance) or spawn_offset_distance < 0.0:
		return &"invalid_spawn_offset_distance"
	if not is_finite(texture_forward_offset_degrees):
		return &"invalid_texture_forward_offset"
	if not is_finite(attack_interval) or attack_interval <= 0.0:
		return &"invalid_attack_interval"
	return &""


func is_valid() -> bool:
	return validation_error().is_empty()


## Resolves a normalized flight direction from spawn_origin toward
## player_position. HORIZONTAL_ONLY ignores height and always returns
## Vector2.RIGHT/LEFT. AIM_AT_PLAYER points at the player (including height
## difference), falls back to the horizontal facing on exact overlap, and
## clamps the result to aim_angle_limit_degrees away from the horizontal so
## shots never become unreadably vertical.
func resolve_direction(spawn_origin: Vector2, player_position: Vector2, fallback_facing: float) -> Vector2:
	var fallback_sign := 1.0 if not is_zero_approx(fallback_facing) else 1.0
	if not is_zero_approx(fallback_facing):
		fallback_sign = signf(fallback_facing)

	if aim_mode != AimMode.AIM_AT_PLAYER:
		var dir_x := signf(player_position.x - spawn_origin.x)
		if is_zero_approx(dir_x):
			dir_x = fallback_sign
		return Vector2.RIGHT if dir_x >= 0.0 else Vector2.LEFT

	var raw := player_position - spawn_origin
	if raw.is_zero_approx():
		return Vector2.RIGHT if fallback_sign >= 0.0 else Vector2.LEFT
	# Physics floor-settle jitter can leave sub-pixel Y noise between two
	# bodies resting on the same flat ground; without this deadzone that
	# noise would tilt an otherwise level shot by a fraction of a degree.
	if absf(raw.y) < VERTICAL_ALIGNMENT_DEADZONE_PX:
		raw.y = 0.0

	var direction := raw.normalized()
	var horizontal_sign := signf(direction.x)
	if is_zero_approx(horizontal_sign):
		horizontal_sign = fallback_sign

	var limit_rad := deg_to_rad(clampf(aim_angle_limit_degrees, 0.0, 90.0))
	var angle_from_horizontal := atan2(absf(direction.y), absf(direction.x))
	if angle_from_horizontal > limit_rad:
		var vertical_sign := 1.0
		if not is_zero_approx(direction.y):
			vertical_sign = signf(direction.y)
		direction = Vector2(horizontal_sign * cos(limit_rad), vertical_sign * sin(limit_rad))
	return direction.normalized()


## Symmetric fan of directions around base_direction. spread_count == 1
## returns exactly [base_direction] with no rotation.
func spread_directions(base_direction: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	if spread_count <= 1:
		directions.append(base_direction)
		return directions
	var half_width := deg_to_rad(spread_angle_degrees) * 0.5
	var step := deg_to_rad(spread_angle_degrees) / float(spread_count - 1)
	for index in range(spread_count):
		var offset := -half_width + step * float(index)
		directions.append(base_direction.rotated(offset))
	return directions


func spawn_origin_for(entity_origin: Vector2, direction: Vector2) -> Vector2:
	return Vector2(entity_origin.x + direction.x * spawn_offset_distance, entity_origin.y)


## Instantiates, configures and initializes exactly one projectile delivery
## for this shot. Returns null (and frees the half-built node) on any failure.
## Does not add the delivery to the tree — the caller owns that so it can
## choose the correct parent.
func spawn(
		caster: Node2D,
		spawn_transform: Transform2D,
		direction: Vector2,
		cast_source: StringName,
		hit_index: int = 1
) -> ProjectileDelivery:
	if not validation_error().is_empty():
		return null
	var delivery := projectile_scene.instantiate() as ProjectileDelivery
	if delivery == null:
		return null
	delivery.speed = speed
	delivery.max_distance = max_distance
	delivery.hurtbox_collision_mask = hurtbox_collision_mask
	delivery.blocking_collision_mask = blocking_collision_mask
	var cast_snapshot := CastSnapshot.new(
		CombatEnemy._allocate_enemy_cast_id(),
		cast_source,
		caster.get_instance_id(),
		caster.get_instance_id(),
		&"enemy",
		ElementIds.NONE,
		CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(damage, damage, element_id, element_amount, presentation_tags)
	if not delivery.initialize_delivery(cast_snapshot, payload, hit_index, spawn_transform, direction):
		delivery.free()
		return null
	return delivery
