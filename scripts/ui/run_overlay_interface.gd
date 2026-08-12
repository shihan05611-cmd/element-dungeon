class_name RunOverlayInterface
extends Control

const UI := preload("res://scripts/ui/combat_ui_tokens.gd")

signal status_requested(message: String, tone: StringName)

const SLOT_ORDER: Array[StringName] = [
	SkillSlotIds.ACTIVE_1,
	SkillSlotIds.ACTIVE_2,
	SkillSlotIds.ACTIVE_3,
	SkillSlotIds.PASSIVE_1,
	SkillSlotIds.PASSIVE_2,
	SkillSlotIds.PASSIVE_3,
	SkillSlotIds.PASSIVE_4,
]
const FORMAL_LOADOUT_DRAG_KIND := &"formal_shop_loadout"

var colorblind_mode: bool = false
var _current_element_id: StringName = ElementIds.WATER

var _host: RunSessionHost
var _formal_coordinator: Node
var _formal_mode: bool = false
var _catalog: RunContentCatalog
var _snapshot: RunSnapshot
var _working_loadout: RuntimeLoadoutSnapshot
var _shop_draft: ShopDraft
var _selected_skill_id: StringName = &""
var _reward_offer: RewardOffer
var _reward_selected_index: int = -1
var _reward_submitting: bool = false
var _reward_submit_count: int = 0
var _reward_cards: Array[Button] = []
var _skill_cards: Dictionary = {}

var _panel: PanelContainer
var _outer_margin: MarginContainer
var _panel_margin: MarginContainer
var _title: Label
var _subtitle: Label
var _close: Button
var _slot_row: HBoxContainer
var _warning: Label
var _inventory: GridContainer
var _passive_list: VBoxContainer
var _relic_list: VBoxContainer
var _status: Label
var _confirm: Button
var _reward_area: VBoxContainer
var _reward_cards_stage: HBoxContainer
var _reward_status: Label
var _reward_confirm: Button
var _loadout_area: VBoxContainer
var _root_box: VBoxContainer
var _formal_scroll: ScrollContainer
var _formal_area: VBoxContainer
var _formal_kind: StringName = &""
var _formal_body: Control
var _formal_status: Label
var _formal_selected_route_id: StringName = &""
var _formal_route_revision: int = -1
var _formal_route_submitting: bool = false
var _formal_route_submit_count: int = 0
var _formal_route_cards: Array[Button] = []
var _formal_route_confirm: Button
var _formal_shop_draft: ShopDraft
var _formal_selected_skill_id: StringName = &""
var _formal_selected_slot_id: StringName = &""
var _formal_reset_skill_id: StringName = &""
var _formal_focus_id: StringName = &""
var _formal_command_busy: bool = false
var _formal_buttons: Dictionary = {}


func _ready() -> void:
	_build()
	_apply_responsive_layout()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _outer_margin != null:
		_apply_responsive_layout()


func configure(host: RunSessionHost, formal_coordinator: Node = null) -> void:
	_host = host
	_formal_coordinator = formal_coordinator
	_formal_mode = formal_coordinator != null
	_catalog = host.content_catalog if host != null else null
	_snapshot = host.run_session.snapshot() if host != null and host.run_session != null else null
	if host != null:
		var callback := Callable(self, "_on_snapshot_changed")
		if not host.session_snapshot_changed.is_connected(callback):
			host.session_snapshot_changed.connect(callback)
		var reward_callback := Callable(self, "show_reward")
		if not host.reward_ready.is_connected(reward_callback):
			host.reward_ready.connect(reward_callback)
	if _snapshot != null:
		_working_loadout = _snapshot.loadout
		if _formal_mode:
			_render_formal_phase(_snapshot, &"configured")


func toggle_loadout() -> void:
	if _formal_mode:
		if _snapshot != null and _snapshot.route.phase == RunPhase.SHOP:
			_render_formal_phase(_snapshot, &"toggle_shop")
		return
	if visible:
		if _reward_offer != null:
			if _reward_status != null:
				_reward_status.text = "奖励尚未确认 · 先选择候选，再使用独立确认按钮"
			return
		hide_overlay()
	else:
		show_loadout()


func show_loadout(snapshot_override: RuntimeLoadoutSnapshot = null) -> void:
	if _formal_mode:
		return
	if _host == null or _catalog == null:
		return
	_reward_offer = null
	_reward_selected_index = -1
	_reward_submitting = false
	_reward_cards.clear()
	_reward_area.visible = false
	_loadout_area.visible = true
	_close.visible = true
	_snapshot = _host.run_session.snapshot()
	_shop_draft = null
	var route_phase := _snapshot.route.phase
	if route_phase == RunPhase.SHOP:
		var opened := _host.run_session.open_shop_draft()
		if opened.accepted:
			_shop_draft = opened.draft
			_working_loadout = _shop_draft.preview_loadout()
	else:
		_working_loadout = (
			snapshot_override
			if snapshot_override != null
			else _host.runtime_loadout.snapshot()
		)
	_title.text = "共享配装 · ACTIVE 1–3 + PASSIVE 1–4"
	_subtitle.text = (
		"商店 · 技能装配即时生效；属性分配在离店时确认"
		if _shop_draft != null
		else "战斗只读预览 · 按 L 关闭 · 四槽在所有元素间共享"
	)
	_confirm.disabled = _shop_draft == null
	_confirm.text = "确认属性并离开" if _shop_draft != null else "仅商店阶段可离开"
	_refresh_loadout()
	_show_overlay()


func show_reward(offer: RewardOffer) -> void:
	if offer == null or not offer.valid:
		return
	_reward_offer = offer
	_reward_selected_index = -1
	_reward_submitting = false
	_reward_cards.clear()
	_reward_area.visible = true
	_loadout_area.visible = false
	_close.visible = false
	_snapshot = _host.run_session.snapshot() if _host != null and _host.run_session != null else _snapshot
	_title.text = "房间奖励"
	_subtitle.text = _reward_context_summary(offer)
	_clear_children(_reward_area)
	var context := _label("比较 %d 项权威候选 · 移动焦点不会领取" % offer.options.size(), 14, UI.TEXT_MUTED)
	context.name = "Context"
	context.custom_minimum_size.y = 24
	context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_area.add_child(context)
	_reward_cards_stage = HBoxContainer.new()
	_reward_cards_stage.name = "CardsStage"
	_reward_cards_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_cards_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reward_cards_stage.add_theme_constant_override(&"separation", UI.GAP_MD)
	_reward_area.add_child(_reward_cards_stage)
	var options := offer.options
	for index: int in options.size():
		var button := _build_reward_card(options[index], index)
		_reward_cards.append(button)
		_reward_cards_stage.add_child(button)
	var footer := HBoxContainer.new()
	footer.name = "RewardFooter"
	footer.custom_minimum_size.y = 52
	footer.add_theme_constant_override(&"separation", UI.GAP_MD)
	_reward_area.add_child(footer)
	_reward_status = _label("请选择候选；领取只发生在显式确认后。", 13, UI.TEXT_MUTED)
	_reward_status.name = "Status"
	_reward_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_reward_status)
	_reward_confirm = Button.new()
	_reward_confirm.name = "ConfirmReward"
	_reward_confirm.text = "确认领取"
	_reward_confirm.custom_minimum_size = Vector2(176, 48)
	_reward_confirm.focus_mode = Control.FOCUS_ALL
	_reward_confirm.disabled = true
	_reward_confirm.add_theme_font_size_override(&"font_size", 15)
	_reward_confirm.add_theme_stylebox_override(&"normal", UI.button_style(UI.SURFACE_RAISED, UI.BORDER))
	_reward_confirm.add_theme_stylebox_override(&"hover", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
	_reward_confirm.add_theme_stylebox_override(&"focus", UI.focus_style())
	_reward_confirm.pressed.connect(_confirm_reward_selection)
	footer.add_child(_reward_confirm)
	_wire_reward_focus()
	_apply_responsive_layout()
	_show_overlay()
	call_deferred(&"_focus_initial_reward")


func hide_overlay() -> void:
	visible = false
	_selected_skill_id = &""
	get_viewport().set_input_as_handled()


func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled
	if visible and _loadout_area.visible:
		_refresh_loadout()
	elif visible and _reward_area.visible:
		_update_reward_card_styles()


func set_current_element(element_id: StringName) -> void:
	if element_id.is_empty():
		return
	_current_element_id = element_id


func reward_selected_index() -> int:
	return _reward_selected_index


func reward_card_count() -> int:
	return _reward_cards.size()


func reward_card(index: int) -> Button:
	return _reward_cards[index] if index >= 0 and index < _reward_cards.size() else null


func reward_cards_container() -> HBoxContainer:
	return _reward_cards_stage


func reward_confirm_button() -> Button:
	return _reward_confirm


func reward_submission_active() -> bool:
	return _reward_submitting


func reward_submit_count() -> int:
	return _reward_submit_count


func set_preview_snapshot(snapshot: RuntimeLoadoutSnapshot) -> void:
	if snapshot == null:
		return
	_working_loadout = snapshot
	_shop_draft = null
	_refresh_loadout()


func try_preview_assignment(skill_id: StringName, slot_id: StringName) -> StringName:
	if _host == null or _working_loadout == null:
		return &"missing_loadout_ui_context"
	var candidate := _candidate_with_assignment(_working_loadout, slot_id, skill_id)
	if _shop_draft != null:
		var before := _working_loadout
		var result := _host.run_session.apply_shop_loadout_immediately(_shop_draft, candidate)
		if not result.accepted:
			_snapshot = _host.run_session.snapshot()
			_working_loadout = _snapshot.loadout
			if not skill_id.is_empty():
				_selected_skill_id = skill_id
			_publish_detail(_detail_text(result.detail), &"error")
			_refresh_loadout()
			_restore_shop_selection_focus()
			return result.detail
		_snapshot = result.run_snapshot
		_working_loadout = _shop_draft.preview_loadout()
		_publish_detail(
			_assignment_committed_text(before, _working_loadout, skill_id, slot_id),
			&"success"
		)
		_refresh_loadout()
		return &""
	# Compatibility-only preview API for the frozen task-12 runner. Formal
	# combat input paths below are guarded read-only and never call this branch.
	var validation := _host.runtime_loadout.validate_snapshot(candidate)
	if not validation.accepted:
		_publish_detail(_detail_text(validation.detail), &"error")
		return validation.detail
	_working_loadout = candidate
	_publish_detail(_assignment_preview_text(skill_id, slot_id), &"success")
	_refresh_loadout()
	return &""


func current_preview() -> RuntimeLoadoutSnapshot:
	return _working_loadout


func zero_active_warning_visible() -> bool:
	return _warning != null and _warning.visible


func slot_card(slot_id: StringName) -> Control:
	return _slot_row.get_node_or_null(String(slot_id)) as Control if _slot_row != null else null


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UI.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	_outer_margin = MarginContainer.new()
	_outer_margin.name = "OuterMargin"
	_outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_outer_margin)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override(
		&"panel",
		UI.panel(UI.SURFACE, UI.BORDER_FOCUS, 10, 2)
	)
	_outer_margin.add_child(_panel)

	_panel_margin = MarginContainer.new()
	_panel_margin.name = "PanelMargin"
	_panel.add_child(_panel_margin)

	_root_box = VBoxContainer.new()
	_root_box.name = "RootBox"
	_root_box.add_theme_constant_override(&"separation", 10)
	_panel_margin.add_child(_root_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 46
	_root_box.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_title = _label("共享配装", 22, UI.TEXT)
	heading.add_child(_title)
	_subtitle = _label("", 13, UI.TEXT_MUTED)
	heading.add_child(_subtitle)
	_close = Button.new()
	_close.name = "Close"
	_close.text = "关闭  L"
	_close.custom_minimum_size = Vector2(112, 44)
	_close.add_theme_stylebox_override(
		&"normal",
		UI.button_style(UI.SURFACE_RAISED, UI.BORDER)
	)
	_close.add_theme_stylebox_override(&"focus", UI.focus_style())
	_close.pressed.connect(hide_overlay)
	header.add_child(_close)

	_loadout_area = VBoxContainer.new()
	_loadout_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loadout_area.add_theme_constant_override(&"separation", 8)
	_root_box.add_child(_loadout_area)

	_slot_row = HBoxContainer.new()
	_slot_row.custom_minimum_size.y = 132
	_slot_row.add_theme_constant_override(&"separation", 8)
	_loadout_area.add_child(_slot_row)

	_warning = _label("", 14, UI.WARNING)
	_warning.custom_minimum_size.y = 34
	_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loadout_area.add_child(_warning)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 12)
	_loadout_area.add_child(body)

	var inventory_panel := PanelContainer.new()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_stretch_ratio = 1.55
	inventory_panel.add_theme_stylebox_override(
		&"panel",
		UI.flat_panel(UI.SURFACE_RAISED, UI.BORDER)
	)
	body.add_child(inventory_panel)
	var inventory_margin := MarginContainer.new()
	inventory_margin.add_theme_constant_override(&"margin_left", 12)
	inventory_margin.add_theme_constant_override(&"margin_top", 10)
	inventory_margin.add_theme_constant_override(&"margin_right", 12)
	inventory_margin.add_theme_constant_override(&"margin_bottom", 10)
	inventory_panel.add_child(inventory_margin)
	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override(&"separation", 6)
	inventory_margin.add_child(inventory_box)
	inventory_box.add_child(_label("已拥有技能 · 行为与元素策略", 15, UI.TEXT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_box.add_child(scroll)
	_inventory = GridContainer.new()
	_inventory.columns = 2
	_inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory.add_theme_constant_override(&"h_separation", 8)
	_inventory.add_theme_constant_override(&"v_separation", 8)
	scroll.add_child(_inventory)

	var summary_panel := PanelContainer.new()
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.add_theme_stylebox_override(
		&"panel",
		UI.flat_panel(UI.SURFACE_RAISED, UI.BORDER)
	)
	body.add_child(summary_panel)
	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override(&"margin_left", 12)
	summary_margin.add_theme_constant_override(&"margin_top", 10)
	summary_margin.add_theme_constant_override(&"margin_right", 12)
	summary_margin.add_theme_constant_override(&"margin_bottom", 10)
	summary_panel.add_child(summary_margin)
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override(&"separation", 6)
	summary_margin.add_child(summary)
	summary.add_child(_label("当前生效被动", 15, UI.TEXT))
	_passive_list = VBoxContainer.new()
	summary.add_child(_passive_list)
	summary.add_child(_separator())
	summary.add_child(_label("遗物响应范围", 15, UI.TEXT))
	_relic_list = VBoxContainer.new()
	_relic_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_child(_relic_list)

	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 52
	footer.add_theme_constant_override(&"separation", 10)
	_loadout_area.add_child(footer)
	_status = _label("选择技能后点击槽位，或拖放到槽位。", 13, UI.TEXT_MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_status)
	var clear_button := Button.new()
	clear_button.text = "清空所选槽"
	clear_button.custom_minimum_size = Vector2(124, 44)
	clear_button.focus_mode = Control.FOCUS_ALL
	clear_button.add_theme_stylebox_override(&"focus", UI.focus_style())
	clear_button.pressed.connect(_clear_selected_slot)
	footer.add_child(clear_button)
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(176, 44)
	_confirm.focus_mode = Control.FOCUS_ALL
	_confirm.add_theme_stylebox_override(&"focus", UI.focus_style())
	_confirm.pressed.connect(_confirm_shop)
	footer.add_child(_confirm)

	_reward_area = VBoxContainer.new()
	_reward_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reward_area.alignment = BoxContainer.ALIGNMENT_BEGIN
	_reward_area.add_theme_constant_override(&"separation", UI.GAP_SM)
	_root_box.add_child(_reward_area)

	_formal_scroll = ScrollContainer.new()
	_formal_scroll.name = "FormalScroll"
	_formal_scroll.visible = false
	_formal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_formal_scroll)
	_formal_area = VBoxContainer.new()
	_formal_area.name = "FormalArea"
	_formal_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_formal_area.add_theme_constant_override(&"separation", UI.GAP_SM)
	_formal_scroll.add_child(_formal_area)


func _build_reward_card(option: RewardOption, index: int) -> Button:
	var card := Button.new()
	card.name = "RewardOption%d" % index
	card.text = ""
	card.custom_minimum_size = _reward_card_size()
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.focus_mode = Control.FOCUS_ALL
	card.clip_contents = true
	card.add_theme_stylebox_override(&"normal", UI.button_style(UI.SURFACE_RAISED, UI.BORDER))
	card.add_theme_stylebox_override(&"hover", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
	card.add_theme_stylebox_override(&"pressed", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
	card.add_theme_stylebox_override(&"focus", UI.focus_style())
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", UI.GAP_XS)
	margin.add_child(box)
	var content := _catalog.content_for(option.content_id) if _catalog != null else null
	var skill := content.gameplay_definition if content != null else null
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = 52
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override(&"separation", UI.GAP_SM)
	box.add_child(header)
	if content != null and content.icon != null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(48, 48)
		icon.texture = content.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(icon)
	else:
		header.add_child(_reward_type_glyph(option.reward_type))
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	var number := _label("%d · %s" % [index + 1, _reward_type_copy(option.reward_type)], 12, UI.TEXT_MUTED)
	number.name = "Ordinal"
	heading.add_child(number)
	var title := _label(option.display_name, 18, UI.TEXT)
	title.name = "Name"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title)
	var policy_copy := _reward_policy_copy(skill, option.reward_type)
	if not policy_copy.is_empty():
		var policy := _label(policy_copy, 12, _policy_color(skill) if skill != null else UI.NEUTRAL)
		policy.name = "Policy"
		policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		policy.max_lines_visible = 2
		box.add_child(policy)
	var description := _label(option.description, 13, UI.TEXT)
	description.name = "Description"
	description.custom_minimum_size.y = 72
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 4
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(description)
	var metric_copy := _reward_metric_copy(skill)
	if not metric_copy.is_empty():
		var metrics := _label(metric_copy, 12, UI.TEXT_MUTED)
		metrics.name = "Metrics"
		metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		metrics.max_lines_visible = 2
		box.add_child(metrics)
	var build := _label(_reward_build_copy(option, skill), 12, UI.TEXT_MUTED)
	build.name = "BuildState"
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.max_lines_visible = 2
	box.add_child(build)
	var selection := _label("○ 候选", 12, UI.TEXT_MUTED)
	selection.name = "Selection"
	selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(selection)
	card.tooltip_text = "%s\n%s" % [option.display_name, option.description]
	card.focus_entered.connect(_focus_reward_option.bind(index))
	card.pressed.connect(_focus_reward_option.bind(index))
	return card


func _reward_type_glyph(reward_type: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TypeGlyph"
	panel.custom_minimum_size = Vector2(48, 48)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_SOFT, UI.BORDER_FOCUS, 8, 2))
	var glyph := _label("S" if reward_type == RewardType.SKILL else "R", 20, UI.BORDER_FOCUS)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(glyph)
	return panel


func _focus_initial_reward() -> void:
	if _reward_cards.is_empty() or not visible:
		return
	_focus_reward_option(0)
	_reward_cards[0].grab_focus()


func _focus_reward_option(index: int) -> void:
	if _reward_submitting or index < 0 or index >= _reward_cards.size():
		return
	_reward_selected_index = index
	if _reward_confirm != null:
		_reward_confirm.disabled = false
	if _reward_status != null and _reward_offer != null:
		var option := _reward_offer.options[index]
		_reward_status.text = "已聚焦 %d：%s · 尚未领取" % [index + 1, option.display_name]
	_update_reward_card_styles()


func _update_reward_card_styles() -> void:
	for index: int in _reward_cards.size():
		var card := _reward_cards[index]
		var selected := index == _reward_selected_index
		card.add_theme_stylebox_override(
			&"normal",
			UI.button_style(UI.SURFACE_SOFT if selected else UI.SURFACE_RAISED, UI.BORDER_FOCUS if selected else UI.BORDER)
		)
		var marker := card.get_node("Margin/Content/Selection") as Label
		marker.text = "◆ 已聚焦" if selected else "○ 候选"
		marker.add_theme_color_override(&"font_color", UI.BORDER_FOCUS if selected else UI.TEXT_MUTED)


func _wire_reward_focus() -> void:
	if _reward_confirm == null:
		return
	for index: int in _reward_cards.size():
		var card := _reward_cards[index]
		if index > 0:
			card.focus_neighbor_left = card.get_path_to(_reward_cards[index - 1])
		if index + 1 < _reward_cards.size():
			card.focus_neighbor_right = card.get_path_to(_reward_cards[index + 1])
		else:
			card.focus_neighbor_right = card.get_path_to(_reward_confirm)
		card.focus_neighbor_bottom = card.get_path_to(_reward_confirm)
		card.focus_next = card.get_path_to(_reward_cards[index + 1] if index + 1 < _reward_cards.size() else _reward_confirm)
	if not _reward_cards.is_empty():
		_reward_confirm.focus_neighbor_top = _reward_confirm.get_path_to(_reward_cards[_reward_selected_index if _reward_selected_index >= 0 else 0])
		_reward_confirm.focus_next = _reward_confirm.get_path_to(_reward_cards[0])


func _confirm_reward_selection() -> void:
	if _reward_selected_index < 0 or _reward_offer == null or _reward_submitting:
		return
	var options := _reward_offer.options
	if _reward_selected_index >= options.size():
		return
	_claim_reward(options[_reward_selected_index].option_id)


func _reward_context_summary(offer: RewardOffer) -> String:
	var equipped := 0
	if _snapshot != null and _snapshot.loadout != null:
		for slot_id: StringName in SLOT_ORDER:
			if not _snapshot.loadout.get_skill_id(slot_id).is_empty():
				equipped += 1
	return "%s · 当前元素 %s · 已装备 %d/7" % [
		_reward_type_copy(offer.reward_type),
		_element_text(_current_element_id),
		equipped,
	]


func _reward_type_copy(reward_type: int) -> String:
	return "技能奖励" if reward_type == RewardType.SKILL else "遗物奖励"


func _reward_policy_copy(skill: SkillDefinition, reward_type: int) -> String:
	if reward_type != RewardType.SKILL or skill == null:
		return "RELIC 遗物" if reward_type == RewardType.RELIC else ""
	return "%s · %s" % [_activation_text(skill), _policy_text(skill)]


func _reward_metric_copy(skill: SkillDefinition) -> String:
	if skill == null:
		return ""
	if skill.is_passive_skill():
		return "无按键 · 无能耗 / 冷却"
	var energy := "无能耗" if skill.energy_cost <= 0 else "能量 %d" % skill.energy_cost
	var cooldown := "无冷却" if is_zero_approx(skill.cooldown) else "冷却 %.1fs" % skill.cooldown
	return "%s · %s" % [energy, cooldown]


func _reward_build_copy(option: RewardOption, skill: SkillDefinition) -> String:
	var owned := false
	var equipped_slot: StringName = &""
	if _snapshot != null:
		if option.reward_type == RewardType.SKILL:
			owned = _snapshot.skills.owns(option.content_id)
			for slot_id: StringName in SLOT_ORDER:
				if _snapshot.loadout.get_skill_id(slot_id) == option.content_id:
					equipped_slot = slot_id
					break
		else:
			owned = _snapshot.relics.owns(option.content_id)
	var state := "已拥有" if owned else "未拥有"
	if not equipped_slot.is_empty():
		state += " · 已装备 %s" % String(equipped_slot).to_upper()
	elif option.reward_type == RewardType.SKILL:
		state += " · 未装备"
	if skill != null:
		state += " · " + (
			"槽位 ACTIVE 1–3 / PASSIVE 1"
			if skill.is_passive_skill()
			else "槽位 ACTIVE 1–3"
		)
	return state


func _reward_card_size() -> Vector2:
	var compact := size.x <= 960.0 or size.y <= 560.0
	return Vector2(268, 300) if compact else Vector2(328, 320)


func _apply_responsive_layout() -> void:
	if _outer_margin == null or _panel_margin == null:
		return
	var compact := size.x <= 960.0 or size.y <= 560.0
	var horizontal := 24 if compact else 56
	var vertical := 32 if compact else 72
	_outer_margin.add_theme_constant_override(&"margin_left", horizontal)
	_outer_margin.add_theme_constant_override(&"margin_top", vertical)
	_outer_margin.add_theme_constant_override(&"margin_right", horizontal)
	_outer_margin.add_theme_constant_override(&"margin_bottom", vertical)
	for side: StringName in [&"margin_left", &"margin_right"]:
		_panel_margin.add_theme_constant_override(side, 12)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		_panel_margin.add_theme_constant_override(side, 8)
	for card: Button in _reward_cards:
		card.custom_minimum_size = _reward_card_size()


func _refresh_loadout() -> void:
	if _working_loadout == null or _catalog == null:
		return
	_clear_children(_slot_row)
	for slot_id: StringName in SLOT_ORDER:
		_slot_row.add_child(_build_slot_card(slot_id, _working_loadout.get_skill_id(slot_id)))
	_clear_children(_inventory)
	_skill_cards.clear()
	var owned := _snapshot.skills.owned_skill_ids if _snapshot != null else []
	for skill_id: StringName in owned:
		var content := _catalog.content_for(skill_id)
		if content == null or not content.equippable:
			continue
		var card := _build_skill_card(content)
		_skill_cards[skill_id] = card
		_inventory.add_child(card)
	_refresh_warning()
	_refresh_passives()
	_refresh_relics()


func _build_slot_card(slot_id: StringName, skill_id: StringName) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = String(slot_id)
	card.custom_minimum_size = Vector2(0, 126)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_passive_slot := SkillSlotIds.is_passive(slot_id)
	card.add_theme_stylebox_override(
		&"panel",
		UI.flat_panel(
			UI.SURFACE_SOFT,
			UI.BORDER_FOCUS if _selected_skill_id.is_empty() else UI.BORDER,
			7,
			2
		)
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_slot_input.bind(slot_id))
	card.set_drag_forwarding(
		Callable(self, "_slot_drag_data").bind(slot_id),
		Callable(self, "_slot_can_drop").bind(slot_id),
		Callable(self, "_slot_drop").bind(slot_id)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	margin.add_child(box)
	box.add_child(_label(
		"%s · 仅被动" % String(slot_id).to_upper() if is_passive_slot else "%s · 仅主动" % String(slot_id).to_upper(),
		12,
		UI.WARNING if is_passive_slot else UI.TEXT_MUTED
	))
	if skill_id.is_empty():
		box.add_child(_label("空槽", 18, UI.TEXT_DIM))
		box.add_child(_label("拖入技能", 12, UI.TEXT_DIM))
		return card
	var content := _catalog.content_for(skill_id)
	var skill := content.gameplay_definition if content != null else null
	if content == null or skill == null:
		box.add_child(_label("未知内容", 16, UI.ERROR))
		return card
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 8)
	box.add_child(name_row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.texture = content.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_row.add_child(icon)
	var skill_name_label := _label(content.display_name, 17, UI.TEXT)
	skill_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(skill_name_label)
	box.add_child(_label(
		"%s · %s" % [_activation_text(skill), _policy_text(skill)],
		12,
		_policy_color(skill)
	))
	if skill.is_passive_skill() and not is_passive_slot:
		box.add_child(_label("被动 · 此按键不可释放", 12, UI.WARNING))
	elif is_passive_slot:
		box.add_child(_label("持续生效 · 无释放键", 12, UI.TEXT_MUTED))
	else:
		box.add_child(_label("按键 %s" % _key_for_slot(slot_id), 12, UI.TEXT_MUTED))
	return card


func _build_skill_card(content: SkillContentDefinition) -> Button:
	var skill := content.gameplay_definition
	var card := Button.new()
	card.custom_minimum_size = Vector2(238, 92)
	card.text = "%s\n%s · %s\n%s" % [
		content.display_name,
		_activation_text(skill),
		_policy_text(skill),
		content.description,
	]
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override(&"font_size", 12)
	card.add_theme_color_override(&"font_color", UI.TEXT)
	card.add_theme_stylebox_override(
		&"normal",
		UI.button_style(
			UI.SURFACE_SOFT,
			UI.BORDER_FOCUS if _selected_skill_id == content.skill_id else UI.BORDER
		)
	)
	card.add_theme_stylebox_override(&"focus", UI.focus_style())
	card.pressed.connect(_select_skill.bind(content.skill_id))
	card.set_drag_forwarding(
		Callable(self, "_skill_drag_data").bind(content.skill_id),
		Callable(self, "_skill_can_drop"),
		Callable(self, "_skill_drop")
	)
	card.tooltip_text = "%s\n%s" % [content.display_name, content.description]
	return card


func _select_skill(skill_id: StringName) -> void:
	if _shop_draft == null:
		_publish_detail("战斗阶段为只读预览；请在商店调整技能。", &"info")
		return
	_selected_skill_id = skill_id
	var content := _catalog.content_for(skill_id)
	_publish_detail(
		"已选择 %s；点击目标槽位。" % (content.display_name if content != null else String(skill_id)),
		&"info"
	)
	_refresh_loadout()


func _on_slot_input(event: InputEvent, slot_id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _shop_draft == null:
			_publish_detail("战斗阶段为只读预览；请在商店调整技能。", &"info")
			return
		if not _selected_skill_id.is_empty():
			var detail := try_preview_assignment(_selected_skill_id, slot_id)
			if detail.is_empty():
				_selected_skill_id = &""
				_refresh_loadout()
		else:
			_selected_skill_id = _working_loadout.get_skill_id(slot_id)
			_status.text = "已选择槽位 %s；“清空所选槽”可移除。" % String(slot_id)


func _skill_drag_data(_position: Vector2, skill_id: StringName) -> Variant:
	if _shop_draft == null:
		_publish_detail("战斗阶段为只读预览；请在商店调整技能。", &"info")
		return null
	var preview := Label.new()
	var content := _catalog.content_for(skill_id)
	preview.text = content.display_name if content != null else String(skill_id)
	preview.add_theme_color_override(&"font_color", UI.TEXT)
	preview.add_theme_stylebox_override(
		&"normal",
		UI.flat_panel(UI.SURFACE_SOFT, UI.BORDER_FOCUS)
	)
	set_drag_preview(preview)
	return {"skill_id": skill_id}


func _skill_can_drop(_position: Vector2, _data: Variant) -> bool:
	return false


func _skill_drop(_position: Vector2, _data: Variant) -> void:
	pass


func _slot_drag_data(_position: Vector2, slot_id: StringName) -> Variant:
	if _shop_draft == null:
		return null
	var skill_id := _working_loadout.get_skill_id(slot_id)
	if skill_id.is_empty():
		return null
	return {"skill_id": skill_id}


func _slot_can_drop(_position: Vector2, data: Variant, _slot_id: StringName) -> bool:
	return _shop_draft != null and data is Dictionary and data.has("skill_id")


func _slot_drop(_position: Vector2, data: Variant, slot_id: StringName) -> void:
	if _shop_draft == null:
		_publish_detail("战斗阶段为只读预览；请在商店调整技能。", &"info")
		return
	var skill_id := StringName(data.get("skill_id", &""))
	var detail := try_preview_assignment(skill_id, slot_id)
	if detail.is_empty():
		_selected_skill_id = &""
		_refresh_loadout()


func _clear_selected_slot() -> void:
	if _shop_draft == null:
		_publish_detail("战斗阶段为只读预览；请在商店调整技能。", &"info")
		return
	if _selected_skill_id.is_empty():
		_publish_detail("先点击一个已装备槽位。", &"warning")
		return
	var found_slot := &""
	for slot_id: StringName in SLOT_ORDER:
		if _working_loadout.get_skill_id(slot_id) == _selected_skill_id:
			found_slot = slot_id
			break
	if found_slot.is_empty():
		_publish_detail("所选技能当前未装备。", &"warning")
		return
	var detail := try_preview_assignment(&"", found_slot)
	if detail.is_empty():
		_selected_skill_id = &""
		_refresh_loadout()


func _confirm_shop() -> void:
	if _shop_draft == null or _host == null:
		return
	var result := _host.run_session.confirm_shop(_shop_draft)
	if not result.accepted:
		_publish_detail(_detail_text(result.detail), &"error")
		return
	_publish_detail("属性已提交，已离开商店。", &"success")
	hide_overlay()


func _claim_reward(option_id: StringName) -> void:
	if _host == null or _reward_offer == null or _reward_submitting:
		return
	_reward_submitting = true
	_reward_submit_count += 1
	_set_reward_input_enabled(false)
	if _reward_status != null:
		_reward_status.text = "正在领取 · 请稍候"
	var result := _host.run_session.claim_reward(_reward_offer.offer_id, option_id)
	if not result.accepted:
		_reward_submitting = false
		_set_reward_input_enabled(true)
		var message := _detail_text(result.detail)
		if _reward_status != null:
			_reward_status.text = message
			_reward_status.add_theme_color_override(&"font_color", UI.ERROR)
		status_requested.emit(message, &"error")
		_restore_reward_focus()
		return
	_snapshot = result.run_snapshot
	_reward_submitting = false
	_reward_offer = null
	_show_route_options()


func _set_reward_input_enabled(enabled: bool) -> void:
	for card: Button in _reward_cards:
		card.disabled = not enabled
	if _reward_confirm != null:
		_reward_confirm.disabled = not enabled or _reward_selected_index < 0


func _restore_reward_focus() -> void:
	if _reward_selected_index < 0 or _reward_selected_index >= _reward_cards.size():
		return
	_reward_cards[_reward_selected_index].call_deferred(&"grab_focus")


func _show_route_options() -> void:
	_reward_cards.clear()
	_reward_cards_stage = null
	_reward_confirm = null
	_reward_status = null
	_reward_selected_index = -1
	_close.visible = false
	_clear_children(_reward_area)
	var heading := _label("奖励已领取 · 选择下一步", 19, UI.SUCCESS)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_area.add_child(heading)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 12)
	_reward_area.add_child(row)
	for option: RouteOption in _snapshot.route.next_options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 72)
		button.text = _route_option_text(option)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_stylebox_override(&"focus", UI.focus_style())
		button.pressed.connect(_choose_route.bind(option.option_id))
		row.add_child(button)
	if row.get_child_count() > 0:
		(row.get_child(0) as Button).call_deferred(&"grab_focus")


func _choose_route(option_id: StringName) -> void:
	var result := _host.run_session.choose_route(option_id)
	if not result.accepted:
		_publish_detail(_detail_text(result.detail), &"error")
		return
	_snapshot = result.run_snapshot
	if _snapshot.route.phase == RunPhase.SHOP:
		show_loadout()
	else:
		hide_overlay()


func _on_snapshot_changed(snapshot: RunSnapshot, _cause: StringName) -> void:
	_snapshot = snapshot
	if _formal_mode:
		_render_formal_phase(snapshot, _cause)
		return
	if visible and _loadout_area.visible:
		_working_loadout = _shop_draft.preview_loadout() if _shop_draft != null else snapshot.loadout
		_refresh_loadout()


func _refresh_warning() -> void:
	var active_count := 0
	for slot_id: StringName in SkillSlotIds.active():
		var skill := _host.runtime_loadout.get_skill(_working_loadout.get_skill_id(slot_id))
		if skill != null and skill.is_active_skill():
			active_count += 1
	_warning.visible = active_count == 0
	_warning.text = (
		"无可按键技能 · 战斗将依赖普通攻击与被动（合法配置，可直接离店）"
		if _warning.visible
		else "当前可按键主动：%d / 3" % active_count
	)
	_warning.add_theme_color_override(
		&"font_color",
		UI.WARNING if _warning.visible else UI.TEXT_MUTED
	)


func _refresh_passives() -> void:
	_clear_children(_passive_list)
	var seen: Array[StringName] = []
	for slot_id: StringName in SLOT_ORDER:
		var skill_id := _working_loadout.get_skill_id(slot_id)
		var content := _catalog.content_for(skill_id)
		if content == null or content.gameplay_definition == null:
			continue
		if not content.gameplay_definition.is_passive_skill() or seen.has(skill_id):
			continue
		seen.append(skill_id)
		_passive_list.add_child(_label(
			"• %s · %s" % [content.display_name, _policy_text(content.gameplay_definition)],
			13,
			UI.TEXT
		))
	if seen.is_empty():
		_passive_list.add_child(_label("暂无生效被动", 13, UI.TEXT_DIM))


func _refresh_relics() -> void:
	_clear_children(_relic_list)
	if _snapshot == null or _snapshot.relics.display_states.is_empty():
		_relic_list.add_child(_label("暂无遗物", 13, UI.TEXT_DIM))
		return
	for state: RelicDisplayState in _snapshot.relics.display_states:
		var scope := "全部元素变化"
		for definition: RelicDefinition in _catalog.relic_definitions:
			if definition == null or definition.relic_id != state.relic_id:
				continue
			if definition is FormChangeRelicDefinition:
				match (definition as FormChangeRelicDefinition).response_policy:
					FormChangeResponsePolicy.Value.MANUAL_ONLY:
						scope = "仅手动切换"
					FormChangeResponsePolicy.Value.SKILL_AUTO_ONLY:
						scope = "仅技能自动切换"
			break
		_relic_list.add_child(_label(
			"• %s · %s" % [state.display_name, scope],
			13,
			UI.TEXT
		))


func _candidate_with_assignment(
	base: RuntimeLoadoutSnapshot,
	slot_id: StringName,
	skill_id: StringName
) -> RuntimeLoadoutSnapshot:
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in base.entries:
		var candidate_skill := skill_id if entry.slot_id == slot_id else entry.skill_id
		if not skill_id.is_empty() and entry.slot_id != slot_id and entry.skill_id == skill_id:
			candidate_skill = &""
		entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, candidate_skill))
	return RuntimeLoadoutSnapshot.new(entries, base.revision)


func _candidate_for_drag_drop(
	base: RuntimeLoadoutSnapshot,
	skill_id: StringName,
	source_slot_id: StringName,
	target_slot_id: StringName
) -> RuntimeLoadoutSnapshot:
	if (
		source_slot_id.is_empty()
		or source_slot_id == target_slot_id
		or base.get_skill_id(source_slot_id) != skill_id
	):
		return _candidate_with_assignment(base, target_slot_id, skill_id)
	var target_skill_id := base.get_skill_id(target_slot_id)
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in base.entries:
		var candidate_skill := entry.skill_id
		if entry.slot_id == source_slot_id:
			candidate_skill = target_skill_id
		elif entry.slot_id == target_slot_id:
			candidate_skill = skill_id
		entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, candidate_skill))
	return RuntimeLoadoutSnapshot.new(entries, base.revision)


func _activation_text(skill: SkillDefinition) -> String:
	return "ACTIVE 主动" if skill != null and skill.is_active_skill() else "PASSIVE 被动"


func _policy_text(skill: SkillDefinition) -> String:
	if skill == null:
		return "未知策略"
	match skill.element_policy:
		SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
			return "固定元素 · %s" % _element_text(skill.required_element_id)
		SkillDefinition.ElementPolicy.CURRENT_ELEMENT:
			return "读取当前元素 · 动态锁定"
		SkillDefinition.ElementPolicy.NEUTRAL:
			return "无属性 · 中性空心"
		_:
			return "未知策略"


func _policy_color(skill: SkillDefinition) -> Color:
	if skill == null:
		return UI.TEXT_DIM
	if skill.element_policy == SkillDefinition.ElementPolicy.NEUTRAL:
		return UI.NEUTRAL
	if skill.element_policy == SkillDefinition.ElementPolicy.EXCLUSIVE_ELEMENT:
		return _element_color(skill.required_element_id)
	return UI.WARNING


func _element_text(element_id: StringName) -> String:
	var content_name := String(element_id).to_upper()
	if element_id == ElementIds.WATER:
		return "水滴 WATER"
	if element_id == ElementIds.FIRE:
		return "火焰 FIRE"
	return "菱形 %s" % content_name


func _element_color(element_id: StringName) -> Color:
	if element_id == ElementIds.WATER:
		return UI.WATER_COLORBLIND if colorblind_mode else UI.WATER
	if element_id == ElementIds.FIRE:
		return UI.FIRE_COLORBLIND if colorblind_mode else UI.FIRE
	return UI.NEUTRAL


func _assignment_preview_text(skill_id: StringName, slot_id: StringName) -> String:
	if skill_id.is_empty():
		return "%s 已清空。" % String(slot_id)
	var content := _catalog.content_for(skill_id)
	var skill := content.gameplay_definition if content != null else null
	if skill != null and skill.is_passive_skill() and SkillSlotIds.is_active(slot_id):
		return "%s → %s；预览：该按键将不可释放。" % [content.display_name, String(slot_id)]
	return "%s → %s；预览合法。" % [
		content.display_name if content != null else String(skill_id),
		String(slot_id),
	]


func _assignment_committed_text(
		before: RuntimeLoadoutSnapshot,
		after: RuntimeLoadoutSnapshot,
		skill_id: StringName,
		slot_id: StringName
) -> String:
	if before.same_mapping(after):
		return "%s 已是权威配装 · 无需重复提交" % String(slot_id).to_upper()
	if skill_id.is_empty():
		var removed_id := before.get_skill_id(slot_id)
		var removed := _catalog.content_for(removed_id)
		return "%s 已卸下 · 即时生效" % (
			removed.display_name if removed != null else String(slot_id).to_upper()
		)
	var content := _catalog.content_for(skill_id)
	var display_name := content.display_name if content != null else String(skill_id)
	var previous_slot: StringName = &""
	for candidate_slot: StringName in SLOT_ORDER:
		if before.get_skill_id(candidate_slot) == skill_id:
			previous_slot = candidate_slot
			break
	if not previous_slot.is_empty() and previous_slot != slot_id:
		return "%s 已换至 %s · 即时生效" % [display_name, String(slot_id).to_upper()]
	return "%s 已装配至 %s · 即时生效" % [display_name, String(slot_id).to_upper()]


func _restore_shop_selection_focus() -> void:
	if _selected_skill_id.is_empty():
		return
	var card := _skill_cards.get(_selected_skill_id) as Button
	if card != null:
		card.call_deferred(&"grab_focus")


func _publish_detail(message: String, tone: StringName) -> void:
	_status.text = message
	_status.add_theme_color_override(&"font_color", _tone_color(tone))
	status_requested.emit(message, tone)


func _detail_text(detail: StringName) -> String:
	match detail:
		&"active_skill_in_passive_slot":
			return "拒绝：主动技能不能放入 PASSIVE 1–4；请改放 ACTIVE 1–3。"
		&"passive_skill_in_active_slot":
			return "拒绝：被动技能不能放入 ACTIVE 1–3；请改放 PASSIVE 1–4。"
		&"duplicate_equipped_skill":
			return "拒绝：同一技能只能装备一次。"
		&"loadout_contains_unowned_skill":
			return "拒绝：只能装备本局已拥有的技能。"
		&"unknown_shared_slot", &"missing_shared_slot", &"expected_four_shared_slots", &"expected_seven_shared_slots", &"unknown_loadout_slot":
			return "拒绝：目标槽位无效；请使用 ACTIVE 1–3 或 PASSIVE 1–4。"
		&"stale_loadout_revision", &"run_changed_since_draft_opened", &"loadout_changed_since_draft_opened", &"loadout_mapping_changed_since_draft_opened", &"draft_is_not_active":
			return "草稿已过期；请重新打开商店。"
		&"shop_loadout_outside_shop":
			return "战斗阶段为只读预览；请在商店调整技能。"
		&"stale_run_revision", &"stale_shop_session":
			return "权威状态已变化；界面已恢复最新商店或路线 snapshot。"
		&"stale_route_option":
			return "路线选项已过期；界面已恢复当前冻结门牌。"
		&"insufficient_dream_dust_for_purchase", &"insufficient_dream_dust_for_upgrade", &"no_affordable_shop_offer":
			return "梦尘不足；余额与价格未发生变化。"
		&"active_skill_max_level_reached":
			return "该主动技能已达最高等级。"
		&"no_active_skill_upgrade_investment":
			return "该技能没有可重置的累计实付。"
		&"passive_skill_has_no_levels":
			return "被动技能没有等级或重置事务。"
		&"command_id_reused_with_different_payload":
			return "重复命令载荷不一致，权威状态未改变。"
		_:
			return "操作未提交：%s" % String(detail)


func _route_option_text(option: RouteOption) -> String:
	match option.kind:
		RouteOption.Kind.SHOP:
			return "前往商店 / 配装"
		RouteOption.Kind.RUN_COMPLETE:
			return "完成本局"
		RouteOption.Kind.REWARD_ROOM:
			return "下一奖励房 · %s" % ("技能" if option.reward_type == RewardType.SKILL else "遗物")
		_:
			return String(option.option_id)


func _key_for_slot(slot_id: StringName) -> String:
	match slot_id:
		SkillSlotIds.ACTIVE_1:
			return "1"
		SkillSlotIds.ACTIVE_2:
			return "2"
		SkillSlotIds.ACTIVE_3:
			return "3"
		_:
			return "—"


func _tone_color(tone: StringName) -> Color:
	match tone:
		&"error":
			return UI.ERROR
		&"warning":
			return UI.WARNING
		&"success":
			return UI.SUCCESS
		_:
			return UI.TEXT_MUTED


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _separator() -> HSeparator:
	var line := HSeparator.new()
	line.add_theme_constant_override(&"separation", 8)
	return line


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _show_overlay() -> void:
	_apply_responsive_layout()
	visible = true
	move_to_front()


# Formal RunGame projection -------------------------------------------------
# These controls only project immutable RunSnapshot fields and submit through
# RunFlowCoordinator's thin command surface. They never own economy, route,
# level, loadout legality, room flow, or result state.


func formal_kind() -> StringName:
	return _formal_kind


func formal_area() -> Control:
	return _formal_area


func formal_control(control_id: StringName) -> Control:
	return _formal_buttons.get(control_id) as Control


func formal_route_cards() -> Array[Button]:
	return _formal_route_cards.duplicate()


func formal_route_confirm_button() -> Button:
	return _formal_route_confirm


func formal_selected_route_id() -> StringName:
	return _formal_selected_route_id


func formal_route_submit_count() -> int:
	return _formal_route_submit_count


func _render_formal_phase(snapshot: RunSnapshot, cause: StringName) -> void:
	if not _formal_mode or snapshot == null:
		return
	_snapshot = snapshot
	match snapshot.route.phase:
		RunPhase.SHOP:
			_show_formal_shop(cause)
		RunPhase.ROUTE_CHOICE:
			_show_formal_route(cause)
		RunPhase.RUN_COMPLETE, RunPhase.RUN_FAILED:
			_show_formal_result()
		_:
			_formal_kind = &"combat"
			_formal_command_busy = false
			_formal_route_submitting = false
			visible = false


func _formal_begin(kind: StringName, heading: String, subtitle: String) -> void:
	_formal_kind = kind
	_loadout_area.visible = false
	_reward_area.visible = false
	_close.visible = false
	_formal_scroll.visible = true
	_formal_area.visible = true
	_clear_children(_formal_area)
	_formal_buttons.clear()
	_title.text = heading
	_subtitle.text = subtitle
	_formal_status = null
	_formal_body = null
	_show_overlay()


func _show_formal_shop(cause: StringName = &"") -> void:
	if _snapshot == null or _snapshot.shop == null or _host == null:
		return
	if (
		_formal_shop_draft == null
		or _formal_shop_draft.confirmed
		or _formal_shop_draft.shop_session_id != _snapshot.shop.session_id
	):
		var opened := _host.run_session.open_shop_draft()
		if not opened.accepted:
			_formal_begin(&"shop", "梦尘商店", "权威商店会话不可用")
			_formal_status = _label(_detail_text(opened.detail), 14, UI.ERROR)
			_formal_area.add_child(_formal_status)
			return
		_formal_shop_draft = opened.draft
	_working_loadout = _formal_shop_draft.preview_loadout()
	_formal_begin(
		&"shop",
		"梦尘商店",
		"购买 / 升级 / 重置均独立提交 · 七槽装配即时生效"
	)

	var wallet := HBoxContainer.new()
	wallet.name = "Wallet"
	wallet.custom_minimum_size.y = 44
	wallet.add_theme_constant_override(&"separation", UI.GAP_MD)
	_formal_area.add_child(wallet)
	var balance := _label("✦ 梦尘余额  %d" % _snapshot.economy.balance, 22, UI.BORDER_FOCUS)
	balance.name = "Balance"
	balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet.add_child(balance)
	wallet.add_child(_label(
		"本局收入 %d  ·  购买支出 %d  ·  升级支出 %d  ·  已返还 %d" % [
			_snapshot.economy.total_earned,
			_snapshot.economy.total_spent_on_purchases,
			_snapshot.economy.total_spent_on_upgrades,
			_snapshot.economy.total_refunded,
		],
		13,
		UI.TEXT_MUTED
	))

	var body := HBoxContainer.new()
	body.name = "ShopBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", UI.GAP_MD)
	_formal_area.add_child(body)
	_formal_body = body

	var offers_panel := _formal_section_panel("固定技能候选", 1.45)
	body.add_child(offers_panel)
	var offers_scroll := ScrollContainer.new()
	offers_scroll.name = "OffersScroll"
	offers_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(offers_panel.get_node("Margin/Box") as VBoxContainer).add_child(offers_scroll)
	var offers_grid := GridContainer.new()
	offers_grid.name = "Offers"
	offers_grid.columns = 2
	offers_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers_grid.add_theme_constant_override(&"h_separation", UI.GAP_SM)
	offers_grid.add_theme_constant_override(&"v_separation", UI.GAP_SM)
	offers_scroll.add_child(offers_grid)
	for content: SkillContentDefinition in _catalog.shop_contents():
		offers_grid.add_child(_build_formal_shop_card(content))

	var loadout_panel := _formal_section_panel("权威即时配装 · A1–A3 / P1–P4", 1.0)
	body.add_child(loadout_panel)
	var loadout_box := loadout_panel.get_node("Margin/Box") as VBoxContainer
	loadout_box.add_child(_label("先选择已拥有技能，再点击同类型槽位；槽位操作无需离店确认。", 12, UI.TEXT_MUTED))
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.name = "OwnedScroll"
	inventory_scroll.custom_minimum_size.y = 78
	loadout_box.add_child(inventory_scroll)
	var inventory_row := HFlowContainer.new()
	inventory_row.name = "OwnedSkills"
	inventory_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_row.add_theme_constant_override(&"h_separation", UI.GAP_XS)
	inventory_row.add_theme_constant_override(&"v_separation", UI.GAP_XS)
	inventory_scroll.add_child(inventory_row)
	for skill_id: StringName in _snapshot.skills.owned_skill_ids:
		var owned_content := _catalog.content_for(skill_id)
		if owned_content == null or not owned_content.equippable:
			continue
		var select := _formal_action_button(
			"%s%s" % ["◆ " if _formal_selected_skill_id == skill_id else "", owned_content.display_name],
			"select:%s" % String(skill_id),
			Callable(self, "_formal_select_skill").bind(skill_id),
			Vector2(124, 44)
		)
		select.set_drag_forwarding(
			Callable(self, "_formal_skill_drag_data").bind(skill_id),
			Callable(self, "_formal_inventory_can_drop"),
			Callable(self, "_formal_inventory_drop")
		)
		inventory_row.add_child(select)
	loadout_box.add_child(_formal_slot_zone("主动槽 · 有键帽 / SP / 状态", SkillSlotIds.active()))
	loadout_box.add_child(_formal_slot_zone("被动槽 · 无键帽 / SP / 冷却", SkillSlotIds.passive()))
	var slot_actions := HBoxContainer.new()
	slot_actions.add_theme_constant_override(&"separation", UI.GAP_SM)
	loadout_box.add_child(slot_actions)
	var clear := _formal_action_button(
		"卸下所选槽",
		"clear_slot",
		Callable(self, "_formal_clear_selected_slot"),
		Vector2(148, 44)
	)
	clear.disabled = _formal_selected_slot_id.is_empty()
	slot_actions.add_child(clear)
	var selected_copy := "选择技能或槽位"
	if not _formal_selected_skill_id.is_empty():
		var selected_content := _catalog.content_for(_formal_selected_skill_id)
		selected_copy = "待装配：%s" % (selected_content.display_name if selected_content != null else String(_formal_selected_skill_id))
	elif not _formal_selected_slot_id.is_empty():
		selected_copy = "已选槽：%s" % String(_formal_selected_slot_id).to_upper()
	var selection := _label(selected_copy, 12, UI.WARNING)
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_actions.add_child(selection)

	var footer := HBoxContainer.new()
	footer.name = "ShopFooter"
	footer.custom_minimum_size.y = 50
	footer.add_theme_constant_override(&"separation", UI.GAP_MD)
	_formal_area.add_child(footer)
	_formal_status = _label(_shop_cause_copy(cause), 13, UI.TEXT_MUTED)
	_formal_status.name = "Status"
	_formal_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_formal_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_formal_status)
	var leave := _formal_action_button(
		"离开商店",
		"leave_shop",
		Callable(self, "_formal_leave_shop"),
		Vector2(176, 48),
		true
	)
	footer.add_child(leave)
	_restore_formal_focus()


func _build_formal_shop_card(content: SkillContentDefinition) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Skill_%s" % _safe_node_id(content.skill_id)
	card.custom_minimum_size = Vector2(238, 172)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_RAISED, UI.BORDER, 7, 1))
	var margin := _margin_container(9, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UI.GAP_XS)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override(&"separation", UI.GAP_SM)
	box.add_child(heading)
	if content.icon != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.texture = content.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading.add_child(icon)
	var title := _label(content.display_name, 16, UI.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var progress := _snapshot.skills.progress_for(content.skill_id)
	var owned := progress != null
	heading.add_child(_label("已拥有" if owned else "未拥有", 12, UI.SUCCESS if owned else UI.TEXT_MUTED))
	box.add_child(_label(
		"ACTIVE 主动" if content.gameplay_definition.is_active_skill() else "PASSIVE 被动",
		11,
		UI.WATER if content.gameplay_definition.is_active_skill() else UI.BORDER_PASSIVE
	))
	var description := _label(content.description, 11, UI.TEXT_MUTED)
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	if not owned:
		box.add_child(_label("购买价  ✦ %d" % content.purchase_price, 13, UI.BORDER_FOCUS))
		var offer := _shop_offer_for_skill(content.skill_id)
		var purchase := _formal_action_button(
			"购买 · %d" % content.purchase_price,
			"purchase:%s" % String(content.skill_id),
			Callable(self, "_formal_purchase").bind(offer.offer_id if offer != null else StringName()),
			Vector2(132, 44),
			true
		)
		purchase.disabled = offer == null
		box.add_child(purchase)
		return card
	if progress.is_passive():
		box.add_child(_label("持续生效 · 无等级 / 无重置", 12, UI.TEXT_MUTED))
		return card
	var current_effect := content.level_effect(progress.level)
	var maximum := content.active_progression.maximum_level() if content.active_progression != null else progress.level
	box.add_child(_label(
		"当前 Lv.%d/%d · %s" % [progress.level, maximum, _effect_copy(current_effect)],
		12,
		UI.TEXT
	))
	var next_price := content.active_progression.upgrade_price_from(progress.level) if content.active_progression != null else -1
	if next_price > 0:
		var next_effect := content.level_effect(progress.level + 1)
		box.add_child(_label("下一级 %s · ✦ %d" % [_effect_copy(next_effect), next_price], 11, UI.SUCCESS))
	else:
		box.add_child(_label("已达最高等级", 11, UI.SUCCESS))
	var refund := _estimated_refund(progress)
	box.add_child(_label("累计实付 ✦ %d · 预计返还 ✦ %d" % [progress.cumulative_upgrade_spend, refund], 11, UI.TEXT_MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", UI.GAP_XS)
	box.add_child(actions)
	var upgrade := _formal_action_button(
		"升级%s" % (" · %d" % next_price if next_price > 0 else ""),
		"upgrade:%s" % String(content.skill_id),
		Callable(self, "_formal_upgrade").bind(content.skill_id),
		Vector2(116, 44),
		true
	)
	upgrade.disabled = next_price <= 0
	actions.add_child(upgrade)
	var request_reset := _formal_action_button(
		"重置",
		"reset:%s" % String(content.skill_id),
		Callable(self, "_formal_request_reset").bind(content.skill_id),
		Vector2(88, 44)
	)
	request_reset.disabled = progress.level <= 1 or progress.cumulative_upgrade_spend <= 0
	actions.add_child(request_reset)
	if _formal_reset_skill_id == content.skill_id:
		var confirmation := HBoxContainer.new()
		confirmation.name = "ResetConfirmation"
		confirmation.add_theme_constant_override(&"separation", UI.GAP_XS)
		box.add_child(confirmation)
		confirmation.add_child(_label("确认返还 ✦ %d？" % refund, 12, UI.WARNING))
		confirmation.add_child(_formal_action_button(
			"确认重置",
			"reset_confirm:%s" % String(content.skill_id),
			Callable(self, "_formal_confirm_reset").bind(content.skill_id),
			Vector2(104, 44),
			true
		))
		confirmation.add_child(_formal_action_button(
			"取消",
			"reset_cancel:%s" % String(content.skill_id),
			Callable(self, "_formal_cancel_reset"),
			Vector2(72, 44)
		))
	return card


func _formal_section_panel(title_text: String, stretch: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_OVERLAY, UI.BORDER, 8, 1))
	var margin := _margin_container(10, 8)
	margin.name = "Margin"
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", UI.GAP_SM)
	margin.add_child(box)
	box.add_child(_label(title_text, 15, UI.TEXT))
	return panel


func _formal_slot_zone(title_text: String, slot_ids: Array[StringName]) -> VBoxContainer:
	var zone := VBoxContainer.new()
	zone.name = "ActiveSlots" if slot_ids == SkillSlotIds.active() else "PassiveSlots"
	zone.add_theme_constant_override(&"separation", UI.GAP_XS)
	zone.add_child(_label(title_text, 12, UI.TEXT_MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UI.GAP_XS)
	zone.add_child(row)
	for slot_id: StringName in slot_ids:
		var skill_id := _working_loadout.get_skill_id(slot_id)
		var content := _catalog.content_for(skill_id)
		var display := "空槽" if content == null else content.display_name
		var prefix := "A%d" % (SkillSlotIds.active().find(slot_id) + 1) if SkillSlotIds.is_active(slot_id) else "P%d" % (SkillSlotIds.passive().find(slot_id) + 1)
		var button := _formal_action_button(
			"%s\n%s" % [prefix, display],
			"slot:%s" % String(slot_id),
			Callable(self, "_formal_press_slot").bind(slot_id),
			Vector2(112, 54)
		)
		if _formal_selected_slot_id == slot_id:
			button.add_theme_stylebox_override(&"normal", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
		button.set_drag_forwarding(
			Callable(self, "_formal_slot_drag_data").bind(slot_id),
			Callable(self, "_formal_slot_can_drop").bind(slot_id),
			Callable(self, "_formal_slot_drop").bind(slot_id)
		)
		row.add_child(button)
	return zone


func _formal_skill_drag_data(_position: Vector2, skill_id: StringName) -> Variant:
	if not _formal_drag_context_ready() or not _snapshot.skills.owned_skill_ids.has(skill_id):
		return null
	var content := _catalog.content_for(skill_id)
	if content == null or not content.equippable:
		return null
	set_drag_preview(_formal_drag_preview(content))
	return {
		"kind": FORMAL_LOADOUT_DRAG_KIND,
		"skill_id": skill_id,
		"source_slot_id": &"",
	}


func _formal_slot_drag_data(_position: Vector2, slot_id: StringName) -> Variant:
	if not _formal_drag_context_ready():
		return null
	var skill_id := _working_loadout.get_skill_id(slot_id)
	if skill_id.is_empty():
		return null
	var content := _catalog.content_for(skill_id)
	if content == null:
		return null
	set_drag_preview(_formal_drag_preview(content))
	return {
		"kind": FORMAL_LOADOUT_DRAG_KIND,
		"skill_id": skill_id,
		"source_slot_id": slot_id,
	}


func _formal_slot_can_drop(_position: Vector2, data: Variant, _slot_id: StringName) -> bool:
	return (
		_formal_drag_context_ready()
		and data is Dictionary
		and data.get("kind", &"") == FORMAL_LOADOUT_DRAG_KIND
		and not StringName(data.get("skill_id", &"")).is_empty()
	)


func _formal_slot_drop(_position: Vector2, data: Variant, slot_id: StringName) -> void:
	if not _formal_slot_can_drop(_position, data, slot_id):
		return
	_formal_apply_drag_drop(
		StringName(data.get("skill_id", &"")),
		StringName(data.get("source_slot_id", &"")),
		slot_id
	)


func _formal_inventory_can_drop(_position: Vector2, _data: Variant) -> bool:
	return false


func _formal_inventory_drop(_position: Vector2, _data: Variant) -> void:
	pass


func _formal_drag_context_ready() -> bool:
	return (
		_formal_kind == &"shop"
		and not _formal_command_busy
		and _formal_shop_draft != null
		and _working_loadout != null
		and _snapshot != null
		and _snapshot.shop != null
	)


func _formal_drag_preview(content: SkillContentDefinition) -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(164, 52)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_RAISED, UI.BORDER_FOCUS, 7, 2))
	var margin := _margin_container(8, 6)
	preview.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UI.GAP_SM)
	margin.add_child(row)
	if content.icon != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.texture = content.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override(&"separation", 0)
	row.add_child(copy)
	copy.add_child(_label(content.display_name, 14, UI.TEXT))
	copy.add_child(_label(
		"ACTIVE 主动" if content.gameplay_definition.is_active_skill() else "PASSIVE 被动",
		11,
		UI.WATER if content.gameplay_definition.is_active_skill() else UI.BORDER_PASSIVE
	))
	return preview


func _formal_apply_drag_drop(skill_id: StringName, source_slot_id: StringName, target_slot_id: StringName) -> void:
	if not _formal_drag_context_ready():
		return
	_formal_focus_id = StringName("slot:%s" % String(target_slot_id))
	if not source_slot_id.is_empty() and _working_loadout.get_skill_id(source_slot_id) != skill_id:
		_recover_formal_shop(null, "拖拽来源已变化")
		return
	var candidate := _candidate_for_drag_drop(_working_loadout, skill_id, source_slot_id, target_slot_id)
	var result := _formal_coordinator.call("apply_shop_loadout", _formal_shop_draft, candidate) as RunCommandResult
	if result == null or not result.accepted:
		_recover_formal_shop(result, "拖拽装配未生效")
		return
	var target_before := _working_loadout.get_skill_id(target_slot_id)
	_snapshot = result.run_snapshot
	_working_loadout = _formal_shop_draft.preview_loadout()
	_formal_selected_skill_id = &""
	_formal_selected_slot_id = target_slot_id
	_show_formal_shop(&"loadout_applied")
	_set_formal_status(
		"槽位已互换并由权威即时生效。"
		if not source_slot_id.is_empty() and not target_before.is_empty() and source_slot_id != target_slot_id
		else "拖拽装配已由权威 RuntimeLoadout 即时生效。",
		&"success"
	)


func _formal_select_skill(skill_id: StringName) -> void:
	if _formal_command_busy:
		return
	_formal_selected_skill_id = skill_id
	_formal_selected_slot_id = &""
	_formal_focus_id = StringName("select:%s" % String(skill_id))
	_show_formal_shop(&"skill_selected")


func _formal_press_slot(slot_id: StringName) -> void:
	if _formal_command_busy or _formal_shop_draft == null:
		return
	if _formal_selected_skill_id.is_empty():
		_formal_selected_slot_id = slot_id
		_formal_focus_id = StringName("slot:%s" % String(slot_id))
		_show_formal_shop(&"slot_selected")
		return
	var candidate := _candidate_with_assignment(_working_loadout, slot_id, _formal_selected_skill_id)
	_formal_focus_id = StringName("slot:%s" % String(slot_id))
	var result := _formal_coordinator.call("apply_shop_loadout", _formal_shop_draft, candidate) as RunCommandResult
	if result == null or not result.accepted:
		_recover_formal_shop(result, "装配未生效")
		return
	_snapshot = result.run_snapshot
	_working_loadout = _formal_shop_draft.preview_loadout()
	_formal_selected_skill_id = &""
	_formal_selected_slot_id = slot_id
	_show_formal_shop(&"loadout_applied")
	_set_formal_status("装配已由权威 RuntimeLoadout 即时生效。", &"success")


func _formal_clear_selected_slot() -> void:
	if _formal_selected_slot_id.is_empty() or _formal_shop_draft == null:
		return
	var slot_id := _formal_selected_slot_id
	var candidate := _candidate_with_assignment(_working_loadout, slot_id, &"")
	_formal_focus_id = &"clear_slot"
	var result := _formal_coordinator.call("apply_shop_loadout", _formal_shop_draft, candidate) as RunCommandResult
	if result == null or not result.accepted:
		_recover_formal_shop(result, "卸下未生效")
		return
	_snapshot = result.run_snapshot
	_working_loadout = _formal_shop_draft.preview_loadout()
	_formal_selected_slot_id = &""
	_show_formal_shop(&"loadout_applied")
	_set_formal_status("槽位已卸下并即时生效。", &"success")


func _formal_purchase(offer_id: StringName) -> void:
	if _formal_command_busy or offer_id.is_empty():
		return
	_formal_command_busy = true
	var result := _formal_coordinator.call(
		"purchase_shop_skill",
		offer_id,
		_snapshot.revision,
		_snapshot.shop.session_id
	) as RunCommandResult
	_formal_command_busy = false
	_process_shop_result(result, "购买成功，梦尘与所有权已权威更新。")


func _formal_upgrade(skill_id: StringName) -> void:
	if _formal_command_busy:
		return
	_formal_command_busy = true
	_formal_focus_id = StringName("upgrade:%s" % String(skill_id))
	var result := _formal_coordinator.call(
		"upgrade_shop_skill",
		skill_id,
		_snapshot.revision,
		_snapshot.shop.session_id
	) as RunCommandResult
	_formal_command_busy = false
	_process_shop_result(result, "主动技能等级已权威提升。")


func _formal_request_reset(skill_id: StringName) -> void:
	if _formal_command_busy:
		return
	_formal_reset_skill_id = skill_id
	_formal_focus_id = StringName("reset_confirm:%s" % String(skill_id))
	_show_formal_shop(&"reset_focused")
	_set_formal_status("重置尚未提交；请使用独立“确认重置”或取消。", &"warning")


func _formal_cancel_reset() -> void:
	var skill_id := _formal_reset_skill_id
	_formal_reset_skill_id = &""
	_formal_focus_id = StringName("reset:%s" % String(skill_id))
	_show_formal_shop(&"reset_cancelled")
	_set_formal_status("已取消重置；权威等级与梦尘未变化。", &"info")


func _formal_confirm_reset(skill_id: StringName) -> void:
	if _formal_command_busy or _formal_reset_skill_id != skill_id:
		return
	_formal_command_busy = true
	_formal_focus_id = StringName("reset:%s" % String(skill_id))
	var result := _formal_coordinator.call(
		"reset_shop_skill",
		skill_id,
		_snapshot.revision,
		_snapshot.shop.session_id
	) as RunCommandResult
	_formal_command_busy = false
	_formal_reset_skill_id = &""
	_process_shop_result(result, "主动技能已权威重置，返还计入梦尘账本。")


func _formal_leave_shop() -> void:
	if _formal_command_busy or _snapshot == null or _snapshot.shop == null:
		return
	_formal_command_busy = true
	var result := _formal_coordinator.call(
		"leave_shop",
		_snapshot.revision,
		_snapshot.shop.session_id
	) as RunCommandResult
	_formal_command_busy = false
	if result == null or not result.accepted:
		_recover_formal_shop(result, "未能离开商店")


func _process_shop_result(result: RunCommandResult, success_copy: String) -> void:
	if result == null or not result.accepted:
		_recover_formal_shop(result, "交易未提交")
		return
	_snapshot = result.run_snapshot
	_show_formal_shop(&"authority_transaction")
	_set_formal_status(success_copy, &"success")


func _recover_formal_shop(result: RunCommandResult, prefix: String) -> void:
	_snapshot = (
		result.run_snapshot
		if result != null and result.run_snapshot != null
		else _formal_coordinator.call("current_snapshot") as RunSnapshot
	)
	if _snapshot != null and _snapshot.route.phase == RunPhase.SHOP:
		_show_formal_shop(&"authority_rejected")
		_set_formal_status("%s：%s" % [prefix, _detail_text(result.detail if result != null else &"missing_result")], &"error")
		_restore_formal_focus()


func _show_formal_route(cause: StringName = &"") -> void:
	if _snapshot == null:
		return
	_formal_begin(&"route", "路线门牌", "聚焦 / Hover 仅查看 · 只有独立确认才会选择路线")
	_formal_route_revision = _snapshot.revision
	_formal_route_cards.clear()
	_formal_route_confirm = null
	var option_ids: Array[StringName] = []
	for option: RouteOption in _snapshot.route.next_options:
		option_ids.append(option.option_id)
	if not option_ids.has(_formal_selected_route_id):
		_formal_selected_route_id = &""
	var context := _label(
		"已完成战斗 %d/6 · 当前选择：%s" % [
			_snapshot.route.completed_combat_rooms,
			"尚未选择" if _formal_selected_route_id.is_empty() else String(_formal_selected_route_id),
		],
		14,
		UI.TEXT_MUTED
	)
	_formal_area.add_child(context)
	var row := HBoxContainer.new()
	row.name = "RouteCards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 18)
	_formal_area.add_child(row)
	for option: RouteOption in _snapshot.route.next_options:
		var selected := option.option_id == _formal_selected_route_id
		var card := _formal_action_button(
			"%s%s\n\n资源 / 梦尘：%s\n遭遇：%s\n环境：%s\n风险：%s（Tier %d）\n\n%s" % [
				"◆ " if selected else "",
				option.title,
				option.expected_dream_dust_label,
				option.encounter_label,
				option.environment_label,
				option.risk_label,
				option.risk_tier,
				"已聚焦 · 尚未选择" if selected else "聚焦查看详情",
			],
			"route:%s" % String(option.option_id),
			Callable(self, "_formal_focus_route").bind(option.option_id),
			Vector2(410, 300)
		)
		card.name = "Route_%s" % _safe_node_id(option.option_id)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override(&"font_size", 15)
		if selected:
			card.add_theme_stylebox_override(&"normal", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
		_formal_route_cards.append(card)
		row.add_child(card)
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 56
	footer.add_theme_constant_override(&"separation", UI.GAP_MD)
	_formal_area.add_child(footer)
	_formal_status = _label(_route_cause_copy(cause), 13, UI.TEXT_MUTED)
	_formal_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_formal_status)
	_formal_route_confirm = _formal_action_button(
		"确认路线",
		"route_confirm",
		Callable(self, "_formal_confirm_route"),
		Vector2(176, 48),
		true
	)
	_formal_route_confirm.disabled = _formal_selected_route_id.is_empty() or _formal_route_submitting
	footer.add_child(_formal_route_confirm)
	_wire_formal_route_focus()
	_restore_formal_focus()


func _formal_focus_route(option_id: StringName) -> void:
	if _formal_route_submitting:
		return
	_formal_selected_route_id = option_id
	_formal_focus_id = StringName("route:%s" % String(option_id))
	_show_formal_route(&"route_focused")
	_set_formal_status("路线已聚焦，权威选择尚未发生。", &"warning")


func _formal_confirm_route() -> void:
	if _formal_route_submitting or _formal_selected_route_id.is_empty():
		return
	_formal_route_submitting = true
	_formal_route_submit_count += 1
	if _formal_route_confirm != null:
		_formal_route_confirm.disabled = true
	var result := _formal_coordinator.call(
		"choose_route",
		_formal_selected_route_id,
		_formal_route_revision
	) as RunCommandResult
	if result == null or not result.accepted:
		_formal_route_submitting = false
		_snapshot = (
			result.run_snapshot
			if result != null and result.run_snapshot != null
			else _formal_coordinator.call("current_snapshot") as RunSnapshot
		)
		if _snapshot != null and _snapshot.route.phase == RunPhase.ROUTE_CHOICE:
			_show_formal_route(&"authority_rejected")
			_set_formal_status(_detail_text(result.detail if result != null else &"missing_result"), &"error")
			_restore_formal_focus()


func _wire_formal_route_focus() -> void:
	for index: int in _formal_route_cards.size():
		var card := _formal_route_cards[index]
		if index > 0:
			card.focus_neighbor_left = card.get_path_to(_formal_route_cards[index - 1])
		if index + 1 < _formal_route_cards.size():
			card.focus_neighbor_right = card.get_path_to(_formal_route_cards[index + 1])
		card.focus_neighbor_bottom = card.get_path_to(_formal_route_confirm)
	if not _formal_route_cards.is_empty():
		_formal_route_confirm.focus_neighbor_top = _formal_route_confirm.get_path_to(_formal_route_cards[0])


func _show_formal_result() -> void:
	if _snapshot == null or _snapshot.result == null:
		return
	var result := _snapshot.result
	var complete := result.is_complete()
	_formal_begin(
		&"result",
		"本局通关" if complete else "本局失败",
		"冻结结算 · 不含免费奖励、额外商店或 Boss 梦尘"
	)
	var outcome := _label(
		"VICTORY  通关" if complete else "DEFEAT  失败 · %s" % String(result.failure_reason),
		24,
		UI.SUCCESS if complete else UI.ERROR
	)
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formal_area.add_child(outcome)
	var columns := HBoxContainer.new()
	columns.name = "ResultColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", UI.GAP_MD)
	_formal_area.add_child(columns)
	var summary := _formal_section_panel("流程与梦尘账本", 1.0)
	columns.add_child(summary)
	var summary_box := summary.get_node("Margin/Box") as VBoxContainer
	summary_box.add_child(_label("战斗进度  %d / %d" % [result.completed_combat_rooms, result.total_combat_rooms], 20, UI.TEXT))
	summary_box.add_child(_label("商店访问 %d / 3  ·  路线确认 %d / 2" % [result.shop_visits, result.route_choices], 14, UI.TEXT_MUTED))
	summary_box.add_child(_separator())
	summary_box.add_child(_label("梦尘收入  +%d" % result.economy.total_earned, 14, UI.SUCCESS))
	summary_box.add_child(_label("购买支出  -%d" % result.economy.total_spent_on_purchases, 14, UI.TEXT))
	summary_box.add_child(_label("升级支出  -%d" % result.economy.total_spent_on_upgrades, 14, UI.TEXT))
	summary_box.add_child(_label("重置返还  +%d" % result.economy.total_refunded, 14, UI.WARNING))
	summary_box.add_child(_label("最终余额  %d" % result.economy.balance, 20, UI.BORDER_FOCUS))
	summary_box.add_child(_separator())
	var route_copy := " → ".join(PackedStringArray(result_route_ids()))
	summary_box.add_child(_label("路线摘要：%s" % (route_copy if not route_copy.is_empty() else "未确认路线"), 13, UI.TEXT_MUTED))

	var build := _formal_section_panel("最终技能等级与七槽", 1.25)
	columns.add_child(build)
	var build_box := build.get_node("Margin/Box") as VBoxContainer
	var active_levels := HBoxContainer.new()
	active_levels.add_theme_constant_override(&"separation", UI.GAP_SM)
	build_box.add_child(active_levels)
	for progress: SkillProgressSnapshot in result.skills.progress_entries:
		if not progress.is_active():
			continue
		var content := _catalog.content_for(progress.skill_id)
		active_levels.add_child(_result_badge(
			"%s\nLv.%d" % [content.display_name if content != null else String(progress.skill_id), progress.level],
			UI.WATER
		))
	build_box.add_child(_formal_result_slot_row("A1–A3 主动", SkillSlotIds.active(), result.loadout))
	build_box.add_child(_formal_result_slot_row("P1–P4 被动", SkillSlotIds.passive(), result.loadout))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.custom_minimum_size.y = 52
	footer.add_theme_constant_override(&"separation", UI.GAP_MD)
	_formal_area.add_child(footer)
	var return_entry := _formal_action_button(
		"返回入口（暂不可用）",
		"return_entry",
		Callable(),
		Vector2(210, 48)
	)
	return_entry.disabled = true
	return_entry.tooltip_text = "当前项目未定义独立标题入口；不会伪造返回事务。"
	footer.add_child(return_entry)
	var new_run := _formal_action_button(
		"开始新一局",
		"new_run",
		Callable(self, "_formal_new_run"),
		Vector2(190, 48),
		true
	)
	footer.add_child(new_run)
	new_run.call_deferred(&"grab_focus")


func _formal_result_slot_row(title_text: String, slot_ids: Array[StringName], loadout: RuntimeLoadoutSnapshot) -> VBoxContainer:
	var zone := VBoxContainer.new()
	zone.add_theme_constant_override(&"separation", UI.GAP_XS)
	zone.add_child(_label(title_text, 12, UI.TEXT_MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UI.GAP_XS)
	zone.add_child(row)
	for slot_id: StringName in slot_ids:
		var skill_id := loadout.get_skill_id(slot_id)
		var content := _catalog.content_for(skill_id)
		var index := SkillSlotIds.active().find(slot_id) + 1 if SkillSlotIds.is_active(slot_id) else SkillSlotIds.passive().find(slot_id) + 1
		var prefix := ("A" if SkillSlotIds.is_active(slot_id) else "P") + str(index)
		row.add_child(_result_badge("%s\n%s" % [prefix, "空槽" if content == null else content.display_name], UI.BORDER if SkillSlotIds.is_active(slot_id) else UI.BORDER_PASSIVE))
	return zone


func _result_badge(copy: String, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(116, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", UI.flat_panel(UI.SURFACE_RAISED, border, 6, 1))
	var label := _label(copy, 12, UI.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _formal_new_run() -> void:
	if _formal_coordinator != null:
		_formal_coordinator.call("request_new_run")


func result_route_ids() -> Array[String]:
	var ids: Array[String] = []
	if _snapshot == null:
		return ids
	for option_id: StringName in _snapshot.route.selected_route_option_ids:
		ids.append(String(option_id))
	return ids


func _shop_offer_for_skill(skill_id: StringName) -> ShopOfferSnapshot:
	if _snapshot == null or _snapshot.shop == null:
		return null
	for offer: ShopOfferSnapshot in _snapshot.shop.offers:
		if offer.skill_id == skill_id:
			return offer
	return null


func _estimated_refund(progress: SkillProgressSnapshot) -> int:
	if progress == null or _snapshot == null or _snapshot.rules == null:
		return 0
	return floori(
		float(progress.cumulative_upgrade_spend)
		* float(_snapshot.rules.upgrade_refund_basis_points)
		/ float(RunRulesSnapshot.BASIS_POINTS_DENOMINATOR)
	)


func _effect_copy(effect: ActiveSkillLevelEffectSnapshot) -> String:
	if effect == null:
		return "效果未提供"
	var parts: Array[String] = []
	if not is_equal_approx(effect.damage_scale, 1.0):
		parts.append("伤害 ×%.2f" % effect.damage_scale)
	if not is_equal_approx(effect.healing_scale, 1.0):
		parts.append("治疗 ×%.2f" % effect.healing_scale)
	if not is_equal_approx(effect.shield_scale, 1.0):
		parts.append("护盾 ×%.2f" % effect.shield_scale)
	if not is_equal_approx(effect.resource_gain_scale, 1.0):
		parts.append("资源 ×%.2f" % effect.resource_gain_scale)
	return "基础效果" if parts.is_empty() else " / ".join(PackedStringArray(parts))


func _formal_action_button(
	copy: String,
	control_id: String,
	callback: Callable,
	minimum: Vector2 = Vector2(120, 44),
	primary: bool = false
) -> Button:
	var button := Button.new()
	button.name = _safe_node_id(StringName(control_id))
	button.text = copy
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override(
		&"normal",
		UI.button_style(UI.SURFACE_SOFT if primary else UI.SURFACE_RAISED, UI.BORDER_FOCUS if primary else UI.BORDER)
	)
	button.add_theme_stylebox_override(&"hover", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
	button.add_theme_stylebox_override(&"pressed", UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS))
	button.add_theme_stylebox_override(&"focus", UI.focus_style())
	if callback.is_valid():
		button.pressed.connect(callback)
	_formal_buttons[StringName(control_id)] = button
	return button


func _margin_container(horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", horizontal)
	margin.add_theme_constant_override(&"margin_right", horizontal)
	margin.add_theme_constant_override(&"margin_top", vertical)
	margin.add_theme_constant_override(&"margin_bottom", vertical)
	return margin


func _safe_node_id(value: StringName) -> String:
	return String(value).replace(":", "_").replace("/", "_").replace(" ", "_")


func _set_formal_status(copy: String, tone: StringName) -> void:
	if _formal_status == null:
		return
	_formal_status.text = copy
	_formal_status.add_theme_color_override(&"font_color", _tone_color(tone))
	status_requested.emit(copy, tone)


func _restore_formal_focus() -> void:
	if _formal_focus_id.is_empty():
		return
	call_deferred(&"_grab_formal_focus", _formal_focus_id)


func _grab_formal_focus(control_id: StringName) -> void:
	var control := _formal_buttons.get(control_id) as Control
	if (
		control != null
		and control.is_inside_tree()
		and control.is_visible_in_tree()
		and control.focus_mode != Control.FOCUS_NONE
	):
		control.grab_focus()


func _shop_cause_copy(cause: StringName) -> String:
	match cause:
		&"skill_selected":
			return "已选择技能；点击同类型槽位即可即时生效。"
		&"slot_selected":
			return "已选择槽位；可卸下，或选择技能后换槽。"
		&"reset_focused":
			return "重置尚未提交。"
		&"authority_rejected":
			return "权威拒绝后已恢复最新余额、等级、七槽与焦点。"
		&"loadout_applied":
			return "七槽映射已即时生效。"
		_:
			return "所有数值来自当前权威商店 snapshot。"


func _route_cause_copy(cause: StringName) -> String:
	match cause:
		&"route_focused":
			return "已聚焦，尚未选择；请独立确认。"
		&"authority_rejected":
			return "权威拒绝后已恢复冻结选项与焦点。"
		_:
			return "两张路线卡均来自当前冻结 snapshot。"
