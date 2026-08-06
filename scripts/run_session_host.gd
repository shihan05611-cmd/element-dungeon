class_name RunSessionHost
extends Node

signal session_ready(snapshot: RunSnapshot)
signal session_snapshot_changed(snapshot: RunSnapshot, cause: StringName)
signal reward_ready(offer: RewardOffer)
signal integration_error(detail: StringName)
signal run_event_projected(event: RunEvent, result: RunCommandResult)

@export var room_id: StringName = &"room_1"
@export_range(0, 1000000, 1, "or_greater") var room_completion_experience: int = 50
@export var reward_seed: int = 4107

var run_session: RunSession:
	get:
		return _run_session

var runtime_loadout: RuntimeSkillLoadout:
	get:
		return _runtime_loadout

var growth_adapter: PlayerGrowthAdapter:
	get:
		return _growth_adapter

var passive_adapter: PassiveEffectAdapter:
	get:
		return _passive_adapter

var content_catalog: RunContentCatalog:
	get:
		return _content_catalog

var active_room_instance_id: int:
	get:
		return _room_instance_id


var persistence_adapter: SharedLoadoutPersistenceAdapter:
	get:
		return _loadout_persistence

var saved_shared_loadout: RuntimeLoadoutSnapshot:
	get:
		return _loadout_persistence.saved_snapshot if _loadout_persistence != null else null

var last_error: StringName:
	get:
		return _last_error


var _player: PlayerCharacter
var _enemies: Array[CombatEnemy] = []
var _content_catalog: RunContentCatalog
var _run_session: RunSession
var _runtime_loadout: RuntimeSkillLoadout
var _growth_adapter: PlayerGrowthAdapter
var _passive_adapter: PassiveEffectAdapter
var _loadout_persistence: SharedLoadoutPersistenceAdapter
var _player_damage_taken: int = 0
var _configured: bool = false
var _last_error: StringName = &""
var _formal_flow: RunFlowDefinition
var _room_definition: CombatRoomDefinition
var _room_instance_id: int = 0


func configure(
		player: PlayerCharacter,
		enemies: Array[CombatEnemy],
		content_catalog_value: RunContentCatalog,
		restored_shared_snapshot: RuntimeLoadoutSnapshot = null,
		legacy_loadouts: Array[SkillLoadout] = [],
		flow_definition: RunFlowDefinition = null,
		initial_room_definition: CombatRoomDefinition = null,
		initial_room_instance_id: int = 0,
		run_id: StringName = &""
) -> bool:
	if _configured:
		return _fail(&"run_session_host_already_configured")
	if player == null or room_id.is_empty() or enemies.is_empty():
		return _fail(&"invalid_run_session_host_dependencies")
	var enemy_error := _enemy_configuration_error(enemies)
	if not enemy_error.is_empty():
		return _fail(enemy_error)
	if content_catalog_value == null:
		return _fail(&"missing_run_content_catalog")
	var catalog_error := content_catalog_value.validation_error()
	if not catalog_error.is_empty():
		return _fail(catalog_error)
	_player = player
	_enemies = enemies.duplicate()
	_content_catalog = content_catalog_value
	_formal_flow = flow_definition
	_room_definition = initial_room_definition
	_room_instance_id = initial_room_instance_id
	if _formal_flow != null:
		if (
			not _formal_flow.is_valid()
			or _room_definition == null
			or not _room_definition.validation_error().is_empty()
			or _room_definition.room_id != room_id
			or _room_instance_id <= 0
			or run_id.is_empty()
		):
			return _fail(&"invalid_formal_run_host_configuration")

	_growth_adapter = PlayerGrowthAdapter.new()
	if not _growth_adapter.configure(_player):
		return _fail(&"player_growth_adapter_configuration_failed")
	_passive_adapter = PassiveEffectAdapter.new(_growth_adapter)
	if not _passive_adapter.configure_runtime_ports(_player, _enemies):
		return _fail(&"passive_runtime_ports_configuration_failed")

	var template := _player.skill_controller.shared_loadout
	if template == null or not template.is_shared():
		return _fail(&"missing_shared_loadout_template")
	_loadout_persistence = SharedLoadoutPersistenceAdapter.new()
	var snapshot_to_restore := restored_shared_snapshot
	if snapshot_to_restore == null and legacy_loadouts.is_empty():
		snapshot_to_restore = _content_catalog.default_loadout_snapshot()
	if not _loadout_persistence.restore(
		snapshot_to_restore,
		_player.current_element_controller.current_element_id,
		_player.current_element_controller.ordered_available_elements,
		legacy_loadouts
	):
		return _fail(&"shared_loadout_restore_or_migration_failed")
	if _loadout_persistence.migrated_legacy:
		var normalized_migration := _without_nonequippable_content(
			_loadout_persistence.saved_snapshot
		)
		if normalized_migration == null or not _loadout_persistence.save_shared(normalized_migration):
			return _fail(&"legacy_shared_loadout_normalization_failed")
	_runtime_loadout = RuntimeSkillLoadout.new(
		_content_catalog.equippable_gameplay_definitions(),
		_loadout_persistence.saved_snapshot,
		_passive_adapter
	)
	if not _runtime_loadout.configuration_error.is_empty():
		return _fail(_runtime_loadout.configuration_error)
	_runtime_loadout.loadout_replaced.connect(_on_runtime_loadout_replaced)
	if not _player.configure_run_runtime(_runtime_loadout, _content_catalog, room_id):
		return _fail(&"player_runtime_configuration_failed")
	var basic_attack_callback := Callable(_passive_adapter, "on_basic_attack_committed")
	if not _player.basic_attack_committed.is_connected(basic_attack_callback):
		_player.basic_attack_committed.connect(basic_attack_callback)

	var owned_skill_ids := _merge_owned_with_equipped(_content_catalog.initial_owned_skill_ids())
	_run_session = RunSession.new(
		_content_catalog.reward_definitions(),
		_content_catalog.relic_definitions,
		owned_skill_ids,
		_player.current_element_controller.ordered_available_elements,
		_runtime_loadout,
		_growth_adapter,
		RunRulesSnapshot.formal_disabled() if _formal_flow != null else null,
		_content_catalog if _formal_flow != null else null,
		0,
		_formal_flow,
		run_id
	)
	_run_session.snapshot_changed.connect(_on_session_snapshot_changed)
	if _formal_flow == null:
		var begin_result := _run_session.begin_combat_room(room_id)
		if not begin_result.accepted:
			return _fail(begin_result.detail)
	elif not _player.configure_run_skill_level_effects(_run_session):
		return _fail(&"formal_skill_level_effect_configuration_failed")

	var element_callback := Callable(self, "_on_element_changed")
	if not _player.current_element_controller.element_changed.is_connected(element_callback):
		_player.current_element_controller.element_changed.connect(element_callback)
	var defeated_callback := Callable(self, "_on_player_defeated")
	if _formal_flow != null and not _player.player_defeated.is_connected(defeated_callback):
		_player.player_defeated.connect(defeated_callback)
	_bind_combat_events()
	_configured = true
	_growth_adapter.apply_progression(_run_session.snapshot().progression)
	session_ready.emit(_run_session.snapshot())
	return true


func activate_formal_room(
		definition: CombatRoomDefinition,
		enemies: Array[CombatEnemy],
		room_instance_id: int,
		scene_path: String,
		transition_id: StringName,
		expected_run_revision: int
) -> RunCommandResult:
	if not _configured or _formal_flow == null or definition == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"formal_host_not_configured"
		)
	if not definition.validation_error().is_empty() or enemies.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			&"invalid_formal_room_configuration"
		)
	var enemy_error := _enemy_configuration_error(enemies)
	if not enemy_error.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			enemy_error
		)
	var accepted := _run_session.accept_room_transition(
		transition_id,
		expected_run_revision,
		definition.room_id,
		room_instance_id,
		scene_path
	)
	if not accepted.accepted:
		return accepted
	var first_activation := _room_instance_id == room_instance_id
	room_id = definition.room_id
	_room_definition = definition
	_room_instance_id = room_instance_id
	_enemies = enemies.duplicate()
	_passive_adapter.set_enemies(_enemies)
	_player_damage_taken = 0
	if not first_activation:
		_player.prepare_floor_transition()
	var room_sync_succeeded := _player.current_element_controller.set_event_room_id(room_id)
	assert(room_sync_succeeded, "validated formal room ID must synchronize")
	if not room_sync_succeeded:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.SCENE_TRANSITION_FAILED,
			&"current_element_room_sync_failed"
		)
	_bind_combat_events()
	return accepted


func fail_scene_transition(detail: StringName) -> RunCommandResult:
	if not _configured or _formal_flow == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"formal_host_not_configured"
		)
	return _run_session.fail_formal_run(
		StringName("scene_failure:%d:%s" % [_run_session.snapshot().revision, String(detail)]),
		_run_session.snapshot().revision,
		detail if not detail.is_empty() else &"scene_transition_failed"
	)


func begin_next_room(next_room_id: StringName, enemies: Array[CombatEnemy]) -> RunCommandResult:
	if not _configured or next_room_id.is_empty() or enemies.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"invalid_next_room_configuration"
		)
	var enemy_error := _enemy_configuration_error(enemies)
	if not enemy_error.is_empty():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, enemy_error)
	var begin_result := _run_session.begin_combat_room(next_room_id)
	if not begin_result.accepted:
		return begin_result
	room_id = next_room_id
	_enemies = enemies.duplicate()
	_passive_adapter.set_enemies(_enemies)
	_player_damage_taken = 0
	_player.skill_controller.on_floor_changed()
	var room_sync_succeeded := _player.current_element_controller.set_event_room_id(room_id)
	assert(room_sync_succeeded, "validated room ID must synchronize to CurrentElementController")
	if not room_sync_succeeded:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"current_element_room_sync_failed"
		)
	_bind_combat_events()
	return begin_result


func on_run_reloaded() -> void:
	if not _configured:
		return
	_player.skill_controller.on_run_reloaded()
	_growth_adapter.clear_temporary_modifiers()


func _process(delta: float) -> void:
	if not _configured:
		return
	_growth_adapter.advance(delta)
	_passive_adapter.advance(delta)
	_run_session.advance_relics(delta)


func _bind_combat_events() -> void:
	var player_hit_callback := Callable(self, "_on_combat_result").bind(&"player", true)
	if not _player.combat_receiver.hit_resolved.is_connected(player_hit_callback):
		_player.combat_receiver.hit_resolved.connect(player_hit_callback)
	for enemy: CombatEnemy in _enemies:
		if enemy == null:
			continue
		var enemy_id := _enemy_event_id(enemy)
		var hit_callback := Callable(self, "_on_combat_result").bind(
			enemy_id,
			false,
			enemy.combat_receiver
		)
		if not enemy.combat_receiver.hit_resolved.is_connected(hit_callback):
			enemy.combat_receiver.hit_resolved.connect(hit_callback)
		var defeated_callback := Callable(self, "_on_enemy_defeated").bind(enemy)
		if not enemy.enemy_defeated.is_connected(defeated_callback):
			enemy.enemy_defeated.connect(defeated_callback)


func _on_combat_result(
		result: CombatResult,
		target_id: StringName,
		target_is_player: bool,
		target_receiver: CombatReceiver = null
) -> void:
	if not _configured or result == null or not result.accepted:
		return
	if target_is_player:
		_player_damage_taken += maxi(0, -result.health_delta)
	elif target_receiver != null and result.root_owner_id == _player.get_instance_id():
		var carrier := target_receiver.get_element_carrier()
		if carrier != null:
			_player.publish_basic_attack_commit(result, target_id, carrier.snapshot())
	var event := CombatCommittedEvent.new(
		StringName("combat:%d:%d:%d:%s" % [
			result.cast_id,
			result.delivery_id,
			result.hit_index,
			String(target_id),
		]),
		room_id,
		result.cast_id,
		result.delivery_id,
		result.hit_index,
		target_id,
		result.skill_id,
		result.source_element_id,
		result.final_damage,
		result.reaction_consumed,
		result.current_health
	)
	_project_event(event)


func _on_enemy_defeated(enemy: CombatEnemy) -> void:
	if not _configured or enemy == null:
		return
	var enemy_id := _enemy_event_id(enemy)
	var event := EnemyKilledEvent.new(
		StringName("enemy_killed:%s:%s" % [String(room_id), String(enemy_id)]),
		room_id,
		enemy_id,
		enemy.experience_reward,
		enemy.dream_dust_reward,
		enemy.terminal_enemy
	)
	var result := _project_event(event)
	if not result.accepted:
		return
	if _all_enemies_defeated():
		_complete_room()


func _complete_room() -> void:
	var completion_dream_dust := (
		_room_definition.completion_dream_dust
		if _formal_flow != null and _room_definition != null
		else 0
	)
	var terminal_room := (
		_room_definition.final_boss
		if _formal_flow != null and _room_definition != null
		else false
	)
	var event := RoomCompletedEvent.new(
		StringName("room_completed:%s:%d" % [String(room_id), _room_instance_id]),
		room_id,
		0 if _formal_flow != null else room_completion_experience,
		_player_damage_taken,
		completion_dream_dust,
		terminal_room
	)
	var result := _project_event(event)
	if not result.accepted:
		return
	if _formal_flow == null:
		_generate_room_reward()


func _generate_room_reward() -> void:
	var snapshot := _run_session.snapshot()
	var reward_type := (
		RewardType.SKILL
		if snapshot.route.completed_combat_rooms == 1
		else snapshot.route.selected_reward_type
	)
	if not RewardType.is_valid(reward_type):
		_fail(&"missing_route_reward_type")
		return
	var generated := _run_session.generate_reward(
		RoomRewardContext.new(room_id, reward_type),
		reward_seed + snapshot.route.completed_combat_rooms
	)
	if not generated.accepted:
		_fail(generated.detail)
		return
	reward_ready.emit(generated.reward_offer)


func _project_event(event: RunEvent) -> RunCommandResult:
	var result := _run_session.handle_event(event)
	run_event_projected.emit(event, result)
	if not result.accepted:
		_fail(result.detail)
	return result


func _on_element_changed(change: ElementChangeResult) -> void:
	if not _configured or change == null or not change.accepted or not change.changed:
		return
	var event := change.event
	if event == null or not event.is_valid():
		_fail(&"invalid_committed_element_event")
		return
	_project_event(event)


func _on_session_snapshot_changed(snapshot: RunSnapshot, cause: StringName) -> void:
	_growth_adapter.apply_progression(snapshot.progression)
	session_snapshot_changed.emit(snapshot, cause)


func _on_player_defeated() -> void:
	if not _configured or _formal_flow == null or _run_session.snapshot().result != null:
		return
	var revision := _run_session.snapshot().revision
	var result := _run_session.fail_formal_run(
		StringName("player_defeated:%s:%d" % [String(room_id), _room_instance_id]),
		revision,
		&"player_defeated"
	)
	if not result.accepted:
		_fail(result.detail)


func _on_runtime_loadout_replaced(
		_previous: RuntimeLoadoutSnapshot,
		current: RuntimeLoadoutSnapshot
) -> void:
	if _loadout_persistence == null or not _loadout_persistence.save_shared(current):
		_fail(&"shared_loadout_persistence_failed")


func _all_enemies_defeated() -> bool:
	for enemy: CombatEnemy in _enemies:
		if enemy != null and not enemy.defeated:
			return false
	return true


func _enemy_configuration_error(enemies: Array[CombatEnemy]) -> StringName:
	var seen: Dictionary[StringName, bool] = {}
	for enemy: CombatEnemy in enemies:
		if enemy == null or enemy.growth_enemy_id.is_empty():
			return &"invalid_growth_enemy_configuration"
		var event_id := _enemy_event_id(enemy)
		if event_id.is_empty() or seen.has(event_id):
			return &"duplicate_growth_enemy_instance"
		seen[event_id] = true
	return &""


func _enemy_event_id(enemy: CombatEnemy) -> StringName:
	if enemy == null or enemy.growth_enemy_id.is_empty():
		return &""
	var identity := String(enemy.get_path())
	if identity.is_empty():
		identity = "instance_%d" % enemy.get_instance_id()
	return StringName("%s@%s" % [String(enemy.growth_enemy_id), identity])


func _merge_owned_with_equipped(initial_ids: Array[StringName]) -> Array[StringName]:
	var result := initial_ids.duplicate()
	for entry: RuntimeLoadoutSlotSnapshot in _runtime_loadout.snapshot().entries:
		if not entry.skill_id.is_empty() and not result.has(entry.skill_id):
			result.append(entry.skill_id)
	for skill_id: StringName in _loadout_persistence.migration_overflow_skill_ids:
		if not result.has(skill_id):
			result.append(skill_id)
	return result


func _without_nonequippable_content(
		snapshot: RuntimeLoadoutSnapshot
) -> RuntimeLoadoutSnapshot:
	if snapshot == null:
		return null
	var entries: Array[RuntimeLoadoutSlotSnapshot] = []
	for entry: RuntimeLoadoutSlotSnapshot in snapshot.entries:
		var skill_id := entry.skill_id
		var content := _content_catalog.content_for(skill_id)
		if content != null and not content.equippable:
			skill_id = &""
		entries.append(RuntimeLoadoutSlotSnapshot.new(entry.slot_id, skill_id))
	return RuntimeLoadoutSnapshot.new(entries, snapshot.revision)


func _fail(detail: StringName) -> bool:
	_last_error = detail
	integration_error.emit(detail)
	return false


func _exit_tree() -> void:
	if _runtime_loadout != null:
		_runtime_loadout.clear_for_run_end()
