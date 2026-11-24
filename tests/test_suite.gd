extends Node
## Headless smoke tests. Loaded at runtime by tests/run_tests.gd so that
## autoload singletons (Balance, Sfx, ...) are available when this compiles.

signal finished(failures: int)

var _failures := 0
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not Sfx.loaded:
		await Sfx.finished_loading
	_test_balance()
	_test_sfx()
	_test_level_generation()
	await _test_enemy_hearing()
	await _test_touch_controls()
	await _test_camp()
	await _test_auto_shot()
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


func _test_touch_controls() -> void:
	var touch := TouchControls.new()
	add_child(touch)
	await get_tree().process_frame
	Game.touch_mode = true
	touch.visible = true
	touch._layout()
	var size := touch._screen_size()
	# Stick: press on the left half, drag right -> move_right is pressed.
	touch._on_press(0, Vector2(size.x * 0.2, size.y * 0.7))
	_check(touch._stick_id == 0, "touch on left half starts the stick")
	touch._update_stick(Vector2(size.x * 0.2 + 60.0, size.y * 0.7))
	_check(Input.get_action_strength("move_right") > 0.5, "dragging right presses move_right")
	touch._on_release(0)
	_check(Input.get_action_strength("move_right") == 0.0, "releasing the stick stops movement")
	# Buttons: pressing the dodge button presses the action.
	var dodge: Dictionary = touch._buttons[0]
	_check(dodge["id"] == "dodge", "first touch button is dodge")
	touch._on_press(1, dodge["pos"])
	_check(Input.is_action_pressed("dodge"), "dodge button presses the dodge action")
	touch._on_release(1)
	touch._release_everything()
	_check(not Input.is_action_pressed("dodge"), "dodge action is released")
	Game.touch_mode = false
	touch.queue_free()


func _test_camp() -> void:
	var camp := Camp.new()
	add_child(camp)
	await get_tree().process_frame
	var poly := PackedVector2Array()
	for p: Array in camp.cfg["walkable"]:
		poly.append(camp._pt(p))
	_check(Geometry2D.is_point_in_polygon(camp.spawn_point, poly), "camp spawn lies on the walkable platform")
	_check(Geometry2D.is_point_in_polygon(camp.gate_point, poly), "camp gate lies on the walkable platform")
	_check(camp.is_at_gate(camp.gate_point) and not camp.is_at_gate(camp.spawn_point), "gate is only reachable at the gate")
	camp.queue_free()


func _test_auto_shot() -> void:
	var level := Level.new()
	add_child(level)
	level.generate(3, Balance.section("run"))
	var player := Player.new()
	player.sound_parent = level
	var room := level.rooms[0]
	player.position = level.cell_center(room.get_center())
	level.add_child(player)
	var e := Enemy.new()
	e.setup(Balance.section("enemies")["ghoul"], level, null, 1)
	e.position = player.position + Vector2(60, 0)
	level.add_child(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player._pick_target(260.0) == e, "bow targets a lit enemy in range")
	player.torch_on = false
	_check(player._pick_target(260.0) == null, "bow ignores an enemy standing in the dark")
	player.torch_on = true
	var hp0 := e.hp
	e.take_damage(30.0, player.global_position)
	_check(e.hp == hp0 - 30.0 and e.state == Enemy.State.CHASE, "a hit hurts the ghoul and makes it hunt")
	level.queue_free()
