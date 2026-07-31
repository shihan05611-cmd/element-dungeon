class_name RunOverlayInterface
extends Control

const UI := preload("res://scripts/ui/combat_ui_tokens.gd")

signal status_requested(message: String, tone: StringName)

const SLOT_ORDER: Array[StringName] = [
	SkillSlotIds.ACTIVE_1,
	SkillSlotIds.ACTIVE_2,
	SkillSlotIds.ACTIVE_3,
	SkillSlotIds.PASSIVE_1,
]

var colorblind_mode: bool = false

var _host: RunSessionHost
var _catalog: RunContentCatalog
var _snapshot: RunSnapshot
var _working_loadout: RuntimeLoadoutSnapshot
var _shop_draft: ShopDraft
var _selected_skill_id: StringName = &""
var _reward_offer: RewardOffer

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _slot_row: HBoxContainer
var _warning: Label
var _inventory: GridContainer
var _passive_list: VBoxContainer
var _relic_list: VBoxContainer
var _status: Label
var _confirm: Button
var _reward_area: VBoxContainer
var _loadout_area: VBoxContainer


func _ready() -> void:
	_build()
	visible = false


func configure(host: RunSessionHost) -> void:
	_host = host
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


func toggle_loadout() -> void:
	if visible:
		hide_overlay()
	else:
		show_loadout()


func show_loadout(snapshot_override: RuntimeLoadoutSnapshot = null) -> void:
	if _host == null or _catalog == null:
		return
	_reward_offer = null
	_reward_area.visible = false
	_loadout_area.visible = true
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
	_title.text = "共享配装 · ACTIVE 1–3 + PASSIVE 1"
	_subtitle.text = (
		"商店草稿 · 拖放或先选技能再点槽位 · 确认后原子生效"
		if _shop_draft != null
		else "战斗只读预览 · 按 L 关闭 · 四槽在所有元素间共享"
	)
	_confirm.disabled = _shop_draft == null
	_confirm.text = "确认配装与属性" if _shop_draft != null else "仅商店阶段可确认"
	_refresh_loadout()
	_show_overlay()


func show_reward(offer: RewardOffer) -> void:
	if offer == null or not offer.valid:
		return
	_reward_offer = offer
	_reward_area.visible = true
	_loadout_area.visible = false
	_title.text = "房间奖励"
	_subtitle.text = "选择一项已生成奖励；界面不重算候选或权重"
	_clear_children(_reward_area)
	var prompt := _label("选择一项", 18, UI.TEXT)
	_reward_area.add_child(prompt)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 12)
	_reward_area.add_child(cards)
	for option: RewardOption in offer.options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(236, 160)
		button.text = "%s\n\n%s" % [option.display_name, option.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override(&"font_size", 15)
		button.add_theme_color_override(&"font_color", UI.TEXT)
		button.add_theme_stylebox_override(
			&"normal",
			UI.button_style(UI.SURFACE_RAISED, UI.BORDER)
		)
		button.add_theme_stylebox_override(
			&"hover",
			UI.button_style(UI.SURFACE_SOFT, UI.BORDER_FOCUS)
		)
		button.pressed.connect(_claim_reward.bind(option.option_id))
		cards.add_child(button)
	_show_overlay()


func hide_overlay() -> void:
	visible = false
	_selected_skill_id = &""
	get_viewport().set_input_as_handled()


func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled
	if visible and _loadout_area.visible:
		_refresh_loadout()


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
	var validation := _host.runtime_loadout.validate_snapshot(candidate)
	if not validation.accepted:
		_publish_detail(_detail_text(validation.detail), &"error")
		return validation.detail
	if _shop_draft != null:
		var draft_result := _shop_draft.try_assign_slot(slot_id, skill_id)
		if not draft_result.accepted:
			_publish_detail(_detail_text(draft_result.detail), &"error")
			return draft_result.detail
		_working_loadout = _shop_draft.preview_loadout()
	else:
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

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 32)
	margin.add_theme_constant_override(&"margin_top", 24)
	margin.add_theme_constant_override(&"margin_right", 32)
	margin.add_theme_constant_override(&"margin_bottom", 24)
	add_child(margin)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override(
		&"panel",
		UI.panel(UI.SURFACE, UI.BORDER_FOCUS, 10, 2)
	)
	margin.add_child(_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override(&"margin_left", 20)
	panel_margin.add_theme_constant_override(&"margin_top", 16)
	panel_margin.add_theme_constant_override(&"margin_right", 20)
	panel_margin.add_theme_constant_override(&"margin_bottom", 16)
	_panel.add_child(panel_margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override(&"separation", 10)
	panel_margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 46
	root_box.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_title = _label("共享配装", 22, UI.TEXT)
	heading.add_child(_title)
	_subtitle = _label("", 13, UI.TEXT_MUTED)
	heading.add_child(_subtitle)
	var close := Button.new()
	close.text = "关闭  L"
	close.custom_minimum_size = Vector2(112, 44)
	close.add_theme_stylebox_override(
		&"normal",
		UI.button_style(UI.SURFACE_RAISED, UI.BORDER)
	)
	close.pressed.connect(hide_overlay)
	header.add_child(close)

	_loadout_area = VBoxContainer.new()
	_loadout_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loadout_area.add_theme_constant_override(&"separation", 8)
	root_box.add_child(_loadout_area)

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
	clear_button.pressed.connect(_clear_selected_slot)
	footer.add_child(clear_button)
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(176, 44)
	_confirm.pressed.connect(_confirm_shop)
	footer.add_child(_confirm)

	_reward_area = VBoxContainer.new()
	_reward_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reward_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_area.add_theme_constant_override(&"separation", 16)
	root_box.add_child(_reward_area)


func _refresh_loadout() -> void:
	if _working_loadout == null or _catalog == null:
		return
	_clear_children(_slot_row)
	for slot_id: StringName in SLOT_ORDER:
		_slot_row.add_child(_build_slot_card(slot_id, _working_loadout.get_skill_id(slot_id)))
	_clear_children(_inventory)
	var owned := _snapshot.skills.owned_skill_ids if _snapshot != null else []
	for skill_id: StringName in owned:
		var content := _catalog.content_for(skill_id)
		if content == null or not content.equippable:
			continue
		_inventory.add_child(_build_skill_card(content))
	_refresh_warning()
	_refresh_passives()
	_refresh_relics()


func _build_slot_card(slot_id: StringName, skill_id: StringName) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = String(slot_id)
	card.custom_minimum_size = Vector2(0, 126)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_passive_slot := slot_id == SkillSlotIds.PASSIVE_1
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
		"PASSIVE_1 · 仅被动" if is_passive_slot else "%s · 可主动/被动" % String(slot_id).to_upper(),
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
	card.pressed.connect(_select_skill.bind(content.skill_id))
	card.set_drag_forwarding(
		Callable(self, "_skill_drag_data").bind(content.skill_id),
		Callable(self, "_skill_can_drop"),
		Callable(self, "_skill_drop")
	)
	card.tooltip_text = "%s\n%s" % [content.display_name, content.description]
	return card


func _select_skill(skill_id: StringName) -> void:
	_selected_skill_id = skill_id
	var content := _catalog.content_for(skill_id)
	_publish_detail(
		"已选择 %s；点击目标槽位。" % (content.display_name if content != null else String(skill_id)),
		&"info"
	)
	_refresh_loadout()


func _on_slot_input(event: InputEvent, slot_id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _selected_skill_id.is_empty():
			try_preview_assignment(_selected_skill_id, slot_id)
			_selected_skill_id = &""
		else:
			_selected_skill_id = _working_loadout.get_skill_id(slot_id)
			_status.text = "已选择槽位 %s；“清空所选槽”可移除。" % String(slot_id)


func _skill_drag_data(_position: Vector2, skill_id: StringName) -> Variant:
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
	var skill_id := _working_loadout.get_skill_id(slot_id)
	if skill_id.is_empty():
		return null
	return {"skill_id": skill_id}


func _slot_can_drop(_position: Vector2, data: Variant, _slot_id: StringName) -> bool:
	return data is Dictionary and data.has("skill_id")


func _slot_drop(_position: Vector2, data: Variant, slot_id: StringName) -> void:
	try_preview_assignment(StringName(data.get("skill_id", &"")), slot_id)


func _clear_selected_slot() -> void:
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
	try_preview_assignment(&"", found_slot)
	_selected_skill_id = &""


func _confirm_shop() -> void:
	if _shop_draft == null or _host == null:
		return
	var result := _host.run_session.confirm_shop(_shop_draft)
	if not result.accepted:
		_publish_detail(_detail_text(result.detail), &"error")
		return
	_publish_detail("配装与属性已提交。", &"success")
	hide_overlay()


func _claim_reward(option_id: StringName) -> void:
	if _host == null or _reward_offer == null:
		return
	var result := _host.run_session.claim_reward(_reward_offer.offer_id, option_id)
	if not result.accepted:
		_publish_detail(_detail_text(result.detail), &"error")
		return
	_snapshot = result.run_snapshot
	_show_route_options()


func _show_route_options() -> void:
	_clear_children(_reward_area)
	_reward_area.add_child(_label("奖励已领取 · 选择下一步", 19, UI.SUCCESS))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	_reward_area.add_child(row)
	for option: RouteOption in _snapshot.route.next_options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 72)
		button.text = _route_option_text(option)
		button.pressed.connect(_choose_route.bind(option.option_id))
		row.add_child(button)


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
	if visible and _loadout_area.visible and _shop_draft == null:
		_working_loadout = snapshot.loadout
		_refresh_loadout()


func _refresh_warning() -> void:
	var active_count := 0
	for slot_id: StringName in SkillSlotIds.active():
		var skill := _host.runtime_loadout.get_skill(_working_loadout.get_skill_id(slot_id))
		if skill != null and skill.is_active_skill():
			active_count += 1
	_warning.visible = active_count == 0
	_warning.text = (
		"无可按键技能 · 战斗将依赖普通攻击与被动（合法配置，可继续确认）"
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


func _publish_detail(message: String, tone: StringName) -> void:
	_status.text = message
	_status.add_theme_color_override(&"font_color", _tone_color(tone))
	status_requested.emit(message, tone)


func _detail_text(detail: StringName) -> String:
	match detail:
		&"active_skill_in_passive_slot":
			return "拒绝：主动技能不能放入 PASSIVE 1；请改放 ACTIVE 1–3。"
		&"duplicate_equipped_skill":
			return "拒绝：同一技能只能装备一次。"
		&"loadout_contains_unowned_skill":
			return "拒绝：只能装备本局已拥有的技能。"
		&"stale_loadout_revision", &"run_changed_since_draft_opened":
			return "草稿已过期；请重新打开商店。"
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
	visible = true
	move_to_front()
