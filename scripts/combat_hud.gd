class_name CombatHUD
extends CanvasLayer

signal reduced_motion_changed(enabled: bool)

const WATER_COLOR := Color("43c8f5")
const FIRE_COLOR := Color("ff6847")
const LOW_HEALTH_THRESHOLD := 0.30
const WARNING_RATE_LIMIT_MSEC := 650

@onready var status_panel: PanelContainer = $Root/StatusPanel
@onready var skill_panel: PanelContainer = $Root/SkillPanel
@onready var health_bar: ProgressBar = $Root/StatusPanel/Margin/Status/HealthRow/HealthBar
@onready var health_value: Label = $Root/StatusPanel/Margin/Status/HealthRow/HealthValue
@onready var low_health: Label = $Root/StatusPanel/Margin/Status/LowHealth
@onready var energy_row: HBoxContainer = $Root/StatusPanel/Margin/Status/EnergyRow
@onready var energy_bar: ProgressBar = $Root/StatusPanel/Margin/Status/EnergyRow/EnergyBar
@onready var energy_value: Label = $Root/StatusPanel/Margin/Status/EnergyRow/EnergyValue
@onready var element_swatch: ColorRect = $Root/StatusPanel/Margin/Status/TitleRow/ElementBadge/BadgeMargin/BadgeRow/ElementSwatch
@onready var element_text: Label = $Root/StatusPanel/Margin/Status/TitleRow/ElementBadge/BadgeMargin/BadgeRow/ElementText
@onready var primary_state: Label = $Root/SkillPanel/Margin/Skills/PrimaryRow/PrimaryState
@onready var melee_state: Label = $Root/SkillPanel/Margin/Skills/MeleeRow/MeleeState
@onready var phase_text: Label = $Root/SkillPanel/Margin/Skills/PhaseText
@onready var warning_text: Label = $Root/WarningText
@onready var debug_panel: PanelContainer = $Root/DebugPanel
@onready var debug_skill: Label = $Root/DebugPanel/Margin/Debug/Skill
@onready var debug_target: Label = $Root/DebugPanel/Margin/Debug/Target
@onready var debug_result: Label = $Root/DebugPanel/Margin/Debug/Result
@onready var motion_state: Label = $Root/DebugPanel/Margin/Debug/Motion

var reduced_motion: bool = false

var _player: PlayerCharacter
var _target: CombatEnemy
var _feedback: CombatFeedback
var _player_damage: DamageReceiver
var _player_energy: EnergyComponent
var _player_form: ElementFormController
var _player_executor: SkillExecutor
var _player_skills: SkillController
var _target_damage: DamageReceiver
var _target_carrier: ElementCarrier
var _last_warning_msec: int = -WARNING_RATE_LIMIT_MSEC
var _warning_tween: Tween
var _energy_tween: Tween
var _form_tween: Tween
var _debug_elapsed: float = 0.0
var _last_event_text: String = "等待战斗结果"


func configure(player: PlayerCharacter, target: CombatEnemy, feedback: CombatFeedback) -> void:
	_player = player
	_target = target
	_feedback = feedback
	if _player == null or _target == null:
		return

	_player_damage = _player.damage_receiver
	_player_energy = _player.energy_component
	_player_form = _player.form_controller
	_player_executor = _player.skill_executor
	_player_skills = _player.skill_controller
	_target_damage = _target.damage_receiver
	_target_carrier = _target.element_carrier

	_player_damage.health_changed.connect(_on_player_health_changed)
	_player_energy.energy_changed.connect(_on_energy_changed)
	_player_form.form_changed.connect(_on_form_changed)
	_player_executor.phase_changed.connect(_on_phase_changed)
	_player_executor.cooldown_started.connect(_on_cooldown_changed)
	_player_executor.cooldown_finished.connect(_on_cooldown_finished)
	_player_skills.cast_attempted.connect(_on_cast_attempted)
	_target_damage.health_changed.connect(_on_target_health_changed)
	_target_carrier.elements_changed.connect(_on_target_elements_changed)
	if _feedback != null:
		_feedback.result_observed.connect(_on_result_observed)

	_on_player_health_changed(
		_player_damage.current_health,
		_player_damage.maximum_health,
		0,
	)
	_on_energy_changed(_player_energy.current_energy, _player_energy.maximum, 0)
	_on_form_changed(_player_form.current_form_id, ElementIds.NONE)
	_refresh_skill_status()
	_refresh_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_refresh_debug()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_reduced_motion"):
		reduced_motion = not reduced_motion
		motion_state.text = "动态效果：%s（F4）" % ("减少" if reduced_motion else "完整")
		reduced_motion_changed.emit(reduced_motion)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not debug_panel.visible:
		return
	_debug_elapsed += delta
	if _debug_elapsed >= 0.10:
		_debug_elapsed = 0.0
		_refresh_debug()


func _on_player_health_changed(current: int, maximum: int, _delta: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%3d / %3d" % [current, maximum]
	var ratio := float(current) / float(maxi(1, maximum))
	low_health.visible = ratio < LOW_HEALTH_THRESHOLD


func _on_energy_changed(current: int, maximum: int, delta: int) -> void:
	energy_bar.max_value = maximum
	energy_bar.value = current
	energy_value.text = "%3d / %3d" % [current, maximum]
	if delta < 0:
		_pulse_energy()
	_refresh_skill_status()


func _on_form_changed(current_form: StringName, _previous_form: StringName) -> void:
	var definition := _player.get_element_definition(current_form) if _player != null else null
	var display_name := "水" if current_form == ElementIds.WATER else "火"
	var color := WATER_COLOR if current_form == ElementIds.WATER else FIRE_COLOR
	if definition != null and definition.is_valid():
		display_name = definition.display_name
		color = definition.presentation_color
	element_swatch.color = color
	element_text.text = "%s · %s" % [display_name, String(current_form).to_upper()]
	if reduced_motion:
		element_text.modulate = Color.WHITE
		return
	if _form_tween != null and _form_tween.is_valid():
		_form_tween.kill()
	element_text.modulate.a = 0.45
	_form_tween = create_tween()
	_form_tween.tween_property(element_text, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refresh_skill_status()


func _on_phase_changed(
		_cast_id: int,
		_previous_phase: SkillExecutor.Phase,
		_current_phase: SkillExecutor.Phase
) -> void:
	_refresh_skill_status()


func _on_cooldown_changed(_skill_id: StringName, _duration: float) -> void:
	_refresh_skill_status()


func _on_cooldown_finished(_skill_id: StringName) -> void:
	_refresh_skill_status()


func _on_cast_attempted(slot_id: StringName, result: CastAttemptResult) -> void:
	if result == null:
		return
	if not result.accepted:
		_last_event_text = "释放拒绝：%s / %s" % [String(slot_id), String(result.reason_name())]
		if result.reject_reason == CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY:
			_show_energy_warning()
	else:
		_last_event_text = "释放接受：%s / cast %d" % [String(result.skill_id), result.cast_snapshot.cast_id]
	_refresh_skill_status()


func _on_target_health_changed(_current: int, _maximum: int, _delta: int) -> void:
	_refresh_debug()


func _on_target_elements_changed(
		_current: ElementSnapshot,
		_water_delta: int,
		_fire_delta: int
) -> void:
	_refresh_debug()


func _on_result_observed(result: CombatResult, receiver: CombatReceiver) -> void:
	if result == null:
		return
	if result.accepted:
		_last_event_text = (
			"cast=%d  delivery=%d  hit=%d\n"
			+ "damage=%d  element=%s  reaction=%s\n"
			+ "consume=%d  multiplier=%.1f  ΔW=%d  ΔF=%d"
		) % [
			result.cast_id,
			result.delivery_id,
			result.hit_index,
			result.final_damage,
			String(result.source_element_id),
			str(result.reaction_triggered),
			result.reaction_consumed,
			result.reaction_multiplier,
			result.water_delta,
			result.fire_delta,
		]
	else:
		var target_name := String(receiver.target_team_id) if receiver != null else "unknown"
		_last_event_text = "命中拒绝：%s / %s\n目标：%s" % [
			String(result.reject_code),
			String(result.reject_detail),
			target_name,
		]
	_refresh_debug()


func _refresh_skill_status() -> void:
	if _player_executor == null or _player_skills == null or _player_energy == null:
		return
	var phase := String(_player_executor.get_phase_name())
	phase_text.text = "动作阶段：%s" % phase.to_upper()
	var primary := _player_skills.get_skill_for_slot(&"primary")
	var melee := _player_skills.get_skill_for_slot(&"melee")
	primary_state.text = _availability_text(primary)
	melee_state.text = _availability_text(melee)


func _availability_text(skill: SkillDefinition) -> String:
	if skill == null:
		return "未配置"
	if _player_executor.current_phase != SkillExecutor.Phase.IDLE:
		var active_snapshot := _player_executor.current_cast_snapshot
		if active_snapshot != null and active_snapshot.skill_id == skill.skill_id:
			return "施放中"
		return "忙碌"
	if _player_energy.current_energy < skill.energy_cost:
		return "能量不足"
	if _player_executor.is_skill_on_cooldown(skill.skill_id):
		return "冷却 %.1fs" % _player_executor.get_cooldown_remaining(skill.skill_id)
	return "可用"


func _pulse_energy() -> void:
	if reduced_motion:
		return
	if _energy_tween != null and _energy_tween.is_valid():
		_energy_tween.kill()
	energy_row.modulate = Color(1.30, 1.30, 1.30, 1.0)
	_energy_tween = create_tween()
	_energy_tween.tween_property(energy_row, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_energy_warning() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_warning_msec < WARNING_RATE_LIMIT_MSEC:
		return
	_last_warning_msec = now
	warning_text.text = "能量不足"
	warning_text.visible = true
	warning_text.modulate.a = 1.0
	_pulse_energy()
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_interval(0.48)
	_warning_tween.tween_property(warning_text, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_warning_tween.tween_callback(func() -> void: warning_text.visible = false)


func _refresh_debug() -> void:
	if _player_executor == null or _target_damage == null or _target_carrier == null:
		return
	var cast_snapshot := _player_executor.current_cast_snapshot
	var skill_id := String(cast_snapshot.skill_id) if cast_snapshot != null else "none"
	var cast_id := cast_snapshot.cast_id if cast_snapshot != null else 0
	var primary := _player_skills.get_skill_for_slot(&"primary")
	var cooldown := _player_executor.get_cooldown_remaining(primary.skill_id) if primary != null else 0.0
	debug_skill.text = "技能：%s\nphase=%s  cast_id=%d  cooldown=%.2f" % [
		skill_id,
		String(_player_executor.get_phase_name()),
		cast_id,
		cooldown,
	]
	debug_target.text = "目标：HP %d / %d\n水 %d / 10    火 %d / 10" % [
		_target_damage.current_health,
		_target_damage.maximum_health,
		_target_carrier.get_amount(ElementIds.WATER),
		_target_carrier.get_amount(ElementIds.FIRE),
	]
	debug_result.text = _last_event_text
	motion_state.text = "动态效果：%s（F4）" % ("减少" if reduced_motion else "完整")



