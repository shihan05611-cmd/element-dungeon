class_name CombatEnemy
extends CharacterBody2D

signal delivery_created(delivery: Node)
signal enemy_defeated

const ENEMY_MELEE_SCENE: PackedScene = preload("res://scenes/transient_melee_delivery.tscn")
const BOSS_PROJECTILE_SCENE: PackedScene = preload("res://scenes/run/boss_arc_projectile.tscn")
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
@export var terminal_enemy: bool = false

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
var reinforcement_dormant: bool = false
var boss_visual_scale: float = 1.0
var boss_projectiles_fired: int = 0
var _boss_projectile_cooldown: float = 1.9
var _body_collision_layer: int = 0
var _body_collision_mask: int = 0
var _hurtbox_collision_layer: int = 0
var _hurtbox_collision_mask: int = 0

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
	if damage_receiver == null:
		return false
	var configured := damage_receiver.configure_runtime(
		definition.maximum_health,
		definition.maximum_health,
		definition.defense_flat
	)
	if configured and terminal_enemy:
		_configure_boss_presentation()
	return configured


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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 760.0)

	if defeated:
		velocity.x = move_toward(velocity.x, 0.0, 560.0 * delta)
		move_and_slide()
		return

	if terminal_enemy:
		_boss_projectile_cooldown = maxf(0.0, _boss_projectile_cooldown - delta)
		if _boss_projectile_cooldown <= 0.0:
			_spawn_boss_projectile()
			_boss_projectile_cooldown = 1.9

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


func _configure_boss_presentation() -> void:
	boss_visual_scale = 1.7
	sprite.scale *= boss_visual_scale
	var outline := AnimatedSprite2D.new()
	outline.name = "BossPurpleOutline"
	outline.sprite_frames = sprite.sprite_frames
	outline.animation = sprite.animation
	outline.position = sprite.position
	outline.scale = sprite.scale * 1.12
	var outline_material := ShaderMaterial.new()
	var outline_shader := Shader.new()
	outline_shader.code = "shader_type canvas_item; void fragment() { float a = texture(TEXTURE, UV).a; COLOR = vec4(0.72, 0.16, 1.0, a * 0.96); }"
	outline_material.shader = outline_shader
	outline.material = outline_material
	outline.z_index = sprite.z_index - 1
	add_child(outline)
	outline.play(sprite.animation)


func _spawn_boss_projectile() -> void:
	if defeated or not terminal_enemy or not is_instance_valid(player):
		return
	var delivery := BOSS_PROJECTILE_SCENE.instantiate() as ProjectileDelivery
	if delivery == null:
		return
	var direction_x := signf(player.global_position.x - global_position.x)
	if is_zero_approx(direction_x):
		direction_x = facing if not is_zero_approx(facing) else -1.0
	facing = direction_x
	var direction := Vector2.RIGHT if direction_x > 0.0 else Vector2.LEFT
	var spawn_transform := Transform2D(0.0, Vector2(global_position.x + direction.x * 58.0, global_position.y + 84.0))
	var cast_snapshot := CastSnapshot.new(
		_allocate_enemy_cast_id(), &"boss_arc", get_instance_id(), get_instance_id(), &"enemy", ElementIds.NONE, CombatStatSnapshot.new()
	)
	var payload := RuntimeAttackPayload.new(8.0, 8.0, ElementIds.NONE, 0, PackedStringArray(["boss_projectile"]))
	if not delivery.initialize_delivery(cast_snapshot, payload, 1, spawn_transform, direction):
		delivery.free()
		return
	get_tree().current_scene.add_child(delivery)
	boss_projectiles_fired += 1
	delivery_created.emit(delivery)


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
