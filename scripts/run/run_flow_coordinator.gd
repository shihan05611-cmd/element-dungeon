class_name RunFlowCoordinator
extends Node2D

const SHOP_ROOM_SCENE: PackedScene = preload("res://scenes/run/rooms/room_shop_formal.tscn")

signal room_activated(
	room_id: StringName,
	scene_path: String,
	room_instance_id: int
)
signal flow_error(detail: StringName)
signal ui_command_result(command: StringName, result: RunCommandResult)
signal combat_loadout_availability_changed(available: bool)
signal shop_ui_visibility_changed(visible: bool)

@export var flow_definition: RunFlowDefinition
@export var content_catalog: RunContentCatalog
@export var run_id_override: StringName = &""

var active_room: RunRoomInstance:
	get:
		return _active_room

var active_shop_room: RunShopRoomInstance:
	get:
		return _active_shop_room

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
@onready var combat_hud: CombatHUD = $CombatHUD
# Read-only compatibility alias retained for the accepted Task29 persistence
# runner. The formal scene no longer instantiates or depends on the smoke UI.
@onready var smoke_panel: CombatHUD = $CombatHUD
@onready var room_staging: Node2D = $RoomStaging
@onready var room_container: Node2D = $RoomContainer

var _active_room: RunRoomInstance
var _active_shop_room: RunShopRoomInstance
var _staged_room: RunRoomInstance
var _activated_scene_paths: Array[String] = []
var _activated_room_instance_ids: Array[int] = []
var _command_sequence: int = 0
var _transition_scheduled: bool = false
var _transition_in_progress: bool = false
var _last_error: StringName = &""
var _interaction_busy: bool = false
var _shop_ui_visible: bool = false


func _ready() -> void:
	player.interact_requested.connect(_on_interact_requested)
	call_deferred("_bootstrap_run")


func current_snapshot() -> RunSnapshot:
	return host.run_session.snapshot() if host != null and host.run_session != null else null


func choose_route(option_id: StringName, expected_revision: int = -1) -> RunCommandResult:
	if host.run_session == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"run_session_not_ready"
		)
	var snapshot := host.run_session.snapshot()
	var result := host.run_session.choose_formal_route(
		_next_command_id(&"route"),
		snapshot.revision if expected_revision < 0 else expected_revision,
		option_id
	)
	ui_command_result.emit(&"choose_route", result)
	return result


func purchase_shop_skill(
	offer_id: StringName,
	expected_revision: int = -1,
	shop_session_id: StringName = &""
) -> RunCommandResult:
	var snapshot := current_snapshot()
	if snapshot == null or snapshot.shop == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_session_missing")
	var result := host.run_session.purchase_skill(
		_next_command_id(&"purchase"),
		snapshot.revision if expected_revision < 0 else expected_revision,
		snapshot.shop.session_id if shop_session_id.is_empty() else shop_session_id,
		offer_id
	)
	ui_command_result.emit(&"purchase_skill", result)
	return result


func upgrade_shop_skill(
	skill_id: StringName,
	expected_revision: int = -1,
	shop_session_id: StringName = &""
) -> RunCommandResult:
	var snapshot := current_snapshot()
	if snapshot == null or snapshot.shop == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_session_missing")
	var result := host.run_session.upgrade_active_skill(
		_next_command_id(&"upgrade"),
		snapshot.revision if expected_revision < 0 else expected_revision,
		snapshot.shop.session_id if shop_session_id.is_empty() else shop_session_id,
		skill_id
	)
	ui_command_result.emit(&"upgrade_skill", result)
	return result


func reset_shop_skill(
	skill_id: StringName,
	expected_revision: int = -1,
	shop_session_id: StringName = &""
) -> RunCommandResult:
	var snapshot := current_snapshot()
	if snapshot == null or snapshot.shop == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_session_missing")
	var result := host.run_session.reset_active_skill_upgrades(
		_next_command_id(&"reset"),
		snapshot.revision if expected_revision < 0 else expected_revision,
		snapshot.shop.session_id if shop_session_id.is_empty() else shop_session_id,
		skill_id
	)
	ui_command_result.emit(&"reset_skill", result)
	return result


func apply_shop_loadout(
	draft: ShopDraft,
	candidate: RuntimeLoadoutSnapshot
) -> RunCommandResult:
	if host.run_session == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"run_session_not_ready")
	var result := host.run_session.apply_shop_loadout_immediately(draft, candidate)
	ui_command_result.emit(&"apply_shop_loadout", result)
	return result


func combat_loadout_available() -> bool:
	return (
		_active_room != null
		and is_instance_valid(_active_room)
		and host != null
		and host.formal_combat_loadout_available(
			_active_room.room_id,
			_active_room.get_instance_id(),
			_active_room.room_is_cleared
		)
	)


func apply_combat_loadout(
		candidate: RuntimeLoadoutSnapshot,
		expected_revision: int = -1
) -> RunCommandResult:
	var snapshot := current_snapshot()
	if snapshot == null or _active_room == null or not is_instance_valid(_active_room):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"active_combat_room_missing"
		)
	var result := host.apply_formal_combat_loadout(
		snapshot.revision if expected_revision < 0 else expected_revision,
		candidate,
		_active_room.room_id,
		_active_room.get_instance_id(),
		_active_room.room_is_cleared
	)
	ui_command_result.emit(&"apply_combat_loadout", result)
	return result


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
			return purchase_shop_skill(offer.offer_id, snapshot.revision, snapshot.shop.session_id)
	return RunCommandResult.rejected(
		RunCommandResult.RejectReason.INSUFFICIENT_DREAM_DUST,
		&"no_affordable_shop_offer",
		snapshot
	)


func leave_shop(
	expected_revision: int = -1,
	shop_session_id: StringName = &""
) -> RunCommandResult:
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
	var result := host.run_session.leave_formal_shop(
		_next_command_id(&"leave_shop"),
		snapshot.revision if expected_revision < 0 else expected_revision,
		snapshot.shop.session_id if shop_session_id.is_empty() else shop_session_id
	)
	ui_command_result.emit(&"leave_shop", result)
	return result


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
	var run_id := (
		run_id_override
		if not run_id_override.is_empty()
		else StringName("formal_run_%d_%d" % [get_instance_id(), Time.get_ticks_usec()])
	)
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
	combat_hud.configure(player, _staged_room.enemies[0], feedback, host, self)
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
	var cleared_callback := Callable(self, "_on_active_room_cleared")
	if not _active_room.room_cleared.is_connected(cleared_callback):
		_active_room.room_cleared.connect(cleared_callback)
	combat_loadout_availability_changed.emit(false)
	if _active_shop_room != null:
		_active_shop_room.queue_free()
		_active_shop_room = null
	if previous != null and previous != _active_room:
		previous.queue_free()
	player.global_position = _active_room.player_spawn_global_position()
	player.velocity = Vector2.ZERO
	if not vfx.set_enemies(_active_room.enemies):
		_transition_in_progress = false
		return _fail(&"skill_vfx_enemy_rebind_failed")
	_bind_persistent_feedback(_active_room.enemies)
	combat_hud.rebind_target(_active_room.enemies[0])
	_activated_scene_paths.append(_active_room.scene_path)
	_activated_room_instance_ids.append(_active_room.get_instance_id())
	_transition_in_progress = false
	room_activated.emit(
		definition.room_id,
		_active_room.scene_path,
		_active_room.get_instance_id()
	)
	return true


func _on_active_room_cleared(cleared_room_id: StringName, room_instance_id: int) -> void:
	if (
		_active_room == null
		or not is_instance_valid(_active_room)
		or cleared_room_id != _active_room.room_id
		or room_instance_id != _active_room.get_instance_id()
	):
		return
	combat_loadout_availability_changed.emit(combat_loadout_available())


func _on_session_snapshot_changed(snapshot: RunSnapshot, _cause: StringName) -> void:
	if snapshot == null or _transition_in_progress:
		return
	if snapshot.route.phase == RunPhase.ROOM_LOADING and not _transition_scheduled:
		_transition_scheduled = true
		call_deferred("_load_pending_room")
	elif snapshot.route.phase == RunPhase.SHOP and _active_shop_room == null:
		# Keep the formal Overlay closed inside this authority signal stack;
		# the deferred room swap must not expose a merchant frame.
		_set_shop_ui_visible(false)
		call_deferred("_enter_shop_room")


func _enter_shop_room() -> void:
	if _active_shop_room != null or host.run_session == null:
		return
	var snapshot := current_snapshot()
	if snapshot == null or snapshot.route.phase != RunPhase.SHOP:
		return
	var shop := SHOP_ROOM_SCENE.instantiate() as RunShopRoomInstance
	if shop == null:
		_fail(&"shop_room_protocol_mismatch")
		return
	shop.deactivate()
	room_container.add_child(shop)
	shop.activate()
	if _active_room != null:
		_active_room.queue_free()
		_active_room = null
	combat_loadout_availability_changed.emit(false)
	_active_shop_room = shop
	_clear_transient_deliveries()
	vfx.clear_presentations()
	player.global_position = shop.player_spawn_global_position()
	player.velocity = Vector2.ZERO
	_set_shop_ui_visible(false)


func _on_interact_requested() -> void:
	if _interaction_busy or host.run_session == null:
		return
	_interaction_busy = true
	if _active_shop_room != null:
		var shop_target := _active_shop_room.interaction_target_at(player.global_position)
		if shop_target != null:
			if shop_target.kind == RunWorldInteractable.Kind.SHOP_CROWN:
				_open_shop_ui_from_crown()
			elif shop_target.kind == RunWorldInteractable.Kind.SHOP_EXIT:
				var shop_result := leave_shop()
				if shop_result.accepted:
					shop_target.mark_consumed("正在传送")
		_interaction_busy = false
		return
	if _active_room == null or not _active_room.room_is_cleared:
		_interaction_busy = false
		return
	var target := _active_room.interaction_target_at(player.global_position)
	if target == null:
		_interaction_busy = false
		return
	var snapshot := current_snapshot()
	if target.kind == RunWorldInteractable.Kind.CHEST:
		if _active_room.room_definition.final_boss:
			var completion := host.complete_formal_room(_active_room.room_id, _active_room.get_instance_id())
			if completion.accepted:
				_active_room.open_settlement_chest()
		else:
			var claim := host.claim_formal_room_chest(
				_next_command_id(&"chest"), snapshot.revision, _active_room.room_id, _active_room.get_instance_id()
			)
			if claim.accepted and claim.chest_reward != null:
				var copy := "+150 梦尘"
				if claim.chest_reward.kind == RunChestRewardSnapshot.Kind.SKILL:
					var content := content_catalog.content_for(claim.chest_reward.skill_id)
					copy = "获得技能 · %s" % (content.display_name if content != null else String(claim.chest_reward.skill_id))
				_active_room.apply_chest_reward(copy)
	elif target.kind == RunWorldInteractable.Kind.PORTAL:
		var completion := host.complete_formal_room(_active_room.room_id, _active_room.get_instance_id())
		if completion.accepted:
			target.mark_consumed("正在传送")
	_interaction_busy = false


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
		if enemy is BossTideEmber:
			var summon_callback := Callable(self, "_on_boss_summon_created")
			if not (enemy as BossTideEmber).summon_created.is_connected(summon_callback):
				(enemy as BossTideEmber).summon_created.connect(summon_callback)


func _on_boss_summon_created(summon: CombatEnemy) -> void:
	if summon == null or not is_instance_valid(summon) or summon.is_queued_for_deletion():
		return
	var summons: Array[CombatEnemy] = [summon]
	_bind_persistent_feedback(summons)
	if not vfx.add_enemy(summon):
		_fail(&"skill_vfx_summon_bind_failed")


func _on_delivery_created(delivery: Node) -> void:
	feedback.observe_delivery(delivery)


func _clear_transient_deliveries() -> void:
	for child: Node in get_children():
		if child is DeliveryBase:
			child.queue_free()


func _set_shop_ui_visible(value: bool) -> void:
	var changed := _shop_ui_visible != value
	_shop_ui_visible = value
	if combat_hud != null and combat_hud.run_overlay != null:
		combat_hud.run_overlay.visible = value
		if value:
			combat_hud.run_overlay.move_to_front()
	if changed:
		shop_ui_visibility_changed.emit(value)


func _open_shop_ui_from_crown() -> bool:
	if combat_hud == null or combat_hud.run_overlay == null:
		return false
	var overlay := combat_hud.run_overlay as RunOverlayInterface
	var was_shop_visible := overlay.visible and overlay.formal_kind() == &"shop"
	if not overlay.show_formal_shop_from_world_interaction():
		return false
	_shop_ui_visible = true
	overlay.move_to_front()
	if not was_shop_visible:
		shop_ui_visibility_changed.emit(true)
	return true


func _next_command_id(prefix: StringName) -> StringName:
	_command_sequence += 1
	return StringName("%s:%d" % [String(prefix), _command_sequence])


func _fail(detail: StringName) -> bool:
	_last_error = detail if not detail.is_empty() else &"unknown_run_flow_error"
	flow_error.emit(_last_error)
	return false
