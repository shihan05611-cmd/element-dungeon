class_name TidalSentry
extends CombatEnemy

## Stationary ranged enemy: gravity-only settling, zero horizontal movement,
## deterministic Player lookup. Ranged attack cadence, aiming, and the
## pre-attack telegraph are entirely inherited from CombatEnemy's shared
## _advance_ranged_attack_cycle()/_launch_ranged_projectile() so this script
## only wires up its own profile default and static physics.

const SENTRY_GRAVITY := 1150.0
const FIRST_PROJECTILE_DELAY := 0.75
const SENTRY_PROJECTILE_PROFILE: EnemyProjectileProfile = preload("res://resources/run/projectiles/tidal_sentry_projectile_profile.tres")


func _ready() -> void:
	add_to_group(&"enemies")
	combat_receiver.configure_components(element_carrier, damage_receiver)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)
	sprite.play(&"idle")
	prompt.visible = false
	ranged_projectile_profile = SENTRY_PROJECTILE_PROFILE
	_boss_projectile_cooldown = FIRST_PROJECTILE_DELAY
	_body_collision_layer = collision_layer
	_body_collision_mask = collision_mask
	var hurtbox := $CombatHurtbox as Area2D
	_hurtbox_collision_layer = hurtbox.collision_layer
	_hurtbox_collision_mask = hurtbox.collision_mask
	_connect_reduced_motion_source()


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
		_advance_ranged_attack_cycle(delta, ranged_projectile_profile, &"tidal_sentry_bolt")
	move_and_slide()
