class_name PlayerCharacter
extends CharacterBody2D

signal delivery_created(delivery: Node)
signal player_defeated
signal basic_attack_committed(event: BasicAttackCommittedEvent)
signal ignition_reclaimed(event: ReclaimVfxEvent)
signal interact_requested

const SPEED := 235.0
const GROUND_ACCELERATION := 1450.0
const AIR_ACCELERATION := 780.0
const FRICTION := 1750.0
const GRAVITY := 1150.0
const JUMP_VELOCITY := -520.0
const HURT_DURATION := 0.34
const DODGE_DURATION := 0.18
const DODGE_COOLDOWN := 0.55
const DODGE_DISTANCE_IN_BODY_WIDTHS := 5.0
const PLAYER_BODY_COLLISION_LAYER := 1
const ENEMY_BODY_COLLISION_LAYER := 2
const WORLD_BLOCKER_COLLISION_LAYER := 3
const PLAYER_HURTBOX_COLLISION_LAYER := 5
const GLOBAL_INSTAKILL_SKILL_ID: StringName = &"global_instakill"
const ELEMENT_BEAM_DELIVERY_SCRIPT := preload(
	"res://combat/delivery/element_beam_delivery.gd"
)
const BASIC_ATTACK_AIRFLOW_TEXTURES := {
	&"attack": preload("res://assets/characters/cat/cat_attack_airflow.png"),
	&"water_attack": preload("res://assets/characters/cat/cat_water_attack_airflow.png"),
	&"fire_attack": preload("res://assets/characters/cat/cat_fire_attack_airflow.png"),
}
const BASIC_ATTACK_FRAME_SIZE := Vector2(80.0, 64.0)
const IGNITION_AIRFLOW_SCALE_MULTIPLIER := 1.5
## Task 85 measured the actual FIRE attack hit-start frame (frame 1 at 20 fps,
## after the 0.08 s startup). Its airflow alpha begins at x=23 in the centered
## 80 px frame, so the authored 2x sprite reaches (40 - 23) * 2 = 34 px.
## The unchanged melee scene reaches 30 spawn + 42 offset + 36 half-width =
## 108 px, leaving the normal fixed forward margin P = 108 - 34 = 74 px.
## Ignition keeps that same margin: V1 + P = 34 * 1.5 + 74 = 125 px.
## The accepted attack snapshot therefore locks 125 / 108, not a 1.5 range.
const BASIC_ATTACK_CRITICAL_AIRFLOW_FRAME := 1
const BASIC_ATTACK_CRITICAL_ALPHA_MIN_X := 23.0
const BASIC_ATTACK_VISUAL_FRONT := (BASIC_ATTACK_FRAME_SIZE.x * 0.5 - BASIC_ATTACK_CRITICAL_ALPHA_MIN_X) * 2.0
const BASIC_ATTACK_QUERY_FRONT := 108.0
const BASIC_ATTACK_FIXED_FORWARD_MARGIN := BASIC_ATTACK_QUERY_FRONT - BASIC_ATTACK_VISUAL_FRONT
const IGNITION_VISUAL_FRONT := BASIC_ATTACK_VISUAL_FRONT * IGNITION_AIRFLOW_SCALE_MULTIPLIER
const IGNITION_QUERY_FRONT := IGNITION_VISUAL_FRONT + BASIC_ATTACK_FIXED_FORWARD_MARGIN
const IGNITION_MELEE_QUERY_MULTIPLIER := IGNITION_QUERY_FRONT / BASIC_ATTACK_QUERY_FRONT

@export var attack_multiplier: float = 1.0
@export var flat_damage_bonus: float = 0.0
@export var water_definition: ElementDefinition
@export var fire_definition: ElementDefinition
@export var basic_attack_airflow_enabled: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_receiver: DamageReceiver = $DamageReceiver
@onready var combat_receiver: CombatReceiver = $CombatReceiver
@onready var energy_component: EnergyComponent = $EnergyComponent
@onready var current_element_controller: CurrentElementController = $ElementFormController
@onready var skill_executor: SkillExecutor = $SkillExecutor
@onready var skill_controller: SkillController = $SkillController
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var combat_hurtbox: Area2D = $CombatHurtbox
@onready var basic_attack_airflow: Sprite2D = $BasicAttackAirflow

var facing: float = 1.0
var hurt_time: float = 0.0
var jump_requested: bool = false
var defeated: bool = false

var _base_sprite_modulate := Color.WHITE
var _element_tween: Tween
var _flash_tween: Tween
var _dodge_tween: Tween
var _content_catalog: RunContentCatalog
var _basic_attack_definition: SkillDefinition
var _active_beam_ref: WeakRef
var _active_beam_snapshot: ChannelExecutionSnapshot
var _skill_level_effect_adapter: RunSkillLevelEffectAdapter
var _ignition_state: IgnitionState
var _basic_attack_airflow_base_scale := Vector2.ONE
var _dodging: bool = false
var _dodge_elapsed: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: float = 1.0
var _dodge_target_distance: float = 0.0
var _dodge_distance_traveled: float = 0.0
var _dodge_saved_collision_layer: int = 0
var _dodge_has_saved_collision_layer: bool = false
var _dodge_saved_collision_mask: int = 0
var _dodge_has_saved_collision_mask: bool = false
var _dodge_saved_sprite_modulate := Color.WHITE
var _dodge_has_saved_visual: bool = false
var _dodge_saved_velocity := Vector2.ZERO
var _dodge_has_saved_velocity: bool = false
var _dodge_saved_hurtbox_collision_layer: int = 0
var _dodge_has_saved_hurtbox_collision_layer: bool = false

static var _last_global_instakill_cast_id: int = 3_000_000_000


func _ready() -> void:
	add_to_group(&"player")
	_ignition_state = IgnitionState.new()
	_ignition_state.name = &"IgnitionState"
	add_child(_ignition_state)
	_ignition_state.cleared.connect(_on_ignition_state_cleared)
	combat_receiver.configure_components(null, damage_receiver)
	var delivery_parent: Node = get_tree().current_scene
	if delivery_parent == null:
		delivery_parent = get_parent()
	skill_executor.configure_dependencies(
		energy_component,
		current_element_controller,
		delivery_parent,
	)
	skill_executor.configure_cast_identity(get_instance_id(), get_instance_id(), &"player")
	skill_executor.set_external_action_gate(_can_start_skill)
	skill_controller.set_external_manual_element_gate(_can_change_element)
	skill_executor.set_stat_snapshot_provider(_capture_attack_stats)
	skill_executor.set_spawn_snapshot_provider(_capture_spawn_snapshot)

	skill_executor.phase_changed.connect(_on_skill_phase_changed)
	skill_executor.delivery_spawned.connect(_on_delivery_spawned)
	skill_executor.execution_activated.connect(_on_execution_activated)
	skill_executor.execution_tick_generated.connect(_on_execution_tick_generated)
	skill_executor.execution_ended.connect(_on_execution_ended)
	current_element_controller.element_changed.connect(_on_element_changed)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)
	_apply_element_presentation(current_element_controller.current_element_id, false)
	_update_energy_regeneration_pause()
	sprite.play(_idle_animation_name())
	_basic_attack_airflow_base_scale = basic_attack_airflow.scale
	_sync_basic_attack_airflow()


func _process(_delta: float) -> void:
	_sync_basic_attack_airflow()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		if what == NOTIFICATION_PAUSED:
			_finish_dodge()
		skill_controller.handle_pause_exit()


func _unhandled_input(event: InputEvent) -> void:
	if defeated:
		return
	if event.is_action_pressed(&"global_instakill"):
		release_global_instakill()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"dodge"):
		_try_start_dodge()
		return
	if _dodging:
		return
	if event.is_action_pressed(&"jump"):
		jump_requested = true
	elif event.is_action_pressed(&"interact"):
		interact_requested.emit()
	elif event.is_action_pressed(&"attack_melee"):
		try_basic_attack()
	elif event.is_action_pressed(&"cast_active_1"):
		try_cast_slot(SkillSlotIds.ACTIVE_1)
	elif event.is_action_pressed(&"cast_active_2"):
		try_cast_slot(SkillSlotIds.ACTIVE_2)
	elif event.is_action_pressed(&"cast_active_3"):
		try_cast_slot(SkillSlotIds.ACTIVE_3)
	elif event.is_action_pressed(&"switch_element"):
		cycle_next()
	elif event.is_action_released(&"cast_active_1"):
		release_channel_for_slot(SkillSlotIds.ACTIVE_1)
	elif event.is_action_released(&"cast_active_2"):
		release_channel_for_slot(SkillSlotIds.ACTIVE_2)
	elif event.is_action_released(&"cast_active_3"):
		release_channel_for_slot(SkillSlotIds.ACTIVE_3)


func _physics_process(delta: float) -> void:
	if _dodge_cooldown_remaining > 0.0:
		_dodge_cooldown_remaining = maxf(0.0, _dodge_cooldown_remaining - delta)

	if _dodging:
		_advance_dodge(delta)
		return

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
	if slot_id == SkillSlotIds.LEGACY_MELEE:
		return try_basic_attack()
	return skill_controller.try_cast_slot(slot_id)


func try_basic_attack() -> CastAttemptResult:
	if _basic_attack_definition == null:
		return CastAttemptResult.rejected(
			CastAttemptResult.RejectReason.INVALID_CONFIGURATION,
			&"",
			&"missing_basic_attack_catalog_entry"
		)
	var basic_attack := _ignition_basic_attack_definition() if ignition_active() else _basic_attack_definition
	var attempt := skill_executor.try_cast(basic_attack)
	if attempt.accepted:
		var animation := &"fire_attack" if ignition_active() else _element_animation_name(&"attack", &"water_attack", &"fire_attack")
		sprite.play(animation)
		_sync_basic_attack_airflow()
	return attempt


## The attack wind current is authored as a separate texture/node so VFX or
## accessibility code can suppress it without changing the character clip or
## any authoritative basic-attack timing. By default this mirrors the body
## frame, facing and tint exactly, reproducing the former combined sheet.
func set_basic_attack_airflow_enabled(enabled: bool) -> void:
	basic_attack_airflow_enabled = enabled
	_sync_basic_attack_airflow()


func _sync_basic_attack_airflow() -> void:
	if basic_attack_airflow == null or sprite == null:
		return
	var texture: Texture2D = BASIC_ATTACK_AIRFLOW_TEXTURES.get(sprite.animation)
	var ignition_attack_airflow := sprite.animation == &"fire_attack" and ignition_active()
	basic_attack_airflow.scale = _basic_attack_airflow_base_scale * (IGNITION_AIRFLOW_SCALE_MULTIPLIER if ignition_attack_airflow else 1.0)
	basic_attack_airflow.modulate = (
		Color("ff7a20")
		if ignition_attack_airflow
		else sprite.modulate
	)
	var should_show := basic_attack_airflow_enabled and texture != null and sprite.visible
	basic_attack_airflow.visible = should_show
	if not should_show:
		return
	basic_attack_airflow.texture = texture
	basic_attack_airflow.region_rect = Rect2(
		Vector2(float(sprite.frame) * BASIC_ATTACK_FRAME_SIZE.x, 0.0),
		BASIC_ATTACK_FRAME_SIZE
	)
	basic_attack_airflow.flip_h = sprite.flip_h


func configure_run_runtime(
		loadout: RuntimeSkillLoadout,
		content_catalog: RunContentCatalog,
		event_room_id: StringName
) -> bool:
	if loadout == null or content_catalog == null or event_room_id.is_empty():
		return false
	var basic_attack := content_catalog.fixed_basic_attack_definition()
	if basic_attack == null or not basic_attack.is_valid():
		return false
	if not current_element_controller.set_event_room_id(event_room_id):
		return false
	_content_catalog = content_catalog
	_basic_attack_definition = basic_attack
	var reclaim_port := RangeElementReclaimPort.new(
		self,
		energy_component,
		8,
		256
	)
	var services := SkillExecutionServices.new(reclaim_port)
	services.set_ignition_port(RangeIgnitionPort.new(
		self,
		_ignition_state,
		8,
		256,
		Callable(self, "_on_ignition_reclaimed")
	))
	services.set_projectile_sweep_query_port(PhysicsProjectileSweepQuery2D.new())
	services.set_skill_delivery_prepare_port(CombatSkillDeliveryAdapter.new(self, content_catalog))
	services.set_projectile_source(self)
	if not skill_executor.set_execution_services(services):
		return false
	return skill_controller.configure_runtime(current_element_controller, skill_executor, loadout)


func configure_run_skill_level_effects(session: RunSession) -> bool:
	if session == null:
		return false
	_skill_level_effect_adapter = RunSkillLevelEffectAdapter.new(session)
	return skill_controller.set_active_skill_level_effect_port(_skill_level_effect_adapter)


func release_channel_for_slot(slot_id: StringName) -> bool:
	var canonical_slot := SkillSlotIds.canonicalize_input(slot_id)
	return (
		SkillSlotIds.is_active(canonical_slot)
		and skill_executor.current_slot_id == canonical_slot
		and skill_executor.current_execution_snapshot is ChannelExecutionSnapshot
		and skill_executor.request_channel_release(skill_executor.current_cast_id)
	)


func release_global_instakill() -> int:
	var candidates := get_tree().get_nodes_in_group(&"enemies")
	var instakill_damage := 0.0
	for node: Node in candidates:
		var enemy := node as CombatEnemy
		if not _is_live_instakill_target(enemy):
			continue
		instakill_damage = maxf(
			instakill_damage,
			float(enemy.damage_receiver.current_health) + enemy.damage_receiver.defense_flat + 1.0
		)
	if instakill_damage <= 0.0:
		return 0

	_last_global_instakill_cast_id += 1
	var stats := CombatStatSnapshot.new(
		instakill_damage / CombatStatSnapshot.BASE_ATTACK,
		0.0
	)
	var cast_snapshot := CastSnapshot.new(
		_last_global_instakill_cast_id,
		GLOBAL_INSTAKILL_SKILL_ID,
		get_instance_id(),
		get_instance_id(),
		&"player",
		ElementIds.NONE,
		stats
	)
	var payload := RuntimeAttackPayload.from_locked_stats(
		stats,
		1.0,
		ElementIds.NONE,
		0,
		PackedStringArray(["global_instakill"])
	)
	var defeated_count := 0
	var hit_index := 0
	# A room may reveal its reinforcement wave synchronously when the initial
	# wave dies. Re-scan the captured room nodes so one T press clears both.
	for _pass: int in range(candidates.size() + 1):
		var pass_defeated := 0
		for node: Node in candidates:
			var enemy := node as CombatEnemy
			if not _is_active_instakill_target(enemy):
				continue
			var direction := enemy.global_position - global_position
			if direction.is_zero_approx():
				direction = Vector2.RIGHT
			else:
				direction = direction.normalized()
			var request := HitRequest.new(
				cast_snapshot,
				payload,
				_last_global_instakill_cast_id,
				hit_index,
				enemy.global_position,
				direction
			)
			hit_index += 1
			var result := enemy.combat_receiver.receive_hit(request)
			if result != null and result.accepted and enemy.defeated:
				defeated_count += 1
				pass_defeated += 1
		if pass_defeated == 0:
			break
	return defeated_count


func _is_live_instakill_target(enemy: CombatEnemy) -> bool:
	return (
		enemy != null
		and is_instance_valid(enemy)
		and not enemy.is_queued_for_deletion()
		and not enemy.defeated
		and enemy.damage_receiver != null
		and enemy.combat_receiver != null
	)


func _is_active_instakill_target(enemy: CombatEnemy) -> bool:
	return (
		_is_live_instakill_target(enemy)
		and enemy.is_visible_in_tree()
		and enemy.combat_receiver.accepting_hits
	)


func publish_basic_attack_commit(
		result: CombatResult,
		target_id: StringName,
		target_elements: ElementSnapshot
) -> bool:
	if (
		result == null
		or not result.accepted
		or _basic_attack_definition == null
		or result.skill_id != _basic_attack_definition.skill_id
		or result.root_owner_id != get_instance_id()
	):
		return false
	var event := BasicAttackCommittedEvent.new(
		StringName("basic_attack:%d:%d:%d:%s" % [
			result.cast_id,
			result.delivery_id,
			result.hit_index,
			String(target_id),
		]),
		get_instance_id(),
		target_id,
		target_elements,
		result
	)
	if not event.is_valid():
		return false
	basic_attack_committed.emit(event)
	return true


func respawn() -> void:
	_finish_dodge(false, false)
	_dodge_cooldown_remaining = 0.0
	defeated = false
	hurt_time = 0.0
	velocity = Vector2.ZERO
	combat_receiver.accepting_hits = true
	combat_receiver.clear_recent_hits()
	damage_receiver.restore_full()
	energy_component.set_current(energy_component.maximum)
	skill_controller.on_owner_respawned()
	_update_energy_regeneration_pause()
	_apply_element_presentation(current_element_controller.current_element_id, false)
	sprite.play(_idle_animation_name())


func prepare_floor_transition() -> void:
	skill_controller.on_floor_changed()


func reload_run_state() -> void:
	skill_controller.on_run_reloaded()

func request_element(element_id: StringName) -> ElementChangeResult:
	if _dodging:
		return ElementChangeResult.rejected(
			&"dodging",
			current_element_controller.current_element_id,
			FormChangedEvent.Source.MANUAL
		)
	return skill_controller.request_element(element_id)


func cycle_next() -> ElementChangeResult:
	if _dodging:
		return ElementChangeResult.rejected(
			&"dodging",
			current_element_controller.current_element_id,
			FormChangedEvent.Source.MANUAL
		)
	return skill_controller.cycle_next()


func get_element_definition(element_id: StringName) -> ElementDefinition:
	if element_id == ElementIds.WATER:
		return water_definition
	if element_id == ElementIds.FIRE:
		return fire_definition
	return null


func _can_start_skill(_skill: SkillDefinition) -> bool:
	return not defeated and hurt_time <= 0.0 and not _dodging


func _can_change_element() -> bool:
	return not defeated and hurt_time <= 0.0 and not _dodging


func _capture_attack_stats(_skill: SkillDefinition) -> CombatStatSnapshot:
	var multiplier := attack_multiplier
	if _skill != null and _basic_attack_definition != null and _skill.skill_id == _basic_attack_definition.skill_id and ignition_active():
		multiplier *= _ignition_state.multiplier
	return CombatStatSnapshot.new(multiplier, flat_damage_bonus)


func ignition_active() -> bool:
	return _ignition_state != null and _ignition_state.active


func ignition_multiplier() -> float:
	return _ignition_state.multiplier if _ignition_state != null else 1.0


func _ignition_basic_attack_definition() -> SkillDefinition:
	var copy := _basic_attack_definition.duplicate(true) as SkillDefinition
	assert(copy != null)
	copy.element_policy = SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT
	copy.required_element_id = ElementIds.FIRE
	var execution := copy.execution_definition as InstantDeliveryExecution
	assert(execution != null)
	var payload := execution.payload
	assert(payload != null)
	payload.element_mode = AttackPayloadDefinition.ElementMode.FIXED_ELEMENT
	payload.fixed_element_id = ElementIds.FIRE
	payload.element_amount = 1
	payload.melee_query_multiplier = IGNITION_MELEE_QUERY_MULTIPLIER
	return copy


func _on_ignition_reclaimed(event: ReclaimVfxEvent) -> void:
	if event != null and event.is_valid():
		ignition_reclaimed.emit(event)


func _on_ignition_state_cleared(_reason: StringName) -> void:
	_sync_basic_attack_airflow()


func _capture_spawn_snapshot(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
	var direction := Vector2.RIGHT if facing >= 0.0 else Vector2.LEFT
	var spawn_transform := global_transform
	var spawn_distance := 30.0
	if _skill != null and _basic_attack_definition != null and _skill.skill_id == _basic_attack_definition.skill_id:
		var execution := _skill.execution_definition as InstantDeliveryExecution
		if execution != null and execution.payload != null:
			spawn_distance *= execution.payload.melee_query_multiplier
	spawn_transform.origin = global_position + Vector2(spawn_distance * direction.x, -2.0)
	return DeliverySpawnSnapshot.new(spawn_transform, direction)


func _skill_locks_movement() -> bool:
	return (
		skill_executor.current_phase != SkillExecutor.Phase.IDLE
		and skill_executor.current_movement_policy
			== SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT
	)


func _try_start_dodge() -> bool:
	if (
		_dodging
		or defeated
		or hurt_time > 0.0
		or _dodge_cooldown_remaining > 0.0
		or skill_executor == null
		or skill_executor.current_phase != SkillExecutor.Phase.IDLE
	):
		return false
	var body_width := _dodge_body_world_width()
	if body_width <= 0.0:
		return false
	var input_axis := Input.get_axis(&"move_left", &"move_right")
	_dodge_direction = signf(input_axis) if absf(input_axis) > 0.01 else signf(facing)
	if is_zero_approx(_dodge_direction):
		_dodge_direction = 1.0
	facing = _dodge_direction
	sprite.flip_h = facing > 0.0
	_dodge_elapsed = 0.0
	_dodge_distance_traveled = 0.0
	_dodge_target_distance = body_width * DODGE_DISTANCE_IN_BODY_WIDTHS
	_dodge_saved_collision_layer = collision_layer
	_dodge_has_saved_collision_layer = true
	_dodge_saved_collision_mask = collision_mask
	_dodge_has_saved_collision_mask = true
	_dodge_saved_velocity = velocity
	_dodge_has_saved_velocity = true
	_dodge_saved_sprite_modulate = sprite.modulate
	_dodge_has_saved_visual = true
	jump_requested = false
	velocity = Vector2.ZERO
	_dodging = true
	combat_receiver.dodging = true
	set_collision_layer_value(PLAYER_BODY_COLLISION_LAYER, false)
	set_collision_mask_value(ENEMY_BODY_COLLISION_LAYER, false)
	set_collision_mask_value(WORLD_BLOCKER_COLLISION_LAYER, true)
	if combat_hurtbox != null:
		_dodge_saved_hurtbox_collision_layer = combat_hurtbox.collision_layer
		_dodge_has_saved_hurtbox_collision_layer = true
		combat_hurtbox.set_collision_layer_value(PLAYER_HURTBOX_COLLISION_LAYER, false)
	_start_dodge_visual()
	return true


func _advance_dodge(delta: float) -> void:
	if not _dodging:
		return
	jump_requested = false
	var step_time := minf(maxf(delta, 0.0), DODGE_DURATION - _dodge_elapsed)
	if step_time > 0.0:
		var step_distance := _dodge_target_distance * step_time / DODGE_DURATION
		var before := global_position
		var collision := move_and_collide(Vector2(_dodge_direction * step_distance, 0.0))
		_dodge_distance_traveled += absf(global_position.x - before.x)
		_dodge_elapsed += step_time
		if collision != null:
			_finish_dodge()
			return
	if _dodge_elapsed >= DODGE_DURATION - 0.00001:
		_finish_dodge()


func _finish_dodge(start_cooldown: bool = true, resume_presentation: bool = true) -> void:
	var was_dodging := _dodging
	_dodging = false
	if combat_receiver != null:
		combat_receiver.dodging = false
	if _dodge_has_saved_collision_layer:
		collision_layer = _dodge_saved_collision_layer
		_dodge_has_saved_collision_layer = false
	if _dodge_has_saved_collision_mask:
		collision_mask = _dodge_saved_collision_mask
		_dodge_has_saved_collision_mask = false
	if _dodge_tween != null and _dodge_tween.is_valid():
		_dodge_tween.kill()
	_dodge_tween = null
	if _dodge_has_saved_visual and sprite != null:
		sprite.modulate = _dodge_saved_sprite_modulate
		_dodge_has_saved_visual = false
	if _dodge_has_saved_velocity:
		velocity = _dodge_saved_velocity
		_dodge_has_saved_velocity = false
	if _dodge_has_saved_hurtbox_collision_layer:
		if combat_hurtbox != null:
			combat_hurtbox.collision_layer = _dodge_saved_hurtbox_collision_layer
		_dodge_has_saved_hurtbox_collision_layer = false
	if was_dodging and start_cooldown:
		_dodge_cooldown_remaining = DODGE_COOLDOWN
	if was_dodging and resume_presentation and is_inside_tree():
		_play_locomotion_animation()


func _dodge_body_world_width() -> float:
	if body_collision == null or body_collision.shape == null:
		return 0.0
	return body_collision.shape.get_rect().size.x * body_collision.global_transform.x.length()


func _start_dodge_visual() -> void:
	if _element_tween != null and _element_tween.is_valid():
		_element_tween.kill()
	_element_tween = null
	if _dodge_tween != null and _dodge_tween.is_valid():
		_dodge_tween.kill()
	var low_alpha := _dodge_saved_sprite_modulate
	low_alpha.a *= 0.36
	var high_alpha := _dodge_saved_sprite_modulate
	high_alpha.a *= 0.78
	_dodge_tween = create_tween()
	_dodge_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_dodge_tween.tween_property(sprite, "modulate", low_alpha, 0.035)
	_dodge_tween.tween_property(sprite, "modulate", high_alpha, 0.05)
	_dodge_tween.tween_property(sprite, "modulate", low_alpha, 0.05)
	_dodge_tween.tween_property(sprite, "modulate", _dodge_saved_sprite_modulate, 0.045)


func _idle_animation_name() -> StringName:
	return _element_animation_name(&"idle", &"water_idle", &"fire_idle")


func _element_animation_name(
	default_animation: StringName,
	water_animation: StringName,
	fire_animation: StringName
) -> StringName:
	if sprite.sprite_frames == null:
		return default_animation
	if (
		current_element_controller.current_element_id == ElementIds.WATER
		and sprite.sprite_frames.has_animation(water_animation)
	):
		return water_animation
	if (
		current_element_controller.current_element_id == ElementIds.FIRE
		and sprite.sprite_frames.has_animation(fire_animation)
	):
		return fire_animation
	return default_animation


func _refresh_idle_animation_if_active() -> void:
	if (
		sprite.animation != &"idle"
		and sprite.animation != &"water_idle"
		and sprite.animation != &"fire_idle"
	):
		return
	var idle_animation := _idle_animation_name()
	if sprite.animation != idle_animation:
		sprite.play(idle_animation)


func _play_locomotion_animation() -> void:
	if _dodging or _skill_locks_movement() or hurt_time > 0.0 or defeated:
		return
	if not is_on_floor():
		var jump_animation := _element_animation_name(&"jump", &"water_jump", &"fire_jump")
		if sprite.animation != jump_animation:
			sprite.play(jump_animation)
	elif absf(velocity.x) > 12.0:
		var walk_animation := _element_animation_name(&"walk", &"water_walk", &"fire_walk")
		if sprite.animation != walk_animation:
			sprite.play(walk_animation)
	else:
		var idle_animation := _idle_animation_name()
		if sprite.animation != idle_animation:
			sprite.play(idle_animation)


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


func _on_execution_activated(snapshot: SkillExecutionSnapshot) -> void:
	if not snapshot is ChannelExecutionSnapshot or _content_catalog == null:
		return
	var delivery_scene := _content_catalog.runtime_delivery_scene_for(snapshot.skill_id)
	if delivery_scene == null:
		return
	var node := delivery_scene.instantiate()
	var spawn_snapshot := _capture_spawn_snapshot(_content_catalog.gameplay_for(snapshot.skill_id))
	var beam := node as ELEMENT_BEAM_DELIVERY_SCRIPT
	if (
		beam == null
		or not beam.initialize_channel(
			snapshot as ChannelExecutionSnapshot,
			1,
			spawn_snapshot.initial_transform,
			spawn_snapshot.direction
		)
	):
		if node != null:
			node.free()
		return
	add_child(beam)
	_active_beam_ref = weakref(beam)
	_active_beam_snapshot = snapshot as ChannelExecutionSnapshot
	delivery_created.emit(beam)


func _on_execution_tick_generated(snapshot: ChannelTickSnapshot) -> void:
	var beam := _active_beam_ref.get_ref() as ELEMENT_BEAM_DELIVERY_SCRIPT if _active_beam_ref != null else null
	if (
		beam != null
		and is_instance_valid(beam)
		and not beam.is_queued_for_deletion()
		and snapshot != null
		and snapshot.channel_snapshot == _active_beam_snapshot
	):
		beam.submit_tick(snapshot)


func _on_execution_ended(
		snapshot: SkillExecutionSnapshot,
		_result: SkillExecutionEndResult
) -> void:
	if snapshot != _active_beam_snapshot:
		return
	var beam := _active_beam_ref.get_ref() as ELEMENT_BEAM_DELIVERY_SCRIPT if _active_beam_ref != null else null
	if beam != null and is_instance_valid(beam) and not beam.is_queued_for_deletion():
		beam.close_hit_window()
	_active_beam_ref = null
	_active_beam_snapshot = null


func _on_element_changed(change: ElementChangeResult) -> void:
	if change != null and change.accepted and change.changed:
		_apply_element_presentation(change.current_element_id, true)


func _apply_element_presentation(element_id: StringName, animate: bool) -> void:
	var definition := get_element_definition(element_id)
	var tint := Color("c9f3ff") if element_id == ElementIds.WATER else Color("ffd1bd")
	if definition != null and definition.is_valid():
		tint = definition.presentation_color.lerp(Color.WHITE, 0.68)
	_base_sprite_modulate = tint
	_refresh_idle_animation_if_active()
	if _element_tween != null and _element_tween.is_valid():
		_element_tween.kill()
	_element_tween = null
	if not animate:
		sprite.modulate = _base_sprite_modulate
		return
	_element_tween = create_tween()
	_element_tween.tween_property(sprite, "modulate", Color.WHITE * 1.25, 0.07)
	_element_tween.tween_property(sprite, "modulate", _base_sprite_modulate, 0.13)


func _on_health_state_changed(
		_current_health: int,
		_maximum_health: int,
		delta: int,
		result: CombatResult
) -> void:
	if delta >= 0 or defeated:
		return
	_finish_dodge()
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
	_finish_dodge(true, false)
	defeated = true
	hurt_time = 0.0
	combat_receiver.accepting_hits = false
	skill_controller.cancel_current_cast(&"death", skill_executor.current_cast_id)
	skill_controller.on_owner_died()
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
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(1.8, 1.8, 1.8), 0.05)
	_flash_tween.tween_property(sprite, "modulate", _base_sprite_modulate, 0.12)


func _exit_tree() -> void:
	_finish_dodge(false, false)
	var beam := _active_beam_ref.get_ref() as ELEMENT_BEAM_DELIVERY_SCRIPT if _active_beam_ref != null else null
	if beam != null and is_instance_valid(beam) and not beam.is_queued_for_deletion():
		beam.close_hit_window()
	_active_beam_ref = null
	_active_beam_snapshot = null
	if _element_tween != null and _element_tween.is_valid():
		_element_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _dodge_tween != null and _dodge_tween.is_valid():
		_dodge_tween.kill()
	_element_tween = null
	_flash_tween = null
	_dodge_tween = null
