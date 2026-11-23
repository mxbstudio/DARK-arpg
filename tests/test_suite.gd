extends Node
## Headless smoke tests. Loaded at runtime by tests/run_tests.gd so that
## autoload singletons (Balance, Sfx, ...) are available when this compiles.

signal finished(failures: int)

var _failures := 0
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_balance()
	_test_sfx()
	_test_level_generation()
	await _test_enemy_hearing()
	print("Tests: %d checks, %d failures" % [_checks, _failures])
	finished.emit(_failures)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _balance() -> Node:
	return Balance


func _test_balance() -> void:
	var b := _balance()
	for s in ["player", "armor", "vision", "audio", "enemies", "run"]:
		_check(b.data.has(s), "balance section '%s' exists" % s)
	var armor: Dictionary = b.section("armor")
	_check(float(armor["plate"]["step_noise_radius"]) > float(armor["leather"]["step_noise_radius"]), "plate armor is louder than leather")
	_check(float(armor["plate"]["damage_reduction"]) > float(armor["leather"]["damage_reduction"]), "plate armor protects more than leather")


func _test_sfx() -> void:
	var sfx := Sfx
	for s in ["step_soft", "step_plate", "enemy_step", "breath", "growl", "alert", "swing", "hit", "wind", "drone", "fire"]:
		var w: AudioStreamWAV = sfx.stream(s)
		_check(w != null and w.data.size() > 0, "sound '%s' synthesized" % s)


func _test_level_generation() -> void:
	var cfg: Dictionary = _balance().section("run")
	for seed_value in 25:
		var level := Level.new()
		add_child(level)
		level.generate(seed_value, cfg)
		_check(level.rooms.size() >= 2, "seed %d: at least two rooms" % seed_value)
		_check(level.is_open(level.start_cell) and level.is_open(level.exit_cell), "seed %d: start/exit open" % seed_value)
		_check(level.start_cell != level.exit_cell, "seed %d: exit differs from start" % seed_value)
		var path := level.find_path(level.cell_center(level.start_cell), level.cell_center(level.exit_cell))
		_check(path.size() > 1, "seed %d: exit reachable from start" % seed_value)
		var spawns := level.spawn_points(6, int(cfg["spawn_min_dist_cells"]))
		_check(spawns.size() >= 4, "seed %d: enough spawn points (%d)" % [seed_value, spawns.size()])
		for r in level.rooms:
			var p := level.find_path(level.cell_center(level.start_cell), level.cell_center(r.get_center()))
			_check(p.size() > 0, "seed %d: room %s reachable" % [seed_value, r])
		level.free()


func _test_enemy_hearing() -> void:
	var b := _balance()
	var level := Level.new()
	add_child(level)
	level.generate(7, b.section("run"))
	var e := Enemy.new()
	e.setup(b.section("enemies")["ghoul"], level, null, 1)
	e.position = level.cell_center(level.rooms[0].get_center())
	level.add_child(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var events := Events
	var armor: Dictionary = b.section("armor")
	var dist := 150.0  # between leather and plate step radius
	var noise_pos := e.global_position + Vector2(dist, 0)
	events.noise_emitted.emit(noise_pos, float(armor["leather"]["step_noise_radius"]), null)
	_check(e.state == Enemy.State.WANDER, "leather step at %dpx is not heard" % dist)
	events.noise_emitted.emit(noise_pos, float(armor["plate"]["step_noise_radius"]), null)
	_check(e.state == Enemy.State.INVESTIGATE, "plate step at %dpx is heard" % dist)
	_check(e.target_pos == noise_pos, "enemy investigates the noise position")
	level.queue_free()
