class_name PassiveEffectAdapter
extends PassiveEffectPort

class PlayerOwnerPort:
	extends PassiveOwnerPort

	var _player_ref: WeakRef
	var _growth_adapter: PlayerGrowthAdapter

	func _init(player: PlayerCharacter, growth_adapter: PlayerGrowthAdapter) -> void:
		_player_ref = weakref(player) if player != null else null
		_growth_adapter = growth_adapter

	func capture_attack_stats() -> CombatStatSnapshot:
		var player := _player_ref.get_ref() as PlayerCharacter if _player_ref != null else null
		if not _is_live_node(player):
			return null
		return CombatStatSnapshot.new(player.attack_multiplier, player.flat_damage_bonus)

	func restore_health(
			amount: int,
			source_skill_id: StringName,
			event_id: StringName
	) -> bool:
		return (
			_growth_adapter != null
			and amount > 0
			and not source_skill_id.is_empty()
			and not event_id.is_empty()
			and _growth_adapter.restore_health(amount, source_skill_id, event_id)
		)

	func restore_energy(
			amount: int,
			source_skill_id: StringName,
			event_id: StringName
	) -> bool:
		return (
			_growth_adapter != null
			and amount > 0
			and not source_skill_id.is_empty()
			and not event_id.is_empty()
			and _growth_adapter.restore_energy(amount, source_skill_id, event_id)
		)

	static func _is_live_node(node: Node) -> bool:
		return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


class EnemyTargetPort:
	extends PassiveTargetPort

	var _player_ref: WeakRef
	var _enemy_refs: Array[WeakRef] = []
	var _targets_by_id: Dictionary[StringName, WeakRef] = {}
	var _next_cast_id: int = 2_000_000_000

	func _init(player: PlayerCharacter, enemies: Array[CombatEnemy]) -> void:
		_player_ref = weakref(player) if player != null else null
		set_enemies(enemies)

	func set_enemies(enemies: Array[CombatEnemy]) -> void:
		_enemy_refs.clear()
		_targets_by_id.clear()
		for enemy: CombatEnemy in enemies:
			if _is_live_node(enemy):
				_enemy_refs.append(weakref(enemy))

	func query_targets(observed_element_id: StringName) -> Array[PassiveTargetSnapshot]:
		var result: Array[PassiveTargetSnapshot] = []
		_targets_by_id.clear()
		for enemy_ref: WeakRef in _enemy_refs:
			var enemy := enemy_ref.get_ref() as CombatEnemy
			if not _is_live_node(enemy) or enemy.defeated:
				continue
			var receiver := enemy.combat_receiver
			var carrier := receiver.get_element_carrier() if receiver != null else null
			if (
				not _is_live_node(receiver)
				or not receiver.accepting_hits
				or not _is_live_node(carrier)
			):
				continue
			var elements := carrier.snapshot()
			if elements.get_amount(observed_element_id) <= 0:
				continue
			var target_id := _target_id(receiver)
			_targets_by_id[target_id] = weakref(enemy)
			result.append(PassiveTargetSnapshot.new(target_id, elements))
		result.sort_custom(func(
				left: PassiveTargetSnapshot,
				right: PassiveTargetSnapshot
		) -> bool:
			return String(left.target_id) < String(right.target_id)
		)
		return result

	func submit_damage(request: PassiveDamageRequest) -> bool:
		if request == null or not request.is_valid():
			return false
		var enemy_ref := _targets_by_id.get(request.target.target_id) as WeakRef
		var enemy := enemy_ref.get_ref() as CombatEnemy if enemy_ref != null else null
		var player := _player_ref.get_ref() as PlayerCharacter if _player_ref != null else null
		if not _is_live_node(enemy) or not _is_live_node(player) or enemy.defeated:
			return false
		var receiver := enemy.combat_receiver
		var carrier := receiver.get_element_carrier() if receiver != null else null
		if (
			not _is_live_node(receiver)
			or not receiver.accepting_hits
			or not _is_live_node(carrier)
			or not carrier.snapshot().equals(request.target.elements)
		):
			return false
		_next_cast_id += 1
		var locked_multiplier := request.payload.effective_attack / CombatStatSnapshot.BASE_ATTACK
		var locked_stats := CombatStatSnapshot.new(
			locked_multiplier,
			request.payload.fixed_damage_bonus
		)
		var cast_snapshot := CastSnapshot.new(
			_next_cast_id,
			request.source_skill_id,
			player.get_instance_id(),
			player.get_instance_id(),
			&"player",
			ElementIds.NONE,
			locked_stats
		)
		var hit_request := HitRequest.new(
			cast_snapshot,
			request.payload,
			_next_cast_id,
			0,
			enemy.global_position,
			Vector2.ZERO
		)
		var combat_result := receiver.receive_hit(hit_request)
		return combat_result != null and combat_result.accepted

	static func _target_id(receiver: CombatReceiver) -> StringName:
		return StringName("passive_target:%d" % receiver.get_instance_id())

	static func _is_live_node(node: Node) -> bool:
		return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


var registered_runtimes: Array[PassiveEffectRuntime]:
	get:
		return _registered_runtimes.duplicate()

var _growth_adapter: PlayerGrowthAdapter
var _registered_runtimes: Array[PassiveEffectRuntime] = []
var _owner_port: PlayerOwnerPort
var _target_port: EnemyTargetPort


func _init(
		growth_adapter: PlayerGrowthAdapter = null,
		context: PassiveRuntimeContext = null
) -> void:
	super(context)
	_growth_adapter = growth_adapter


func configure(
		growth_adapter: PlayerGrowthAdapter,
		context: PassiveRuntimeContext = null
) -> bool:
	if growth_adapter == null:
		return false
	_growth_adapter = growth_adapter
	if context != null:
		set_runtime_context(context)
	return true


func configure_runtime_ports(
		player: PlayerCharacter,
		enemies: Array[CombatEnemy]
) -> bool:
	if player == null or _growth_adapter == null:
		return false
	_owner_port = PlayerOwnerPort.new(player, _growth_adapter)
	_target_port = EnemyTargetPort.new(player, enemies)
	return set_runtime_context(PassiveRuntimeContext.new(_owner_port, _target_port))


func set_enemies(enemies: Array[CombatEnemy]) -> bool:
	if _target_port == null:
		return false
	_target_port.set_enemies(enemies)
	return true


func validation_error(bindings: Array[PassiveEffectBinding]) -> StringName:
	var base_error := super(bindings)
	if not base_error.is_empty():
		return base_error
	if _growth_adapter == null:
		return &"missing_player_growth_adapter"
	return &""


func commit_replace_effects(runtimes: Array[PassiveEffectRuntime]) -> void:
	var health_bonus := 0
	var energy_bonus := 0
	var attack_multiplier := 1.0
	for runtime: PassiveEffectRuntime in runtimes:
		var modifier := runtime.stat_modifier_snapshot()
		assert(modifier != null and modifier.is_valid(), "passive runtime modifier must be valid")
		health_bonus += modifier.maximum_health_bonus
		energy_bonus += modifier.maximum_energy_bonus
		attack_multiplier *= modifier.attack_multiplier
	_registered_runtimes = runtimes.duplicate()
	if _growth_adapter != null:
		var committed := _growth_adapter.set_passive_modifiers(
			health_bonus,
			energy_bonus,
			attack_multiplier
		)
		assert(committed, "validated passive aggregate must commit")


func registered_skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for runtime: PassiveEffectRuntime in _registered_runtimes:
		result.append(runtime.skill_id)
	return result


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0:
		return false
	var triggered := false
	for runtime: PassiveEffectRuntime in _registered_runtimes:
		triggered = runtime.advance(delta) or triggered
	return triggered


func on_basic_attack_committed(event: BasicAttackCommittedEvent) -> bool:
	if event == null or not event.is_valid():
		return false
	var triggered := false
	for runtime: PassiveEffectRuntime in _registered_runtimes:
		triggered = runtime.on_basic_attack_committed(event) or triggered
	return triggered


func on_combat_result(
		result: CombatResult,
		target_id: StringName,
		target_is_player: bool,
		owner_root_id: int
) -> bool:
	if result == null or target_id.is_empty() or owner_root_id <= 0:
		return false
	var triggered := false
	for runtime: PassiveEffectRuntime in _registered_runtimes:
		triggered = runtime.on_combat_result(
			result,
			target_id,
			target_is_player,
			owner_root_id
		) or triggered
	return triggered
