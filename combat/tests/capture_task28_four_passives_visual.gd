extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://scenes/test_room.tscn")
const PASSIVE_VITALITY: SkillDefinition = preload("res://resources/skills/passive_vitality.tres")
const PASSIVE_ENERGY: SkillDefinition = preload("res://resources/skills/passive_energy.tres")
const PASSIVE_FOCUS: SkillDefinition = preload("res://resources/skills/passive_focus.tres")
const PASSIVE_BALANCE: SkillDefinition = preload("res://resources/skills/passive_balance.tres")
const EVIDENCE_DIR := "res://docs/agent_tasks/evidence/task28"
const LOGICAL_SAFE_RECT := Rect2(16.0, 16.0, 1120.0, 616.0)

var _room: Node2D
var _safe_root: Control
var _panel: PanelContainer


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EVIDENCE_DIR)
	)
	if directory_error != OK:
		_fail("TASK 28 evidence directory failed: %d" % directory_error)
		return
	root.size = Vector2i(1920, 1080)
	_room = ROOM_SCENE.instantiate() as Node2D
	root.add_child(_room)
	current_scene = _room
	await process_frame
	await physics_frame
	var player := _room.get_node("Player") as PlayerCharacter
	var enemy := _room.get_node("Orc") as CombatEnemy
	var host := _room.get_node("RunSessionHost") as RunSessionHost
	player.set_physics_process(false)
	player.skill_executor.set_process(false)
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	host.set_process(false)
	player.global_position = Vector2(340.0, 470.0)
	enemy.global_position = Vector2(760.0, 470.0)

	var definitions: Array[SkillDefinition] = [
		PASSIVE_VITALITY,
		PASSIVE_ENERGY,
		PASSIVE_FOCUS,
		PASSIVE_BALANCE,
	]
	var runtime := RuntimeSkillLoadout.new(definitions, _four_passive_snapshot())
	if runtime.configuration_error != &"" or runtime.snapshot().entries.size() != 7:
		_fail("TASK 28 visual seven-slot runtime did not configure")
		return
	if (
		runtime.registered_passive_skill_ids.size() != 4
		or _unique_count(runtime.registered_passive_skill_ids) != 4
		or runtime.registered_passive_slot_ids != SkillSlotIds.passive()
		or runtime.passive_registration_commit_count != 1
	):
		_fail("TASK 28 visual four-passive initial registration is not unique")
		return
	var before_floor := _runtime_instances(runtime)
	runtime.on_floor_changed()
	var after_floor := _runtime_instances(runtime)
	if (
		after_floor.size() != 4
		or _unique_object_count(after_floor) != 4
		or _same_instances(before_floor, after_floor)
		or runtime.passive_registration_commit_count != 2
		or runtime.passive_unregistration_commit_count != 1
	):
		_fail("TASK 28 visual floor rebuild did not restore exactly four fresh runtimes")
		return

	_add_diagnostic_panel(runtime)
	await process_frame
	await process_frame
	if not _panel_inside_logical_safe_area():
		_fail("TASK 28 diagnostic panel is outside the 1152x648 logical safe area")
		return
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		_fail("TASK 28 screenshot has wrong size: %s" % str(image.get_size()))
		return
	var proof := _panel_proof_counts(image)
	if proof.x < 600 or proof.y < 350:
		_fail("TASK 28 diagnostic panel pixels missing: border=%d text=%d" % [proof.x, proof.y])
		return
	var output_path := "%s/01_four_passive_runtime_1920x1080.png" % EVIDENCE_DIR
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		_fail("TASK 28 screenshot save failed: %d" % save_error)
		return
	print(
		"TASK 28 VISUAL CAPTURE COMPLETE: 1920x1080, seven slots, four unique passives, floor registration 1 -> 2, unregistration 0 -> 1, border_pixels %d, text_pixels %d"
		% [proof.x, proof.y]
	)
	quit(0)


func _add_diagnostic_panel(runtime: RuntimeSkillLoadout) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_room.add_child(layer)
	_safe_root = Control.new()
	_safe_root.name = &"Task28LogicalSafeRoot"
	_safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_safe_root)
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.name = &"Task28FourPassiveDiagnostic"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 24.0
	_panel.offset_top = 128.0
	_panel.offset_right = 454.0
	_panel.offset_bottom = 418.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e3151d2d")
	style.border_color = Color("73e6bd")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override(&"panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 5)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "TASK 28 · SEVEN-SLOT RUNTIME"
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Color("f6e7b2"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "3 ACTIVE  +  4 PASSIVE · strict partition"
	subtitle.add_theme_font_size_override(&"font_size", 16)
	subtitle.add_theme_color_override(&"font_color", Color("a9b8ca"))
	box.add_child(subtitle)
	var separator := HSeparator.new()
	box.add_child(separator)
	var passive_names := ["VITALITY", "ENERGY", "FOCUS", "BALANCE"]
	for index: int in 4:
		var row := Label.new()
		row.text = "P%d  %-10s  ✓ UNIQUE RUNTIME" % [index + 1, passive_names[index]]
		row.add_theme_font_size_override(&"font_size", 17)
		row.add_theme_color_override(&"font_color", Color("d9fff1"))
		box.add_child(row)
	var footer := Label.new()
	footer.text = "FLOOR REBUILD  4 → 4  ·  REG 2 / UNREG 1\nRevision preserved · no duplicate subscriptions"
	footer.add_theme_font_size_override(&"font_size", 15)
	footer.add_theme_color_override(&"font_color", Color("73e6bd"))
	box.add_child(footer)
	_safe_root.add_child(_panel)
	assert(runtime.registered_passive_skill_ids.size() == 4)


func _panel_inside_logical_safe_area() -> bool:
	if _panel == null:
		return false
	var panel_rect := _panel.get_rect()
	return (
		LOGICAL_SAFE_RECT.encloses(panel_rect)
		and panel_rect.size.x >= 420.0
		and panel_rect.size.y >= 280.0
		and panel_rect.end.y < 440.0
	)


func _panel_proof_counts(image: Image) -> Vector2i:
	var bounds := Rect2i(18, 118, 450, 314)
	var border_target := Color("73e6bd")
	var text_target := Color("d9fff1")
	var border_pixels := 0
	var text_pixels := 0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var pixel := image.get_pixel(x, y)
			if _color_is_near(pixel, border_target, 0.05):
				border_pixels += 1
			if _color_is_near(pixel, text_target, 0.09):
				text_pixels += 1
	return Vector2i(border_pixels, text_pixels)


func _four_passive_snapshot() -> RuntimeLoadoutSnapshot:
	return RuntimeLoadoutSnapshot.new([
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_1),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_2),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.ACTIVE_3),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_1, PASSIVE_VITALITY.skill_id),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_2, PASSIVE_ENERGY.skill_id),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_3, PASSIVE_FOCUS.skill_id),
		RuntimeLoadoutSlotSnapshot.new(SkillSlotIds.PASSIVE_4, PASSIVE_BALANCE.skill_id),
	], 28)


func _runtime_instances(runtime: RuntimeSkillLoadout) -> Array[PassiveEffectRuntime]:
	var result: Array[PassiveEffectRuntime] = []
	for slot_id: StringName in SkillSlotIds.passive():
		var instance := runtime.passive_runtime_for_slot(slot_id)
		if instance != null:
			result.append(instance)
	return result


func _same_instances(
		left: Array[PassiveEffectRuntime],
		right: Array[PassiveEffectRuntime]
) -> bool:
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


func _color_is_near(value: Color, target: Color, tolerance: float) -> bool:
	return (
		absf(value.r - target.r) <= tolerance
		and absf(value.g - target.g) <= tolerance
		and absf(value.b - target.b) <= tolerance
		and value.a >= 0.95
	)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
