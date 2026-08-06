class_name RunFlowCoordinator
extends Node2D

signal room_activated(
	room_id: StringName,
	scene_path: String,
	room_instance_id: int
)
signal flow_error(detail: StringName)

@export var flow_definition: RunFlowDefinition
@export var content_catalog: RunContentCatalog

var active_room: RunRoomInstance:
	get:
		return _active_room

var active_enemies: Array[CombatEnemy]:
	get:
		return _active_room.enemies if _active_room != null else []

var activated_scene_paths: Array[String]:
	get:
		return _activated_scene_paths.duplicate()

var activated_room_instance_ids: Array[int]:
	get:
		return _activated_room_instance_ids.duplicate()

var last_error: StringName:
	get:
		return _last_error

@onready var host: RunSessionHost = $RunSessionHost
@onready var player: PlayerCharacter = $Player
@onready var feedback: CombatFeedback = $CombatFeedback
@onready var vfx: SkillVfxCoordinator = $SkillVfxCoordinator
@onready var smoke_panel: RunFlowSmokePanel = $RunFlowSmokePanel
@onready var room_staging: Node2D = $RoomStaging
@onready var room_container: Node2D = $RoomContainer

var _active_room: RunRoomInstance
var _staged_room: RunRoomInstance
var _activated_scene_paths: Array[String] = []
var _activated_room_instance_ids: Array[int] = []
var _command_sequence: int = 0
var _transition_scheduled: bool = false
var _transition_in_progress: bool = false
var _last_error: StringName = &""


func _ready() -> void:
	call_deferred("_bootstrap_run")


func choose_route(option_id: StringName) -> RunCommandResult:
	if host.run_session == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"run_session_not_ready"
		)
	var snapshot := host.run_session.snapshot()
	return host.run_session.choose_formal_route(
		_next_command_id(&"route"),
		snapshot.revision,
		option_id
	)


func purchase_first_affordable_skill() -> RunCommandResult:
	if host.run_session == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"run_session_not_ready"
		)
	var snapshot := host.run_session.snapshot()
	if snapshot.route.phase != RunPhase.SHOP or snapshot.shop == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"purchase_outside_shop"
		)
	for offer: ShopOfferSnapshot in snapshot.shop.offers:
		if offer.purchase_price <= snapshot.economy.balance:
			return host.run_session.purchase_skill(
				_next_command_id(&"purchase"),
				snapshot.revision,
				snapshot.shop.session_id,
				offer.offer_id
			)
	return RunCommandResult.rejected(
		RunCommandResult.RejectReason.INSUFFICIENT_DREAM_DUST,
		&"no_affordable_shop_offer",
		snapshot
	)


func leave_shop() -> RunCommandResult:
	if host.run_session == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"run_session_not_ready"
		)
	var snapshot := host.run_session.snapshot()
	if snapshot.shop == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"shop_session_missing"
		)
	return host.run_session.leave_formal_shop(
		_next_command_id(&"leave_shop"),
		snapshot.revision,
		snapshot.shop.session_id
	)


func request_new_run() -> void:
	get_tree().reload_current_scene()


func _bootstrap_run() -> void:
	if flow_definition == null or not flow_definition.is_valid():
		_fail(flow_definition.validation_error() if flow_definition != null else &"missing_run_flow")
		return
	if content_catalog == null or not content_catalog.is_valid():
		_fail(content_catalog.validation_error() if content_catalog != null else &"missing_run_catalog")
		return
	var entry := flow_definition.node_for(flow_definition.entry_node_id)
	var first_node_id := entry.next_node_id if entry != null else StringName()
	if not _stage_room(first_node_id):
		_fail(_last_error)
		return
	var definition := flow_definition.combat_room_for(first_node_id)
	host.room_id = first_node_id
	var run_id := StringName("formal_run_%d_%d" % [get_instance_id(), Time.get_ticks_usec()])
	if not host.configure(
		player,
		_staged_room.enemies,
		content_catalog,
		null,
		[],
		flow_definition,
		definition,
		_staged_room.get_instance_id(),
		run_id
	):
		_fail(host.last_error)
		return
	if not vfx.configure(player, host, _staged_room.enemies):
		_fail(&"skill_vfx_coordinator_configuration_failed")
		return
	_bind_persistent_feedback(_staged_room.enemies)
	smoke_panel.configure(self, host, player)
	host.session_snapshot_changed.connect(_on_session_snapshot_changed)
	host.integration_error.connect(_fail)
	var started := host.run_session.start_formal_run(
		_next_command_id(&"start"),
		host.run_session.snapshot().revision
	)
	if not started.accepted:
		_fail(started.detail)
		return
	if not _activate_staged_room(started.run_snapshot):
		return


func _stage_room(node_id: StringName) -> bool:
	if _transition_in_progress or node_id.is_empty():
		return _fail(&"invalid_or_reentrant_room_transition")
	var definition := flow_definition.combat_room_for(node_id)
	if definition == null or not definition.validation_error().is_empty():
		return _fail(&"pending_room_definition_invalid")
	var candidate := definition.room_scene.instantiate() as RunRoomInstance
	if candidate == null:
		return _fail(&"room_scene_protocol_mismatch")
	candidate.deactivate()
	room_staging.add_child(candidate)
	if not candidate.configure(definition):
		var detail := candidate.configuration_error
		candidate.queue_free()
		return _fail(detail)
	_staged_room = candidate
	return true


func _activate_staged_room(authority_snapshot: RunSnapshot) -> bool:
	if _staged_room == null or authority_snapshot == null:
		return _fail(&"missing_staged_room_or_snapshot")
	_transition_in_progress = true
	var definition := _staged_room.room_definition
	var transition := host.activate_formal_room(
		definition,
		_staged_room.enemies,
		_staged_room.get_instance_id(),
		_staged_room.scene_path,
		_next_command_id(&"activate"),
		authority_snapshot.revision
	)
	if not transition.accepted:
		_transition_in_progress = false
		var failure := host.fail_scene_transition(transition.detail)
		_fail(failure.detail if not failure.accepted else transition.detail)
		return false
	_clear_transient_deliveries()
	vfx.clear_presentations()
	var previous := _active_room
	_staged_room.reparent(room_container)
	_staged_room.activate()
	_active_room = _staged_room
	_staged_room = null
	if previous != null and previous != _active_room:
		previous.queue_free()
	player.global_position = _active_room.player_spawn_global_position()
	player.velocity = Vector2.ZERO
	if not vfx.set_enemies(_active_room.enemies):
		_transition_in_progress = false
		return _fail(&"skill_vfx_enemy_rebind_failed")
	_bind_persistent_feedback(_active_room.enemies)
	_activated_scene_paths.append(_active_room.scene_path)
	_activated_room_instance_ids.append(_active_room.get_instance_id())
	_transition_in_progress = false
	room_activated.emit(
		definition.room_id,
		_active_room.scene_path,
		_active_room.get_instance_id()
	)
	return true


func _on_session_snapshot_changed(snapshot: RunSnapshot, _cause: StringName) -> void:
	if snapshot == null or _transition_in_progress:
		return
	if snapshot.route.phase == RunPhase.ROOM_LOADING and not _transition_scheduled:
		_transition_scheduled = true
		call_deferred("_load_pending_room")


func _load_pending_room() -> void:
	_transition_scheduled = false
	if host.run_session == null or _transition_in_progress:
		return
	var snapshot := host.run_session.snapshot()
	if snapshot.route.phase != RunPhase.ROOM_LOADING:
		return
	if not _stage_room(snapshot.route.pending_node_id):
		host.fail_scene_transition(_last_error)
		return
	_activate_staged_room(snapshot)


func _bind_persistent_feedback(enemies: Array[CombatEnemy]) -> void:
	feedback.observe_receiver(player.combat_receiver)
	var player_delivery_callback := Callable(self, "_on_delivery_created")
	if not player.delivery_created.is_connected(player_delivery_callback):
		player.delivery_created.connect(player_delivery_callback)
	for enemy: CombatEnemy in enemies:
		feedback.observe_receiver(enemy.combat_receiver)
		var enemy_delivery_callback := Callable(self, "_on_delivery_created")
		if not enemy.delivery_created.is_connected(enemy_delivery_callback):
			enemy.delivery_created.connect(enemy_delivery_callback)


func _on_delivery_created(delivery: Node) -> void:
	feedback.observe_delivery(delivery)


func _clear_transient_deliveries() -> void:
	for child: Node in get_children():
		if child is DeliveryBase:
			child.queue_free()


func _next_command_id(prefix: StringName) -> StringName:
	_command_sequence += 1
	return StringName("%s:%d" % [String(prefix), _command_sequence])


func _fail(detail: StringName) -> bool:
	_last_error = detail if not detail.is_empty() else &"unknown_run_flow_error"
	flow_error.emit(_last_error)
	return false
