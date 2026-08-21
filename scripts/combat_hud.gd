class_name CombatHUD
extends CanvasLayer

const UI := preload("res://scripts/ui/combat_ui_tokens.gd")
const RUN_OVERLAY_SCRIPT := preload("res://scripts/ui/run_overlay_interface.gd")

signal reduced_motion_changed(enabled: bool)
signal colorblind_mode_changed(enabled: bool)

const WARNING_RATE_LIMIT_MSEC := 450
const SLOT_TRANSIENT_MSEC := 900
const STATUS_SIZE := Vector2(264, 76)
const SKILL_STRIP_SIZE := Vector2(532, 72)
## Deliberately larger than the naive 4*96 + 3*GAP_SM + 2*GAP_SM = 424
## hand-derivation: PanelContainer.set_size() clamps up to its own computed
## minimum (children + each nested panel stylebox's border-driven content
## margin), so the true floor here is 442 (100px per slot once its own
## 2px border is included, +16 row margin +2 outer border). 448 keeps a
## few px of headroom above that floor -- landing exactly on 442 risks a
## sub-pixel float clamp -- while still satisfying B5 criterion 2 (<=452.2).
const PASSIVE_STRIP_SIZE := Vector2(448, 56)
const ELEMENT_PIVOT_SIZE := Vector2(72, 56)
const ACTIVE_SLOT_SIZE := Vector2(132, 54)
const PASSIVE_SLOT_SIZE := Vector2(96, 42)
const ROOM_TITLE_SIZE := Vector2(280, 32)
const SLOT_ORDER: Array[StringName] = [
	SkillSlotIds.ACTIVE_1,
	SkillSlotIds.ACTIVE_2,
	SkillSlotIds.ACTIVE_3,
	SkillSlotIds.PASSIVE_1,
	SkillSlotIds.PASSIVE_2,
	SkillSlotIds.PASSIVE_3,
	SkillSlotIds.PASSIVE_4,
]

var reduced_motion: bool = false
var colorblind_mode: bool = false

var status_panel: PanelContainer
var skill_panel: PanelContainer
var passive_panel: PanelContainer
var health_bar: ProgressBar
var health_value: Label
var low_health: Label
var energy_row: HBoxContainer
var energy_bar: ProgressBar
var energy_value: Label
var element_swatch: ColorRect
var element_text: Label
var phase_text: Label
var warning_text: Label
var debug_panel: PanelContainer
var debug_skill: Label
var debug_target: Label
var debug_result: Label
var motion_state: Label
var help_panel: PanelContainer
var run_overlay
var boss_panel: PanelContainer

var _player: PlayerCharacter
var _target: CombatEnemy
var _feedback: CombatFeedback
var _host: RunSessionHost
var _catalog: RunContentCatalog
var _player_damage: DamageReceiver
var _player_energy: EnergyComponent
var _player_element: CurrentElementController
var _player_executor: SkillExecutor
var _player_skills: SkillController
var _target_damage: DamageReceiver
var _target_carrier: ElementCarrier
var _slot_views: Dictionary = {}
var _compat_slot_views: Dictionary = {}
var _slot_transients: Dictionary = {}
var _target_water: Label
var _target_fire: Label
var _target_panel: PanelContainer
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _element_pivot: PanelContainer
var _element_pivot_swatch: ColorRect
var _element_pivot_text: Label
var _element_pivot_shape: Label
var _legacy_element_swatch: ColorRect
var _legacy_element_text: Label
var _last_warning_msec: int = -WARNING_RATE_LIMIT_MSEC
var _banner_tween: Tween
var _energy_tween: Tween
var _element_tween: Tween
var _debug_elapsed: float = 0.0
var _last_event_text: String = "等待战斗结果"
var _pending_auto_change: ElementChangeResult
var _boss_target: BossTideEmber
var _boss_health_bar: ProgressBar
var _boss_health_value: Label
var _boss_form_label: Label
var _boss_counter_bar: ProgressBar
var _boss_counter_label: Label
var _room_title_label: Label


func _enter_tree() -> void:
	if get_node_or_null("Root") == null:
		_build_ui()


func _ready() -> void:
	_bind_ui_refs()


func configure(
	player: PlayerCharacter,
	target: CombatEnemy,
	feedback: CombatFeedback,
	host: RunSessionHost = null,
	formal_coordinator: Node = null
) -> void:
	_player = player
	_target = target
	_feedback = feedback
	_host = host
	_catalog = host.content_catalog if host != null else null
	if _player == null or _target == null:
		return
	_player_damage = _player.damage_receiver
	_player_energy = _player.energy_component
	_player_element = _player.current_element_controller
	_player_executor = _player.skill_executor
	_player_skills = _player.skill_controller
	_target_damage = _target.damage_receiver
	_target_carrier = _target.element_carrier

	_connect_once(_player_damage.health_changed, _on_player_health_changed)
	_connect_once(_player_energy.energy_changed, _on_energy_changed)
	_connect_once(_player_element.element_changed, _on_element_changed)
	_connect_once(_player_executor.phase_changed, _on_phase_changed)
	_connect_once(_player_executor.cooldown_started, _on_cooldown_changed)
	_connect_once(_player_executor.cooldown_finished, _on_cooldown_finished)
	_connect_once(_player_skills.cast_attempted, _on_cast_attempted)
	_connect_once(_player_skills.element_change_attempted, _on_element_change_attempted)
	_connect_once(_target_damage.health_changed, _on_target_health_changed)
	_connect_once(_target_carrier.elements_changed, _on_target_elements_changed)
	if _feedback != null:
		_connect_once(_feedback.result_observed, _on_result_observed)
	if _host != null and _host.runtime_loadout != null:
		_connect_once(_host.runtime_loadout.loadout_replaced, _on_loadout_replaced)
		run_overlay.configure(_host, formal_coordinator)
		run_overlay.set_current_element(_player_element.current_element_id)
		run_overlay.status_requested.connect(_on_overlay_status_requested)

	_on_player_health_changed(_player_damage.current_health, _player_damage.maximum_health, 0)
	_on_energy_changed(_player_energy.current_energy, _player_energy.maximum, 0)
	_refresh_element(_player_element.current_element_id, false)
	_refresh_target_elements()
	_refresh_skill_status()
	_refresh_debug()
	_bind_boss_panel(_target)


func rebind_target(target: CombatEnemy) -> void:
	if target == null:
		return
	_target = target
	_target_damage = target.damage_receiver
	_target_carrier = target.element_carrier
	_connect_once(_target_damage.health_changed, _on_target_health_changed)
	_connect_once(_target_carrier.elements_changed, _on_target_elements_changed)
	_refresh_target_elements()
	_refresh_debug()
	_bind_boss_panel(_target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		debug_panel.visible = not debug_panel.visible
		if debug_panel.visible:
			_refresh_debug()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_reduced_motion"):
		set_reduced_motion(not reduced_motion)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L:
			run_overlay.toggle_loadout()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
			set_colorblind_mode(not colorblind_mode)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if debug_panel.visible:
		_debug_elapsed += delta
		if _debug_elapsed >= 0.10:
			_debug_elapsed = 0.0
			_refresh_debug()
	if _player_executor != null:
		_expire_slot_transients()
		_refresh_cooldown_text_only()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	motion_state.text = "动态效果：%s（F4）" % ("减少" if enabled else "完整")
	if _feedback != null:
		_feedback.set_reduced_motion(enabled)
	reduced_motion_changed.emit(enabled)
	_show_feedback("减少动态：保留文字、形状与状态语义" if enabled else "动态效果：完整", &"info", 1.0)


func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled
	run_overlay.set_colorblind_mode(enabled)
	_refresh_element(_player_element.current_element_id if _player_element != null else ElementIds.WATER, false)
	_refresh_target_elements()
	_refresh_skill_status()
	colorblind_mode_changed.emit(enabled)
	_show_feedback("色觉辅助：%s · 水滴/火焰形状与文字保持可见" % ("开启" if enabled else "关闭"), &"info", 1.4)


func slot_panel(slot_id: StringName) -> PanelContainer:
	var view: Dictionary = _compat_slot_views.get(slot_id, {})
	return view.get("panel") as PanelContainer


func visual_slot_panel(slot_id: StringName) -> PanelContainer:
	var view: Dictionary = _slot_views.get(slot_id, {})
	return view.get("panel") as PanelContainer


func element_pivot_panel() -> PanelContainer:
	return _element_pivot


## Task 72 §2 B3: public entry point so room instances push their title copy
## into the HUD instead of owning a world-space Label of their own.
func set_room_title(text: String) -> void:
	if _room_title_label != null:
		_room_title_label.text = text


func room_title_label() -> Label:
	return _room_title_label


func has_visible_target_attachment_text() -> bool:
	return _target_panel != null and _target_panel.is_visible_in_tree()


func feedback_text() -> String:
	return _feedback_label.text


func _on_player_health_changed(current: int, maximum: int, _delta: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%3d / %3d" % [current, maximum]
	low_health.visible = float(current) / float(maxi(1, maximum)) < 0.30


func _on_energy_changed(current: int, maximum: int, delta: int) -> void:
	energy_bar.max_value = maximum
	energy_bar.value = current
	energy_value.text = "%3d / %3d" % [current, maximum]
	if delta < 0:
		_pulse_energy()
	_refresh_skill_status()


func _on_element_changed(change: ElementChangeResult) -> void:
	if change == null or not change.accepted or not change.changed:
		return
	_refresh_element(change.current_element_id)
	if change.source == FormChangedEvent.Source.MANUAL:
		_pending_auto_change = null
		_show_feedback("手动切换 · %s" % _element_label(change.current_element_id), &"manual")
	else:
		_pending_auto_change = change


func _on_element_change_attempted(result: ElementChangeResult) -> void:
	if result == null:
		return
	if not result.accepted:
		_show_feedback("切换失败 · %s" % String(result.detail), &"error")
	elif result.buffered:
		_show_feedback("手动切换已排队 · %s" % _element_label(result.current_element_id), &"manual")


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
		_pending_auto_change = null
		_last_event_text = "释放拒绝：%s / %s" % [String(slot_id), String(result.reason_name())]
		_set_slot_transient(slot_id, "失败", &"error")
		_show_reject_feedback(result)
		_refresh_skill_status()
		return
	var skill := _player_skills.get_skill_for_slot(slot_id)
	var content := _catalog.content_for(result.skill_id) if _catalog != null else null
	var display_name := content.display_name if content != null else String(result.skill_id)
	if skill != null:
		var feedback := cast_acceptance_feedback(
			skill,
			display_name,
			slot_id,
			result.cast_snapshot,
			_pending_auto_change != null
		)
		if not feedback.is_empty():
			_show_feedback(feedback, _acceptance_tone(skill, _pending_auto_change != null))
			_set_slot_transient(slot_id, "锁定", &"lock")
	_pending_auto_change = null
	_last_event_text = "释放接受：%s / cast %d / locked=%s" % [String(result.skill_id), result.cast_snapshot.cast_id, String(result.cast_snapshot.cast_element_id)]
	_refresh_skill_status()


func cast_acceptance_feedback(
	skill: SkillDefinition,
	display_name: String,
	slot_id: StringName,
	snapshot: CastSnapshot,
	auto_change_committed: bool
) -> String:
	if skill == null or snapshot == null:
		return ""
	match skill.element_policy:
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
			if auto_change_committed:
				return "自动调谐 · %s → 当前元素 %s" % [String(slot_id).to_upper(), _element_label(snapshot.cast_element_id)]
			return "固定元素锁定 · %s · %s" % [display_name, _element_label(snapshot.cast_element_id)]
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
			return "元素锁定 · %s · %s" % [display_name, _element_label(snapshot.cast_element_id)]
		SkillDefinition.ElementPolicy.NEUTRAL:
			return "无属性锁定 · %s · ○ NONE" % display_name
		_:
			return ""


func _acceptance_tone(skill: SkillDefinition, auto_change_committed: bool) -> StringName:
	if skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT and auto_change_committed:
		return &"auto"
	if skill.element_policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
		return &"lock"
	if skill.element_policy == SkillDefinition.ElementPolicy.NEUTRAL:
		return &"neutral"
	return &"lock"


func _show_reject_feedback(result: CastAttemptResult) -> void:
	match result.reject_reason:
		CastAttemptResult.RejectReason.INSUFFICIENT_ENERGY:
			_show_feedback("能量不足 · 等待恢复后重试", &"energy")
			_pulse_energy()
		CastAttemptResult.RejectReason.COOLDOWN_ACTIVE:
			_show_feedback("冷却中 · %.1f 秒后可用" % result.cooldown_remaining, &"cooldown")
		CastAttemptResult.RejectReason.BUSY, CastAttemptResult.RejectReason.EXTERNAL_GATE_REJECTED:
			_show_feedback("当前忙碌 · 动作结束后重试", &"busy")
		CastAttemptResult.RejectReason.NOT_CASTABLE:
			_show_feedback("被动技能 · 此按键不发起释放", &"passive")
		CastAttemptResult.RejectReason.SLOT_UNASSIGNED:
			_show_feedback("槽位为空 · 请在共享配装中装备技能", &"error")
		_:
			_show_feedback("释放失败 · %s" % String(result.reason_name()), &"error")


func _on_target_health_changed(_current: int, _maximum: int, _delta: int) -> void:
	_refresh_debug()
	_refresh_boss_health()


## Task 61 §3.9: Boss health bar + form + counter progress. Purely additive
## -- non-Boss targets (_target not a BossTideEmber) leave boss_panel hidden
## and every existing HUD path (debug panel, target element text, etc.)
## behaves exactly as before.
func _bind_boss_panel(target: CombatEnemy) -> void:
	if boss_panel == null:
		return
	var boss := target as BossTideEmber
	_boss_target = boss
	boss_panel.visible = boss != null
	if boss == null:
		return
	if not boss.form_changed.is_connected(_on_boss_form_changed):
		boss.form_changed.connect(_on_boss_form_changed)
	if not boss.counter_progress_changed.is_connected(_on_boss_counter_progress_changed):
		boss.counter_progress_changed.connect(_on_boss_counter_progress_changed)
	_on_boss_form_changed(boss.current_form_id, boss.current_form.display_name)
	_on_boss_counter_progress_changed(boss.counter_hits, boss.tuning.counter_hit_threshold)
	_refresh_boss_health()


func _on_boss_form_changed(form_id: StringName, display_name: String) -> void:
	if _boss_form_label == null:
		return
	_boss_form_label.text = "形态：%s" % display_name
	var color := UI.NEUTRAL
	if form_id == &"ember":
		color = _element_color(ElementIds.FIRE)
	elif form_id == &"tide":
		color = _element_color(ElementIds.WATER)
	_boss_form_label.add_theme_color_override(&"font_color", color)


func _on_boss_counter_progress_changed(hits: int, threshold: int) -> void:
	if _boss_counter_bar == null:
		return
	_boss_counter_bar.max_value = maxi(1, threshold)
	_boss_counter_bar.value = hits
	_boss_counter_label.text = "克制进度 %d / %d" % [hits, threshold]


func _refresh_boss_health() -> void:
	if _boss_target == null or _boss_health_bar == null or not is_instance_valid(_boss_target):
		return
	var damage := _boss_target.damage_receiver
	if damage == null:
		return
	_boss_health_bar.max_value = damage.maximum_health
	_boss_health_bar.value = damage.current_health
	_boss_health_value.text = "%3d / %3d" % [damage.current_health, damage.maximum_health]


func _on_target_elements_changed(_current: ElementSnapshot, _water_delta: int, _fire_delta: int) -> void:
	_refresh_target_elements()
	_refresh_debug()


func _on_result_observed(result: CombatResult, receiver: CombatReceiver) -> void:
	if result == null:
		return
	if result.accepted:
		_pulse_matching_passive(result.skill_id)
		_last_event_text = "基础=%.1f  反应后=%.1f  最终=%d\n反应×%.1f  实耗=%d  ΔW=%d  ΔF=%d" % [
			result.offensive_damage,
			result.reacted_damage,
			result.final_damage,
			result.reaction_multiplier,
			result.reaction_consumed,
			result.water_delta,
			result.fire_delta,
		]
		if result.mitigation_applied:
			_show_feedback("同元素免伤 · 伤害大幅降低（%d）" % result.final_damage, &"mitigated")
		elif result.reaction_triggered:
			_show_feedback("反元素增伤 · ×%.1f（%d）" % [result.reaction_multiplier, result.final_damage], &"reaction")
	else:
		var target_name := String(receiver.target_team_id) if receiver != null else "unknown"
		_last_event_text = "命中拒绝：%s / %s\n目标：%s" % [String(result.reject_code), String(result.reject_detail), target_name]
	_refresh_debug()


func _on_loadout_replaced(_previous: RuntimeLoadoutSnapshot, _current: RuntimeLoadoutSnapshot) -> void:
	_refresh_skill_status()
	_show_feedback("共享配装已提交 · 被动列表同步更新", &"success")


func _on_overlay_status_requested(message: String, tone: StringName) -> void:
	if tone == &"error":
		_show_feedback(message, &"error", 1.8)


func _refresh_element(current_element_id: StringName, animate: bool = true) -> void:
	var definition := _player.get_element_definition(current_element_id) if _player != null else null
	var color := _element_color(current_element_id)
	if definition != null and definition.is_valid() and not colorblind_mode:
		color = definition.presentation_color
	element_swatch.color = color
	element_text.text = _element_label(current_element_id)
	if _legacy_element_swatch != null:
		_legacy_element_swatch.color = color
	if _legacy_element_text != null:
		_legacy_element_text.text = _element_label(current_element_id)
	if _element_pivot_swatch != null:
		_element_pivot_swatch.color = color
	if _element_pivot_text != null:
		_element_pivot_text.text = _element_short_label(current_element_id)
	if _element_pivot_shape != null:
		_element_pivot_shape.text = _element_shape(current_element_id)
		_element_pivot_shape.add_theme_color_override(&"font_color", color)
	if run_overlay != null:
		run_overlay.set_current_element(current_element_id)
	# Element changes already have persistent shape/color/text plus the feedback
	# banner.  Never fade the compact element text during a live skill frame:
	# capture and gameplay must keep the semantic short label fully readable.
	if _element_tween != null and _element_tween.is_valid():
		_element_tween.kill()
	_element_tween = null
	element_text.modulate = Color.WHITE
	_refresh_skill_status()


func _refresh_target_elements() -> void:
	if _target_carrier == null or _target_water == null:
		return
	var water := _target_carrier.get_amount(ElementIds.WATER)
	var fire := _target_carrier.get_amount(ElementIds.FIRE)
	_target_water.text = "水滴 WATER  ×%d" % water
	_target_fire.text = "火焰 FIRE   ×%d" % fire
	_target_water.add_theme_color_override(&"font_color", _element_color(ElementIds.WATER) if water > 0 else UI.TEXT_DIM)
	_target_fire.add_theme_color_override(&"font_color", _element_color(ElementIds.FIRE) if fire > 0 else UI.TEXT_DIM)
	# Task 24 keeps the authoritative binding for compatibility, but formal
	# Viewports never render target attachment copy.
	if _target_panel != null:
		_target_panel.visible = false


func _refresh_skill_status() -> void:
	if _player_executor == null or _player_skills == null or _player_energy == null:
		return
	phase_text.text = "动作阶段：%s" % String(_player_executor.get_phase_name()).to_upper()
	for slot_id: StringName in SLOT_ORDER:
		_refresh_slot(slot_id)


func _refresh_slot(slot_id: StringName) -> void:
	var skill := _player_skills.get_skill_for_slot(slot_id)
	var view: Dictionary = _slot_views.get(slot_id, {})
	if not view.is_empty():
		_refresh_slot_view(view, slot_id, skill, true)
	var compatibility_view: Dictionary = _compat_slot_views.get(slot_id, {})
	if not compatibility_view.is_empty():
		_refresh_slot_view(compatibility_view, slot_id, skill, false)


func _refresh_slot_view(
	view: Dictionary,
	slot_id: StringName,
	skill: SkillDefinition,
	compact: bool
) -> void:
	var key_panel := view["key_panel"] as PanelContainer
	var key_label := view["key"] as Label
	var icon := view["icon"] as TextureRect
	var policy := view["policy"] as Label
	var state := view["state"] as Label
	var is_passive_slot := SkillSlotIds.is_passive(slot_id)
	var name_label := view.get("name") as Label
	var level_label := view.get("level") as Label
	var cost_label := view.get("cost") as Label
	var meta := view.get("meta") as Label
	var slot_label := view.get("slot") as Label
	var cooldown_mask := view.get("cooldown_mask") as ColorRect
	var cooldown_label := view.get("cooldown_label") as Label
	var passive_mark := view.get("passive_mark") as Label
	state.visible = true
	if slot_label != null:
		slot_label.text = String(slot_id).to_upper()
	if cooldown_mask != null:
		cooldown_mask.visible = false
	if cooldown_label != null:
		cooldown_label.visible = false
	if passive_mark != null:
		passive_mark.visible = is_passive_slot
	if skill == null:
		icon.texture = null
		if name_label != null:
			name_label.text = "空槽"
		if level_label != null:
			level_label.text = "—"
		if cost_label != null:
			cost_label.text = ""
		policy.text = "—" if compact else "— 未装备 —"
		state.text = "空" if compact else "未配置"
		state.add_theme_color_override(&"font_color", UI.TEXT_DIM)
		if meta != null:
			meta.text = "共享槽位"
		key_panel.visible = false
		return
	var content := _catalog.content_for(skill.skill_id) if _catalog != null else null
	icon.texture = content.icon if content != null else null
	if name_label != null:
		name_label.text = content.display_name if content != null else String(skill.skill_id)
	if level_label != null:
		level_label.text = "Lv.%d" % _skill_level(skill.skill_id)
	if cost_label != null:
		cost_label.text = "SP %d" % skill.energy_cost if skill.is_active_skill() else ""
	(view["panel"] as Control).tooltip_text = "%s · %s" % [
		content.display_name if content != null else String(skill.skill_id),
		_skill_policy_badge(skill),
	]
	policy.text = _policy_glyph(skill) if compact else _skill_policy_badge(skill)
	policy.add_theme_color_override(&"font_color", _policy_color(skill))
	var castable_here := skill.is_active_skill() and not is_passive_slot
	var transient: Dictionary = _slot_transients.get(slot_id, {})
	key_panel.visible = castable_here
	key_label.text = _key_for_slot(slot_id)
	if not castable_here:
		if compact and not transient.is_empty():
			state.text = String(transient.get("text", "触发"))
			state.add_theme_color_override(&"font_color", _tone_color(StringName(transient.get("tone", &"passive"))))
		else:
			state.text = "生效" if skill.is_passive_skill() else ("锁" if compact else "不可释放")
			state.add_theme_color_override(&"font_color", UI.WARNING)
		if meta != null:
			meta.text = "持续生效 · 无键帽/能量/冷却"
		return
	if compact and not transient.is_empty():
		state.text = String(transient.get("text", "状态"))
		state.add_theme_color_override(&"font_color", _tone_color(StringName(transient.get("tone", &"info"))))
	else:
		state.text = _compact_availability_text(skill) if compact else _availability_text(skill)
		state.add_theme_color_override(&"font_color", _availability_color(state.text))
	state.visible = not state.text.is_empty()
	var remaining := _player_executor.get_cooldown_remaining(skill.skill_id)
	if compact and remaining > 0.0 and cooldown_mask != null and cooldown_label != null:
		var ratio := clampf(remaining / maxf(skill.cooldown, remaining), 0.0, 1.0)
		cooldown_mask.visible = true
		cooldown_mask.position.y = 8.0 + 32.0 * (1.0 - ratio)
		cooldown_mask.size = Vector2(32.0, 32.0 * ratio)
		cooldown_label.visible = true
		cooldown_label.text = _format_cooldown(remaining)
	if meta != null:
		var cooldown_text := " · CD %.1fs" % skill.cooldown if skill.cooldown > 0.0 else " · 无冷却"
		meta.text = "能量 ≥%d%s" % [skill.energy_cost, cooldown_text]


func _skill_level(skill_id: StringName) -> int:
	if _host == null or _host.run_session == null:
		return 1
	var progress := _host.run_session.snapshot().skills.progress_for(skill_id)
	return progress.level if progress != null and progress.is_active() else 1


func _refresh_cooldown_text_only() -> void:
	for slot_id: StringName in SkillSlotIds.active():
		var skill := _player_skills.get_skill_for_slot(slot_id) if _player_skills != null else null
		if skill != null and skill.is_active_skill() and _player_executor.is_skill_on_cooldown(skill.skill_id):
			_refresh_slot(slot_id)


func _availability_text(skill: SkillDefinition) -> String:
	if _player_executor.current_phase != SkillExecutor.Phase.IDLE:
		var active_snapshot := _player_executor.current_cast_snapshot
		if active_snapshot != null and active_snapshot.skill_id == skill.skill_id:
			return "施放中"
		return "忙碌"
	if _player_energy.current_energy < skill.energy_cost:
		return "能量不足"
	if _player_executor.is_skill_on_cooldown(skill.skill_id):
		return "冷却 %.1fs" % _player_executor.get_cooldown_remaining(skill.skill_id)
	return ""


func _compact_availability_text(skill: SkillDefinition) -> String:
	if _player_executor.current_phase != SkillExecutor.Phase.IDLE:
		var active_snapshot := _player_executor.current_cast_snapshot
		if active_snapshot != null and active_snapshot.skill_id == skill.skill_id:
			return "释放"
		return "忙"
	if _player_energy.current_energy < skill.energy_cost:
		return "能量"
	if _player_executor.is_skill_on_cooldown(skill.skill_id):
		return "冷却"
	return ""


func _availability_color(text_value: String) -> Color:
	if text_value.begins_with("冷却") or text_value.ends_with("s"):
		return UI.COOLDOWN
	if text_value == "忙碌" or text_value == "施放中" or text_value == "忙" or text_value == "释放":
		return UI.BUSY
	return UI.ERROR


func _format_cooldown(remaining: float) -> String:
	if remaining >= 10.0:
		return "%d" % ceili(remaining)
	return "%.1f" % remaining


func _set_slot_transient(slot_id: StringName, text_value: String, tone: StringName) -> void:
	if not SLOT_ORDER.has(slot_id):
		return
	_slot_transients[slot_id] = {
		"text": text_value,
		"tone": tone,
		"until": Time.get_ticks_msec() + SLOT_TRANSIENT_MSEC,
	}


func _expire_slot_transients() -> void:
	if _slot_transients.is_empty():
		return
	var now := Time.get_ticks_msec()
	var expired: Array[StringName] = []
	for slot_id: StringName in _slot_transients:
		var state: Dictionary = _slot_transients[slot_id]
		if now >= int(state.get("until", 0)):
			expired.append(slot_id)
	for slot_id: StringName in expired:
		_slot_transients.erase(slot_id)
		_refresh_slot(slot_id)


func _pulse_matching_passive(skill_id: StringName) -> void:
	if skill_id.is_empty() or _player_skills == null:
		return
	for slot_id: StringName in SLOT_ORDER:
		var skill := _player_skills.get_skill_for_slot(slot_id)
		if skill != null and skill.is_passive_skill() and skill.skill_id == skill_id:
			_set_slot_transient(slot_id, "触发", &"passive")
			_refresh_slot(slot_id)


func _show_feedback(message: String, tone: StringName, duration: float = 1.25) -> void:
	var now := Time.get_ticks_msec()
	if (
		tone == &"energy"
		and now - _last_warning_msec < WARNING_RATE_LIMIT_MSEC
		and _feedback_label.text == message
	):
		return
	if tone == &"energy":
		_last_warning_msec = now
	_feedback_label.text = message
	_feedback_label.add_theme_color_override(&"font_color", _tone_color(tone))
	_feedback_panel.visible = true
	warning_text.text = message
	# Retain the compatibility label as a read-only text mirror for accepted
	# runners, but never render it alongside the formal centered feedback.
	warning_text.visible = false
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_feedback_panel.modulate = Color.WHITE
	if reduced_motion:
		_banner_tween = create_tween()
		_banner_tween.tween_interval(duration)
		_banner_tween.tween_callback(_hide_feedback)
		return
	# Keep formal HUD geometry immutable while feedback is live.  Repeated skill
	# events can interrupt this tween; animating Control.position would leave an
	# interrupted panel at an intermediate transform and makes frame readback
	# dependent on layout timing.  Opacity conveys the same transient state
	# without moving any Control in the combat CanvasLayer.
	_feedback_panel.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_feedback_panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_feedback_panel, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(_hide_feedback)


func _hide_feedback() -> void:
	_feedback_panel.visible = false
	warning_text.visible = false


func _pulse_energy() -> void:
	if reduced_motion or energy_row == null:
		return
	if _energy_tween != null and _energy_tween.is_valid():
		_energy_tween.kill()
	energy_row.modulate = Color(1.22, 1.22, 1.22, 1.0)
	_energy_tween = create_tween()
	_energy_tween.tween_property(energy_row, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _refresh_debug() -> void:
	if _player_executor == null or _target_damage == null or _target_carrier == null:
		return
	var cast_snapshot := _player_executor.current_cast_snapshot
	var skill_id := String(cast_snapshot.skill_id) if cast_snapshot != null else "none"
	var cast_id := cast_snapshot.cast_id if cast_snapshot != null else 0
	debug_skill.text = "技能：%s\nphase=%s  cast_id=%d" % [skill_id, String(_player_executor.get_phase_name()), cast_id]
	debug_target.text = "目标：HP %d / %d\n水滴 %d / 10    火焰 %d / 10" % [_target_damage.current_health, _target_damage.maximum_health, _target_carrier.get_amount(ElementIds.WATER), _target_carrier.get_amount(ElementIds.FIRE)]
	debug_result.text = _last_event_text
	motion_state.text = "动态：%s · 色觉辅助：%s" % ["减少" if reduced_motion else "完整", "开" if colorblind_mode else "关"]


func _skill_policy_badge(skill: SkillDefinition) -> String:
	match skill.element_policy:
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
			return "● 固定 · %s" % _element_label(skill.required_element_id)
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
			return "◆ 当前 · %s" % _element_label(_player_element.current_element_id)
		SkillDefinition.ElementPolicy.NEUTRAL:
			return "○ 中性 · NONE"
		_:
			return "? 未知"


func _policy_glyph(skill: SkillDefinition) -> String:
	match skill.element_policy:
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
			return "●%s" % _element_short_label(skill.required_element_id)
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
			return "◆%s" % _element_short_label(_player_element.current_element_id)
		SkillDefinition.ElementPolicy.NEUTRAL:
			return "○无"
		_:
			return "? "


func _policy_color(skill: SkillDefinition) -> Color:
	if skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
		return _element_color(skill.required_element_id)
	if skill.element_policy == SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
		return _element_color(_player_element.current_element_id)
	return UI.NEUTRAL


func _element_label(element_id: StringName) -> String:
	if element_id == ElementIds.WATER:
		return "水滴 水 · WATER"
	if element_id == ElementIds.FIRE:
		return "火焰 火 · FIRE"
	if element_id == ElementIds.NONE:
		return "空心 无属性 · NONE"
	return "菱形 %s" % String(element_id).to_upper()


func _element_short_label(element_id: StringName) -> String:
	if element_id == ElementIds.WATER:
		return "水"
	if element_id == ElementIds.FIRE:
		return "火"
	if element_id == ElementIds.NONE:
		return "无"
	return String(element_id).left(2).to_upper()


func _element_shape(element_id: StringName) -> String:
	if element_id == ElementIds.WATER:
		return "◆"
	if element_id == ElementIds.FIRE:
		return "▲"
	return "○"


func _element_color(element_id: StringName) -> Color:
	if element_id == ElementIds.WATER:
		return UI.WATER_COLORBLIND if colorblind_mode else UI.WATER
	if element_id == ElementIds.FIRE:
		return UI.FIRE_COLORBLIND if colorblind_mode else UI.FIRE
	return UI.NEUTRAL


func _tone_color(tone: StringName) -> Color:
	match tone:
		&"manual": return UI.WATER_COLORBLIND
		&"auto": return UI.WARNING
		&"lock": return UI.SUCCESS
		&"neutral": return UI.NEUTRAL
		&"energy", &"error": return UI.ERROR
		&"cooldown": return UI.COOLDOWN
		&"busy": return UI.BUSY
		&"passive": return UI.WARNING
		&"success": return UI.SUCCESS
		&"mitigated": return UI.WARNING
		&"reaction": return UI.SUCCESS
		_: return UI.TEXT


func _key_for_slot(slot_id: StringName) -> String:
	match slot_id:
		SkillSlotIds.ACTIVE_1: return "1"
		SkillSlotIds.ACTIVE_2: return "2"
		SkillSlotIds.ACTIVE_3: return "3"
		_: return ""


func _connect_once(source: Signal, callback: Callable) -> void:
	if not source.is_connected(callback):
		source.connect(callback)


func _bind_ui_refs() -> void:
	status_panel = $Root/StatusPanel
	skill_panel = $Root/SkillPanel
	passive_panel = $Root/PassivePanel
	health_bar = $Root/StatusPanel/Margin/Status/HealthRow/HealthBar
	health_value = $Root/StatusPanel/Margin/Status/HealthRow/HealthValue
	low_health = $Root/StatusPanel/Margin/Status/LowHealth
	energy_row = $Root/StatusPanel/Margin/Status/EnergyRow
	energy_bar = $Root/StatusPanel/Margin/Status/EnergyRow/EnergyBar
	energy_value = $Root/StatusPanel/Margin/Status/EnergyRow/EnergyValue
	_element_pivot = $Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement
	_element_pivot_swatch = $Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementSwatch
	_element_pivot_text = $Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementText
	_element_pivot_shape = $Root/SkillPanel/Margin/Skills/SlotRow/CurrentElement/Body/ElementShape
	element_swatch = _element_pivot_swatch
	element_text = _element_pivot_text
	_legacy_element_swatch = $Root/StatusPanel/Margin/Status/TitleRow/ElementBadge/BadgeMargin/BadgeRow/ElementSwatch
	_legacy_element_text = $Root/StatusPanel/Margin/Status/TitleRow/ElementBadge/BadgeMargin/BadgeRow/ElementText
	phase_text = $Root/SkillPanel/Margin/Skills/PhaseText
	warning_text = $Root/WarningText
	debug_panel = $Root/DebugPanel
	debug_skill = $Root/DebugPanel/Margin/Debug/Skill
	debug_target = $Root/DebugPanel/Margin/Debug/Target
	debug_result = $Root/DebugPanel/Margin/Debug/Result
	motion_state = $Root/DebugPanel/Margin/Debug/Motion
	help_panel = $Root/HelpPanel
	_feedback_panel = $Root/FeedbackPanel
	_feedback_label = $Root/FeedbackPanel/Margin/Text
	_target_panel = $Root/TargetPanel
	_target_water = $Root/TargetPanel/Margin/Box/Water
	_target_fire = $Root/TargetPanel/Margin/Box/Fire
	run_overlay = $Root/RunOverlay


func _build_ui() -> void:
	var root_control := Control.new()
	root_control.name = "Root"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	_build_status_panel(root_control)
	_build_room_title(root_control)
	_build_skill_panel(root_control)
	_build_passive_panel(root_control)
	_build_compatibility_slots(root_control)
	_build_boss_panel(root_control)
	_build_target_panel(root_control)
	_build_feedback_panel(root_control)
	_build_help_panel(root_control)
	_build_debug_panel(root_control)
	var hidden_warning := Label.new()
	hidden_warning.name = "WarningText"
	hidden_warning.visible = false
	root_control.add_child(hidden_warning)
	var overlay := RUN_OVERLAY_SCRIPT.new()
	overlay.name = "RunOverlay"
	root_control.add_child(overlay)


func _build_status_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusPanel"
	# Task 72 §2 B1: top-left safe-margin anchor. The room title now lives in
	# its own HUD band directly below this capsule (see _build_room_title).
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	panel.size = STATUS_SIZE
	panel.add_theme_stylebox_override(&"panel", UI.panel())
	parent.add_child(panel)
	var margin := _margin("Margin", 8, 8)
	panel.add_child(margin)
	var status := Control.new()
	status.name = "Status"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(status)
	# Hidden task-12 path adapter. CurrentElement is rendered only in the
	# bottom strip, but existing readers can still resolve the old node path.
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.visible = false
	status.add_child(title_row)
	var legacy_title := _make_label("Title", "法雅雅", 18, UI.TEXT)
	legacy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(legacy_title)
	var badge := PanelContainer.new()
	badge.name = "ElementBadge"
	badge.add_theme_stylebox_override(&"panel", UI.flat_panel())
	title_row.add_child(badge)
	var badge_margin := _margin("BadgeMargin", UI.GAP_SM, UI.GAP_XS)
	badge.add_child(badge_margin)
	var badge_row := HBoxContainer.new()
	badge_row.name = "BadgeRow"
	badge_row.add_theme_constant_override(&"separation", UI.GAP_XS)
	badge_margin.add_child(badge_row)
	var swatch := ColorRect.new()
	swatch.name = "ElementSwatch"
	swatch.custom_minimum_size = Vector2(12, 18)
	badge_row.add_child(swatch)
	var element_label := _make_label("ElementText", "水滴 水 · WATER", 12, UI.TEXT)
	element_label.custom_minimum_size.x = 110
	badge_row.add_child(element_label)
	var health := _bar_row("HealthRow", "HP", "HealthBar", "HealthValue", Color("dc4658"))
	health.position = Vector2(0, 0)
	health.size = Vector2(248, 26)
	status.add_child(health)
	var energy := _bar_row("EnergyRow", "SP", "EnergyBar", "EnergyValue", Color("289dcf"))
	energy.position = Vector2(0, 30)
	energy.size = Vector2(248, 26)
	status.add_child(energy)
	var low := _make_label("LowHealth", "! HP", 11, UI.ERROR)
	low.visible = false
	low.position = Vector2(0, 1)
	low.size = Vector2(30, 22)
	low.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	low.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_child(low)


## Task 72 §2 B3: the room title used to be a world-space Label owned by each
## room scene, rendered through the static Camera2D (zoom 0.75) and therefore
## blurry and inconsistently styled across rooms. It now lives directly in the
## HUD's safe-margin grid, immediately below StatusPanel, so it renders at
## integer pixel size and shares one style across every room.
func _build_room_title(parent: Control) -> void:
	var label := _make_label("RoomTitle", "", 16, UI.TEXT)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2(16, 100)
	label.size = ROOM_TITLE_SIZE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	_room_title_label = label


func _bar_row(row_name: String, caption: String, bar_name: String, value_name: String, fill: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override(&"separation", UI.GAP_SM)
	var label := _make_label("Label", caption, 13, UI.TEXT_MUTED)
	label.custom_minimum_size.x = 24
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.custom_minimum_size = Vector2(132, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.add_theme_stylebox_override(&"background", UI.flat_panel(Color("070b13"), UI.BORDER, 3, 1))
	bar.add_theme_stylebox_override(&"fill", UI.flat_panel(fill, fill, 3, 0))
	row.add_child(bar)
	var value := _make_label(value_name, "100 / 100", 12, UI.TEXT)
	value.custom_minimum_size.x = 68
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _build_skill_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "SkillPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-266, -88)
	panel.size = SKILL_STRIP_SIZE
	panel.add_theme_stylebox_override(&"panel", UI.panel(Color(0.035, 0.055, 0.09, 0.97)))
	parent.add_child(panel)
	# Task 72 §2 B4 deliberately leaves this margin off-token: vertical=6 is an
	# exact fit -- SKILL_STRIP_SIZE.y (72) minus 2*6 leaves exactly 60px, which
	# matches CurrentElement's real rendered height (its 56px body plus its own
	# 2px stylebox border on each side). Rounding this up to GAP_SM (8) would
	# shrink the interior below 60 and force PanelContainer to clamp SkillPanel
	# taller than 72 -- reopening the "SkillPanel size 532x72 不变" and "active
	# slot position unchanged" guarantees this task must not touch.
	var margin := _margin("Margin", 10, 6)
	panel.add_child(margin)
	var skills := VBoxContainer.new()
	skills.name = "Skills"
	skills.add_theme_constant_override(&"separation", 0)
	margin.add_child(skills)
	var row := HBoxContainer.new()
	row.name = "SlotRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", UI.GAP_SM)
	skills.add_child(row)
	row.add_child(_build_element_pivot())
	for slot_id: StringName in SkillSlotIds.active():
		row.add_child(_build_compact_slot(slot_id))
	var phase := _make_label("PhaseText", "动作阶段：IDLE", 11, UI.TEXT_DIM)
	phase.visible = false
	skills.add_child(phase)


## Task 72 §2 B1/§0.1.1: moved from the top-right corner (where it overlapped
## BossPanel by 196px) down to just above SkillPanel, forming one "loadout"
## band. Both strips share the same CENTER_BOTTOM anchor and are centered on
## the same x (position.x == -size.x / 2 for each), so §5.2's "shared center
## x" assertion holds structurally rather than by coincidence.
func _build_passive_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "PassivePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-224, -152)
	panel.size = PASSIVE_STRIP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		&"panel",
		UI.panel(Color(0.035, 0.045, 0.075, 0.92), UI.BORDER_PASSIVE, 8, 1)
	)
	parent.add_child(panel)
	var margin := _margin("Margin", UI.GAP_SM, UI.GAP_XS)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.name = "SlotRow"
	row.add_theme_constant_override(&"separation", UI.GAP_SM)
	margin.add_child(row)
	for slot_id: StringName in SkillSlotIds.passive():
		row.add_child(_build_compact_slot(slot_id))


func _build_element_pivot() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CurrentElement"
	panel.custom_minimum_size = ELEMENT_PIVOT_SIZE
	panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_SOFT, UI.BORDER_FOCUS, 7, 2))
	var body := Control.new()
	body.name = "Body"
	body.custom_minimum_size = Vector2(68, 52)
	panel.add_child(body)
	var swatch := ColorRect.new()
	swatch.name = "ElementSwatch"
	swatch.position = Vector2(0, 4)
	swatch.size = Vector2(4, 44)
	swatch.color = UI.WATER
	body.add_child(swatch)
	var shape := _make_label("ElementShape", "◆", 20, UI.WATER)
	shape.position = Vector2(7, 2)
	shape.size = Vector2(24, 28)
	shape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(shape)
	var text := _make_label("ElementText", "水", 18, UI.TEXT)
	text.position = Vector2(31, 3)
	text.size = Vector2(30, 26)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(text)
	var key := _make_label("Key", "E · 元素", 11, UI.TEXT_MUTED)
	key.position = Vector2(7, 30)
	key.size = Vector2(55, 20)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(key)
	return panel


func _build_compact_slot(slot_id: StringName) -> PanelContainer:
	var passive := SkillSlotIds.is_passive(slot_id)
	var panel := PanelContainer.new()
	panel.name = String(slot_id)
	panel.custom_minimum_size = PASSIVE_SLOT_SIZE if passive else ACTIVE_SLOT_SIZE
	panel.add_theme_stylebox_override(
		&"panel",
		UI.flat_panel(
			UI.SURFACE_RAISED,
			UI.BORDER_PASSIVE if passive else UI.BORDER,
			10 if passive else 6,
			2 if passive else 1
		)
	)
	var margin := _margin("Margin", 4, 3)
	panel.add_child(margin)
	var body := Control.new()
	body.name = "Body"
	body.custom_minimum_size = Vector2(88 if passive else 122, 36 if passive else 48)
	margin.add_child(body)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(2, 5 if passive else 8)
	icon.size = Vector2(26 if passive else 32, 26 if passive else 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(icon)
	var cooldown_mask := ColorRect.new()
	cooldown_mask.name = "CooldownMask"
	cooldown_mask.position = Vector2(2, 8)
	cooldown_mask.size = Vector2(32, 32)
	cooldown_mask.color = UI.COOLDOWN_SHADE
	cooldown_mask.visible = false
	cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(cooldown_mask)
	var cooldown_label := _make_label("CooldownLabel", "0.0", 13, UI.TEXT)
	cooldown_label.position = Vector2(2, 13)
	cooldown_label.size = Vector2(32, 22)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.visible = false
	body.add_child(cooldown_label)
	var key_panel := PanelContainer.new()
	key_panel.name = "Key"
	key_panel.position = Vector2(0, 0)
	key_panel.size = Vector2(20, 18)
	key_panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_SOFT, UI.BORDER_FOCUS, 4, 1))
	body.add_child(key_panel)
	var key := _make_label("Text", _key_for_slot(slot_id), 11, UI.TEXT)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_panel.add_child(key)
	var passive_mark := _make_label("PassiveMark", "P", 12, UI.WARNING)
	passive_mark.position = Vector2(0, 0)
	passive_mark.size = Vector2(20, 18)
	passive_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_mark.visible = passive
	body.add_child(passive_mark)
	var text_x := 32.0 if passive else 37.0
	var text_width := 56.0 if passive else 81.0
	var name_label := _make_label("Name", "空槽", 11 if passive else 12, UI.TEXT)
	name_label.position = Vector2(text_x, 0)
	name_label.size = Vector2(text_width, 17)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(name_label)
	var level := _make_label("Level", "—", 10, UI.TEXT_MUTED)
	level.position = Vector2(text_x, 17)
	level.size = Vector2(38, 14)
	level.visible = not passive
	body.add_child(level)
	var cost := _make_label("Cost", "", 10, UI.WATER)
	cost.position = Vector2(text_x + 40, 17)
	cost.size = Vector2(44, 14)
	cost.visible = not passive
	body.add_child(cost)
	var state := _make_label("State", "空", 12, UI.TEXT_DIM)
	state.position = Vector2(text_x, 17 if passive else 31)
	state.size = Vector2(text_width if passive else 42, 17)
	body.add_child(state)
	var policy := _make_label("Policy", "—", 11, UI.TEXT_DIM)
	policy.position = Vector2(text_x + 43, 31)
	policy.size = Vector2(40, 17)
	policy.visible = not passive
	body.add_child(policy)
	_slot_views[slot_id] = {
		"panel": panel,
		"key_panel": key_panel,
		"key": key,
		"icon": icon,
		"name": name_label,
		"level": level,
		"cost": cost,
		"policy": policy,
		"state": state,
		"cooldown_mask": cooldown_mask,
		"cooldown_label": cooldown_label,
		"passive_mark": passive_mark,
	}
	return panel


func _build_compatibility_slots(parent: Control) -> void:
	var adapter := Control.new()
	adapter.name = "Task12CompatibilitySlots"
	adapter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	adapter.position = Vector2(-368, -132)
	adapter.size = Vector2(736, 112)
	adapter.visible = false
	adapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(adapter)
	for index: int in SLOT_ORDER.size():
		var slot_id: StringName = SLOT_ORDER[index]
		var card := _build_hud_slot(slot_id)
		card.position = Vector2(index * 184.0, 10)
		card.size = Vector2(160, 92)
		adapter.add_child(card)
		_compat_slot_views[slot_id] = {
			"panel": card,
			"slot": card.get_node("Margin/Box/Top/Slot"),
			"key_panel": card.get_node("Margin/Box/Top/Key"),
			"key": card.get_node("Margin/Box/Top/Key/Text"),
			"icon": card.get_node("Margin/Box/Content/Icon"),
			"name": card.get_node("Margin/Box/Content/Text/Name"),
			"policy": card.get_node("Margin/Box/Content/Text/Policy"),
			"state": card.get_node("Margin/Box/State"),
			"meta": card.get_node("Margin/Box/Meta"),
		}


func _build_hud_slot(slot_id: StringName) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = String(slot_id)
	panel.custom_minimum_size = Vector2(160, 92)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_RAISED, UI.BORDER, 6, 1))
	var margin := _margin("Margin", UI.GAP_SM, UI.GAP_XS)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", UI.GAP_XS)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.name = "Top"
	box.add_child(top)
	var slot := _make_label("Slot", String(slot_id).to_upper(), 10, UI.TEXT_MUTED)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(slot)
	var key_panel := PanelContainer.new()
	key_panel.name = "Key"
	key_panel.custom_minimum_size = Vector2(26, 22)
	key_panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_SOFT, UI.BORDER_FOCUS, 4, 1))
	top.add_child(key_panel)
	var key := _make_label("Text", "1", 12, UI.TEXT)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_panel.add_child(key)
	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override(&"separation", UI.GAP_XS)
	box.add_child(content)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text_box)
	var name_label := _make_label("Name", "空槽", 14, UI.TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(name_label)
	var policy := _make_label("Policy", "— 未装备 —", 10, UI.TEXT_DIM)
	text_box.add_child(policy)
	var state := _make_label("State", "未配置", 12, UI.TEXT_DIM)
	box.add_child(state)
	var meta := _make_label("Meta", "共享槽位", 10, UI.TEXT_DIM)
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(meta)
	return panel


## Task 61 §3.9: centered top-of-screen strip, anchored/scaled with the
## logical 1152x648 canvas like every other panel here -- never raw physical
## window coordinates. Hidden until a BossTideEmber target binds.
func _build_boss_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "BossPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-260, 16)
	panel.size = Vector2(520, 90)
	panel.add_theme_stylebox_override(&"panel", UI.panel(Color(0.035, 0.045, 0.075, 0.94), UI.BORDER_FOCUS, 8, 2))
	parent.add_child(panel)
	var margin := _margin("Margin", UI.GAP_MD, UI.GAP_SM)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 4)
	margin.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	box.add_child(title_row)
	var name_label := _make_label("Name", "熔汐之王", 16, UI.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var form_label := _make_label("Form", "形态：熔炽", 14, UI.FIRE)
	title_row.add_child(form_label)
	var health_row := HBoxContainer.new()
	health_row.name = "HealthRow"
	health_row.add_theme_constant_override(&"separation", 8)
	box.add_child(health_row)
	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(380, 18)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override(&"background", UI.flat_panel(Color("070b13"), UI.BORDER, 3, 1))
	health_bar.add_theme_stylebox_override(&"fill", UI.flat_panel(Color("dc4658"), Color("dc4658"), 3, 0))
	health_row.add_child(health_bar)
	var health_value := _make_label("HealthValue", "280 / 280", 12, UI.TEXT)
	health_value.custom_minimum_size.x = 90
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_row.add_child(health_value)
	var counter_row := HBoxContainer.new()
	counter_row.name = "CounterRow"
	counter_row.add_theme_constant_override(&"separation", 8)
	box.add_child(counter_row)
	var counter_bar := ProgressBar.new()
	counter_bar.name = "CounterBar"
	counter_bar.custom_minimum_size = Vector2(380, 10)
	counter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter_bar.show_percentage = false
	counter_bar.add_theme_stylebox_override(&"background", UI.flat_panel(Color("070b13"), UI.BORDER, 3, 1))
	counter_bar.add_theme_stylebox_override(&"fill", UI.flat_panel(UI.WATER, UI.WATER, 3, 0))
	counter_row.add_child(counter_bar)
	var counter_label := _make_label("CounterLabel", "克制进度 0 / 15", 12, UI.TEXT_MUTED)
	counter_label.custom_minimum_size.x = 90
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_row.add_child(counter_label)
	boss_panel = panel
	_boss_health_bar = health_bar
	_boss_health_value = health_value
	_boss_form_label = form_label
	_boss_counter_bar = counter_bar
	_boss_counter_label = counter_label


func _build_target_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TargetPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-260, 76)
	panel.size = Vector2(240, 92)
	panel.add_theme_stylebox_override(&"panel", UI.panel())
	parent.add_child(panel)
	var margin := _margin("Margin", UI.GAP_MD, UI.GAP_SM)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 4)
	margin.add_child(box)
	box.add_child(_make_label("Title", "目标元素附着", 13, UI.TEXT_MUTED))
	box.add_child(_make_label("Water", "水滴 WATER  ×0", 15, UI.TEXT_DIM))
	box.add_child(_make_label("Fire", "火焰 FIRE   ×0", 15, UI.TEXT_DIM))


func _build_feedback_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "FeedbackPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Keep transient accessibility/command feedback below the top belts.  The
	# centered strip otherwise covers P1 at 16:9 because the passive belt owns
	# the upper-right safe zone.
	panel.position = Vector2(-180, 124)
	panel.size = Vector2(360, 36)
	panel.add_theme_stylebox_override(&"panel", UI.panel(UI.SURFACE_RAISED, UI.BORDER_FOCUS, 7, 1))
	parent.add_child(panel)
	var margin := _margin("Margin", UI.GAP_SM, UI.GAP_XS)
	panel.add_child(margin)
	var text := _make_label("Text", "反馈", 14, UI.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(text)


func _build_help_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "HelpPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-230, 62)
	panel.size = Vector2(460, 36)
	panel.add_theme_stylebox_override(&"panel", UI.flat_panel(Color(0.035, 0.055, 0.09, 0.92), UI.BORDER, 5, 1))
	parent.add_child(panel)
	var text := _make_label("Text", "A/D 移动 · 空格跳跃 · 1/2/3 技能 · E 切换 · L 配装 · F4 减少动态 · F5 色觉辅助", 11, UI.TEXT_MUTED)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(text)


func _build_debug_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "DebugPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-410, 180)
	panel.size = Vector2(390, 270)
	panel.add_theme_stylebox_override(&"panel", UI.panel(Color(0.02, 0.03, 0.05, 0.98), UI.WATER, 7, 2))
	parent.add_child(panel)
	var margin := _margin("Margin", UI.GAP_MD, UI.GAP_MD)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Debug"
	box.add_theme_constant_override(&"separation", 8)
	margin.add_child(box)
	box.add_child(_make_label("Title", "战斗调试 · F3 隐藏", 17, UI.WATER))
	box.add_child(_make_label("Skill", "技能：none", 12, UI.TEXT))
	box.add_child(_make_label("Target", "目标", 12, UI.WARNING))
	box.add_child(_make_label("ResultLabel", "最近提交结果", 11, UI.TEXT_MUTED))
	var result := _make_label("Result", "等待战斗结果", 12, UI.TEXT)
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result)
	box.add_child(_make_label("Motion", "动态：完整 · 色觉辅助：关", 11, UI.TEXT_MUTED))


func _margin(node_name: String, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = node_name
	margin.add_theme_constant_override(&"margin_left", horizontal)
	margin.add_theme_constant_override(&"margin_right", horizontal)
	margin.add_theme_constant_override(&"margin_top", vertical)
	margin.add_theme_constant_override(&"margin_bottom", vertical)
	return margin


func _make_label(node_name: String, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
