extends SceneTree

const RUN_GAME_SCENE: PackedScene = preload("res://scenes/run/run_game.tscn")
const CATALOG: RunContentCatalog = preload("res://resources/content/run_content_catalog.tres")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task32/viewport"
const PASSIVE_IDS: Array[StringName] = [
	&"burning",
	&"unending",
	&"passive_vitality",
	&"passive_energy",
]

var _assertions: int = 0
var _failures: Array[String] = []
var _hit_sequence: int = 3290000
var _images: Dictionary[String, Image] = {}
var _coordinator: RunFlowCoordinator
var _hud: CombatHUD
var _overlay: RunOverlayInterface
var _shop_evidence_revision: int = -1
var _combat_evidence_revision: int = -1
var _runtime_before_rebuild: Array[PassiveEffectRuntime] = []
var _registration_before_rebuild: int = 0
var _unregistration_before_rebuild: int = 0


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	call_deferred(&"_run")


func _run() -> void:
	_coordinator = RUN_GAME_SCENE.instantiate() as RunFlowCoordinator
	_expect(_coordinator != null, "capture instantiates the real RunGame")
	if _coordinator == null:
		_finish()
		return
	root.add_child(_coordinator)
	current_scene = _coordinator
	_expect(await _wait_for_room(&"combat_01_entry"), "capture boots the formal combat one")
	_hud = _coordinator.combat_hud
	_overlay = _hud.run_overlay as RunOverlayInterface

	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "capture reaches the first formal shop")
	await _purchase_and_equip(&"burning", SkillSlotIds.PASSIVE_1)
	_expect(_press(&"leave_shop"), "capture leaves first shop through the visible control")
	_expect(await _wait_for_phase(RunPhase.ROUTE_CHOICE), "capture reaches the formal route choice")
	var route_revision := _coordinator.current_snapshot().revision
	var pressure_index := _route_index(&"route_01_pressure")
	_expect(pressure_index >= 0, "capture route exposes the pressure option")
	if pressure_index < 0:
		_finish()
		return
	_overlay.formal_route_cards()[pressure_index].pressed.emit()
	await process_frame
	_expect_eq(_coordinator.current_snapshot().revision, route_revision, "route focus is non-committing")
	_overlay.formal_route_confirm_button().pressed.emit()
	_expect(await _wait_for_phase(RunPhase.COMBAT), "visible route confirmation reaches combat two")
	await _defeat_current_room()
	_expect(await _wait_for_room(&"combat_03_layer_elite"), "capture reaches the formal layer elite")
	await _defeat_current_room()
	_expect(await _wait_for_phase(RunPhase.SHOP), "capture reaches the second formal shop")

	await _purchase_and_equip(&"unending", SkillSlotIds.PASSIVE_2)
	await _purchase_and_equip(&"passive_vitality", SkillSlotIds.PASSIVE_3)
	await _purchase_and_equip(&"passive_energy", SkillSlotIds.PASSIVE_4)
	_shop_evidence_revision = _coordinator.current_snapshot().revision
	_assert_four_passive_authority("shop setup")
	_runtime_before_rebuild = _runtime_instances(_coordinator.host.runtime_loadout)
	_registration_before_rebuild = _coordinator.host.runtime_loadout.passive_registration_commit_count
	_unregistration_before_rebuild = _coordinator.host.runtime_loadout.passive_unregistration_commit_count
	_expect_eq(_runtime_before_rebuild.size(), 4, "shop evidence has four runtime objects")
	_expect_eq(_unique_object_count(_runtime_before_rebuild), 4, "shop evidence runtime objects are distinct")

	await _capture_shop("01_shop_four_passives_1920x1080.png", Vector2i(1920, 1080))
	await _capture_shop("02_shop_four_passives_2560x1440.png", Vector2i(2560, 1440))

	_expect(_press(&"leave_shop"), "capture leaves the second shop through the visible control")
	_expect(await _wait_for_room(&"combat_04_validation"), "capture reaches real combat four after room rebuild")
	_combat_evidence_revision = _coordinator.current_snapshot().revision
	_assert_four_passive_authority("combat setup")
	var runtime := _coordinator.host.runtime_loadout
	_expect_eq(runtime.passive_registration_commit_count, _registration_before_rebuild + 1, "real room rebuild registers one batch")
	_expect_eq(runtime.passive_unregistration_commit_count, _unregistration_before_rebuild + 1, "real room rebuild unregisters one prior batch")
	var rebuilt := _runtime_instances(runtime)
	_expect_eq(_unique_object_count(rebuilt), 4, "combat evidence has four distinct rebuilt runtimes")
	_expect(not _same_instances(_runtime_before_rebuild, rebuilt), "combat evidence uses fresh room runtimes")
	_stage_live_combatants()

	await _capture_combat("03_combat_p1_p4_1920x1080.png", Vector2i(1920, 1080))
	await _capture_combat("04_combat_p1_p4_2560x1440.png", Vector2i(2560, 1440))

	if _failures.is_empty():
		var directory := ProjectSettings.globalize_path(EVIDENCE_DIR)
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Task32 viewport directory is writable")
		for file_name: String in _images:
			var image: Image = _images[file_name]
			_expect(image != null, "%s has an actual gated Viewport image" % file_name)
			if image == null:
				continue
			_expect(image.detect_alpha() == Image.ALPHA_NONE, "%s actual Viewport capture is fully opaque" % file_name)
			var review_image := image.duplicate()
			review_image.convert(Image.FORMAT_RGB8)
			var path := directory.path_join(file_name)
			_expect(_save_unfiltered_rgb_png(review_image, path) == OK, "%s saves only after all authority and layout gates" % file_name)
			var decoded := Image.load_from_file(path)
			_expect(decoded != null and decoded.get_size() == review_image.get_size(), "%s PNG round-trips at the actual Viewport size" % file_name)
			if decoded != null:
				decoded.convert(Image.FORMAT_RGB8)
				_expect(decoded.get_data() == review_image.get_data(), "%s PNG is pixel-identical to the gated Viewport image" % file_name)

	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	await process_frame
	_finish()


func _purchase_and_equip(skill_id: StringName, slot_id: StringName) -> void:
	var before := _coordinator.current_snapshot()
	_expect(before.route.phase == RunPhase.SHOP and before.shop != null, "%s purchase occurs inside the formal shop" % String(skill_id))
	_expect(_press(StringName("purchase:%s" % String(skill_id))), "%s purchases through a visible formal control" % String(skill_id))
	await process_frame
	var purchased := _coordinator.current_snapshot()
	_expect(purchased.skills.owns(skill_id), "%s ownership is authoritative" % String(skill_id))
	_expect_eq(purchased.economy.balance, before.economy.balance - 75, "%s charges the formal price once" % String(skill_id))
	_expect_eq(purchased.revision, before.revision + 1, "%s purchase advances authority once" % String(skill_id))
	_expect(_press(StringName("select:%s" % String(skill_id))), "%s selects through the visible owned list" % String(skill_id))
	await process_frame
	var equip_revision := _coordinator.current_snapshot().revision
	_expect(_press(StringName("slot:%s" % String(slot_id))), "%s equips through the visible passive endpoint" % String(skill_id))
	await process_frame
	var equipped := _coordinator.current_snapshot()
	_expect_eq(equipped.loadout.get_skill_id(slot_id), skill_id, "%s slot mapping commits immediately" % String(skill_id))
	_expect_eq(equipped.revision, equip_revision + 1, "%s equip advances authority once" % String(skill_id))
	_expect(_coordinator.host.runtime_loadout.snapshot().same_mapping(equipped.loadout), "%s runtime mapping matches authority immediately" % String(skill_id))


func _capture_shop(file_name: String, size: Vector2i) -> void:
	await _set_size(size)
	_assert_four_passive_authority(file_name)
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.revision, _shop_evidence_revision, "%s keeps the frozen shop evidence revision" % file_name)
	_expect(_overlay.visible and _overlay.formal_kind() == &"shop", "%s shows the real formal shop" % file_name)
	_expect_eq(snapshot.route.phase, RunPhase.SHOP, "%s authority phase is shop" % file_name)
	var panel := _overlay.get("_panel") as Control
	_expect(panel != null and _inside(panel.get_global_rect(), _logical_viewport_rect()), "%s shop panel is fully inside the logical safe area" % file_name)
	var copy := _visible_text(_overlay)
	for required: String in ["梦尘余额  65", "购买支出 300", "权威即时配装", "P1", "燃烧", "P2", "不息", "P3", "坚韧体魄", "P4", "元素储备"]:
		_expect(copy.contains(required), "%s contains readable formal copy: %s" % [file_name, required])
	for index: int in PASSIVE_IDS.size():
		var slot_button := _button(StringName("slot:%s" % String(SkillSlotIds.passive()[index])))
		_expect(slot_button != null and slot_button.is_visible_in_tree(), "%s shows visible P%d endpoint" % [file_name, index + 1])
		if slot_button != null:
			_expect(slot_button.text.contains(CATALOG.content_for(PASSIVE_IDS[index]).display_name), "%s P%d displays the authoritative passive name" % [file_name, index + 1])
	await _store_capture(file_name, size)


func _capture_combat(file_name: String, size: Vector2i) -> void:
	await _set_size(size)
	_assert_four_passive_authority(file_name)
	var snapshot := _coordinator.current_snapshot()
	_expect_eq(snapshot.revision, _combat_evidence_revision, "%s keeps the frozen combat evidence revision" % file_name)
	_expect_eq(snapshot.route.phase, RunPhase.COMBAT, "%s authority phase is combat" % file_name)
	_expect(not _overlay.visible and _overlay.formal_kind() == &"combat", "%s leaves real combat unobscured" % file_name)
	_expect(_hud.status_panel.is_visible_in_tree() and _hud.skill_panel.is_visible_in_tree() and _hud.passive_panel.is_visible_in_tree(), "%s shows all formal HUD zones" % file_name)
	var logical_bounds := _logical_viewport_rect()
	_expect(_inside(_hud.status_panel.get_global_rect(), logical_bounds), "%s status panel stays in bounds" % file_name)
	_expect(_inside(_hud.skill_panel.get_global_rect(), logical_bounds), "%s active belt stays in bounds" % file_name)
	_expect(_inside(_hud.passive_panel.get_global_rect(), logical_bounds), "%s passive belt stays in bounds" % file_name)
	var player_rect := _canvas_rect(_coordinator.player.sprite, _sprite_local_rect(_coordinator.player.sprite))
	_expect(_inside(player_rect, logical_bounds), "%s player is visible in the gameplay safe area" % file_name)
	for enemy: CombatEnemy in _coordinator.active_enemies:
		var enemy_rect := _canvas_rect(enemy.sprite, _sprite_local_rect(enemy.sprite))
		_expect(_inside(enemy_rect, logical_bounds), "%s enemy is visible in the gameplay safe area" % file_name)
		_expect(not enemy_rect.intersects(_hud.status_panel.get_global_rect()), "%s enemy does not intersect status HUD" % file_name)
		_expect(not enemy_rect.intersects(_hud.skill_panel.get_global_rect()), "%s enemy does not intersect active HUD" % file_name)
		_expect(not enemy_rect.intersects(_hud.passive_panel.get_global_rect()), "%s enemy does not intersect passive HUD" % file_name)
	_expect(not player_rect.intersects(_hud.status_panel.get_global_rect()), "%s player does not intersect status HUD" % file_name)
	_expect(not player_rect.intersects(_hud.skill_panel.get_global_rect()), "%s player does not intersect active HUD" % file_name)
	_expect(not player_rect.intersects(_hud.passive_panel.get_global_rect()), "%s player does not intersect passive HUD" % file_name)
	for index: int in PASSIVE_IDS.size():
		var slot := _hud.visual_slot_panel(SkillSlotIds.passive()[index])
		var content := CATALOG.content_for(PASSIVE_IDS[index])
		var icon := slot.get_node("Margin/Body/Icon") as TextureRect
		var name_label := slot.get_node("Margin/Body/Name") as Label
		_expect(slot != null and slot.is_visible_in_tree(), "%s P%d is visible" % [file_name, index + 1])
		_expect(icon != null and icon.is_visible_in_tree() and icon.texture == content.icon, "%s P%d renders the formal icon" % [file_name, index + 1])
		_expect(name_label != null and name_label.is_visible_in_tree() and name_label.text == content.display_name, "%s P%d renders the formal name" % [file_name, index + 1])
		_expect(not (slot.get_node("Margin/Body/Key") as Control).visible, "%s P%d has no fake key" % [file_name, index + 1])
		_expect(not (slot.get_node("Margin/Body/Level") as Control).visible, "%s P%d has no fake level" % [file_name, index + 1])
		_expect(not (slot.get_node("Margin/Body/Cost") as Control).visible, "%s P%d has no fake SP cost" % [file_name, index + 1])
		_expect(not (slot.get_node("Margin/Body/CooldownMask") as Control).visible, "%s P%d has no fake cooldown" % [file_name, index + 1])
	await _store_capture(file_name, size, true)


func _assert_four_passive_authority(context: String) -> void:
	var snapshot := _coordinator.current_snapshot()
	var runtime := _coordinator.host.runtime_loadout
	_expect(snapshot != null and snapshot.economy.is_valid(), "%s has a valid authority snapshot" % context)
	_expect_eq(snapshot.economy.total_earned, 365, "%s wallet records formal earnings" % context)
	_expect_eq(snapshot.economy.total_spent_on_purchases, 300, "%s wallet records four purchases" % context)
	_expect_eq(snapshot.economy.balance, 65, "%s wallet conserves to 65" % context)
	_expect(snapshot.revision > 0, "%s exposes a positive authority revision" % context)
	_expect_eq(snapshot.loadout.entries.size(), 7, "%s keeps exactly seven loadout slots" % context)
	for index: int in PASSIVE_IDS.size():
		var skill_id := PASSIVE_IDS[index]
		var content := CATALOG.content_for(skill_id)
		_expect(snapshot.skills.owns(skill_id), "%s owns %s" % [context, String(skill_id)])
		_expect_eq(snapshot.loadout.get_skill_id(SkillSlotIds.passive()[index]), skill_id, "%s maps P%d to %s" % [context, index + 1, String(skill_id)])
		_expect(content != null and content.icon != null, "%s %s has a formal icon" % [context, String(skill_id)])
	_expect_eq(runtime.registered_passive_skill_ids, PASSIVE_IDS, "%s Runtime registers four passive IDs in P1-P4 order" % context)
	_expect_eq(runtime.registered_passive_slot_ids, SkillSlotIds.passive(), "%s Runtime registers P1-P4 slots" % context)
	_expect_eq(_unique_count(runtime.registered_passive_skill_ids), 4, "%s Runtime registers each passive exactly once" % context)
	_expect(runtime.snapshot().same_mapping(snapshot.loadout), "%s Runtime mapping equals authority" % context)


func _stage_live_combatants() -> void:
	_coordinator.player.global_position = Vector2(430.0, 395.0)
	_coordinator.player.velocity = Vector2.ZERO
	var offset := 0.0
	for enemy: CombatEnemy in _coordinator.active_enemies:
		enemy.global_position = Vector2(690.0 + offset, 395.0)
		enemy.velocity = Vector2.ZERO
		offset += 72.0


func _defeat_current_room() -> void:
	var room := _coordinator.active_room
	_expect(room != null and room.configured, "capture uses a configured real combat room")
	if room == null:
		return
	for enemy: CombatEnemy in room.enemies:
		_hit_sequence += 1
		var cast := CastSnapshot.new(
			_hit_sequence,
			&"task32_capture_finisher",
			_coordinator.player.get_instance_id(),
			_coordinator.player.get_instance_id(),
			&"player",
			ElementIds.NONE,
			CombatStatSnapshot.new()
		)
		var payload := RuntimeAttackPayload.new(99999.0, 99999.0, ElementIds.NONE, 0)
		var request := HitRequest.new(cast, payload, _hit_sequence, 0, enemy.global_position, Vector2.RIGHT)
		var hit := enemy.combat_receiver.receive_hit(request)
		_expect(hit.accepted and enemy.defeated, "capture defeats room enemy through real CombatReceiver")
	await process_frame


func _press(control_id: StringName) -> bool:
	var button := _button(control_id)
	if button == null or button.disabled:
		return false
	button.grab_focus()
	button.pressed.emit()
	return true


func _button(control_id: StringName) -> Button:
	return _overlay.formal_control(control_id) as Button


func _route_index(option_id: StringName) -> int:
	var options := _coordinator.current_snapshot().route.next_options
	for index: int in options.size():
		if options[index].option_id == option_id:
			return index
	return -1


func _wait_for_room(room_id: StringName) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == RunPhase.COMBAT
			and _coordinator.active_room != null
			and _coordinator.active_room.room_id == room_id
		)
	, 480)


func _wait_for_phase(phase: int) -> bool:
	return await _wait_until(func() -> bool:
		return (
			_coordinator != null
			and _coordinator.host != null
			and _coordinator.host.run_session != null
			and _coordinator.current_snapshot().route.phase == phase
		)
	, 480)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _set_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for _frame: int in 5:
		await process_frame
	_expect_eq(DisplayServer.window_get_size(), size, "window reaches requested %s" % str(size))


func _store_capture(file_name: String, expected_size: Vector2i, assert_passive_pixels: bool = false) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image != null and image.get_size() == expected_size, "%s is the actual %s Viewport before save" % [file_name, str(expected_size)])
	if image == null:
		return
	if assert_passive_pixels:
		for index: int in PASSIVE_IDS.size():
			var slot := _hud.visual_slot_panel(SkillSlotIds.passive()[index])
			var icon := slot.get_node("Margin/Body/Icon") as TextureRect
			var name_label := slot.get_node("Margin/Body/Name") as Label
			var icon_pixels := _count_visible_pixels(image, _logical_rect_to_physical_pixels(icon.get_global_rect(), expected_size))
			var text_pixels := _count_bright_pixels(image, _logical_rect_to_physical_pixels(name_label.get_global_rect(), expected_size))
			_expect(icon_pixels >= 24, "%s P%d icon has rendered pixels in the exact image" % [file_name, index + 1])
			_expect(text_pixels >= 5, "%s P%d name has readable pixels in the exact image" % [file_name, index + 1])
	_images[file_name] = image


func _logical_viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	))


func _logical_rect_to_physical_pixels(rect: Rect2, image_size: Vector2i) -> Rect2:
	var logical_size := _logical_viewport_rect().size
	var scale := minf(float(image_size.x) / logical_size.x, float(image_size.y) / logical_size.y)
	var offset := (Vector2(image_size) - logical_size * scale) * 0.5
	return Rect2(rect.position * scale + offset, rect.size * scale)


func _count_visible_pixels(image: Image, rect: Rect2) -> int:
	var count := 0
	for y: int in range(clampi(floori(rect.position.y), 0, image.get_height()), clampi(ceili(rect.end.y), 0, image.get_height())):
		for x: int in range(clampi(floori(rect.position.x), 0, image.get_width()), clampi(ceili(rect.end.x), 0, image.get_width())):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b)) >= 0.12:
				count += 1
	return count


func _count_bright_pixels(image: Image, rect: Rect2) -> int:
	var count := 0
	for y: int in range(clampi(floori(rect.position.y), 0, image.get_height()), clampi(ceili(rect.end.y), 0, image.get_height())):
		for x: int in range(clampi(floori(rect.position.x), 0, image.get_width()), clampi(ceili(rect.end.x), 0, image.get_width())):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and maxf(pixel.r, maxf(pixel.g, pixel.b)) >= 0.58:
				count += 1
	return count


func _visible_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_visible_text(node, lines)
	return "\n".join(PackedStringArray(lines))


func _collect_visible_text(node: Node, lines: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_visible_text(child, lines)


func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return (
		rect.position.x >= bounds.position.x - 0.5
		and rect.position.y >= bounds.position.y - 0.5
		and rect.end.x <= bounds.end.x + 0.5
		and rect.end.y <= bounds.end.y + 0.5
	)


func _canvas_rect(item: CanvasItem, local_rect: Rect2) -> Rect2:
	var transform := item.get_global_transform_with_canvas()
	var first := transform * local_rect.position
	var second := transform * Vector2(local_rect.end.x, local_rect.position.y)
	var third := transform * local_rect.end
	var fourth := transform * Vector2(local_rect.position.x, local_rect.end.y)
	var minimum := Vector2(
		minf(minf(first.x, second.x), minf(third.x, fourth.x)),
		minf(minf(first.y, second.y), minf(third.y, fourth.y))
	)
	var maximum := Vector2(
		maxf(maxf(first.x, second.x), maxf(third.x, fourth.x)),
		maxf(maxf(first.y, second.y), maxf(third.y, fourth.y))
	)
	return Rect2(minimum, maximum - minimum)


func _sprite_local_rect(sprite: AnimatedSprite2D) -> Rect2:
	if sprite == null or sprite.sprite_frames == null:
		return Rect2(Vector2(-16.0, -24.0), Vector2(32.0, 48.0))
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2(Vector2(-16.0, -24.0), Vector2(32.0, 48.0))
	var texture_size := Vector2(texture.get_size())
	return Rect2(-texture_size * 0.5, texture_size)


func _runtime_instances(runtime: RuntimeSkillLoadout) -> Array[PassiveEffectRuntime]:
	var result: Array[PassiveEffectRuntime] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var instance := runtime.passive_runtime_for_slot(slot_id)
		if instance != null:
			result.append(instance)
	return result


func _same_instances(left: Array[PassiveEffectRuntime], right: Array[PassiveEffectRuntime]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true


func _unique_object_count(values: Array[PassiveEffectRuntime]) -> int:
	var unique: Array[PassiveEffectRuntime] = []
	for value: PassiveEffectRuntime in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _unique_count(values: Array[StringName]) -> int:
	var unique: Array[StringName] = []
	for value: StringName in values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


func _save_unfiltered_rgb_png(image: Image, path: String) -> Error:
	if image == null or image.get_format() != Image.FORMAT_RGB8:
		return ERR_INVALID_PARAMETER
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return ERR_INVALID_PARAMETER
	var pixels := image.get_data()
	var stride := width * 3
	var raw := PackedByteArray()
	for y: int in height:
		var pixel_row := y * stride
		raw.append(0)
		raw.append_array(pixels.slice(pixel_row, pixel_row + stride))
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.is_empty():
		return ERR_CANT_CREATE
	var png := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	var header := PackedByteArray()
	_append_be32(header, width)
	_append_be32(header, height)
	header.append_array(PackedByteArray([8, 2, 0, 0, 0]))
	_append_png_chunk(png, "IHDR", header)
	_append_png_chunk(png, "IDAT", compressed)
	_append_png_chunk(png, "IEND", PackedByteArray())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(png)
	return OK


func _append_png_chunk(png: PackedByteArray, type_name: String, data: PackedByteArray) -> void:
	var type_bytes := type_name.to_ascii_buffer()
	_append_be32(png, data.size())
	png.append_array(type_bytes)
	png.append_array(data)
	var crc_input := type_bytes.duplicate()
	crc_input.append_array(data)
	_append_be32(png, _png_crc32(crc_input))


func _append_be32(buffer: PackedByteArray, value: int) -> void:
	buffer.append((value >> 24) & 0xff)
	buffer.append((value >> 16) & 0xff)
	buffer.append((value >> 8) & 0xff)
	buffer.append(value & 0xff)


func _png_crc32(data: PackedByteArray) -> int:
	var crc := 0xffffffff
	for byte: int in data:
		crc ^= byte
		for _bit: int in 8:
			crc = (crc >> 1) ^ (0xedb88320 if (crc & 1) != 0 else 0)
	return (~crc) & 0xffffffff


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _expect_eq(actual: Variant, expected: Variant, description: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [description, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("TASK 32 FORMAL FOUR PASSIVE VISUAL CAPTURE COMPLETE: 4 images, 1920x1080 and 2560x1440, %d assertions" % _assertions)
		quit(0)
	else:
		printerr("TASK 32 FORMAL FOUR PASSIVE VISUAL CAPTURE FAILED: %d failures / %d assertions" % [_failures.size(), _assertions])
		for failure: String in _failures:
			printerr("  - " + failure)
		quit(1)
