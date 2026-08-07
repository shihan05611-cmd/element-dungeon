class_name PlayerCharacter
extends CharacterBody2D

signal delivery_created(delivery: Node)
signal player_defeated
signal basic_attack_committed(event: BasicAttackCommittedEvent)

const SPEED := 235.0
const GROUND_ACCELERATION := 1450.0
const AIR_ACCELERATION := 780.0
const FRICTION := 1750.0
const GRAVITY := 1150.0
const JUMP_VELOCITY := -520.0
const HURT_DURATION := 0.34
const ELEMENT_BEAM_DELIVERY_SCRIPT := preload(
	"res://combat/delivery/element_beam_delivery.gd"
)

@export var attack_multiplier: float = 1.0
@export var flat_damage_bonus: float = 0.0
@export var water_definition: ElementDefinition
@export var fire_definition: ElementDefinition

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_receiver: DamageReceiver = $DamageReceiver
@onready var combat_receiver: CombatReceiver = $CombatReceiver
@onready var energy_component: EnergyComponent = $EnergyComponent
@onready var current_element_controller: CurrentElementController = $ElementFormController
@onready var skill_executor: SkillExecutor = $SkillExecutor
@onready var skill_controller: SkillController = $SkillController

var facing: float = 1.0
var hurt_time: float = 0.0
var jump_requested: bool = false
var defeated: bool = false

var _base_sprite_modulate := Color.WHITE
var _element_tween: Tween
var _flash_tween: Tween
var _content_catalog: RunContentCatalog
var _basic_attack_definition: SkillDefinition
var _active_beam_ref: WeakRef
var _active_beam_snapshot: ChannelExecutionSnapshot
var _skill_level_effect_adapter: RunSkillLevelEffectAdapter


func _ready() -> void:
	add_to_group(&"player")
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		skill_controller.handle_pause_exit()


func _unhandled_input(event: InputEvent) -> void:
	if defeated:
		return
	if event.is_action_pressed(&"jump"):
		jump_requested = true
	elif event.is_action_pressed(&"attack_melee"):
		try_basic_attack()
	elif event.is_action_pressed(&"cast_active_1"):
		try_cast_slot(SkillSlotIds.ACTIVE_1)
	elif event.is_action_pressed(&"cast_active_2"):
		try_cast_slot(SkillSlotIds.ACTIVE_2)
	elif event.is_action_pressed(&"cast_active_3"):
		try_cast_slot(SkillSlotIds.ACTIVE_3)
	elif event.is_action_pressed(&"switch_element"):
		skill_controller.cycle_next()
	elif event.is_action_released(&"cast_active_1"):
		release_channel_for_slot(SkillSlotIds.ACTIVE_1)
	elif event.is_action_released(&"cast_active_2"):
		release_channel_for_slot(SkillSlotIds.ACTIVE_2)
	elif event.is_action_released(&"cast_active_3"):
		release_channel_for_slot(SkillSlotIds.ACTIVE_3)


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
	var attempt := skill_executor.try_cast(_basic_attack_definition)
	if attempt.accepted:
		sprite.play(_element_animation_name(
			&"attack",
			&"water_attack",
			&"fire_attack",
		))
	return attempt


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
		160.0,
		8,
		256
	)
	var services := SkillExecutionServices.new(reclaim_port)
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
	return skill_controller.request_element(element_id)


func cycle_next() -> ElementChangeResult:
	return skill_controller.cycle_next()


func get_element_definition(element_id: StringName) -> ElementDefinition:
	if element_id == ElementIds.WATER:
		return water_definition
	if element_id == ElementIds.FIRE:
		return fire_definition
	return null


func _can_start_skill(_skill: SkillDefinition) -> bool:
	return not defeated and hurt_time <= 0.0


func _can_change_element() -> bool:
	return not defeated and hurt_time <= 0.0


func _capture_attack_stats(_skill: SkillDefinition) -> CombatStatSnapshot:
	return CombatStatSnapshot.new(attack_multiplier, flat_damage_bonus)


func _capture_spawn_snapshot(_skill: SkillDefinition) -> DeliverySpawnSnapshot:
	var direction := Vector2.RIGHT if facing >= 0.0 else Vector2.LEFT
	var spawn_transform := global_transform
	spawn_transform.origin = global_position + Vector2(30.0 * direction.x, -2.0)
	return DeliverySpawnSnapshot.new(spawn_transform, direction)


func _skill_locks_movement() -> bool:
	return (
		skill_executor.current_phase != SkillExecutor.Phase.IDLE
		and skill_executor.current_movement_policy
			== SkillExecutionSnapshot.MovementPolicy.LOCK_MOVEMENT
	)


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
	if _skill_locks_movement() or hurt_time > 0.0 or defeated:
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
	var beam := _active_beam_ref.get_ref() as ELEMENT_BEAM_DELIVERY_SCRIPT if _active_beam_ref != null else null
	if beam != null and is_instance_valid(beam) and not beam.is_queued_for_deletion():
		beam.close_hit_window()
	_active_beam_ref = null
	_active_beam_snapshot = null
	if _element_tween != null and _element_tween.is_valid():
		_element_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_element_tween = null
	_flash_tween = null
