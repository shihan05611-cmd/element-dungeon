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
var _rules: RunRulesSnapshot
var _economy: RunEconomyState
var _content_catalog: RunContentCatalog
var _shop_snapshot: ShopSnapshot
var _shop_session_sequence: int = 0
var _command_records: Dictionary = {}
var _observed_experience: int = 0
var _observed_relic_events: int = 0


func _init(
		skill_catalog: Array[SkillRewardDefinition] = [],
		relic_catalog: Array[RelicDefinition] = [],
		initial_skill_ids: Array[StringName] = [],
		unlocked_form_ids: Array[StringName] = [],
		runtime_loadout_port: RuntimeLoadoutPort = null,
		effect_port: GrowthEffectPort = null,
		rules: RunRulesSnapshot = null,
		content_catalog: RunContentCatalog = null,
		initial_dream_dust: int = 0
) -> void:
	_skill_catalog = skill_catalog.duplicate()
	_relic_catalog = relic_catalog.duplicate()
	_rules = rules.copy() if rules != null else RunRulesSnapshot.legacy_enabled()
	_content_catalog = content_catalog if content_catalog != null else _catalog_from_reward_metadata()
	var content_definitions: Array[SkillContentDefinition] = []
	if _content_catalog != null:
		content_definitions = _content_catalog.skill_contents.duplicate()
	_skill_inventory = SkillInventoryState.new(initial_skill_ids, content_definitions)
	_economy = RunEconomyState.new(initial_dream_dust)
	_relic_inventory = RelicInventoryState.new(_relic_catalog)
	_unlocked_form_ids = unlocked_form_ids.duplicate()
	_runtime_loadout_port = runtime_loadout_port
	_relic_controller = RelicController.new(effect_port)


func snapshot() -> RunSnapshot:
	return RunSnapshot.new(
		_progression.snapshot(),
		_skill_inventory.snapshot(),
		_current_relic_snapshot(),
		_current_loadout_snapshot(),
		_director.snapshot(),
		_pending_reward.offer,
		_pending_reward.claimed,
		_unlocked_form_ids,
		_run_revision,
		_rules,
		_economy.snapshot(),
		_shop_snapshot,
		_observed_experience,
		_observed_relic_events
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
			if _rules.relic_mode == RunFeatureMode.Value.ENABLED:
				var dispatch := _relic_controller.handle_event(event)
				if not dispatch.accepted:
					return RunCommandResult.rejected(
						RunCommandResult.RejectReason.INVALID_EVENT,
						dispatch.detail
					)
			elif _rules.relic_mode == RunFeatureMode.Value.OBSERVE_ONLY:
				_observed_relic_events += 1
			_processed_event_keys[event_key] = true
			if event is FormChangedEvent:
				_last_element_change_sequence = (event as FormChangedEvent).sequence
			return _commit_and_publish(&"relic_event_processed")
		_:
			return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_EVENT, &"unsupported_external_run_event")


func generate_reward(context: RoomRewardContext, seed: int) -> RunCommandResult:
	if not _rules.legacy_free_rewards_enabled:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.FEATURE_DISABLED,
			&"legacy_free_rewards_disabled",
			snapshot()
		)
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
	if not _rules.legacy_free_rewards_enabled:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.FEATURE_DISABLED,
			&"legacy_free_rewards_disabled",
			snapshot()
		)
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
		var content := _content_for(option.content_id)
		var skill_add := (
			_skill_inventory.validate_add_content(content)
			if content != null
			else RunCommandResult.success()
		)
		if not skill_add.accepted:
			return skill_add
		if content != null:
			_skill_inventory.commit_add_content(
				content,
				SkillProgressSnapshot.AcquisitionKind.SCRIPTED
			)
		else:
			_skill_inventory.try_add(option.content_id)
	else:
		if _rules.relic_mode != RunFeatureMode.Value.ENABLED:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.FEATURE_DISABLED,
				&"relic_acquisition_disabled",
				snapshot()
			)
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
	if _director.snapshot().phase == RunPhase.SHOP:
		_install_shop_session(_run_revision + 1)
	return _commit_and_publish(&"route_chosen")


func open_shop_draft() -> ShopDraftOpenResult:
	if _director.snapshot().phase != RunPhase.SHOP:
		return ShopDraftOpenResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"shop_draft_outside_shop")
	if _active_shop_draft == null or _active_shop_draft.confirmed:
		if _shop_snapshot == null:
			_install_shop_session(_run_revision)
		_active_shop_draft = ShopDraft.new(
			_run_revision,
			_progression.snapshot(),
			_current_loadout_snapshot(),
			_rules.progression_mode == RunFeatureMode.Value.ENABLED,
			_shop_snapshot.session_id if _shop_snapshot != null else StringName()
		)
	return ShopDraftOpenResult.success(_active_shop_draft, _shop_snapshot)


func purchase_skill(
		command_id: StringName,
		expected_run_revision: int,
		shop_session_id: StringName,
		offer_id: StringName
) -> RunCommandResult:
	var fingerprint := StringName("purchase|%d|%s|%s" % [
		expected_run_revision,
		String(shop_session_id),
		String(offer_id),
	])
	var replay := _command_replay(command_id, fingerprint)
	if replay != null:
		return replay
	var envelope := _validate_shop_envelope(expected_run_revision, shop_session_id)
	if not envelope.accepted:
		return _recorded_rejection(command_id, fingerprint, envelope.reject_reason, envelope.detail)
	var offer := _shop_snapshot.offer_for(offer_id)
	if offer == null:
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.UNKNOWN_OFFER,
			&"unknown_shop_offer"
		)
	var content := _content_for(offer.skill_id)
	if content == null or not content.is_shop_purchasable():
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"invalid_shop_offer_content"
		)
	if content.purchase_price != offer.purchase_price:
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			&"shop_offer_price_mismatch"
		)
	var inventory_validation := _skill_inventory.validate_add_content(content)
	if not inventory_validation.accepted:
		return _recorded_rejection(
			command_id,
			fingerprint,
			inventory_validation.reject_reason,
			inventory_validation.detail
		)
	if not _economy.can_spend(offer.purchase_price):
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.INSUFFICIENT_DREAM_DUST,
			&"insufficient_dream_dust_for_purchase"
		)
	var economy_before := _economy.snapshot()
	_economy.commit_purchase(offer.purchase_price)
	_skill_inventory.commit_add_content(
		content,
		SkillProgressSnapshot.AcquisitionKind.PURCHASED
	)
	var skill_after := _skill_inventory.snapshot().progress_for(content.skill_id)
	var summary := ShopCommitSummary.economy_transaction(
		ShopCommitSummary.TransactionKind.PURCHASE_SKILL,
		content.skill_id,
		economy_before,
		_economy.snapshot(),
		null,
		skill_after,
		offer.purchase_price,
		0,
		&"shop_skill_purchased"
	)
	return _commit_shop_command(
		command_id,
		fingerprint,
		&"shop_skill_purchased",
		summary
	)


func upgrade_active_skill(
		command_id: StringName,
		expected_run_revision: int,
		shop_session_id: StringName,
		skill_id: StringName
) -> RunCommandResult:
	var fingerprint := StringName("upgrade|%d|%s|%s" % [
		expected_run_revision,
		String(shop_session_id),
		String(skill_id),
	])
	var replay := _command_replay(command_id, fingerprint)
	if replay != null:
		return replay
	var envelope := _validate_shop_envelope(expected_run_revision, shop_session_id)
	if not envelope.accepted:
		return _recorded_rejection(command_id, fingerprint, envelope.reject_reason, envelope.detail)
	var content := _content_for(skill_id)
	if content == null or content.gameplay_definition == null:
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"unknown_skill_id"
		)
	if not _skill_inventory.owns(skill_id):
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"skill_not_owned"
		)
	if content.gameplay_definition.is_passive_skill():
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.PASSIVE_HAS_NO_LEVELS,
			&"passive_skill_has_no_levels"
		)
	if content.active_progression == null or not content.active_progression.is_valid():
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.ACTIVE_LEVEL_DATA_MISSING,
			&"active_level_data_missing"
		)
	var skill_before := _skill_inventory.snapshot().progress_for(skill_id)
	if skill_before.level >= content.active_progression.maximum_level():
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.MAX_LEVEL_REACHED,
			&"active_skill_max_level_reached"
		)
	var price := content.active_progression.upgrade_price_from(skill_before.level)
	if price <= 0:
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.ACTIVE_LEVEL_DATA_MISSING,
			&"active_upgrade_price_missing"
		)
	if not _economy.can_spend(price):
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.INSUFFICIENT_DREAM_DUST,
			&"insufficient_dream_dust_for_upgrade"
		)
	var economy_before := _economy.snapshot()
	_economy.commit_upgrade(price)
	_skill_inventory.commit_upgrade(skill_id, price)
	var skill_after := _skill_inventory.snapshot().progress_for(skill_id)
	var summary := ShopCommitSummary.economy_transaction(
		ShopCommitSummary.TransactionKind.UPGRADE_ACTIVE_SKILL,
		skill_id,
		economy_before,
		_economy.snapshot(),
		skill_before,
		skill_after,
		price,
		0,
		&"active_skill_upgraded"
	)
	return _commit_shop_command(command_id, fingerprint, &"active_skill_upgraded", summary)


func reset_active_skill_upgrades(
		command_id: StringName,
		expected_run_revision: int,
		shop_session_id: StringName,
		skill_id: StringName
) -> RunCommandResult:
	var fingerprint := StringName("reset|%d|%s|%s" % [
		expected_run_revision,
		String(shop_session_id),
		String(skill_id),
	])
	var replay := _command_replay(command_id, fingerprint)
	if replay != null:
		return replay
	var envelope := _validate_shop_envelope(expected_run_revision, shop_session_id)
	if not envelope.accepted:
		return _recorded_rejection(command_id, fingerprint, envelope.reject_reason, envelope.detail)
	var content := _content_for(skill_id)
	if content == null or content.gameplay_definition == null:
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"unknown_skill_id"
		)
	if not _skill_inventory.owns(skill_id):
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"skill_not_owned"
		)
	if content.gameplay_definition.is_passive_skill():
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.PASSIVE_HAS_NO_LEVELS,
			&"passive_skill_has_no_levels"
		)
	var skill_before := _skill_inventory.snapshot().progress_for(skill_id)
	if skill_before.level <= 1 or skill_before.cumulative_upgrade_spend <= 0:
		return _recorded_rejection(
			command_id,
			fingerprint,
			RunCommandResult.RejectReason.NO_UPGRADE_INVESTMENT,
			&"no_active_skill_upgrade_investment"
		)
	var refund := floori(
		float(skill_before.cumulative_upgrade_spend)
		* float(_rules.upgrade_refund_basis_points)
		/ float(RunRulesSnapshot.BASIS_POINTS_DENOMINATOR)
	)
	var economy_before := _economy.snapshot()
	_skill_inventory.commit_reset(skill_id)
	_economy.commit_refund(refund)
	var skill_after := _skill_inventory.snapshot().progress_for(skill_id)
	var summary := ShopCommitSummary.economy_transaction(
		ShopCommitSummary.TransactionKind.RESET_ACTIVE_SKILL,
		skill_id,
		economy_before,
		_economy.snapshot(),
		skill_before,
		skill_after,
		0,
		refund,
		&"active_skill_upgrades_reset"
	)
	return _commit_shop_command(
		command_id,
		fingerprint,
		&"active_skill_upgrades_reset",
		summary
	)


func active_skill_level_effect(skill_id: StringName) -> ActiveSkillLevelEffectSnapshot:
	var progress := _skill_inventory.snapshot().progress_for(skill_id)
	if progress == null or not progress.is_active():
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id)
	var content := _content_for(skill_id)
	if content == null:
		return ActiveSkillLevelEffectSnapshot.neutral(skill_id, progress.level)
	var effect := content.level_effect(progress.level)
	return (
		effect
		if effect != null and effect.is_valid()
		else ActiveSkillLevelEffectSnapshot.neutral(skill_id, progress.level)
	)


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
	_shop_snapshot = null
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
	if _rules.relic_mode != RunFeatureMode.Value.ENABLED:
		return RunCommandResult.success(snapshot())
	if _relic_controller.advance(delta):
		return _commit_and_publish(&"relic_cooldowns_advanced")
	return RunCommandResult.success(snapshot())


func _handle_enemy_killed(event: EnemyKilledEvent) -> RunCommandResult:
	if _director.snapshot().phase != RunPhase.COMBAT:
		return RunCommandResult.rejected(RunCommandResult.RejectReason.INVALID_STATE, &"kill_outside_combat")
	var kill_key := StringName("%s:%s" % [String(event.room_id), String(event.enemy_id)])
	if _processed_kill_keys.has(kill_key):
		return RunCommandResult.rejected(RunCommandResult.RejectReason.DUPLICATE_EVENT, &"enemy_kill_already_processed")
	if _rules.progression_mode == RunFeatureMode.Value.ENABLED:
		var experience_result := _progression.try_add_experience(event.experience_reward)
		if not experience_result.accepted:
			return experience_result
	elif _rules.progression_mode == RunFeatureMode.Value.OBSERVE_ONLY:
		_observed_experience += event.experience_reward
	_economy.commit_earned(event.dream_dust_reward)
	if _rules.relic_mode == RunFeatureMode.Value.ENABLED:
		_relic_controller.handle_event(event)
	elif _rules.relic_mode == RunFeatureMode.Value.OBSERVE_ONLY:
		_observed_relic_events += 1
	_processed_event_keys[event.identity_key()] = true
	_processed_kill_keys[kill_key] = true
	return _commit_and_publish(&"enemy_kill_processed")


func _handle_room_completed(event: RoomCompletedEvent) -> RunCommandResult:
	var room_validation := _director.validate_room_completion(event.room_id)
	if not room_validation.accepted:
		return room_validation
	if _rules.progression_mode == RunFeatureMode.Value.ENABLED:
		var experience_plan := ExperienceService.plan_gain(
			_progression.snapshot(),
			event.completion_experience
		)
		if not experience_plan.valid:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.NEGATIVE_EXPERIENCE,
				experience_plan.error
			)
	var room_commit := _director.commit_room_completion(event.room_id)
	if not room_commit.accepted:
		return room_commit
	if _rules.progression_mode == RunFeatureMode.Value.ENABLED:
		var experience_commit := _progression.try_add_experience(event.completion_experience)
		if not experience_commit.accepted:
			return experience_commit
	elif _rules.progression_mode == RunFeatureMode.Value.OBSERVE_ONLY:
		_observed_experience += event.completion_experience
	_economy.commit_earned(event.completion_dream_dust)
	if _rules.relic_mode == RunFeatureMode.Value.ENABLED:
		_relic_controller.handle_event(event)
	elif _rules.relic_mode == RunFeatureMode.Value.OBSERVE_ONLY:
		_observed_relic_events += 1
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
		if _rules.relic_mode != RunFeatureMode.Value.ENABLED:
			return RunCommandResult.rejected(
				RunCommandResult.RejectReason.FEATURE_DISABLED,
				&"relic_acquisition_disabled"
			)
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


func _content_for(skill_id: StringName) -> SkillContentDefinition:
	return _content_catalog.content_for(skill_id) if _content_catalog != null else null


func _catalog_from_reward_metadata() -> RunContentCatalog:
	for definition: SkillRewardDefinition in _skill_catalog:
		if definition == null or not definition.has_meta(&"run_content_catalog"):
			continue
		var candidate: Variant = definition.get_meta(&"run_content_catalog")
		if candidate is RunContentCatalog:
			return candidate as RunContentCatalog
	return null


func _current_relic_snapshot() -> RelicInventorySnapshot:
	if _rules.relic_mode != RunFeatureMode.Value.ENABLED:
		return RelicInventorySnapshot.new()
	return _relic_controller.snapshot(_relic_inventory)


func _install_shop_session(opened_run_revision: int) -> void:
	_shop_session_sequence += 1
	var session_id := StringName("shop_session_%d" % _shop_session_sequence)
	var offers: Array[ShopOfferSnapshot] = []
	var configuration_error: StringName = &""
	if _content_catalog != null:
		for content: SkillContentDefinition in _content_catalog.shop_contents():
			if _skill_inventory.owns(content.skill_id):
				continue
			var offer := ShopOfferSnapshot.new(
				StringName("%s:%s" % [String(session_id), String(content.skill_id)]),
				content.skill_id,
				content.gameplay_definition.activation_kind,
				content.purchase_price
			)
			if not offer.is_valid():
				configuration_error = offer.validation_error
				break
			offers.append(offer)
	_shop_snapshot = ShopSnapshot.new(
		session_id,
		offers,
		opened_run_revision,
		configuration_error
	)


func _validate_shop_envelope(
		expected_run_revision: int,
		shop_session_id: StringName
) -> RunCommandResult:
	if not _rules.is_valid():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			_rules.validation_error
		)
	if _director.snapshot().phase != RunPhase.SHOP:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_STATE,
			&"economy_command_outside_shop"
		)
	if expected_run_revision != _run_revision:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.STALE_RUN_REVISION,
			&"stale_run_revision"
		)
	if (
		_shop_snapshot == null
		or shop_session_id.is_empty()
		or _shop_snapshot.session_id != shop_session_id
	):
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.STALE_SHOP_SESSION,
			&"stale_shop_session"
		)
	if not _shop_snapshot.is_valid():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.CONFIGURATION_ERROR,
			_shop_snapshot.configuration_error
		)
	return RunCommandResult.success()


func _command_replay(
		command_id: StringName,
		fingerprint: StringName
) -> RunCommandResult:
	if command_id.is_empty():
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.INVALID_ARGUMENT,
			&"missing_command_id",
			snapshot()
		)
	if not _command_records.has(command_id):
		return null
	var record: Dictionary = _command_records[command_id]
	if record.get(&"fingerprint", StringName()) != fingerprint:
		return RunCommandResult.rejected(
			RunCommandResult.RejectReason.COMMAND_ID_REUSED,
			&"command_id_reused_with_different_payload",
			snapshot()
		)
	return record.get(&"result") as RunCommandResult


func _recorded_rejection(
		command_id: StringName,
		fingerprint: StringName,
		reason: RunCommandResult.RejectReason,
		detail: StringName
) -> RunCommandResult:
	var result := RunCommandResult.rejected(reason, detail, snapshot())
	_command_records[command_id] = {
		&"fingerprint": fingerprint,
		&"result": result,
	}
	return result


func _commit_shop_command(
		command_id: StringName,
		fingerprint: StringName,
		cause: StringName,
		summary: ShopCommitSummary
) -> RunCommandResult:
	_run_revision += 1
	if _active_shop_draft != null and not _active_shop_draft.confirmed:
		_active_shop_draft.rebase_after_authoritative_shop_transaction(
			_run_revision,
			_progression.snapshot(),
			_current_loadout_snapshot()
		)
	var current := snapshot()
	var result := RunCommandResult.success(current, null, null, summary)
	_command_records[command_id] = {
		&"fingerprint": fingerprint,
		&"result": result,
	}
	snapshot_changed.emit(current, cause)
	return result


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
