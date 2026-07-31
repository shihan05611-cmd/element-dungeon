extends SceneTree

## Dependency-free headless test entry point:
## Godot --headless --path <project> --script res://combat/tests/run_combat_tests.gd

var _failures: Array[String] = []
var _assertions: int = 0
var _tests: int = 0


func _initialize() -> void:
	_run("resolver_water_into_empty", _test_resolver_water_into_empty)
	_run("resolver_same_element_caps_at_ten", _test_resolver_same_element_caps_at_ten)
	_run("resolver_water_five_into_fire_two", _test_resolver_water_five_into_fire_two)
	_run("resolver_water_two_into_fire_five", _test_resolver_water_two_into_fire_five)
	_run("resolver_ten_into_ten", _test_resolver_ten_into_ten)
	_run("resolver_fire_water_symmetry", _test_resolver_fire_water_symmetry)
	_run("zero_element_has_no_ghost_remainder", _test_zero_element_has_no_ghost_remainder)
	_run("invalid_contracts_are_rejected", _test_invalid_contracts_are_rejected)
	_run("neutral_cast_snapshot_is_valid", _test_neutral_cast_snapshot_is_valid)
	_run("stat_dictionary_is_whitelisted_and_copied", _test_stat_dictionary_is_whitelisted_and_copied)
	_run("payload_definition_resolves_cast_form", _test_payload_definition_resolves_cast_form)
	_run("damage_pipeline_rounds_only_at_end", _test_damage_pipeline_rounds_only_at_end)
	_run("receiver_damage_and_element_commit", _test_receiver_damage_and_element_commit)
	_run("receiver_without_carrier_damages", _test_receiver_without_carrier_damages)
	_run("receiver_without_damage_attaches_and_reacts", _test_receiver_without_damage_attaches_and_reacts)
	_run("receiver_without_components_rejects", _test_receiver_without_components_rejects)
	_run("zero_final_damage_still_attaches", _test_zero_final_damage_still_attaches)
	_run("invulnerable_and_blocking_reject_everything", _test_invulnerable_and_blocking_reject_everything)
	_run("friendly_fire_rejects_everything", _test_friendly_fire_rejects_everything)
	_run("duplicate_identity_is_rejected", _test_duplicate_identity_is_rejected)
	_run("recent_hit_cache_is_bounded", _test_recent_hit_cache_is_bounded)
	_run("signals_observe_fully_committed_state", _test_signals_observe_fully_committed_state)
	_run("signal_reentry_is_safely_rejected", _test_signal_reentry_is_safely_rejected)
	_run("lethal_hit_notifies_after_full_commit", _test_lethal_hit_notifies_after_full_commit)
	_run("queue_free_from_signal_finishes_notifications", _test_queue_free_from_signal_finishes_notifications)
	_run("queued_target_is_rejected", _test_queued_target_is_rejected)
	_run("shared_resources_do_not_share_runtime_state", _test_shared_resources_do_not_share_runtime_state)

	if _failures.is_empty():
		print("COMBAT TESTS PASSED: %d tests, %d assertions" % [_tests, _assertions])
		quit(0)
	else:
		printerr("COMBAT TESTS FAILED: %d/%d tests, %d assertions" % [_failures.size(), _tests, _assertions])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _run(test_name: String, test_callable: Callable) -> void:
	_tests += 1
	var failure_count := _failures.size()
	test_callable.call()
	if _failures.size() == failure_count:
		print("PASS " + test_name)
	else:
		for index in range(failure_count, _failures.size()):
			_failures[index] = test_name + ": " + _failures[index]


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (expected %s, got %s)" % [message, expected, actual])


func _payload(element_id: StringName, amount: int, damage: float = 10.0) -> RuntimeAttackPayload:
	return RuntimeAttackPayload.new(damage, damage, element_id, amount)


func _cast(cast_id: int = 1, team_id: StringName = &"player", element_id: StringName = ElementIds.WATER) -> CastSnapshot:
	return CastSnapshot.new(
		cast_id,
		&"test_skill",
		101,
		102,
		team_id,
		element_id,
		CombatStatSnapshot.new()
	)


func _request(
		cast_id: int = 1,
		delivery_id: int = 1,
		hit_index: int = 0,
		element_id: StringName = ElementIds.WATER,
		amount: int = 3,
		damage: float = 10.0,
		team_id: StringName = &"player"
) -> HitRequest:
	return HitRequest.new(
		_cast(cast_id, team_id, element_id if element_id != ElementIds.NONE else ElementIds.WATER),
		_payload(element_id, amount, damage),
		delivery_id,
		hit_index,
		Vector2(25.0, 30.0),
		Vector2.RIGHT
	)


func _make_target(
		with_carrier: bool = true,
		with_damage: bool = true,
		max_health: int = 100,
		starting_health: int = 100,
		defense: float = 0.0
) -> Dictionary:
	var receiver := CombatReceiver.new()
	var carrier: ElementCarrier = null
	var damage: DamageReceiver = null
	if with_carrier:
		carrier = ElementCarrier.new()
		receiver.add_child(carrier)
	if with_damage:
		damage = DamageReceiver.new()
		damage.configure_runtime(max_health, starting_health, defense)
		receiver.add_child(damage)
	receiver.configure_components(carrier, damage)
	root.add_child(receiver)
	return {"receiver": receiver, "carrier": carrier, "damage": damage}


func _free_target(target: Dictionary) -> void:
	var receiver: CombatReceiver = target.receiver
	if is_instance_valid(receiver) and not receiver.is_queued_for_deletion():
		receiver.free()


func _test_resolver_water_into_empty() -> void:
	var result := WaterFireResolver.resolve(_payload(ElementIds.WATER, 3), ElementSnapshot.new())
	_expect(result.is_valid(), "resolution must be valid")
	_expect_eq(result.after.water_amount, 3, "water attaches")
	_expect_eq(result.after.fire_amount, 0, "fire remains empty")
	_expect_float(result.reaction_multiplier, 1.0, "no reaction multiplier")


func _test_resolver_same_element_caps_at_ten() -> void:
	var result := WaterFireResolver.resolve(_payload(ElementIds.WATER, 5), ElementSnapshot.new(8, 0))
	_expect_eq(result.after.water_amount, 10, "same element caps at ten")
	_expect_eq(result.consumed_amount, 0, "same element is not consumed")
	_expect_float(result.reaction_multiplier, 1.0, "same element does not react")


func _test_resolver_water_five_into_fire_two() -> void:
	var result := WaterFireResolver.resolve(_payload(ElementIds.WATER, 5), ElementSnapshot.new(0, 2))
	_expect_eq(result.after.water_amount, 3, "unconsumed incoming water remains")
	_expect_eq(result.after.fire_amount, 0, "opposite fire is consumed")
	_expect_eq(result.consumed_amount, 2, "equal quantities are consumed")
	_expect_float(result.reaction_multiplier, 1.6, "reaction multiplier is independent")


func _test_resolver_water_two_into_fire_five() -> void:
	var result := WaterFireResolver.resolve(_payload(ElementIds.WATER, 2), ElementSnapshot.new(0, 5))
	_expect_eq(result.after.water_amount, 0, "all incoming water is consumed")
	_expect_eq(result.after.fire_amount, 3, "unconsumed target fire remains")
	_expect_eq(result.remaining_incoming_amount, 0, "no ghost incoming remainder")
	_expect_float(result.reaction_multiplier, 1.6, "two layers yield 1.6")


func _test_resolver_ten_into_ten() -> void:
	var result := WaterFireResolver.resolve(_payload(ElementIds.WATER, 10), ElementSnapshot.new(0, 10))
	_expect_eq(result.after.water_amount, 0, "incoming is fully consumed")
	_expect_eq(result.after.fire_amount, 0, "target is fully consumed")
	_expect_eq(result.consumed_amount, 10, "maximum ten layers consumed")
	_expect_float(result.reaction_multiplier, 4.0, "maximum multiplier is four")


func _test_resolver_fire_water_symmetry() -> void:
	var water_hit := WaterFireResolver.resolve(_payload(ElementIds.WATER, 5), ElementSnapshot.new(0, 2))
	var fire_hit := WaterFireResolver.resolve(_payload(ElementIds.FIRE, 5), ElementSnapshot.new(2, 0))
	_expect_eq(fire_hit.after.fire_amount, water_hit.after.water_amount, "same incoming remainder")
	_expect_eq(fire_hit.after.water_amount, water_hit.after.fire_amount, "same opposite remainder")
	_expect_eq(fire_hit.consumed_amount, water_hit.consumed_amount, "same consumption")
	_expect_float(fire_hit.reaction_multiplier, water_hit.reaction_multiplier, "same multiplier")


func _test_zero_element_has_no_ghost_remainder() -> void:
	var result := WaterFireResolver.resolve(_payload(ElementIds.WATER, 0), ElementSnapshot.new(0, 4))
	_expect(result.after.equals(ElementSnapshot.new(0, 4)), "zero amount changes nothing")
	_expect_eq(result.consumed_amount, 0, "zero amount consumes nothing")
	_expect_eq(result.remaining_incoming_amount, 0, "zero amount leaves no remainder")
	_expect(not result.reaction_triggered, "zero amount cannot react")


func _test_invalid_contracts_are_rejected() -> void:
	_expect(not RuntimeAttackPayload.from_locked_inputs(10.0, 1.0, 0.0, 10.0, ElementIds.WATER, -1).is_valid(), "negative amount invalid")
	_expect(not RuntimeAttackPayload.from_locked_inputs(10.0, 1.0, 0.0, 10.0, &"earth", 1).is_valid(), "unknown element invalid")
	_expect(not RuntimeAttackPayload.from_locked_inputs(10.0, 1.0, 0.0, INF, ElementIds.WATER, 1).is_valid(), "infinite damage invalid")
	_expect(not RuntimeAttackPayload.from_locked_inputs(NAN, 1.0, 0.0, 1.0, ElementIds.WATER, 1).is_valid(), "NaN attack invalid")
	var bad_request := HitRequest.new(_cast(), RuntimeAttackPayload.from_locked_inputs(10.0, 1.0, 0.0, 10.0, ElementIds.WATER, -1), 1, 0, Vector2.ZERO, Vector2.RIGHT)
	_expect(not bad_request.is_valid(), "request rejects invalid payload")
	var target := _make_target()
	var result: CombatResult = target.receiver.receive_hit(bad_request)
	_expect(not result.accepted, "receiver rejects invalid request")
	_expect_eq(result.reject_reason, CombatStatus.RejectReason.INVALID_REQUEST, "structured invalid request reason")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 0, "invalid request does not mutate element")
	_expect_eq(target.damage.current_health, 100, "invalid request does not mutate health")
	_free_target(target)


func _test_neutral_cast_snapshot_is_valid() -> void:
	var neutral_cast := _cast(77, &"enemy", ElementIds.NONE)
	_expect(neutral_cast.is_valid(), "neutral cast snapshot is a valid attack source")
	_expect_eq(neutral_cast.cast_element_id, ElementIds.NONE, "neutral cast preserves none element")
	var definition := AttackPayloadDefinition.new()
	definition.damage_multiplier = 0.5
	definition.element_mode = AttackPayloadDefinition.ElementMode.NONE
	definition.element_amount = 0
	var runtime := definition.build_runtime(neutral_cast)
	_expect(runtime.is_valid(), "neutral payload builds from neutral cast")
	_expect_eq(runtime.element_id, ElementIds.NONE, "neutral payload remains elementless")

func _test_stat_dictionary_is_whitelisted_and_copied() -> void:
	var source := {CombatStatSnapshot.ATTACK_MULTIPLIER: 2.0, CombatStatSnapshot.FLAT_DAMAGE_BONUS: 1.0}
	var snapshot := CombatStatSnapshot.from_dictionary(source)
	source[CombatStatSnapshot.ATTACK_MULTIPLIER] = 99.0
	_expect(snapshot.is_valid(), "allowed scalar stats are valid")
	_expect_float(snapshot.attack_multiplier, 2.0, "snapshot is isolated from source mutation")
	_expect_float(snapshot.effective_attack, 20.0, "effective attack locks base attack times modifiers")
	_expect_float(snapshot.calculate_offensive_damage(0.3), 7.0, "offensive formula is explicit")
	_expect(not CombatStatSnapshot.from_dictionary({&"critical_chance": 1.0}).is_valid(), "unknown stat is rejected")
	_expect(not CombatStatSnapshot.from_dictionary({CombatStatSnapshot.ATTACK_MULTIPLIER: {"nested": 2}}).is_valid(), "nested arbitrary data is rejected")


func _test_payload_definition_resolves_cast_form() -> void:
	var definition := AttackPayloadDefinition.new()
	definition.damage_multiplier = 0.55
	definition.element_mode = AttackPayloadDefinition.ElementMode.FOLLOW_CAST_FORM
	definition.element_amount = 4
	var stats := CombatStatSnapshot.new(1.25, 0.25)
	var cast := CastSnapshot.new(1, &"skill", 1, 2, &"player", ElementIds.FIRE, stats)
	var runtime := definition.build_runtime(cast)
	_expect(runtime.is_valid(), "runtime payload builds")
	_expect_eq(runtime.element_id, ElementIds.FIRE, "cast form is locked into payload")
	_expect_eq(runtime.element_amount, 4, "configured amount is preserved")
	_expect_float(runtime.offensive_damage, 7.125, "offense is calculated without rounding")
	cast = CastSnapshot.new(2, &"skill", 1, 2, &"player", ElementIds.WATER, stats)
	_expect_eq(runtime.element_id, ElementIds.FIRE, "existing payload is immutable across later casts")


func _test_damage_pipeline_rounds_only_at_end() -> void:
	var resolution := DamageResolver.resolve(7.125, 1.6, 1.0)
	_expect_float(resolution.reacted_damage, 11.4, "reaction multiplies unrounded offense")
	_expect_float(resolution.mitigated_damage, 10.4, "defense applies before final rounding")
	_expect_eq(resolution.final_damage, 10, "round occurs once at final application")


func _test_receiver_damage_and_element_commit() -> void:
	var target := _make_target()
	target.carrier.set_amounts_silent(0, 2)
	var result: CombatResult = target.receiver.receive_hit(_request(1, 1, 0, ElementIds.WATER, 5, 10.0))
	_expect(result.accepted, "legal hit accepted")
	_expect_eq(result.damage_status, CombatStatus.SubResult.APPLIED, "damage applied independently")
	_expect_eq(result.element_status, CombatStatus.SubResult.APPLIED, "element applied independently")
	_expect_eq(result.final_damage, 16, "reaction damage is applied")
	_expect_eq(target.damage.current_health, 84, "health commits")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "water remainder commits")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 0, "fire consumption commits")
	_expect_eq(result.hit_position, Vector2(25.0, 30.0), "world hit position is returned")
	_expect(result.presentation_tags.has("reaction"), "presentation tag marks reaction")
	_free_target(target)


func _test_receiver_without_carrier_damages() -> void:
	var target := _make_target(false, true)
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(result.accepted, "damage-only target accepts")
	_expect_eq(result.damage_status, CombatStatus.SubResult.APPLIED, "damage processed")
	_expect_eq(result.element_status, CombatStatus.SubResult.NOT_AVAILABLE, "element explicitly unavailable")
	_expect_eq(target.damage.current_health, 90, "damage applies without carrier")
	_free_target(target)


func _test_receiver_without_damage_attaches_and_reacts() -> void:
	var target := _make_target(true, false)
	target.carrier.set_amounts_silent(0, 2)
	var result: CombatResult = target.receiver.receive_hit(_request(1, 1, 0, ElementIds.WATER, 5))
	_expect(result.accepted, "element-only target accepts")
	_expect_eq(result.damage_status, CombatStatus.SubResult.NOT_AVAILABLE, "damage explicitly unavailable")
	_expect_eq(result.element_status, CombatStatus.SubResult.APPLIED, "element processed")
	_expect(result.reaction_triggered, "reaction still occurs")
	_expect_float(result.reaction_multiplier, 1.6, "reaction result survives without health")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "element state commits")
	_free_target(target)


func _test_receiver_without_components_rejects() -> void:
	var target := _make_target(false, false)
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(not result.accepted, "empty target rejects")
	_expect_eq(result.reject_reason, CombatStatus.RejectReason.NO_RECEIVERS, "structured no receiver reason")
	_free_target(target)


func _test_zero_final_damage_still_attaches() -> void:
	var target := _make_target(true, true, 100, 100, 100.0)
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(result.accepted, "legal zero-damage hit is accepted")
	_expect_eq(result.final_damage, 0, "defense can reduce final damage to zero")
	_expect_eq(result.damage_status, CombatStatus.SubResult.PROCESSED_NO_CHANGE, "damage processing is explicit")
	_expect_eq(result.element_status, CombatStatus.SubResult.APPLIED, "element still applies")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "water attaches at zero damage")
	_free_target(target)


func _test_invulnerable_and_blocking_reject_everything() -> void:
	for mode in [&"invulnerable", &"blocking"]:
		var target := _make_target()
		target.receiver.set(String(mode), true)
		var result: CombatResult = target.receiver.receive_hit(_request())
		_expect(not result.accepted, "%s rejects hit" % mode)
		_expect_eq(target.damage.current_health, 100, "%s preserves health" % mode)
		_expect_eq(target.carrier.get_amount(ElementIds.WATER), 0, "%s preserves elements" % mode)
		_free_target(target)


func _test_friendly_fire_rejects_everything() -> void:
	var target := _make_target()
	var result: CombatResult = target.receiver.receive_hit(_request(1, 1, 0, ElementIds.WATER, 3, 10.0, &"enemy"))
	_expect(not result.accepted, "same team rejects")
	_expect_eq(result.reject_reason, CombatStatus.RejectReason.FRIENDLY_FIRE, "structured friendly-fire reason")
	_expect_eq(target.damage.current_health, 100, "friendly fire does no damage")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 0, "friendly fire does not attach")
	_free_target(target)


func _test_duplicate_identity_is_rejected() -> void:
	var target := _make_target()
	var request := _request()
	var first: CombatResult = target.receiver.receive_hit(request)
	var second: CombatResult = target.receiver.receive_hit(request)
	_expect(first.accepted, "first identity accepted")
	_expect(not second.accepted, "duplicate identity rejected")
	_expect_eq(second.reject_reason, CombatStatus.RejectReason.DUPLICATE_HIT, "structured duplicate reason")
	_expect_eq(target.damage.current_health, 90, "duplicate does not damage again")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "duplicate does not attach again")
	_free_target(target)


func _test_recent_hit_cache_is_bounded() -> void:
	var target := _make_target()
	target.receiver.recent_hit_capacity = 2
	_expect(target.receiver.receive_hit(_request(1)).accepted, "first identity accepted")
	_expect(target.receiver.receive_hit(_request(2)).accepted, "second identity accepted")
	_expect(target.receiver.receive_hit(_request(3)).accepted, "third identity evicts first")
	_expect(target.receiver.receive_hit(_request(1)).accepted, "evicted identity may be accepted again")
	_free_target(target)


func _test_signals_observe_fully_committed_state() -> void:
	var target := _make_target()
	var observations: Array[String] = []
	target.receiver.hit_resolved.connect(func(_result: CombatResult) -> void:
		if target.carrier.get_amount(ElementIds.WATER) == 3 and target.damage.current_health == 90:
			observations.append("hit_final")
	)
	target.damage.health_changed.connect(func(current: int, maximum: int, delta: int) -> void:
		if current == 90 and maximum == 100 and delta == -10 and target.carrier.get_amount(ElementIds.WATER) == 3:
			observations.append("health_final")
	)
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(result.accepted, "hit accepted")
	_expect(observations.has("hit_final"), "hit signal sees both final states")
	_expect(observations.has("health_final"), "health signal sees both final states and delta")
	_free_target(target)


func _test_signal_reentry_is_safely_rejected() -> void:
	var target := _make_target()
	var nested_box := {"result": null}
	target.receiver.hit_resolved.connect(func(_result: CombatResult) -> void:
		nested_box.result = target.receiver.receive_hit(_request(2, 1, 0, ElementIds.FIRE, 2, 5.0))
	)
	var outer: CombatResult = target.receiver.receive_hit(_request())
	var nested_result: CombatResult = nested_box.result
	_expect(outer.accepted, "outer hit accepted")
	_expect(nested_result != null, "nested call returns a result")
	_expect(not nested_result.accepted, "nested hit rejected")
	_expect_eq(nested_result.reject_reason, CombatStatus.RejectReason.REENTRANT, "structured reentry reason")
	_expect_eq(target.damage.current_health, 90, "nested hit cannot create partial damage")
	_expect_eq(target.carrier.get_amount(ElementIds.WATER), 3, "outer element remains complete")
	_expect_eq(target.carrier.get_amount(ElementIds.FIRE), 0, "nested element does not apply")
	_free_target(target)


func _test_lethal_hit_notifies_after_full_commit() -> void:
	var target := _make_target(true, true, 10, 10)
	var observation := {"complete": false}
	target.receiver.death_candidate.connect(func(result: CombatResult) -> void:
		observation.complete = (
			result.current_health == 0
			and target.damage.current_health == 0
			and target.carrier.get_amount(ElementIds.WATER) == 3
		)
	)
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(result.accepted, "lethal hit accepted")
	_expect(observation.complete, "death candidate sees full element and health commit")
	_free_target(target)


func _test_queue_free_from_signal_finishes_notifications() -> void:
	var target := _make_target()
	var events: Array[String] = []
	target.receiver.hit_resolved.connect(func(_result: CombatResult) -> void:
		events.append("hit")
		target.receiver.queue_free()
	)
	target.receiver.presentation_requested.connect(func(_result: CombatResult) -> void:
		if target.damage.current_health == 90 and target.carrier.get_amount(ElementIds.WATER) == 3:
			events.append("presentation_final")
	)
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(result.accepted, "hit remains accepted when callback queues target")
	_expect(target.receiver.is_queued_for_deletion(), "callback may queue target only after commit")
	_expect(events.has("hit"), "hit notification ran")
	_expect(events.has("presentation_final"), "later notification safely sees committed state")


func _test_queued_target_is_rejected() -> void:
	var target := _make_target()
	target.receiver.queue_free()
	var result: CombatResult = target.receiver.receive_hit(_request())
	_expect(not result.accepted, "queued receiver rejects")
	_expect_eq(result.reject_reason, CombatStatus.RejectReason.TARGET_UNAVAILABLE, "queued target reason")
	_expect_eq(target.damage.current_health, 100, "queued target is unchanged")


func _test_shared_resources_do_not_share_runtime_state() -> void:
	var shared_definition := AttackPayloadDefinition.new()
	shared_definition.damage_multiplier = 1.0
	shared_definition.element_mode = AttackPayloadDefinition.ElementMode.FIXED_ELEMENT
	shared_definition.fixed_element_id = ElementIds.WATER
	shared_definition.element_amount = 3
	var shared_element := ElementDefinition.new()
	shared_element.id = ElementIds.WATER
	shared_element.display_name = "水"
	var cast := _cast()
	var shared_runtime := shared_definition.build_runtime(cast)
	var first := _make_target()
	var second := _make_target()
	var request := HitRequest.new(cast, shared_runtime, 1, 0, Vector2.ZERO, Vector2.RIGHT)
	_expect(shared_element.is_valid(), "shared element definition is static and valid")
	_expect(first.receiver.receive_hit(request).accepted, "first target accepts shared payload")
	_expect_eq(first.carrier.get_amount(ElementIds.WATER), 3, "first target changes")
	_expect_eq(second.carrier.get_amount(ElementIds.WATER), 0, "second target runtime element is isolated")
	_expect_eq(second.damage.current_health, 100, "second target runtime health is isolated")
	_expect_eq(shared_definition.element_amount, 3, "shared Resource remains unchanged")
	_free_target(first)
	_free_target(second)
