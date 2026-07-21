class_name PlayerCharacter
extends CharacterBody2D

signal delivery_created(delivery: Node)
signal player_defeated

const SPEED := 235.0
const GROUND_ACCELERATION := 1450.0
const AIR_ACCELERATION := 780.0
const FRICTION := 1750.0
const GRAVITY := 1150.0
const JUMP_VELOCITY := -520.0
const HURT_DURATION := 0.34

@export var attack_multiplier: float = 1.0
@export var flat_damage_bonus: float = 0.0
@export var water_definition: ElementDefinition
@export var fire_definition: ElementDefinition

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_receiver: DamageReceiver = $DamageReceiver
@onready var combat_receiver: CombatReceiver = $CombatReceiver
@onready var energy_component: EnergyComponent = $EnergyComponent
@onready var form_controller: ElementFormController = $ElementFormController
@onready var skill_executor: SkillExecutor = $SkillExecutor
@onready var skill_controller: SkillController = $SkillController

var facing: float = 1.0
var hurt_time: float = 0.0
var jump_requested: bool = false
var defeated: bool = false

var _base_sprite_modulate := Color.WHITE


func _ready() -> void:
	add_to_group(&"player")
	combat_receiver.configure_components(null, damage_receiver)
	var delivery_parent: Node = get_tree().current_scene
	if delivery_parent == null:
		delivery_parent = get_parent()
	skill_executor.configure_dependencies(
		energy_component,
		form_controller,
		delivery_parent,
	)
	skill_executor.configure_cast_identity(get_instance_id(), get_instance_id(), &"player")
	skill_executor.set_external_action_gate(_can_start_skill)
	skill_executor.set_stat_snapshot_provider(_capture_attack_stats)
	skill_executor.set_spawn_snapshot_provider(_capture_spawn_snapshot)
	skill_controller.configure_runtime(
		form_controller,
		skill_executor,
		skill_controller.water_loadout,
		skill_controller.fire_loadout,
	)

	skill_executor.phase_changed.connect(_on_skill_phase_changed)
	skill_executor.delivery_spawned.connect(_on_delivery_spawned)
	form_controller.form_changed.connect(_on_form_changed)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)

	_apply_form_presentation(form_controller.current_form_id, false)
	_update_energy_regeneration_pause()
	sprite.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	if defeated:
		return
	if event.is_action_pressed(&"jump"):
		jump_requested = true
	elif event.is_action_pressed(&"attack_melee"):
		try_cast_slot(&"melee")
	elif event.is_action_pressed(&"cast_primary"):
		try_cast_slot(&"primary")
	elif event.is_action_pressed(&"switch_element"):
		skill_controller.toggle_form()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 760.0)

	if jump_requested:
		if is_on_floor() and hurt_time <= 0.0 and not _skill_locks_movement() and not defeated:
			velocity.y = JUMP_VELOCITY
		jump_requested = false

	if defeated:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	if hurt_time > 0.0:
		hurt_time = maxf(0.0, hurt_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, 520.0 * delta)
		move_and_slide()
		if hurt_time <= 0.0:
			_update_energy_regeneration_pause()
			_play_locomotion_animation()
		return

	if _skill_locks_movement():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	var input_axis := Input.get_axis(&"move_left", &"move_right")
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if absf(input_axis) > 0.01:
		velocity.x = move_toward(velocity.x, input_axis * SPEED, acceleration * delta)
		facing = signf(input_axis)
		sprite.flip_h = facing > 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	_play_locomotion_animation()
	move_and_slide()


func try_cast_slot(slot_id: StringName) -> CastAttemptResult:
	return skill_controller.try_cast_slot(slot_id)


func request_form(form_id: StringName) -> bool:
	return skill_controller.request_form(form_id)


func toggle_form() -> bool:
	return skill_controller.toggle_form()


func get_element_definition(element_id: StringName) -> ElementDefinition:
	if element_id == ElementIds.WATER:
		return water_definition
	if element_id == ElementIds.FIRE:
		return fire_definition
	return null


func _can_start_skill(_skill: SkillDefinition) -> bool:
	return not defeated and hurt_time <= 0.0


func _capture_attack_stats(_skill: SkillDefinition) -> CombatStatSnapshot:
	return CombatStatSnapshot.new(attack_multiplier, flat_damage_bonus)


func _capture_spawn_snapshot(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
	var direction := Vector2.RIGHT if facing >= 0.0 else Vector2.LEFT
	var spawn_transform := global_transform
	spawn_transform.origin = global_position + Vector2(30.0 * direction.x, -2.0)
	return DeliverySpawnSnapshot.new(spawn_transform, direction)


func _skill_locks_movement() -> bool:
	return skill_executor.current_phase != SkillExecutor.Phase.IDLE


func _play_locomotion_animation() -> void:
	if _skill_locks_movement() or hurt_time > 0.0 or defeated:
		return
	if not is_on_floor():
		if sprite.animation != &"jump":
			sprite.play(&"jump")
	elif absf(velocity.x) > 12.0:
		if sprite.animation != &"walk":
			sprite.play(&"walk")
	elif sprite.animation != &"idle":
		sprite.play(&"idle")


func _on_skill_phase_changed(
		_cast_id: int,
		_previous_phase: SkillExecutor.Phase,
		current_phase: SkillExecutor.Phase
) -> void:
	_update_energy_regeneration_pause()
	if defeated or hurt_time > 0.0:
		return
	if current_phase == SkillExecutor.Phase.IDLE:
		_play_locomotion_animation()


func _on_delivery_spawned(_cast_id: int, _delivery_id: int, delivery: Node) -> void:
	delivery_created.emit(delivery)


func _on_form_changed(current_form_id: StringName, _previous_form_id: StringName) -> void:
	_apply_form_presentation(current_form_id, true)


func _apply_form_presentation(form_id: StringName, animate: bool) -> void:
	var definition := get_element_definition(form_id)
	var tint := Color("c9f3ff") if form_id == ElementIds.WATER else Color("ffd1bd")
	if definition != null and definition.is_valid():
		tint = definition.presentation_color.lerp(Color.WHITE, 0.68)
	_base_sprite_modulate = tint
	if not animate:
		sprite.modulate = _base_sprite_modulate
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE * 1.25, 0.07)
	tween.tween_property(sprite, "modulate", _base_sprite_modulate, 0.13)


func _on_health_state_changed(
		_current_health: int,
		_maximum_health: int,
		delta: int,
		result: CombatResult
) -> void:
	if delta >= 0 or defeated:
		return
	skill_controller.cancel_current_cast(&"hit", skill_executor.current_cast_id)
	hurt_time = HURT_DURATION
	_update_energy_regeneration_pause()
	var away_x := result.hit_direction.x
	if is_zero_approx(away_x):
		away_x = signf(global_position.x - result.hit_position.x)
	if is_zero_approx(away_x):
		away_x = -facing
	velocity.x = signf(away_x) * 205.0
	velocity.y = -125.0
	sprite.play(&"hurt")
	_flash()


func _on_death_candidate(_result: CombatResult) -> void:
	if defeated:
		return
	defeated = true
	hurt_time = 0.0
	combat_receiver.accepting_hits = false
	skill_controller.cancel_current_cast(&"death", skill_executor.current_cast_id)
	_update_energy_regeneration_pause()
	sprite.play(&"hurt")
	player_defeated.emit()


func _update_energy_regeneration_pause() -> void:
	if energy_component == null or skill_executor == null:
		return
	var phase := skill_executor.current_phase
	energy_component.set_regeneration_paused(
		defeated
		or hurt_time > 0.0
		or phase == SkillExecutor.Phase.STARTUP
		or phase == SkillExecutor.Phase.ACTIVE
	)


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.8, 1.8, 1.8), 0.05)
	tween.tween_property(sprite, "modulate", _base_sprite_modulate, 0.12)
