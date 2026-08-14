class_name RunFlowSmokePanel
extends CanvasLayer

var _coordinator: RunFlowCoordinator
var _host: RunSessionHost
var _player: PlayerCharacter
var _snapshot: RunSnapshot
var _status_detail: String = ""

@onready var title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var state_label: Label = $Root/Panel/Margin/VBox/State
@onready var economy_label: Label = $Root/Panel/Margin/VBox/Economy
@onready var loadout_label: Label = $Root/Panel/Margin/VBox/Loadout
@onready var hint_label: Label = $Root/Panel/Margin/VBox/Hint
@onready var route_buttons: HBoxContainer = $Root/Panel/Margin/VBox/RouteButtons
@onready var route_a: Button = $Root/Panel/Margin/VBox/RouteButtons/RouteA
@onready var route_b: Button = $Root/Panel/Margin/VBox/RouteButtons/RouteB
@onready var shop_buttons: HBoxContainer = $Root/Panel/Margin/VBox/ShopButtons
@onready var purchase_button: Button = $Root/Panel/Margin/VBox/ShopButtons/Purchase
@onready var leave_button: Button = $Root/Panel/Margin/VBox/ShopButtons/Leave
@onready var result_buttons: HBoxContainer = $Root/Panel/Margin/VBox/ResultButtons
@onready var new_run_button: Button = $Root/Panel/Margin/VBox/ResultButtons/NewRun


func _ready() -> void:
	route_a.pressed.connect(_choose_route.bind(0))
	route_b.pressed.connect(_choose_route.bind(1))
	purchase_button.pressed.connect(_purchase_first)
	leave_button.pressed.connect(_leave_shop)
	new_run_button.pressed.connect(_new_run)
	route_buttons.visible = false
	shop_buttons.visible = false
	result_buttons.visible = false


func configure(
		coordinator: RunFlowCoordinator,
		host: RunSessionHost,
		player: PlayerCharacter
) -> void:
	_coordinator = coordinator
	_host = host
	_player = player
	if _host != null:
		_host.session_ready.connect(_on_snapshot.bind(&"session_ready"))
		_host.session_snapshot_changed.connect(_on_snapshot)
		_host.integration_error.connect(_on_error)
	if _coordinator != null:
		_coordinator.room_activated.connect(_on_room_activated)
		_coordinator.flow_error.connect(_on_error)
	if _host != null and _host.run_session != null:
		_on_snapshot(_host.run_session.snapshot(), &"configured")


func _process(_delta: float) -> void:
	if _snapshot != null and _player != null and is_instance_valid(_player):
		_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or _snapshot == null:
		return
	if _snapshot.route.phase == RunPhase.ROUTE_CHOICE:
		if event.keycode == KEY_1 or event.physical_keycode == KEY_1:
			_choose_route(0)
		elif event.keycode == KEY_2 or event.physical_keycode == KEY_2:
			_choose_route(1)
	elif _snapshot.route.phase == RunPhase.SHOP:
		if event.keycode == KEY_P or event.physical_keycode == KEY_P:
			_purchase_first()
		elif event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER:
			_leave_shop()


func _on_snapshot(snapshot: RunSnapshot, cause: StringName = &"") -> void:
	_snapshot = snapshot
	_status_detail = String(cause)
	_refresh_labels()


func _on_room_activated(
		room_id: StringName,
		scene_path: String,
		_room_instance_id: int
) -> void:
	_status_detail = "已换房：%s · %s" % [String(room_id), scene_path.get_file()]
	_refresh_labels()


func _on_error(detail: StringName) -> void:
	_status_detail = "错误：%s" % String(detail)
	hint_label.add_theme_color_override(&"font_color", Color("ff8f8f"))
	_refresh_labels()


func _refresh_labels() -> void:
	if _snapshot == null:
		return
	var route := _snapshot.route
	var room_name := (
		_snapshot.node.display_name
		if _snapshot.node != null
		else String(route.current_node_id)
	)
	var health_text := ""
	if _player != null and _player.damage_receiver != null:
		health_text = " · HP %d/%d · SP %d/%d" % [
			_player.damage_receiver.current_health,
			_player.damage_receiver.maximum_health,
			_player.energy_component.current_energy,
			_player.energy_component.maximum,
		]
	title_label.text = "RUN GAME · 五阶段演示"
	state_label.text = "阶段 %s · 战斗 %d/%d · %s%s" % [
		String(RunPhase.name_of(route.phase)).to_upper(),
		route.completed_combat_rooms,
		RunFlowDefinition.REQUIRED_COMBAT_ROOMS,
		room_name,
		health_text,
	]
	economy_label.text = "梦尘 %d · 商店 %d/%d · 路线 %d/%d · Rev %d" % [
		_snapshot.economy.balance,
		route.shop_visits,
		RunFlowDefinition.REQUIRED_SHOPS,
		route.route_choices,
		RunFlowDefinition.REQUIRED_ROUTES,
		_snapshot.revision,
	]
	loadout_label.text = "七槽 %s" % _loadout_text(_snapshot.loadout)
	hint_label.text = _phase_hint(route.phase)
	if not _status_detail.is_empty():
		hint_label.text += "\n" + _status_detail
	route_buttons.visible = route.phase == RunPhase.ROUTE_CHOICE
	shop_buttons.visible = route.phase == RunPhase.SHOP
	result_buttons.visible = (
		route.phase == RunPhase.RUN_COMPLETE
		or route.phase == RunPhase.RUN_FAILED
	)
	_update_route_buttons(route.next_options)
	if _snapshot.result != null:
		state_label.text = "结算 %s · 五阶段战斗 %d/%d · 余额 %d" % [
			"通关" if _snapshot.result.is_complete() else "失败",
			_snapshot.result.completed_combat_rooms,
			_snapshot.result.total_combat_rooms,
			_snapshot.result.economy.balance,
		]


func _update_route_buttons(options: Array[RouteOption]) -> void:
	var buttons: Array[Button] = [route_a, route_b]
	for index: int in buttons.size():
		var button := buttons[index]
		if index >= options.size():
			button.visible = false
			button.set_meta(&"option_id", StringName())
			continue
		var option := options[index]
		button.visible = true
		button.set_meta(&"option_id", option.option_id)
		button.text = "%d · %s\n%s / %s / %s\n%s" % [
			index + 1,
			option.title,
			option.encounter_label,
			option.environment_label,
			option.risk_label,
			option.expected_dream_dust_label,
		]


func _choose_route(index: int) -> void:
	var button := route_a if index == 0 else route_b
	var option_id: StringName = button.get_meta(&"option_id", StringName())
	if option_id.is_empty() or _coordinator == null:
		return
	var result := _coordinator.choose_route(option_id)
	_status_detail = "路线已确认" if result.accepted else "路线拒绝：%s" % String(result.detail)


func _purchase_first() -> void:
	if _coordinator == null:
		return
	var result := _coordinator.purchase_first_affordable_skill()
	_status_detail = "购买成功" if result.accepted else "购买拒绝：%s" % String(result.detail)
	if result.run_snapshot != null:
		_on_snapshot(result.run_snapshot, &"shop_purchase")


func _leave_shop() -> void:
	if _coordinator == null:
		return
	var result := _coordinator.leave_shop()
	_status_detail = "离开商店" if result.accepted else "离店拒绝：%s" % String(result.detail)


func _new_run() -> void:
	if _coordinator != null:
		_coordinator.request_new_run()


func _phase_hint(phase: int) -> String:
	match phase:
		RunPhase.COMBAT:
			return "A/D移动 · SPACE跳跃 · J普攻 · 1/2/3主动 · E切元素"
		RunPhase.SHOP:
			return "P购买首个可负担技能 · ENTER离开商店"
		RunPhase.ROUTE_CHOICE:
			return "按 1/2 或点击路线；选择将加载真实目标房"
		RunPhase.RUN_COMPLETE:
			return "Boss 零梦尘并已在同一事务直达结算"
		RunPhase.RUN_FAILED:
			return "本局已失败；权威结果已冻结"
		_:
			return "正在验证并加载下一张 PackedScene"


func _loadout_text(snapshot: RuntimeLoadoutSnapshot) -> String:
	if snapshot == null:
		return "未配置"
	var parts: Array[String] = []
	for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
		parts.append("%s=%s" % [
			String(entry.slot_id).replace("active_", "A").replace("passive_", "P"),
			String(entry.skill_id) if not entry.skill_id.is_empty() else "—",
		])
	return "  ".join(parts)
