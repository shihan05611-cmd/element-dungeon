class_name TidalSentry
extends CombatEnemy

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/run/boss_arc_projectile.tscn")
const SENTRY_GRAVITY := 1150.0
const PROJECTILE_INTERVAL := 1.9
const FIRST_PROJECTILE_DELAY := 0.75
const PROJECTILE_SPAWN_OFFSET := 58.0

var projectiles_fired: int = 0
var _projectile_cooldown: float = FIRST_PROJECTILE_DELAY


func _ready() -> void:
	add_to_group(&"enemies")
	combat_receiver.configure_components(element_carrier, damage_receiver)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)
	sprite.play(&"idle")
	prompt.visible = false
	_body_collision_layer = collision_layer
	_body_collision_mask = collision_mask
	var hurtbox := $CombatHurtbox as Area2D
	_hurtbox_collision_layer = hurtbox.collision_layer
	_hurtbox_collision_mask = hurtbox.collision_mask


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + SENTRY_GRAVITY * delta, 760.0)
	velocity.x = 0.0
	if defeated:
		move_and_slide()
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if ai_enabled and is_on_floor() and is_instance_valid(player):
		_projectile_cooldown = maxf(0.0, _projectile_cooldown - delta)
		if _projectile_cooldown <= 0.0:
			_spawn_tidal_projectile()
			_projectile_cooldown = PROJECTILE_INTERVAL
	move_and_slide()


func _spawn_tidal_projectile() -> void:
	if defeated or not is_instance_valid(player):
		return
	var delivery := PROJECTILE_SCENE.instantiate() as ProjectileDelivery
	if delivery == null:
		return
	var direction_x := signf(player.global_position.x - global_position.x)
	if is_zero_approx(direction_x):
		direction_x = -1.0
	facing = direction_x
	sprite.flip_h = facing < 0.0
	var direction := Vector2.RIGHT if direction_x > 0.0 else Vector2.LEFT
	var spawn_transform := Transform2D(
		0.0,
		Vector2(global_position.x + direction.x * PROJECTILE_SPAWN_OFFSET, global_position.y)
	)
	var cast_snapshot := CastSnapshot.new(
		CombatEnemy._allocate_enemy_cast_id(),
		&"tidal_sentry_bolt",
		get_instance_id(),
		get_instance_id(),
		&"enemy",
		ElementIds.NONE,
		CombatStatSnapshot.new(),
	)
	var payload := RuntimeAttackPayload.new(
		8.0,
		8.0,
		ElementIds.NONE,
		0,
		PackedStringArray(["tidal_sentry_projectile"]),
	)
	if not delivery.initialize_delivery(cast_snapshot, payload, 1, spawn_transform, direction):
		delivery.free()
		return
	get_tree().current_scene.add_child(delivery)
	projectiles_fired += 1
	boss_projectiles_fired = projectiles_fired
	delivery_created.emit(delivery)
