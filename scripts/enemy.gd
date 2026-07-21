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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt
@onready var damage_receiver: DamageReceiver = $DamageReceiver
@onready var element_carrier: ElementCarrier = $ElementCarrier
@onready var combat_receiver: CombatReceiver = $CombatReceiver

var player: PlayerCharacter
var facing: float = -1.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var attack_cooldown: float = 0.4
var impact_sent: bool = false
var patrol_target_x: float = 820.0
var defeated: bool = false
var rng := RandomNumberGenerator.new()

static var _last_enemy_cast_id: int = 1_000_000_000


func _ready() -> void:
	add_to_group(&"enemies")
	combat_receiver.configure_components(element_carrier, damage_receiver)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)
	rng.randomize()
	sprite.play(&"idle")
	_choose_patrol_target()


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


func _on_death_candidate(_result: CombatResult) -> void:
	if defeated:
		return
	defeated = true
	attack_time = 0.0
	hurt_time = 0.0
	velocity = Vector2.ZERO
	combat_receiver.accepting_hits = false
	element_carrier.clear_all()
	prompt.visible = true
	prompt.text = "已击败 · R 重置"
	sprite.play(&"hurt")
	enemy_defeated.emit()


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
