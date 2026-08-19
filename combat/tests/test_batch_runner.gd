extends SceneTree

## One-command aggregate runner for every headless `run_*.gd` entry point under
## combat/tests/ and growth/tests/. Each entry is a standalone extends-SceneTree
## script, so this spawns one Godot subprocess per file and collects results.
##
## Godot --headless --path <project> --script res://combat/tests/test_batch_runner.gd
##
## run_global_instakill_tests.gd is a protected regression item (see task 62
## docs/agent_tasks) and is intentionally excluded from this default set.
## run_task34_performance_tests.gd prints a JSON perf report instead of the
## usual "N tests, M assertions" text; that is expected, not a parsing failure.

const SCAN_DIRS: Array[String] = ["res://combat/tests/", "res://growth/tests/"]
const EXCLUDED_FILES: Array[String] = ["run_global_instakill_tests.gd"]

var _tests_re := RegEx.new()
var _assertions_re := RegEx.new()


func _initialize() -> void:
	_tests_re.compile("(\\d+)\\s+tests?,\\s*[\\d,]+\\s+assertions")
	_assertions_re.compile("([\\d,]+)\\s+assertions")
	call_deferred(&"_run_all")


func _run_all() -> void:
	var entries := _discover_entries()
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var rows: Array[Dictionary] = []
	var failed_files := 0

	print("%-58s %8s %12s %6s" % ["file", "tests", "assertions", "exit"])
	for entry_path: String in entries:
		var output: Array = []
		var exit_code: int = OS.execute(
			godot_path,
			PackedStringArray(["--headless", "--path", project_path, "--script", entry_path]),
			output,
			true
		)
		var text := "\n".join(output)
		var tests_text := _extract(text, _tests_re)
		var assertions_text := _extract(text, _assertions_re)
		var file_name := entry_path.get_file()
		rows.append({
			"file": file_name,
			"tests": tests_text,
			"assertions": assertions_text,
			"exit_code": exit_code,
		})
		if exit_code != 0:
			failed_files += 1
		print("%-58s %8s %12s %6d" % [file_name, tests_text, assertions_text, exit_code])

	print("")
	print("TOTAL: %d files, %d failed" % [rows.size(), failed_files])
	quit(1 if failed_files > 0 else 0)


func _discover_entries() -> Array[String]:
	var entries: Array[String] = []
	for dir_path: String in SCAN_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if (
				not dir.current_is_dir()
				and file_name.begins_with("run_")
				and file_name.ends_with(".gd")
				and not EXCLUDED_FILES.has(file_name)
			):
				entries.append(dir_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	entries.sort()
	return entries


func _extract(text: String, regex: RegEx) -> String:
	var result := regex.search(text)
	if result == null:
		return "n/a"
	return result.get_string(1)
