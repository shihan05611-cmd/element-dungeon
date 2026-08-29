extends SceneTree

## Explicit regression-gate runner. The default gate runs only CORE + FEATURE;
## directory discovery is used for manifest diagnostics and never for execution.
##
## Godot --headless --path <project> --log-file <unique-outer-log> \
##   --script res://combat/tests/test_batch_runner.gd
## Optional user arguments after `--`:
##   --tier=core|feature|snapshot|archive  Run one tier (repeatable).
##   --all                                 Run all four tiers.
##   --list                                Print ownership without running tests.
##   --strict-manifest                     Fail when an unlisted run_*.gd exists.

const SCAN_DIRS: Array[String] = ["res://combat/tests/", "res://growth/tests/"]
const TIER_ORDER: Array[String] = ["core", "feature", "snapshot", "archive"]
const DEFAULT_TIERS: Array[String] = ["core", "feature"]

const TIER_ENTRIES := {
	"core": [
		"res://combat/tests/run_combat_tests.gd",
		"res://combat/tests/run_delivery_tests.gd",
		"res://combat/tests/run_passive_runtime_contract_tests.gd",
		"res://growth/tests/run_growth_contract_edge_tests.gd",
		"res://growth/tests/run_growth_session_isolation_test.gd",
		"res://growth/tests/run_growth_tests.gd",
	],
	"feature": [
		"res://growth/tests/run_reward_authority_tests.gd",
	],
	"snapshot": [
		"res://combat/tests/run_hud_loadout_feedback_tests.gd",
		"res://combat/tests/run_skill_content_catalog_tests.gd",
		"res://combat/tests/run_skill_vfx_runtime_tests.gd",
		"res://combat/tests/run_task24_compact_hud_reward_tests.gd",
		"res://combat/tests/run_task29_real_room_flow_tests.gd",
		"res://combat/tests/run_task30_run_ui_tests.gd",
		"res://combat/tests/run_task31_full_run_e2e_tests.gd",
		"res://combat/tests/run_task40_drag_compact_hud_tests.gd",
		"res://combat/tests/run_task57_full_room_background_collision_tests.gd",
		"res://combat/tests/run_task69_boss_timing_and_standoff_tests.gd",
		"res://combat/tests/run_task71_boss_cast_and_telegraph_tests.gd",
		"res://combat/tests/run_task72_hud_layout_tests.gd",
		"res://combat/tests/run_task73_hud_theme_tests.gd",
		"res://combat/tests/run_task74_hud_density_tests.gd",
		"res://combat/tests/run_task75_world_prompt_font_and_motion_tests.gd",
		"res://combat/tests/run_task76_boss_and_basic_attack_presentation_tests.gd",
		"res://combat/tests/run_task81_ignition_tests.gd",
		"res://combat/tests/run_task82_toggle_skill_hud_tests.gd",
		"res://combat/tests/run_task84_shop_tab_layout_tests.gd",
		"res://growth/tests/run_task25_immediate_shop_equip_tests.gd",
		"res://growth/tests/run_task29_run_flow_contract_tests.gd",
		"res://growth/tests/run_task31_content_balance_tests.gd",
		"res://growth/tests/run_task32_formal_four_passive_content_tests.gd",
		"res://growth/tests/run_task42_reward_economy_tuning_tests.gd",
		"res://growth/tests/run_task49_five_stage_demo_flow_tests.gd",
	],
	"archive": [
		"res://combat/tests/run_agent_d_growth_integration_tests.gd",
		"res://combat/tests/run_agent_d_integration_tests.gd",
		"res://combat/tests/run_delivery_reuse_tests.gd",
		"res://combat/tests/run_delivery_skill_integration_test.gd",
		"res://combat/tests/run_first_batch_delivery_tests.gd",
		"res://combat/tests/run_global_instakill_tests.gd",
		"res://combat/tests/run_skill_execution_contract_tests.gd",
		"res://combat/tests/run_skill_tests.gd",
		"res://combat/tests/run_task27_skill_level_effect_tests.gd",
		"res://combat/tests/run_task28_seven_slot_passive_tests.gd",
		"res://combat/tests/run_task34_performance_tests.gd",
		"res://combat/tests/run_task34_projectile_cast_transaction_tests.gd",
		"res://combat/tests/run_task38_reclaim_reaction_energy_tests.gd",
		"res://combat/tests/run_task48_dodge_integration.gd",
		"res://combat/tests/run_task51_boss_projectile_spawn_clearance_tests.gd",
		"res://combat/tests/run_task56_dodge_live_enemy_passthrough_tests.gd",
		"res://combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd",
		"res://combat/tests/run_task59_enemy_projectile_profile_tests.gd",
		"res://combat/tests/run_task61_boss_three_form_tests.gd",
		"res://growth/tests/run_growth_06_contract_tests.gd",
		"res://growth/tests/run_task27_run_economy_progression_tests.gd",
		"res://growth/tests/run_task41_physical_flow_waves_boss_tests.gd",
		"res://growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd",
	],
}

var _tests_re := RegEx.new()
var _assertions_re := RegEx.new()


func _initialize() -> void:
	_tests_re.compile("(\\d+)\\s+tests?,\\s*[\\d,]+\\s+assertions")
	_assertions_re.compile("([\\d,]+)\\s+assertions")
	call_deferred(&"_run_gate")


func _run_gate() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not options.error.is_empty():
		printerr(options.error)
		quit(2)
		return

	var manifest_errors := _manifest_errors()
	var unlisted := _unlisted_entries()
	_print_manifest_diagnostics(unlisted)
	if not manifest_errors.is_empty():
		for error: String in manifest_errors:
			printerr("MANIFEST ERROR: %s" % error)
		quit(2)
		return
	if options.strict_manifest and not unlisted.is_empty():
		printerr("MANIFEST ERROR: unlisted run_*.gd entries exist")
		quit(2)
		return
	if options.list_only:
		_print_manifest()
		quit(0)
		return

	var selected_tiers: Array[String] = options.tiers
	var entries := _entries_for_tiers(selected_tiers)
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var log_dir := _make_log_dir(project_path)
	var failed_files := 0

	print("tiers: %s" % ",".join(selected_tiers))
	print("child logs: %s" % log_dir)
	print("%-10s %-58s %8s %12s %6s" % ["tier", "file", "tests", "assertions", "exit"])
	for entry: Dictionary in entries:
		var entry_path: String = entry.path
		var tier: String = entry.tier
		var output: Array = []
		var log_stem := entry_path.trim_prefix("res://").trim_suffix(".gd").replace("/", "_")
		var log_path := log_dir.path_join("%s_%s.log" % [tier, log_stem])
		var exit_code: int = OS.execute(
			godot_path,
			PackedStringArray([
				"--headless",
				"--path", project_path,
				"--log-file", log_path,
				"--script", entry_path,
			]),
			output,
			true
		)
		var output_text := "\n".join(output)
		var tests_text := _extract(output_text, _tests_re)
		var assertions_text := _extract(output_text, _assertions_re)
		if exit_code != 0:
			failed_files += 1
		print("%-10s %-58s %8s %12s %6d" % [
			tier,
			entry_path.get_file(),
			tests_text,
			assertions_text,
			exit_code,
		])

	print("")
	print("TOTAL: %d files, %d failed" % [entries.size(), failed_files])
	quit(1 if failed_files > 0 else 0)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var selected: Array[String] = []
	var list_only := false
	var strict_manifest := false
	for argument: String in arguments:
		if argument == "--all":
			selected = TIER_ORDER.duplicate()
		elif argument == "--list":
			list_only = true
		elif argument == "--strict-manifest":
			strict_manifest = true
		elif argument.begins_with("--tier="):
			var tier := argument.trim_prefix("--tier=")
			if not TIER_ORDER.has(tier):
				return {"error": "unknown regression tier: %s" % tier}
			if not selected.has(tier):
				selected.append(tier)
		else:
			return {"error": "unknown regression-gate argument: %s" % argument}
	if selected.is_empty():
		selected = DEFAULT_TIERS.duplicate()
	return {
		"error": "",
		"tiers": selected,
		"list_only": list_only,
		"strict_manifest": strict_manifest,
	}


func _entries_for_tiers(selected_tiers: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for tier: String in selected_tiers:
		for entry_path: String in TIER_ENTRIES[tier]:
			entries.append({"tier": tier, "path": entry_path})
	return entries


func _manifest_errors() -> Array[String]:
	var errors: Array[String] = []
	var owners := {}
	for tier: String in TIER_ORDER:
		if not TIER_ENTRIES.has(tier):
			errors.append("missing tier: %s" % tier)
			continue
		for entry_path: String in TIER_ENTRIES[tier]:
			if owners.has(entry_path):
				errors.append("%s belongs to both %s and %s" % [entry_path, owners[entry_path], tier])
			else:
				owners[entry_path] = tier
			if not FileAccess.file_exists(entry_path):
				errors.append("listed file does not exist: %s" % entry_path)
	return errors


func _unlisted_entries() -> Array[String]:
	var registered := {}
	for tier: String in TIER_ORDER:
		for entry_path: String in TIER_ENTRIES[tier]:
			registered[entry_path] = true
	var unlisted: Array[String] = []
	for entry_path: String in _discover_run_files():
		if not registered.has(entry_path):
			unlisted.append(entry_path)
	return unlisted


func _discover_run_files() -> Array[String]:
	var entries: Array[String] = []
	for dir_path: String in SCAN_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("run_") and file_name.ends_with(".gd"):
				entries.append(dir_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	entries.sort()
	return entries


func _print_manifest_diagnostics(unlisted: Array[String]) -> void:
	if unlisted.is_empty():
		print("manifest: all current run_*.gd files have one tier owner")
		return
	print("UNLISTED (not executed by default):")
	for entry_path: String in unlisted:
		print("  %s" % entry_path)


func _print_manifest() -> void:
	for tier: String in TIER_ORDER:
		print("[%s]" % tier)
		for entry_path: String in TIER_ENTRIES[tier]:
			print("  %s" % entry_path)


func _make_log_dir(project_path: String) -> String:
	var timestamp := Time.get_datetime_string_from_system(true, true).replace(":", "-")
	var run_token := "%s-pid%d" % [timestamp, OS.get_process_id()]
	var log_dir := project_path.path_join(".godot").path_join("regression-gate-logs").path_join(run_token)
	var error := DirAccess.make_dir_recursive_absolute(log_dir)
	if error != OK:
		printerr("Could not create child log directory: %s (error %d)" % [log_dir, error])
	return log_dir


func _extract(output_text: String, regex: RegEx) -> String:
	var result := regex.search(output_text)
	if result == null:
		return "n/a"
	return result.get_string(1)
