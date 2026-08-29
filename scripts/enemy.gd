class_name CombatEnemy
extends CharacterBody2D

signal delivery_created(delivery: Node)
signal enemy_defeated

const ENEMY_MELEE_SCENE: PackedScene = preload("res://scenes/transient_melee_delivery.tscn")
const WALK_SPEED := 78.0
const CHASE_SPEED := 118.0
const GRAVITY := 1150.0
const DETECTION_DISTANCE := 260.0
const ATTACK_DISTANCE := 66.0
const ATTACK_DURATION := 0.55

@export var ai_enabled: bool = true
@export var growth_enemy_id: StringName = &"orc_1"
@export_range(0, 1000000, 1, "or_greater") var experience_reward: int = 50
@export_range(0, 1000000, 1, "or_greater") var dream_dust_reward: int = 0
## Pure data flag consumed by growth/flow (final-room dream-dust rules,
## scripts/run_session_host.gd:435's kill event) -- Task 61 retired the last
## behavior branch that used to read it inside this script.
@export var terminal_enemy: bool = false
@export var ranged_projectile_profile: EnemyProjectileProfile = preload("res://resources/run/projectiles/boss_arc_projectile_profile.tres")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt
@onready var damage_receiver: DamageReceiver = $DamageReceiver
@onready var element_carrier: ElementCarrier = $ElementCarrier
@onready var combat_receiver: CombatReceiver = $CombatReceiver
@onready var telegraph_indicator: EnemyTelegraphIndicator = get_node_or_null("EnemyTelegraphIndicator") as EnemyTelegraphIndicator

var player: PlayerCharacter
var facing: float = -1.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var attack_cooldown: float = 0.4
var impact_sent: bool = false
var patrol_target_x: float = 820.0
var defeated: bool = false
var rng := RandomNumberGenerator.new()
var reinforcement_dormant: bool = false
var boss_projectiles_fired: int = 0

## Task 61 §3.8: opt-in poise. Regular enemies keep the legacy "every hit
## interrupts" behavior (poise_enabled = false); the Boss subclass turns this
## on so frequent player hits neither cancel its attack/telegraph nor
## displace it, and only a poise break opens a real stagger window.
var poise_enabled: bool = false
@export_range(1, 999999, 1) var poise_hit_threshold: int = 6
@export_range(0.1, 30.0, 0.001, "or_greater") var poise_break_stun_duration: float = 1.75
var poise_hits: int = 0
var poise_stun_time: float = 0.0

## Generic ranged-attack-cycle state consumed by _advance_ranged_attack_cycle()
## (see its doc comment). The "_boss_" prefix predates this generalization
## and is kept verbatim -- scripts/run/enemies/tidal_sentry.gd:23 assigns
## _boss_projectile_cooldown by this exact name and is outside Task 61's
## allowlist, so it cannot be renamed here without also touching that file.
var _boss_projectile_cooldown: float = 1.9
var _telegraph_active: bool = false
var _telegraph_time_remaining: float = 0.0
var _telegraph_locked_direction: Vector2 = Vector2.RIGHT
var _body_collision_layer: int = 0
var _body_collision_mask: int = 0
var _hurtbox_collision_layer: int = 0
var _hurtbox_collision_mask: int = 0
var _formal_run_spawn: bool = false

static var _last_enemy_cast_id: int = 1_000_000_000


func configure_run_spawn(
		definition: EnemySpawnDefinition,
		is_terminal_enemy: bool = false
) -> bool:
	if definition == null or not definition.validation_error(is_terminal_enemy).is_empty():
		return false
	growth_enemy_id = definition.enemy_id
	experience_reward = 0
	dream_dust_reward = definition.dream_dust_reward
	terminal_enemy = is_terminal_enemy
	_formal_run_spawn = true
	if damage_receiver == null:
		return false
	return damage_receiver.configure_runtime(
		definition.maximum_health,
		definition.maximum_health,
		definition.defense_flat
	)


func configure_runtime_summon(maximum_health: int) -> bool:
	if maximum_health <= 0 or damage_receiver == null or defeated:
		return false
	experience_reward = 0
	dream_dust_reward = 0
	terminal_enemy = false
	_formal_run_spawn = true
	return damage_receiver.configure_runtime(
		maximum_health,
		maximum_health,
		damage_receiver.defense_flat
	)


func _ready() -> void:
	add_to_group(&"enemies")
	combat_receiver.configure_components(element_carrier, damage_receiver)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)
	rng.randomize()
	sprite.play(&"idle")
	_choose_patrol_target()
	_body_collision_layer = collision_layer
	_body_collision_mask = collision_mask
	var hurtbox := $CombatHurtbox as Area2D
	_hurtbox_collision_layer = hurtbox.collision_layer
	_hurtbox_collision_mask = hurtbox.collision_mask
	_connect_reduced_motion_source()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 760.0)

	if defeated:
		velocity.x = move_toward(velocity.x, 0.0, 560.0 * delta)
		move_and_slide()
		return

	if not ai_enabled:
		velocity.x = move_toward(velocity.x, 0.0, 560.0 * delta)
		move_and_slide()
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
		move_and_slide()
		return

	var horizontal_distance := absf(global_position.x - player.global_position.x)
	var vertical_distance := absf(global_position.y - player.global_position.y)
	prompt.visible = horizontal_distance < 112.0 and vertical_distance < 78.0 and hurt_time <= 0.0
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)

	if poise_stun_time > 0.0:
		poise_stun_time = maxf(0.0, poise_stun_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, 560.0 * delta)
		move_and_slide()
		if poise_stun_time <= 0.0:
			sprite.play(&"idle")
		return

	if hurt_time > 0.0:
		hurt_time = maxf(0.0, hurt_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, 560.0 * delta)
		move_and_slide()
		if hurt_time <= 0.0:
			sprite.play(&"idle")
		return

	if attack_time > 0.0:
		attack_time = maxf(0.0, attack_time - delta)
		velocity.x = 0.0
		if not impact_sent and attack_time <= 0.30:
			impact_sent = true
			_spawn_melee_delivery()
		move_and_slide()
		if attack_time <= 0.0:
			sprite.play(&"idle")
		return

	if horizontal_distance <= ATTACK_DISTANCE and vertical_distance < 74.0 and attack_cooldown <= 0.0:
		_start_attack()
		return

	var target_x := patrol_target_x
	var speed := WALK_SPEED
	if horizontal_distance < DETECTION_DISTANCE:
		target_x = player.global_position.x
		speed = CHASE_SPEED
	elif absf(global_position.x - patrol_target_x) < 12.0:
		_choose_patrol_target()
		target_x = patrol_target_x

	var direction_x := signf(target_x - global_position.x)
	velocity.x = direction_x * speed
	if direction_x != 0.0:
		facing = direction_x
		sprite.flip_h = facing < 0.0
		if sprite.animation != &"walk":
			sprite.play(&"walk")
	elif sprite.animation != &"idle":
		sprite.play(&"idle")
	move_and_slide()


func _start_attack() -> void:
	attack_time = ATTACK_DURATION
	attack_cooldown = 1.15
	impact_sent = false
	facing = signf(player.global_position.x - global_position.x)
	if is_zero_approx(facing):
		facing = 1.0
	sprite.flip_h = facing < 0.0
	sprite.play(&"attack")


func _spawn_melee_delivery() -> void:
	if defeated or not is_instance_valid(player):
		return
	var delivery := ENEMY_MELEE_SCENE.instantiate() as MeleeDelivery
	if delivery == null:
		return
	delivery.hurtbox_collision_mask = 16
	delivery.query_offset = Vector2(38.0, 0.0)
	var cast_snapshot := CastSnapshot.new(
		_allocate_enemy_cast_id(),
		&"enemy_claw",
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
		PackedStringArray(["enemy_melee"]),
	)
	var direction := Vector2.RIGHT if facing >= 0.0 else Vector2.LEFT
	if not delivery.initialize_delivery(
		cast_snapshot,
		payload,
		1,
		global_transform,
		direction,
	):
		delivery.free()
		return
	get_tree().current_scene.add_child(delivery)
	delivery_created.emit(delivery)
	get_tree().create_timer(0.12).timeout.connect(_finish_delivery.bind(weakref(delivery)))


func set_reinforcement_dormant(dormant: bool) -> void:
	reinforcement_dormant = dormant
	visible = not dormant
	process_mode = Node.PROCESS_MODE_DISABLED if dormant else Node.PROCESS_MODE_INHERIT
	ai_enabled = not dormant
	collision_layer = 0 if dormant else _body_collision_layer
	collision_mask = 0 if dormant else _body_collision_mask
	var hurtbox := $CombatHurtbox as Area2D
	hurtbox.collision_layer = 0 if dormant else _hurtbox_collision_layer
	hurtbox.collision_mask = 0 if dormant else _hurtbox_collision_mask
	hurtbox.monitorable = not dormant
	combat_receiver.accepting_hits = not dormant and not defeated


## Generic ranged-attack cycle, not gated by terminal_enemy or any other
## flag: decrements the cooldown while idle, begins a telegraph once it
## elapses, and advances/fires an already-active telegraph. Both
## BossTideEmber and TidalSentry inherit this and call it directly from
## their own _physics_process() override (CombatEnemy's own
## _physics_process() never calls it). Kept on CombatEnemy rather than
## duplicated into each subclass because both consumers need the identical
## behavior and TidalSentry's script is outside Task 61's allowlist.
func _advance_ranged_attack_cycle(delta: float, profile: EnemyProjectileProfile, cast_source: StringName) -> void:
	if _telegraph_active:
		velocity.x = 0.0
		_telegraph_time_remaining -= delta
		if telegraph_indicator != null:
			telegraph_indicator.advance(delta)
		if _telegraph_time_remaining <= 0.0:
			_telegraph_active = false
			_launch_ranged_projectile(profile, _telegraph_locked_direction, cast_source)
			_boss_projectile_cooldown = profile.attack_interval if profile != null else 1.9
		return
	_boss_projectile_cooldown = maxf(0.0, _boss_projectile_cooldown - delta)
	if _boss_projectile_cooldown <= 0.0:
		_begin_ranged_attack_telegraph(profile, cast_source)


func _begin_ranged_attack_telegraph(profile: EnemyProjectileProfile, cast_source: StringName) -> void:
	if defeated or profile == null or not profile.validation_error().is_empty() or not is_instance_valid(player):
		return
	var direction := _resolve_accurate_direction(profile, player.global_position)
	_apply_facing(direction)
	if profile.telegraph_duration <= 0.0:
		_launch_ranged_projectile(profile, direction, cast_source)
		_boss_projectile_cooldown = profile.attack_interval
		return
	_telegraph_active = true
	_telegraph_locked_direction = direction
	_telegraph_time_remaining = profile.telegraph_duration
	velocity.x = 0.0
	if telegraph_indicator != null:
		telegraph_indicator.start(profile.telegraph_duration)


## Two-pass aim toward target_position: a direction computed from the
## enemy's raw origin would end up parallel-shifted once the horizontal-only
## spawn offset is applied (see _launch_ranged_projectile), missing a real
## non-horizontal target, so the direction is resolved a second time from the
## actual spawn point that offset produces. The result is what gets locked
## for a telegraphed shot or used immediately for an instant one.
func _resolve_accurate_direction(profile: EnemyProjectileProfile, target_position: Vector2) -> Vector2:
	var rough_direction := profile.resolve_direction(global_position, target_position, facing)
	var spawn_origin := profile.spawn_origin_for(global_position, rough_direction)
	return profile.resolve_direction(spawn_origin, target_position, facing)


func _apply_facing(direction: Vector2) -> void:
	if not is_zero_approx(direction.x):
		facing = signf(direction.x)
		sprite.flip_h = facing < 0.0


## Finds the live combat HUD (present under RunFlowCoordinator/test_room as a
## child literally named "CombatHUD") and mirrors its real reduced_motion
## state onto this enemy's telegraph indicator, then keeps following future
## toggles. Safe to call with no HUD in the tree (unit tests, bare fixtures):
## the indicator just stays on its animated default.
func _connect_reduced_motion_source() -> void:
	if telegraph_indicator == null:
		return
	var hud := get_tree().root.find_child("CombatHUD", true, false) as CombatHUD
	if hud == null:
		return
	telegraph_indicator.set_reduced_motion(hud.reduced_motion)
	if not hud.reduced_motion_changed.is_connected(_on_hud_reduced_motion_changed):
		hud.reduced_motion_changed.connect(_on_hud_reduced_motion_changed)


func _on_hud_reduced_motion_changed(enabled: bool) -> void:
	if telegraph_indicator != null:
		telegraph_indicator.set_reduced_motion(enabled)


func _cancel_ranged_attack_telegraph() -> void:
	if not _telegraph_active:
		return
	_telegraph_active = false
	_telegraph_time_remaining = 0.0
	# A cancelled telegraph must not leave the cooldown at/below zero, or the
	# very next physics tick would immediately begin a new telegraph.
	if ranged_projectile_profile != null:
		_boss_projectile_cooldown = ranged_projectile_profile.attack_interval
	if telegraph_indicator != null:
		telegraph_indicator.cancel()


## The one place that actually instantiates/initializes/adds a ranged
## delivery for an already-resolved direction (see _resolve_accurate_direction);
## spread_count > 1 fans this out into several independent deliveries from
## the same profile. The spawn point sits spawn_offset_distance to the side
## of the enemy's own current origin, horizontal-only, so it never changes
## spawn height and stays inside the ground clearance already proven safe.
func _launch_ranged_projectile(profile: EnemyProjectileProfile, direction: Vector2, cast_source: StringName) -> void:
	if defeated or profile == null or not is_instance_valid(player):
		return
	var spawn_origin := profile.spawn_origin_for(global_position, direction)
	var launched_any := false
	for shot_direction: Vector2 in profile.spread_directions(direction):
		var spawn_transform := Transform2D(
			shot_direction.angle() + deg_to_rad(profile.texture_forward_offset_degrees),
			spawn_origin
		)
		var delivery := profile.spawn(self, spawn_transform, shot_direction, cast_source)
		if delivery == null:
			continue
		get_tree().current_scene.add_child(delivery)
		launched_any = true
		delivery_created.emit(delivery)
	if launched_any:
		boss_projectiles_fired += 1


func _finish_delivery(reference: WeakRef) -> void:
	var delivery: Variant = reference.get_ref()
	if is_instance_valid(delivery) and not delivery.is_queued_for_deletion():
		delivery.close_hit_window()


func _on_health_state_changed(
		_current_health: int,
		_maximum_health: int,
		delta: int,
		result: CombatResult
) -> void:
	if delta >= 0 or defeated:
		return
	if poise_enabled:
		_on_poise_hit()
		return
	if _telegraph_active and ranged_projectile_profile != null and ranged_projectile_profile.cancel_telegraph_on_hurt:
		_cancel_ranged_attack_telegraph()
	attack_time = 0.0
	hurt_time = 0.42
	attack_cooldown = 0.75
	var away_x := result.hit_direction.x
	if is_zero_approx(away_x):
		away_x = signf(global_position.x - result.hit_position.x)
	if is_zero_approx(away_x):
		away_x = -facing
	velocity.x = signf(away_x) * 230.0
	velocity.y = -105.0
	sprite.play(&"hurt")
	_flash()


## Task 61 §3.8: a poise-enabled enemy (the Boss) never has its attack_time,
## active telegraph, or ranged-attack cycle interrupted by a normal hit --
## only visual feedback (_flash) plays. Hits accumulate; once poise_hits
## reaches poise_hit_threshold, a real stagger opens (poise_stun_time,
## consumed by _physics_process) as the player's output window, then poise
## resets. Deliberately does not touch cancel_telegraph_on_hurt or
## _cancel_ranged_attack_telegraph: the Boss's ranged attack must be able to
## fire while poise is merely accumulating, and even the stagger itself only
## blocks movement/melee (mirroring hurt_time), not an already-launched
## ranged cycle.
func _on_poise_hit() -> void:
	_flash()
	if poise_stun_time > 0.0:
		return
	poise_hits += 1
	if poise_hits < poise_hit_threshold:
		return
	poise_hits = 0
	poise_stun_time = poise_break_stun_duration
	# The poise-break stagger (unlike every hit leading up to it) is meant to
	# be a real, fully vulnerable output window: it is the one moment allowed
	# to interrupt an in-progress ranged telegraph/attack.
	_cancel_ranged_attack_telegraph()
	attack_time = 0.0
	if telegraph_indicator != null:
		telegraph_indicator.cancel()
	sprite.play(&"hurt")


func _on_death_candidate(_result: CombatResult) -> void:
	if defeated:
		return
	defeated = true
	_cancel_ranged_attack_telegraph()
	attack_time = 0.0
	if telegraph_indicator != null:
		telegraph_indicator.cancel()
	hurt_time = 0.0
	velocity = Vector2.ZERO
	combat_receiver.accepting_hits = false
	element_carrier.clear_all()
	prompt.visible = not _formal_run_spawn
	if prompt.visible:
		prompt.text = "已击败 · R 重置"
	sprite.play(&"hurt")
	enemy_defeated.emit()
	if _formal_run_spawn:
		call_deferred("queue_free")


func _choose_patrol_target() -> void:
	patrol_target_x = rng.randf_range(650.0, 982.0)


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.8, 1.5, 1.5), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.13)


static func _allocate_enemy_cast_id() -> int:
	_last_enemy_cast_id += 1
	if _last_enemy_cast_id <= 0:
		_last_enemy_cast_id = 1_000_000_000
	return _last_enemy_cast_id
