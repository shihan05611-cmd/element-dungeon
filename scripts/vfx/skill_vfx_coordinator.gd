class_name SkillVfxCoordinator
extends Node2D

const FURY_SCRIPT := preload("res://combat/delivery/element_rage_delivery.gd")
const LASER_SCRIPT := preload("res://combat/delivery/element_beam_delivery.gd")

@export var fury_scene: PackedScene
@export var laser_scene: PackedScene
@export var reclaim_scene: PackedScene
@export var burning_scene: PackedScene
@export var unending_scene: PackedScene

var configured: bool:
	get:
		return _configured

var active_laser_count: int:
	get:
		return _laser_presentations.size()

var burning_loop_count: int:
	get:
		return _burning_loops.size()

var unending_loop_count: int:
	get:
		return _unending_loops.size()

var fury_playback_count: int = 0
var laser_tick_count: int = 0
var reclaim_playback_count: int = 0
var burning_tick_count: int = 0
var unending_trigger_count: int = 0

var _configured: bool = false
var _player_ref: WeakRef
var _host_ref: WeakRef
var _passive_adapter_ref: WeakRef
var _enemy_refs: Array[WeakRef] = []
var _enemy_by_event_id: Dictionary[StringName, WeakRef] = {}
var _burning_registered: bool = false
var _unending_registered: bool = false
var _burning_loops: Dictionary[int, WeakRef] = {}
var _unending_loops: Dictionary[int, WeakRef] = {}
var _laser_presentations: Dictionary[int, WeakRef] = {}
var _laser_tick_positions: Dictionary[int, Array] = {}


func configure(
		player: PlayerCharacter,
		host: RunSessionHost,
		enemies: Array[CombatEnemy]
) -> bool:
	if _configured or not _scenes_are_valid():
		return false
	if (
		not _is_live_node(player)
		or not _is_live_node(host)
		or host.runtime_loadout == null
		or host.passive_adapter == null
		or enemies.is_empty()
	):
		return false
	_player_ref = weakref(player)
	_host_ref = weakref(host)
	_passive_adapter_ref = weakref(host.passive_adapter)
	_bind_player(player)
	_bind_runtime_loadout(host.runtime_loadout)
	var reclaim_port := ReclaimVfxPort.new(
		RangeElementReclaimPort.new(player, player.energy_component, 8, 256),
		Callable(self, "_on_reclaim_vfx_committed")
	)
	if not player.skill_executor.set_execution_reclaim_port(reclaim_port):
		_disconnect_all()
		return false
	if not set_enemies(enemies):
		_disconnect_all()
		return false
	_configured = true
	_apply_passive_registrations(host.passive_adapter.registered_skill_ids())
	return true


func set_enemies(enemies: Array[CombatEnemy]) -> bool:
	for enemy: CombatEnemy in enemies:
		if not _is_live_node(enemy):
			return false
	_clear_enemy_bindings()
	for enemy: CombatEnemy in enemies:
		var enemy_ref: WeakRef = weakref(enemy)
		_enemy_refs.append(enemy_ref)
		_index_enemy(enemy)
		var element_callback := Callable(
			self,
			"_on_enemy_elements_changed"
		).bind(enemy_ref)
		if not enemy.element_carrier.elements_changed.is_connected(element_callback):
			enemy.element_carrier.elements_changed.connect(element_callback)
		var hit_callback := Callable(self, "_on_enemy_hit_resolved").bind(enemy_ref)
		if not enemy.combat_receiver.hit_resolved.is_connected(hit_callback):
			enemy.combat_receiver.hit_resolved.connect(hit_callback)
		var defeated_callback := Callable(self, "_on_enemy_defeated").bind(enemy_ref)
		if not enemy.enemy_defeated.is_connected(defeated_callback):
			enemy.enemy_defeated.connect(defeated_callback)
		var tree_callback := Callable(
			self,
			"_on_enemy_tree_exiting"
		).bind(enemy.get_instance_id())
		if not enemy.tree_exiting.is_connected(tree_callback):
			enemy.tree_exiting.connect(tree_callback)
		_refresh_enemy(enemy)
	return true


func clear_presentations() -> void:
	_free_weak_nodes(_burning_loops)
	_free_weak_nodes(_unending_loops)
	_free_weak_nodes(_laser_presentations)
	_burning_loops.clear()
	_unending_loops.clear()
	_laser_presentations.clear()
	_laser_tick_positions.clear()
	for child: Node in get_children():
		if child is FuryVfxPresentation or child is ReclaimVfxPresentation:
			child.queue_free()


func _bind_player(player: PlayerCharacter) -> void:
	var delivery_callback := Callable(self, "_on_delivery_created")
	if not player.delivery_created.is_connected(delivery_callback):
		player.delivery_created.connect(delivery_callback)
	var basic_attack_callback := Callable(self, "_on_basic_attack_committed")
	if not player.basic_attack_committed.is_connected(basic_attack_callback):
		player.basic_attack_committed.connect(basic_attack_callback)
	var ignition_callback := Callable(self, "_on_ignition_reclaimed")
	if not player.ignition_reclaimed.is_connected(ignition_callback):
		player.ignition_reclaimed.connect(ignition_callback)
	var defeated_callback := Callable(self, "_on_player_defeated")
	if not player.player_defeated.is_connected(defeated_callback):
		player.player_defeated.connect(defeated_callback)


func _bind_runtime_loadout(loadout: RuntimeSkillLoadout) -> void:
	var callback := Callable(self, "_on_loadout_replaced")
	if not loadout.loadout_replaced.is_connected(callback):
		loadout.loadout_replaced.connect(callback)


func _on_delivery_created(delivery: Node) -> void:
	if delivery is FURY_SCRIPT:
		_observe_fury(delivery as FURY_SCRIPT)
	elif delivery is LASER_SCRIPT:
		_observe_laser(delivery as LASER_SCRIPT)


func _observe_fury(delivery: ElementRageDelivery) -> void:
	if delivery.cast_snapshot == null:
		return
	var element_id := delivery.cast_snapshot.cast_element_id
	var callback := Callable(self, "_on_fury_burst").bind(element_id)
	if not delivery.burst_submitted.is_connected(callback):
		delivery.burst_submitted.connect(callback)


func _on_fury_burst(
		origin: Vector2,
		radius: float,
		_target_count: int,
		element_id: StringName
) -> void:
	var presentation := fury_scene.instantiate() as FuryVfxPresentation
	if presentation == null:
		return
	add_child(presentation)
	if presentation.play_burst(origin, radius, element_id):
		fury_playback_count += 1
	else:
		presentation.queue_free()


func _observe_laser(delivery: ElementBeamDelivery) -> void:
	if delivery.cast_snapshot == null:
		return
	var presentation := laser_scene.instantiate() as LaserVfxPresentation
	if presentation == null:
		return
	add_child(presentation)
	if not presentation.configure(delivery, delivery.cast_snapshot.cast_element_id):
		presentation.queue_free()
		return
	var delivery_id := delivery.get_instance_id()
	_laser_presentations[delivery_id] = weakref(presentation)
	_laser_tick_positions[delivery_id] = []
	var hit_callback := Callable(
		self,
		"_on_laser_hit_submitted"
	).bind(delivery_id)
	if not delivery.hit_submitted.is_connected(hit_callback):
		delivery.hit_submitted.connect(hit_callback)
	var tick_callback := Callable(
		self,
		"_on_laser_tick_submitted"
	).bind(delivery_id)
	if not delivery.tick_submitted.is_connected(tick_callback):
		delivery.tick_submitted.connect(tick_callback)
	var finished_callback := Callable(
		self,
		"_on_laser_finished"
	).bind(delivery_id)
	if not delivery.delivery_finished.is_connected(finished_callback):
		delivery.delivery_finished.connect(finished_callback)


func _on_laser_hit_submitted(
		result: CombatResult,
		_receiver: CombatReceiver,
		_hurtbox: CombatHurtbox,
		delivery_id: int
) -> void:
	if result == null or not result.accepted:
		return
	var positions: Array = _laser_tick_positions.get(delivery_id, [])
	positions.append(result.hit_position)
	_laser_tick_positions[delivery_id] = positions


func _on_laser_tick_submitted(
		_tick_index: int,
		_target_count: int,
		delivery_id: int
) -> void:
	var presentation := _weak_node(
		_laser_presentations.get(delivery_id)
	) as LaserVfxPresentation
	if presentation == null:
		return
	var typed_positions: Array[Vector2] = []
	for value: Variant in _laser_tick_positions.get(delivery_id, []):
		if value is Vector2:
			typed_positions.append(value)
	presentation.pulse(typed_positions)
	_laser_tick_positions[delivery_id] = []
	laser_tick_count += 1


func _on_laser_finished(_reason: StringName, delivery_id: int) -> void:
	var presentation := _weak_node(
		_laser_presentations.get(delivery_id)
	) as LaserVfxPresentation
	if presentation != null:
		presentation.stop()
	_laser_presentations.erase(delivery_id)
	_laser_tick_positions.erase(delivery_id)


func _on_reclaim_vfx_committed(event: ReclaimVfxEvent) -> void:
	var player := (
		_player_ref.get_ref() as PlayerCharacter
		if _player_ref != null
		else null
	)
	if not _is_live_node(player):
		return
	var presentation := reclaim_scene.instantiate() as ReclaimVfxPresentation
	if presentation == null:
		return
	add_child(presentation)
	if presentation.play_reclaim(event, player):
		reclaim_playback_count += 1
	else:
		presentation.queue_free()


func _on_ignition_reclaimed(event: ReclaimVfxEvent) -> void:
	_on_reclaim_vfx_committed(event)


func _on_loadout_replaced(
		_previous: RuntimeLoadoutSnapshot,
		_current: RuntimeLoadoutSnapshot
) -> void:
	var adapter := (
		_passive_adapter_ref.get_ref() as PassiveEffectAdapter
		if _passive_adapter_ref != null
		else null
	)
	if adapter != null:
		_apply_passive_registrations(adapter.registered_skill_ids())


func _apply_passive_registrations(skill_ids: Array[StringName]) -> void:
	_burning_registered = skill_ids.has(&"burning")
	_unending_registered = skill_ids.has(&"unending")
	for enemy_ref: WeakRef in _enemy_refs:
		var enemy := enemy_ref.get_ref() as CombatEnemy
		if _is_live_node(enemy):
			_refresh_enemy(enemy)


func _on_enemy_elements_changed(
		_current: ElementSnapshot,
		_water_delta: int,
		_fire_delta: int,
		enemy_ref: WeakRef
) -> void:
	var enemy := enemy_ref.get_ref() as CombatEnemy
	if _is_live_node(enemy):
		_refresh_enemy(enemy)


func _on_enemy_hit_resolved(result: CombatResult, enemy_ref: WeakRef) -> void:
	if (
		result == null
		or not result.accepted
		or result.skill_id != &"burning"
		or not _burning_registered
	):
		return
	var enemy := enemy_ref.get_ref() as CombatEnemy
	if not _is_live_node(enemy):
		return
	var loop := _weak_node(
		_burning_loops.get(enemy.get_instance_id())
	) as EnemyPassiveVfxPresentation
	if loop != null:
		loop.play_trigger()
		burning_tick_count += 1


func _on_basic_attack_committed(event: BasicAttackCommittedEvent) -> void:
	if (
		not _unending_registered
		or event == null
		or not event.is_valid()
		or event.target_elements.get_amount(ElementIds.WATER) <= 0
	):
		return
	var enemy := _enemy_for_event(event.target_id)
	if enemy == null:
		return
	var loop := _weak_node(
		_unending_loops.get(enemy.get_instance_id())
	) as EnemyPassiveVfxPresentation
	if loop != null:
		loop.play_trigger()
		unending_trigger_count += 1


func _refresh_enemy(enemy: CombatEnemy) -> void:
	if not _is_live_node(enemy) or enemy.defeated:
		_remove_enemy_loops(enemy.get_instance_id() if enemy != null else 0)
		return
	var snapshot := enemy.element_carrier.snapshot()
	_set_loop(
		enemy,
		snapshot.fire_amount > 0,
		burning_scene,
		_burning_loops
	)
	_set_loop(
		enemy,
		snapshot.water_amount > 0,
		unending_scene,
		_unending_loops
	)


func _set_loop(
		enemy: CombatEnemy,
		should_show: bool,
		scene: PackedScene,
		storage: Dictionary[int, WeakRef]
) -> void:
	var enemy_id := enemy.get_instance_id()
	var existing := _weak_node(
		storage.get(enemy_id)
	) as EnemyPassiveVfxPresentation
	if should_show:
		if existing != null:
			return
		var presentation := scene.instantiate() as EnemyPassiveVfxPresentation
		if presentation == null:
			return
		enemy.add_child(presentation)
		presentation.position = Vector2(0.0, 30.0)
		storage[enemy_id] = weakref(presentation)
	elif existing != null:
		existing.queue_free()
		storage.erase(enemy_id)


func _on_enemy_defeated(enemy_ref: WeakRef) -> void:
	var enemy := enemy_ref.get_ref() as CombatEnemy
	if enemy != null:
		_remove_enemy_loops(enemy.get_instance_id())


func _on_enemy_tree_exiting(enemy_id: int) -> void:
	_remove_enemy_loops(enemy_id)


func _on_player_defeated() -> void:
	clear_presentations()


func _remove_enemy_loops(enemy_id: int) -> void:
	for storage: Dictionary in [_burning_loops, _unending_loops]:
		var node := _weak_node(storage.get(enemy_id))
		if node != null:
			node.queue_free()
		storage.erase(enemy_id)


func _index_enemy(enemy: CombatEnemy) -> void:
	var reference: WeakRef = weakref(enemy)
	_enemy_by_event_id[StringName(
		"passive_target:%d" % enemy.combat_receiver.get_instance_id()
	)] = reference
	var identity := String(enemy.get_path())
	if identity.is_empty():
		identity = "instance_%d" % enemy.get_instance_id()
	_enemy_by_event_id[StringName(
		"%s@%s" % [String(enemy.growth_enemy_id), identity]
	)] = reference


func _enemy_for_event(target_id: StringName) -> CombatEnemy:
	return _weak_node(_enemy_by_event_id.get(target_id)) as CombatEnemy


func _clear_enemy_bindings() -> void:
	for enemy_ref: WeakRef in _enemy_refs:
		var enemy := enemy_ref.get_ref() as CombatEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var element_callback := Callable(
			self,
			"_on_enemy_elements_changed"
		).bind(enemy_ref)
		if enemy.element_carrier.elements_changed.is_connected(element_callback):
			enemy.element_carrier.elements_changed.disconnect(element_callback)
		var hit_callback := Callable(
			self,
			"_on_enemy_hit_resolved"
		).bind(enemy_ref)
		if enemy.combat_receiver.hit_resolved.is_connected(hit_callback):
			enemy.combat_receiver.hit_resolved.disconnect(hit_callback)
		var defeated_callback := Callable(
			self,
			"_on_enemy_defeated"
		).bind(enemy_ref)
		if enemy.enemy_defeated.is_connected(defeated_callback):
			enemy.enemy_defeated.disconnect(defeated_callback)
		var tree_callback := Callable(
			self,
			"_on_enemy_tree_exiting"
		).bind(enemy.get_instance_id())
		if enemy.tree_exiting.is_connected(tree_callback):
			enemy.tree_exiting.disconnect(tree_callback)
	_enemy_refs.clear()
	_enemy_by_event_id.clear()
	_free_weak_nodes(_burning_loops)
	_free_weak_nodes(_unending_loops)
	_burning_loops.clear()
	_unending_loops.clear()


func _disconnect_all() -> void:
	_clear_enemy_bindings()
	clear_presentations()
	_player_ref = null
	_host_ref = null
	_passive_adapter_ref = null
	_configured = false


func _scenes_are_valid() -> bool:
	for scene: PackedScene in [
		fury_scene,
		laser_scene,
		reclaim_scene,
		burning_scene,
		unending_scene,
	]:
		if scene == null or not scene.can_instantiate():
			return false
	return true


static func _free_weak_nodes(storage: Dictionary) -> void:
	for reference: Variant in storage.values():
		var node := _weak_node(reference)
		if node != null:
			node.queue_free()


static func _weak_node(reference: Variant) -> Node:
	var weak_reference := reference as WeakRef
	var node := (
		weak_reference.get_ref() as Node
		if weak_reference != null
		else null
	)
	return node if _is_live_node(node) else null


static func _is_live_node(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and not node.is_queued_for_deletion()
	)


func _exit_tree() -> void:
	_disconnect_all()
