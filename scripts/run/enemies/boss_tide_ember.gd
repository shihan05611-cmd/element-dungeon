class_name BossTideEmber
extends CombatEnemy

## Tide-Ember Sovereign: the three-form final Boss (Task 61). Replaces the
## old single-bool "terminal_enemy on a generic enemy" hack entirely --
## terminal_enemy is now a pure data flag with no behavior tied to it
## anywhere in scripts/enemy.gd. Extends CombatEnemy to reuse its generic,
## not Boss-specific infrastructure: DamageReceiver/ElementCarrier/
## CombatReceiver wiring, poise, and the generic ranged-attack cycle
## (_advance_ranged_attack_cycle() and its cooldown/telegraph fields), which
## TidalSentry also inherits and drives from its own _physics_process()
## override the same way this class does.
##
## Form switching, counter-hit counting, layer regen, same-element
## mitigation opt-in, melee telegraphs (DelayedAreaDelivery) and summons are
## all implemented here; CombatEnemy itself stays generic.

signal form_changed(form_id: StringName, display_name: String)
signal counter_progress_changed(hits: int, threshold: int)

const BOSS_MELEE_SCENE: PackedScene = preload("res://scenes/run/boss_melee_delivery.tscn")
const MELEE_ACTIVE_DURATION := 0.14
const MELEE_RECOVERY_DURATION := 0.22
const TRANSITION_MOVE_DAMP := 560.0

@export var ember_form: BossFormDefinition = preload("res://resources/run/enemies/boss_forms/boss_form_ember.tres")
@export var tide_form: BossFormDefinition = preload("res://resources/run/enemies/boss_forms/boss_form_tide.tres")
@export var plain_form: BossFormDefinition = preload("res://resources/run/enemies/boss_forms/boss_form_plain.tres")
@export var tuning: BossTuning = preload("res://resources/run/enemies/boss_forms/boss_tuning.tres")
@export var starting_form_id: StringName = &"ember"

var current_form_id: StringName = &"ember":
	get:
		return current_form_id

var current_form: BossFormDefinition:
	get:
		return _forms.get(current_form_id)

var counter_hits: int = 0
var alternation_count: int = 0
var total_switch_count: int = 0
var switch_history: Array[StringName] = []
var entered_plain_form: bool = false

var _forms: Dictionary = {}
var _initial_layers_applied: bool = false
var _summon_cooldown_remaining: float = 0.0
var _layer_regen_timer: float = 0.0
var _transition_invulnerable_time: float = 0.0
var _active_deliveries: Array[WeakRef] = []
var _active_summons: Array[WeakRef] = []


func _ready() -> void:
	add_to_group(&"enemies")
	_forms = {
		&"ember": ember_form,
		&"tide": tide_form,
		&"plain": plain_form,
	}
	combat_receiver.configure_components(element_carrier, damage_receiver)
	combat_receiver.health_state_changed.connect(_on_health_state_changed)
	combat_receiver.death_candidate.connect(_on_death_candidate)
	combat_receiver.hit_resolved.connect(_on_hit_resolved)
	delivery_created.connect(_on_delivery_created)
	rng.randomize()
	terminal_enemy = true
	poise_enabled = true
	poise_hit_threshold = tuning.poise_hit_threshold
	poise_break_stun_duration = tuning.poise_break_stun_duration
	element_carrier.set_meta(&"same_element_mitigation_factor", tuning.same_element_mitigation_factor)
	current_form_id = starting_form_id
	ranged_projectile_profile = current_form.ranged_projectile_profile
	_play_pose(&"idle")
	_choose_patrol_target()
	_body_collision_layer = collision_layer
	_body_collision_mask = collision_mask
	var hurtbox := $CombatHurtbox as Area2D
	_hurtbox_collision_layer = hurtbox.collision_layer
	_hurtbox_collision_mask = hurtbox.collision_mask
	_connect_reduced_motion_source()


func _physics_process(delta: float) -> void:
	# RunFlowCoordinator stages the next room (and its enemies, including
	# this Boss) in a hidden staging container ahead of time, then
	# reparents it into the active room when the player actually arrives.
	# Reparenting triggers Node._exit_tree() on every descendant, and
	# ElementCarrier._exit_tree() silently clears its attachment ("leaving
	# the room clears attachment without broadcasting into a tearing-down
	# scene tree") -- which would wipe out layers applied in _ready() before
	# the Boss ever reaches its final, active position in the tree. Physics
	# processing only starts once the room is actually activate()d (staged
	# rooms sit at PROCESS_MODE_DISABLED), so applying the initial layers
	# here, once, on the first real physics tick, guarantees they land after
	# any such reparenting has already settled.
	if not _initial_layers_applied:
		_initial_layers_applied = true
		_apply_form_layers(current_form, false)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 760.0)

	if defeated:
		velocity.x = move_toward(velocity.x, 0.0, TRANSITION_MOVE_DAMP * delta)
		move_and_slide()
		return

	_advance_layer_regen(delta)

	if _transition_invulnerable_time > 0.0:
		_transition_invulnerable_time = maxf(0.0, _transition_invulnerable_time - delta)
		if _transition_invulnerable_time <= 0.0:
			combat_receiver.invulnerable = false
		velocity.x = move_toward(velocity.x, 0.0, TRANSITION_MOVE_DAMP * delta)
		move_and_slide()
		return

	if not ai_enabled:
		velocity.x = move_toward(velocity.x, 0.0, TRANSITION_MOVE_DAMP * delta)
		move_and_slide()
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerCharacter
		move_and_slide()
		return

	if poise_stun_time > 0.0:
		poise_stun_time = maxf(0.0, poise_stun_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, TRANSITION_MOVE_DAMP * delta)
		move_and_slide()
		if poise_stun_time <= 0.0:
			_play_pose(&"idle")
		return

	var form := current_form
	var horizontal_distance := absf(global_position.x - player.global_position.x)
	var vertical_distance := absf(global_position.y - player.global_position.y)
	# Task 69 §2.3/§2.4: one distance test drives both the ranged stand-off
	# gate below and the accelerated melee recovery here. Inside the ring the
	# Boss has no ranged option left, so its melee cooldown drains at
	# delta / melee_cooldown_close_range_scale instead of delta -- an ember
	# form's 2.4s becomes ~1.44s. Deliberately a scaled drain rather than a
	# reset: a reset would turn point-blank into back-to-back melee, which is
	# worse than the bug being fixed.
	var in_close_range := horizontal_distance < form.ranged_minimum_distance
	var cooldown_step := delta
	if in_close_range:
		cooldown_step = delta / form.melee_cooldown_close_range_scale
	attack_cooldown = maxf(attack_cooldown - cooldown_step, 0.0)
	_summon_cooldown_remaining = maxf(_summon_cooldown_remaining - delta, 0.0)
	prompt.visible = false

	if attack_time > 0.0:
		attack_time = maxf(0.0, attack_time - delta)
		velocity.x = 0.0
		if telegraph_indicator != null:
			telegraph_indicator.advance(delta)
		move_and_slide()
		if attack_time <= 0.0:
			_play_pose(&"idle")
		return

	if not _telegraph_active and horizontal_distance <= form.melee_range and vertical_distance < 90.0 and attack_cooldown <= 0.0:
		_start_melee_attack(form)
		return

	if (
		not _telegraph_active
		and form.summon_max_alive > 0
		and _summon_cooldown_remaining <= 0.0
		and _alive_summon_count() < form.summon_max_alive
	):
		_start_summon(form)
		return

	# Task 69 §2.3: the ranged cycle is gated on distance, but only at the
	# "open a NEW telegraph" boundary -- an already-active telegraph is always
	# driven to completion, otherwise dashing into the Boss mid-windup would
	# be a free, cost-less cancel and the ! indicator would strobe on every
	# in/out step. Whenever the gate does suppress the cycle, the ranged
	# cooldown is drained by hand for exactly the same delta the base class
	# would have consumed, so backing out of the ring is punished immediately
	# instead of granting a free reload. Done here rather than inside
	# CombatEnemy._advance_ranged_attack_cycle() because TidalSentry shares
	# that method and must keep its current behavior verbatim.
	if _telegraph_active or not in_close_range:
		_advance_ranged_attack_cycle(delta, form.ranged_projectile_profile, StringName("boss_%s" % current_form_id))
		if _telegraph_active or attack_time > 0.0:
			velocity.x = 0.0
			move_and_slide()
			return
	else:
		_boss_projectile_cooldown = maxf(0.0, _boss_projectile_cooldown - delta)

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
		if sprite.animation != _animation_name(&"walk"):
			_play_pose(&"walk")
	else:
		if sprite.animation != _animation_name(&"idle"):
			_play_pose(&"idle")
	move_and_slide()


## §3.3 "常驻回补": ticks every physics frame regardless of ai_enabled/attack
## state and regardless of whether layers are being consumed by reactions.
## NONE form never regenerates (it has no element to regenerate).
func _advance_layer_regen(delta: float) -> void:
	var form := current_form
	if form == null or form.element_id == ElementIds.NONE:
		return
	_layer_regen_timer += delta
	var interval := tuning.attach_layer_regen_interval
	while _layer_regen_timer >= interval:
		_layer_regen_timer -= interval
		var before := element_carrier.snapshot()
		var current := before.get_amount(form.element_id)
		if current >= tuning.attach_layer_cap:
			continue
		var next_amount := mini(tuning.attach_layer_cap, current + 1)
		_replace_element_amount(form.element_id, next_amount, before)


func _on_hit_resolved(result: CombatResult) -> void:
	if defeated or result == null or not result.accepted:
		return
	var form := current_form
	if form == null or not form.counters(result.source_element_id):
		return
	counter_hits += 1
	counter_progress_changed.emit(counter_hits, tuning.counter_hit_threshold)
	if counter_hits < tuning.counter_hit_threshold:
		return
	counter_hits = 0
	counter_progress_changed.emit(counter_hits, tuning.counter_hit_threshold)
	_switch_to_next_form(result.source_element_id)


## Task 61 §3.1 exact state machine: alternating water/fire switches
## accumulate; once the NEXT switch would exceed alternation_switch_cap, it
## is redirected to the neutral form and the counter resets. From the
## neutral form, the counting element itself picks the destination and the
## counter restarts from zero.
func _switch_to_next_form(hit_element: StringName) -> void:
	var from := current_form
	var next_form_id: StringName
	if from.element_id == ElementIds.NONE:
		next_form_id = &"tide" if hit_element == ElementIds.WATER else &"ember"
		alternation_count = 0
	else:
		var tentative := alternation_count + 1
		if tentative > tuning.alternation_switch_cap:
			next_form_id = &"plain"
			alternation_count = 0
		else:
			alternation_count = tentative
			next_form_id = &"tide" if from.element_id == ElementIds.FIRE else &"ember"
	_begin_form_transition(next_form_id)


func _begin_form_transition(next_form_id: StringName) -> void:
	var next_form: BossFormDefinition = _forms.get(next_form_id)
	if next_form == null:
		return
	combat_receiver.invulnerable = true
	_transition_invulnerable_time = tuning.form_transition_invulnerable_duration
	_clear_active_deliveries()
	_cancel_ranged_attack_telegraph()
	attack_time = 0.0
	if telegraph_indicator != null:
		telegraph_indicator.cancel()
	poise_hits = 0
	poise_stun_time = 0.0
	current_form_id = next_form_id
	ranged_projectile_profile = next_form.ranged_projectile_profile
	_apply_form_layers(next_form, true)
	total_switch_count += 1
	switch_history.append(next_form_id)
	if next_form_id == &"plain":
		entered_plain_form = true
	_play_pose(&"idle")
	form_changed.emit(next_form_id, next_form.display_name)


## §3.3: switching clears the old attachment and grants attach_layers_on_switch
## of the new form's element; NONE form clears to zero and never regrows.
## Initial spawn (emit_signal=false) uses the same validated path.
func _apply_form_layers(form: BossFormDefinition, emit_signal_now: bool) -> void:
	var before := element_carrier.snapshot()
	var water := 0
	var fire := 0
	if form.element_id == ElementIds.WATER:
		water = tuning.attach_layers_on_switch
	elif form.element_id == ElementIds.FIRE:
		fire = tuning.attach_layers_on_switch
	var after := ElementSnapshot.new(water, fire, element_carrier.per_element_capacity)
	if not element_carrier.can_replace(after):
		return
	element_carrier.replace_silent(after)
	_layer_regen_timer = 0.0
	if emit_signal_now:
		element_carrier.notify_changed(before)


func _replace_element_amount(element_id: StringName, amount: int, before: ElementSnapshot) -> void:
	var water := amount if element_id == ElementIds.WATER else before.water_amount
	var fire := amount if element_id == ElementIds.FIRE else before.fire_amount
	var after := ElementSnapshot.new(water, fire, element_carrier.per_element_capacity)
	if not element_carrier.can_replace(after):
		return
	element_carrier.replace_silent(after)
	element_carrier.notify_changed(before)


func _animation_name(pose: StringName) -> StringName:
	if pose == &"hurt" or pose == &"death":
		return pose
	return StringName("%s_%s" % [current_form_id, pose])


## Every non-attack pose goes through here so speed_scale can never be left
## behind by the ranged windup (which stretches the attack clip to fit the
## profile's telegraph -- see _begin_ranged_attack_telegraph).
func _play_pose(pose: StringName) -> void:
	sprite.speed_scale = 1.0
	sprite.play(_animation_name(pose))


func _play_attack_from_frame(frame_index: int, speed_scale_value: float) -> void:
	sprite.speed_scale = speed_scale_value
	sprite.play(_animation_name(&"attack"))
	var frame_count := _attack_frame_count()
	if frame_count <= 0:
		return
	sprite.set_frame_and_progress(clampi(frame_index, 0, frame_count - 1), 0.0)


func _attack_frame_count() -> int:
	var frames := sprite.sprite_frames
	var animation_name := _animation_name(&"attack")
	if frames == null or not frames.has_animation(animation_name):
		return 0
	return frames.get_frame_count(animation_name)


## Wall-clock length of the attack clip's frames [from_index, to_index), read
## straight off the SpriteFrames (per-frame duration multiplier / animation
## fps). Task 69 forbids restating the tempo as literals in code, so every
## timing the Boss needs is derived from the authored resource plus the single
## configured impact-frame index.
func _attack_segment_duration(from_index: int, to_index: int) -> float:
	var frames := sprite.sprite_frames
	var animation_name := _animation_name(&"attack")
	if frames == null or not frames.has_animation(animation_name):
		return 0.0
	var speed := frames.get_animation_speed(animation_name)
	if speed <= 0.0:
		return 0.0
	var frame_count := frames.get_frame_count(animation_name)
	var total := 0.0
	for index: int in range(maxi(from_index, 0), mini(to_index, frame_count)):
		total += frames.get_frame_duration(animation_name, index) / speed
	return total


## Frames 0 .. impact-1. Must equal the current form's
## melee_telegraph_duration -- asserted by run_task69_*.
func attack_windup_duration() -> float:
	return _attack_segment_duration(0, tuning.melee_attack_impact_frame_index)


## Frames impact .. last. Doubles as the post-launch hold for a ranged shot so
## the impact pose is actually readable instead of being overwritten by walk
## on the very next physics tick.
func attack_recovery_duration() -> float:
	return _attack_segment_duration(tuning.melee_attack_impact_frame_index, _attack_frame_count())


## Task 69 §2.5: the base ranged cycle never touched the sprite, so the Boss
## spent the whole 0.4~0.5s windup marching in place in its walk clip. The
## attack clip's windup segment is reused as the charge-up, time-scaled so its
## impact frame arrives exactly when the projectile spawns even though the
## three forms telegraph for 0.4 / 0.45 / 0.5s against one 0.4s authored
## windup (scale 0.8~1.0 -- a mild slow-down, never a skip).
func _begin_ranged_attack_telegraph(profile: EnemyProjectileProfile, cast_source: StringName) -> void:
	var was_active := _telegraph_active
	super(profile, cast_source)
	if not _telegraph_active or was_active:
		return
	var windup := attack_windup_duration()
	var scale := 1.0
	if windup > 0.0 and profile != null and profile.telegraph_duration > 0.0:
		scale = windup / profile.telegraph_duration
	_play_attack_from_frame(0, scale)


func _launch_ranged_projectile(profile: EnemyProjectileProfile, direction: Vector2, cast_source: StringName) -> void:
	var fired_before := boss_projectiles_fired
	super(profile, direction, cast_source)
	if boss_projectiles_fired == fired_before:
		# Nothing actually spawned (dead, invalid profile, no player): make
		# sure a stretched windup never leaks its speed_scale onward.
		sprite.speed_scale = 1.0
		return
	_play_attack_from_frame(tuning.melee_attack_impact_frame_index, 1.0)
	attack_time = maxf(attack_time, attack_recovery_duration())


## Keeps the stretched ranged-windup speed_scale from surviving a cancel
## (poise break, hurt, form transition, death) that the base class performs.
func _cancel_ranged_attack_telegraph() -> void:
	var was_active := _telegraph_active
	super()
	if was_active:
		sprite.speed_scale = 1.0


func _start_melee_attack(form: BossFormDefinition) -> void:
	facing = signf(player.global_position.x - global_position.x)
	if is_zero_approx(facing):
		facing = 1.0
	sprite.flip_h = facing < 0.0
	# Task 69 §2.2: the swing starts on animation frame 0 at exactly the same
	# instant the ! indicator and the DelayedAreaDelivery's WAITING phase
	# start, so the animation's windup segment (frames 0 .. impact-1) IS the
	# telegraph window and the impact frame lands on the frame the hitbox goes
	# live. Restarting explicitly at frame 0 matters because AnimatedSprite2D
	# keeps its position when play() is called on the already-current, already
	# finished non-looping clip.
	_play_attack_from_frame(0, 1.0)
	attack_cooldown = form.attack_cooldown
	attack_time = maxf(form.melee_telegraph_duration, 0.05) + MELEE_ACTIVE_DURATION + MELEE_RECOVERY_DURATION
	if telegraph_indicator != null and form.melee_telegraph_duration > 0.0:
		telegraph_indicator.start(form.melee_telegraph_duration)
	_spawn_melee_delayed_delivery(form)


## §3.7: melee telegraph reuses DelayedAreaDelivery directly -- the delivery
## is spawned immediately and its own Phase.WAITING (trigger_delay) IS the
## telegraph window; EnemyTelegraphIndicator is started for the identical
## duration in parallel and self-hides. The delivery self-finishes/frees once
## its active window closes (Task 59 precedent), no manual bookkeeping needed
## beyond delivery_created tracking for form-transition cleanup.
func _spawn_melee_delayed_delivery(form: BossFormDefinition) -> void:
	if defeated or not is_instance_valid(player):
		return
	var delivery := BOSS_MELEE_SCENE.instantiate() as DelayedAreaDelivery
	if delivery == null:
		return
	delivery.trigger_delay = maxf(form.melee_telegraph_duration, 0.0)
	delivery.active_duration = MELEE_ACTIVE_DURATION
	delivery.hurtbox_collision_mask = 16
	delivery.query_offset = Vector2(50.0, 0.0)
	var cast_snapshot := CastSnapshot.new(
		_allocate_enemy_cast_id(),
		StringName("boss_%s_melee" % current_form_id),
		get_instance_id(),
		get_instance_id(),
		&"enemy",
		ElementIds.NONE,
		CombatStatSnapshot.new(),
	)
	var payload := RuntimeAttackPayload.new(
		form.melee_damage,
		form.melee_damage,
		ElementIds.NONE,
		0,
		PackedStringArray(["boss_melee"]),
	)
	var direction := Vector2.RIGHT if facing >= 0.0 else Vector2.LEFT
	if not delivery.initialize_delivery(cast_snapshot, payload, 1, global_transform, direction):
		delivery.free()
		return
	get_tree().current_scene.add_child(delivery)
	delivery_created.emit(delivery)


func _alive_summon_count() -> int:
	var count := 0
	for reference: WeakRef in _active_summons:
		var node: Variant = reference.get_ref()
		if node != null and is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			count += 1
	return count


func _start_summon(form: BossFormDefinition) -> void:
	_summon_cooldown_remaining = form.summon_cooldown
	attack_time = 0.5
	_play_attack_from_frame(0, 1.0)
	var slots_free := form.summon_max_alive - _alive_summon_count()
	var to_spawn := mini(form.summon_count_per_cast, slots_free)
	for index: int in to_spawn:
		if form.summon_scene == null:
			break
		var summon := form.summon_scene.instantiate() as CombatEnemy
		if summon == null:
			continue
		var side := 1.0 if index % 2 == 0 else -1.0
		var offset_x := side * (110.0 + 60.0 * float(index))
		summon.global_position = global_position + Vector2(offset_x, -20.0)
		get_tree().current_scene.add_child(summon)
		_active_summons.append(weakref(summon))


func _on_delivery_created(delivery: Node) -> void:
	_active_deliveries.append(weakref(delivery))


## §3.7 form-transition presentation: residual Boss-owned deliveries (melee
## windows and in-flight bolts) are cleared so the player cannot be hit by a
## shot that was aimed/launched under the previous form the instant the
## transition ends.
func _clear_active_deliveries() -> void:
	for reference: WeakRef in _active_deliveries:
		var node: Variant = reference.get_ref()
		if node != null and is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			(node as Node).queue_free()
	_active_deliveries.clear()


func _on_death_candidate(_result: CombatResult) -> void:
	if defeated:
		return
	defeated = true
	_cancel_ranged_attack_telegraph()
	_clear_active_deliveries()
	attack_time = 0.0
	if telegraph_indicator != null:
		telegraph_indicator.cancel()
	poise_stun_time = 0.0
	velocity = Vector2.ZERO
	combat_receiver.accepting_hits = false
	element_carrier.clear_all()
	prompt.visible = true
	prompt.text = "已击败 · R 重置"
	_play_pose(&"death")
	enemy_defeated.emit()
	if _formal_run_spawn:
		call_deferred("queue_free")
