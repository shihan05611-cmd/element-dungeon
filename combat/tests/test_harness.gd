extends RefCounted

## Shared headless-test bookkeeping for extends-SceneTree `run_*.gd` scripts.
## Preload with `const TestHarness := preload("res://combat/tests/test_harness.gd")`
## so scripts run via `--script res://...` do not depend on global class_name
## registration (no editor scan required).

var tests: int = 0
var assertions: int = 0
var failures: Array[String] = []


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	expect(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func expect_float(actual: float, expected: float, message: String) -> void:
	expect(is_equal_approx(actual, expected), "%s (expected %s, got %s)" % [message, expected, actual])


func expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	expect(absf(actual - expected) <= tolerance, "%s (expected %s +/- %s, got %s)" % [message, expected, tolerance, actual])


func run_test(test_name: String, test_callable: Callable) -> void:
	tests += 1
	var before := failures.size()
	await test_callable.call()
	if failures.size() == before:
		print("PASS " + test_name)
	else:
		for index in range(before, failures.size()):
			failures[index] = test_name + ": " + failures[index]


func report(label: String, fixed_test_count: int = -1) -> int:
	var test_count := fixed_test_count if fixed_test_count >= 0 else tests
	if failures.is_empty():
		print("%s PASSED: %d tests, %d assertions" % [label, test_count, assertions])
		return 0
	printerr("%s FAILED: %d/%d tests, %d assertions" % [label, failures.size(), test_count, assertions])
	for failure in failures:
		printerr("  - " + failure)
	return 1
