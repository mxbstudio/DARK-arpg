extends SceneTree
## Headless test runner.
## Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all tests passed.

func _initialize() -> void:
	# Load the suite at runtime: scripts compiled by the -s script itself
	# cannot see autoload singletons yet.
	var suite: Node = load("res://tests/test_suite.gd").new()
	suite.finished.connect(func(failures: int) -> void: quit(1 if failures > 0 else 0))
	root.add_child.call_deferred(suite)
