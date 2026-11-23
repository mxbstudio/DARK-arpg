extends Node
## Input map setup and persistent meta progression between runs.

const SAVE_PATH := "user://meta.cfg"

var total_runs := 0
var best_depth := 0
## Meta currency earned per run. Spending it is not implemented yet.
var ash := 0


func _ready() -> void:
	_setup_input()
	load_meta()


func record_run(depth: int) -> int:
	var gained := depth * int(Balance.section("run")["ash_per_depth"])
	total_runs += 1
	best_depth = maxi(best_depth, depth)
	ash += gained
	save_meta()
	return gained


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	total_runs = int(cfg.get_value("meta", "total_runs", 0))
	best_depth = int(cfg.get_value("meta", "best_depth", 0))
	ash = int(cfg.get_value("meta", "ash", 0))


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "total_runs", total_runs)
	cfg.set_value("meta", "best_depth", best_depth)
	cfg.set_value("meta", "ash", ash)
	cfg.save(SAVE_PATH)


func _setup_input() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_keys("dodge", [KEY_SPACE])
	_mouse("dodge", MOUSE_BUTTON_RIGHT)
	_keys("torch", [KEY_F])
	_keys("armor", [KEY_T])
	_keys("interact", [KEY_E])
	_keys("restart", [KEY_R])
	_keys("help", [KEY_H])


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
