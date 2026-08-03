class_name RunSession
extends RefCounted

## Per-run domain facade. It composes focused states/services and never owns a
## Node, scene instance or mutable gameplay Resource.

signal snapshot_changed(current: RunSnapshot, cause: StringName)

var _progression := ProgressionState.new()
var _skill_inventory: SkillInventoryState
var _relic_inventory: RelicInventoryState
var _pending_reward := PendingRewardState.new()
var _director := RunDirector.new()
var _relic_controller: RelicController
var _runtime_loadout_port: RuntimeLoadoutPort
var _skill_catalog: Array[SkillRewardDefinition] = []
var _relic_catalog: Array[RelicDefinition] = []
var _unlocked_form_ids: Array[StringName] = []
var _processed_event_keys: Dictionary = {}
var _processed_kill_keys: Dictionary = {}
var _last_element_change_sequence: int = 0
var _active_shop_draft: ShopDraft
var _run_revision: int = 0


func _init(
		skill_catalog: Array[SkillRewardDefinition] = [],
		relic_catalog: Array[RelicDefinition] = [],
		initial_skill_ids: Array[StringName] = [],
		unlocked_form_ids: Array[StringName] = [],
		runtime_loadout_port: RuntimeLoadoutPort = null,
		effect_port: GrowthEffectPort = null
) -> void:
	_skill_catalog = skill_catalog.duplicate()
	_relic_catalog = relic_catalog.duplicate()
	_skill_inventory = SkillInventoryState.new(initial_skill_ids)
	_relic_inventory = RelicInventoryState.new(_relic_catalog)
	_unlocked_form_ids = unlocked_form_ids.duplicate()
	_runtime_loadout_port = runtime_loadout_port
	_relic_controller = RelicController.new(effect_port)


func snapshot() -> RunSnapshot:
	return RunSnapshot.new(
		_progression.snapshot(),
		_skill_inventory.snapshot(),
		_relic_controller.snapshot(_relic_inventory),
		_current_loadout_snapshot(),
		_director.snapshot(),
		_pending_reward.offer,
		_pending_reward.claimed,
		_unlocked_form_ids,
		_run_revision
	)


func begin_combat_room(room_id: StringName) -> RunCommandResult:
	var result := _director.begin_combat_room(room_id)
	if not result.accepted:
		return result
	return _commit_and_publish(&"combat_room_began")


func handle_event(event: RunEvent) -> RunCommandResult:
	if event == null or not event.is_valid():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_EVENT, &"invalid_run_event")
	var event_key := event.identity_key()
	if _processed_event_keys.has(event_key):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.DUPLICATE_EVENT, &"event_already_processed")
	if event.room_id != _director.snapshot().current_room_id:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_EVENT, &"event_room_mismatch")
	if event is FormChangedEvent:
		var element_event := event as FormChangedEvent
		if element_event.sequence <= _last_element_change_sequence:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.DUPLICATE_EVENT,
				&"element_sequence_already_processed"
			)
	match event.kind:
		RunEvent.Kind.ENEMY_KILLED:
			return _handle_enemy_killed(event as EnemyKilledEvent)
		RunEvent.Kind.ROOM_COMPLETED:
			return _handle_room_completed(event as RoomCompletedEvent)
		RunEvent.Kind.FORM_CHANGED, RunEvent.Kind.COMBAT_COMMITTED:
			if _director.snapshot().phase != RunPhase.COMBAT:
				return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"combat_event_outside_combat")
			var dispatch := _relic_controller.handle_event(event)
			if not dispatch.accepted:
				return RunCommandResult.rejected(
					RunCommandResult.RejectReason.INVALID_EVENT,
					dispatch.detail
				)
			_processed_event_keys[event_key] = true
			if event is FormChangedEvent:
				_last_element_change_sequence = (event as FormChangedEvent).sequence
			return _commit_and_publish(&"relic_event_processed")
		_:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_EVENT, &"unsupported_external_run_event")


func generate_reward(context: RoomRewardContext, seed: int) -> RunCommandResult:
	var route := _director.snapshot()
	if route.phase != RunPhase.REWARD:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"reward_generation_outside_reward_phase")
	if context == null or context.room_id != route.current_room_id:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"reward_room_mismatch")
	if _pending_reward.offer != null and not _pending_reward.claimed:
		if (
			_pending_reward.offer.room_id != context.room_id
			or _pending_reward.offer.reward_type != context.reward_type
		):
			return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"different_reward_already_pending")
		return RunCommandResult.success(snapshot(), _pending_reward.offer)
	var offer := RewardGenerator.generate(snapshot(), context, seed, _skill_catalog, _relic_catalog)
	if not offer.valid:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.CONFIGURATION_ERROR, offer.configuration_error)
	var install := _pending_reward.install(offer)
	if not install.accepted:
		return install
	_run_revision += 1
	var current := snapshot()
	snapshot_changed.emit(current, &"reward_generated")
	return RunCommandResult.success(current, offer)


func claim_reward(offer_id: StringName, option_id: StringName) -> RunCommandResult:
	if _director.snapshot().phase != RunPhase.REWARD:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"reward_claim_outside_reward_phase")
	var claim_validation := _pending_reward.validate_claim(offer_id, option_id)
	if not claim_validation.accepted:
		return claim_validation
	var option := _pending_reward.offer.find_option(option_id)
	var content_validation := _validate_reward_content(option)
	if not content_validation.accepted:
		return content_validation
	var skill_available_after := _has_skill_candidate_after(option)
	var relic_available_after := _has_relic_candidate_after(option)
	var route_validation := _director.validate_reward_claim(skill_available_after, relic_available_after)
	if not route_validation.accepted:
		return route_validation
	if option.reward_type == RewardType.SKILL:
		var skill_add := _skill_inventory.try_add(option.content_id)
		if not skill_add.accepted:
			return skill_add
	else:
		var definition := _relic_inventory.definition_for(option.content_id)
		var register := _relic_controller.register_owned_relic(definition)
		if not register.accepted:
			return register
		var relic_add := _relic_inventory.try_add(option.content_id)
		if not relic_add.accepted:
			return relic_add
	_pending_reward.mark_claimed(option_id)
	var route_commit := _director.commit_reward_claim(skill_available_after, relic_available_after)
	if not route_commit.accepted:
		return route_commit
	if option.reward_type == RewardType.RELIC:
		var acquisition_event := RelicAcquiredEvent.new(
			StringName("relic_acquired:%s:%s" % [String(offer_id), String(option.content_id)]),
			_pending_reward.offer.room_id,
			option.content_id
		)
		_relic_controller.handle_event(acquisition_event)
	_run_revision += 1
	var current := snapshot()
	snapshot_changed.emit(current, &"reward_claimed")
	return RunCommandResult.success(current, _pending_reward.offer, option)


func choose_route(option_id: StringName) -> RunCommandResult:
	var result := _director.choose_route(option_id)
	if not result.accepted:
		return result
	_active_shop_draft = null
	return _commit_and_publish(&"route_chosen")


func open_shop_draft() -> ShopDraftOpenResult:
	if _director.snapshot().phase != RunPhase.SHOP:
		return ShopDraftOpenResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_draft_outside_shop")
	if _active_shop_draft == null or _active_shop_draft.confirmed:
		_active_shop_draft = ShopDraft.new(_run_revision, _progression.snapshot(), _current_loadout_snapshot())
	return ShopDraftOpenResult.success(_active_shop_draft)


func apply_shop_loadout_immediately(
		draft: ShopDraft,
		candidate: RuntimeLoadoutSnapshot
) -> RunCommandResult:
	if _director.snapshot().phase != RunPhase.SHOP:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_loadout_outside_shop")
	if draft == null or draft != _active_shop_draft:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.STALE_DRAFT, &"draft_is_not_active")
	var progression_current := _progression.snapshot()
	var loadout_current := _current_loadout_snapshot()
	var baseline_validation := draft.validate_baseline(
		_run_revision,
		progression_current,
		loadout_current
	)
	if not baseline_validation.accepted:
		return baseline_validation
	if _runtime_loadout_port == null:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.LOADOUT_REJECTED,
			&"runtime_loadout_port_not_configured"
		)
	var ownership_validation := _validate_loadout_ownership(candidate)
	if not ownership_validation.accepted:
		return ownership_validation
	var loadout_validation := _runtime_loadout_port.validate_snapshot(candidate)
	if not loadout_validation.accepted:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.LOADOUT_REJECTED,
			loadout_validation.detail
		)
	# Validation still runs for an identical request, but an already-authoritative
	# mapping must not create another RuntimeLoadout or aggregate notification.
	if loadout_current.same_mapping(candidate):
		return RunCommandResult.success(snapshot())
	var loadout_commit := _runtime_loadout_port.try_replace_snapshot(candidate)
	if not loadout_commit.accepted:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.LOADOUT_REJECTED,
			loadout_commit.detail
		)
	_run_revision += 1
	var loadout_after := _current_loadout_snapshot()
	# Rebase before publishing so every observer sees an active draft aligned to
	# the exact authoritative run/loadout revisions. Pending stats are untouched.
	draft.rebase_after_immediate_loadout(_run_revision, progression_current, loadout_after)
	var current := snapshot()
	snapshot_changed.emit(current, &"shop_loadout_applied")
	return RunCommandResult.success(current)


func confirm_shop(draft: ShopDraft, complete_run: bool = false) -> RunCommandResult:
	if _director.snapshot().phase != RunPhase.SHOP:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_confirm_outside_shop")
	if draft == null or draft != _active_shop_draft:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.STALE_DRAFT, &"draft_is_not_active")
	var progression_before := _progression.snapshot()
	var loadout_before := _current_loadout_snapshot()
	var baseline_validation := draft.validate_baseline(_run_revision, progression_before, loadout_before)
	if not baseline_validation.accepted:
		return baseline_validation
	var allocation := draft.pending_allocation()
	var allocation_validation := _progression.validate_allocation(allocation)
	if not allocation_validation.accepted:
		return allocation_validation
	# The task-25 UI always rebases the draft after an immediate loadout commit,
	# so its final confirmation reaches this compatibility branch unchanged and
	# commits only stats plus the shop exit. Direct draft callers from frozen
	# pre-task25 contracts remain supported without causing a second UI commit.
	var loadout_candidate := draft.preview_loadout()
	var ownership_validation := _validate_loadout_ownership(loadout_candidate)
	if not ownership_validation.accepted:
		return ownership_validation
	var loadout_changed := not loadout_before.same_mapping(loadout_candidate)
	if loadout_changed:
		if _runtime_loadout_port == null:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.LOADOUT_REJECTED, &"runtime_loadout_port_not_configured")
		var loadout_validation := _runtime_loadout_port.validate_snapshot(loadout_candidate)
		if not loadout_validation.accepted:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.LOADOUT_REJECTED, loadout_validation.detail)
	var exit_validation := _director.validate_shop_exit(complete_run)
	if not exit_validation.accepted:
		return exit_validation
	if loadout_changed:
		var loadout_commit := _runtime_loadout_port.try_replace_snapshot(loadout_candidate)
		if not loadout_commit.accepted:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.LOADOUT_REJECTED, loadout_commit.detail)
	var progression_commit := _progression.commit_allocation(allocation)
	if not progression_commit.accepted:
		return progression_commit
	var exit_commit := _director.commit_shop_exit(complete_run)
	if not exit_commit.accepted:
		return exit_commit
	draft.mark_confirmed()
	var progression_after := _progression.snapshot()
	var loadout_after := _current_loadout_snapshot()
	var summary := ShopCommitSummary.new(progression_before, progression_after, loadout_before, loadout_after)
	_run_revision += 1
	var current := snapshot()
	snapshot_changed.emit(current, &"shop_confirmed")
	return RunCommandResult.success(current, null, null, summary)


func advance_relics(delta: float) -> RunCommandResult:
	if not is_finite(delta) or delta < 0.0:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_ARGUMENT, &"invalid_relic_delta")
	if _relic_controller.advance(delta):
		return _commit_and_publish(&"relic_cooldowns_advanced")
	return RunCommandResult.success(snapshot())


func _handle_enemy_killed(event: EnemyKilledEvent) -> RunCommandResult:
	if _director.snapshot().phase != RunPhase.COMBAT:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"kill_outside_combat")
	var kill_key := StringName("%s:%s" % [String(event.room_id), String(event.enemy_id)])
	if _processed_kill_keys.has(kill_key):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.DUPLICATE_EVENT, &"enemy_kill_already_processed")
	var experience_result := _progression.try_add_experience(event.experience_reward)
	if not experience_result.accepted:
		return experience_result
	_relic_controller.handle_event(event)
	_processed_event_keys[event.identity_key()] = true
	_processed_kill_keys[kill_key] = true
	return _commit_and_publish(&"enemy_kill_processed")


func _handle_room_completed(event: RoomCompletedEvent) -> RunCommandResult:
	var room_validation := _director.validate_room_completion(event.room_id)
	if not room_validation.accepted:
		return room_validation
	var experience_plan := ExperienceService.plan_gain(_progression.snapshot(), event.completion_experience)
	if not experience_plan.valid:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.NEGATIVE_EXPERIENCE, experience_plan.error)
	var room_commit := _director.commit_room_completion(event.room_id)
	if not room_commit.accepted:
		return room_commit
	var experience_commit := _progression.try_add_experience(event.completion_experience)
	if not experience_commit.accepted:
		return experience_commit
	_relic_controller.handle_event(event)
	_processed_event_keys[event.identity_key()] = true
	return _commit_and_publish(&"room_completed")


func _validate_reward_content(option: RewardOption) -> RunCommandResult:
	if option == null or not option.is_valid():
		return RunCommandResult.rejected(RunCommandResult.RejectReason.OPTION_NOT_FOUND, &"invalid_reward_option")
	if option.reward_type == RewardType.SKILL:
		if _skill_inventory.owns(option.content_id):
			return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_OWNED, &"skill_already_owned")
		if _skill_definition_for(option.content_id) == null:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.CONFIGURATION_ERROR, &"unknown_skill_reward")
	else:
		if _relic_inventory.owns(option.content_id):
			return RunCommandResult.rejected(RunCommandResult.RejectReason.ALREADY_OWNED, &"relic_already_owned")
		if _relic_inventory.definition_for(option.content_id) == null:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.CONFIGURATION_ERROR, &"unknown_relic_reward")
	return RunCommandResult.success()


func _validate_loadout_ownership(candidate: RuntimeLoadoutSnapshot) -> RunCommandResult:
	if candidate == null:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.LOADOUT_REJECTED, &"missing_loadout_snapshot")
	for entry in candidate.entries:
		if not entry.skill_id.is_empty() and not _skill_inventory.owns(entry.skill_id):
			return RunCommandResult.rejected(RunCommandResult.RejectReason.LOADOUT_REJECTED, &"loadout_contains_unowned_skill")
	return RunCommandResult.success()


func _has_skill_candidate_after(claimed_option: RewardOption) -> bool:
	for definition in _skill_catalog:
		if definition == null or not definition.validation_error().is_empty():
			continue
		if _skill_inventory.owns(definition.skill_id):
			continue
		if claimed_option.reward_type == RewardType.SKILL and definition.skill_id == claimed_option.content_id:
			continue
		if definition.is_available_for(_unlocked_form_ids):
			return true
	return false


func _has_relic_candidate_after(claimed_option: RewardOption) -> bool:
	for definition in _relic_catalog:
		if definition == null or not definition.is_valid() or _relic_inventory.owns(definition.relic_id):
			continue
		if claimed_option.reward_type == RewardType.RELIC and definition.relic_id == claimed_option.content_id:
			continue
		return true
	return false


func _skill_definition_for(skill_id: StringName) -> SkillRewardDefinition:
	for definition in _skill_catalog:
		if definition != null and definition.skill_id == skill_id:
			return definition
	return null


func _current_loadout_snapshot() -> RuntimeLoadoutSnapshot:
	if _runtime_loadout_port == null:
		return RuntimeLoadoutSnapshot.new()
	var current := _runtime_loadout_port.snapshot()
	return current if current != null else RuntimeLoadoutSnapshot.new()


func _commit_and_publish(cause: StringName) -> RunCommandResult:
	_run_revision += 1
	var current := snapshot()
	snapshot_changed.emit(current, cause)
	return RunCommandResult.success(current)
