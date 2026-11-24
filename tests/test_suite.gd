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
	await _test_rotation()
	await _test_progression()
	await _test_new_foes()
	_test_arena()
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
	_check(player.find_target(260.0) == e, "bow targets a lit enemy in range")
	player.torch_on = false
	_check(player.find_target(260.0) == null, "bow ignores an enemy standing in the dark")
	player.torch_on = true
	var hp0 := e.hp
	e.take_damage(30.0, player.global_position)
	_check(e.hp == hp0 - 30.0 and e.state == Enemy.State.CHASE, "a hit hurts the ghoul and makes it hunt")
	level.queue_free()


func _test_rotation() -> void:
	var level := Level.new()
	add_child(level)
	level.generate(3, Balance.section("run"))
	Game.loadout = SkillRotation.sanitize(["mark", "bloodtoll", "quick", "twin", "heavy"])
	var player := Player.new()
	player.sound_parent = level
	player.position = level.cell_center(level.rooms[0].get_center())
	level.add_child(player)
	var e := Enemy.new()
	e.setup(Balance.section("enemies")["ghoul"], level, null, 1)
	e.position = player.position + Vector2(70, 0)
	level.add_child(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var row := player.rotation_row
	_check(row.loadout.size() == int(SkillRotation.config()["slots"]), "loadout has one skill per slot")
	row.timer = 0.0
	row.index = 0
	row.pending = {}
	row.tick(0.0, player)
	_check(row.pending.get("crit", false) and row.index == 1, "prep (mark) loads a crit for the next attack")
	var before := level.get_children().filter(func(n: Node) -> bool: return n is Arrow).size()
	row.timer = 0.0
	row.tick(0.0, player)
	var arrows := level.get_children().filter(func(n: Node) -> bool: return n is Arrow)
	_check(arrows.size() == before + 1, "attack fires an arrow")
	var arrow: Arrow = arrows[arrows.size() - 1]
	_check(arrow.crit and row.pending.is_empty(), "the attack consumes the prep and crits")
	# Trigger: a crit with Blutzoll heals.
	player.hp = 50.0
	arrow.hit_enemy(e)
	_check(player.hp > 50.0, "on-crit trigger (Blutzoll) heals the player")
	# The row holds its place while no target is visible.
	player.torch_on = false
	e.global_position = player.global_position + Vector2(400, 0)
	row.index = 2
	row.timer = 0.0
	row.tick(0.0, player)
	_check(row.index == 2, "the row waits while there is no target")
	# Extra arrows from Doppelsehne.
	player.torch_on = true
	e.global_position = player.global_position + Vector2(70, 0)
	row.pending = {"extra_arrows": 1}
	before = level.get_children().filter(func(n: Node) -> bool: return n is Arrow).size()
	row.index = 2
	row.timer = 0.0
	row.tick(0.0, player)
	_check(level.get_children().filter(func(n: Node) -> bool: return n is Arrow).size() == before + 2, "extra-arrow prep adds an arrow")
	Game.loadout = SkillRotation.sanitize([])
	level.queue_free()


func _test_progression() -> void:
	var level := Level.new()
	add_child(level)
	level.generate(5, Balance.section("run"))
	var player := Player.new()
	player.sound_parent = level
	player.position = level.cell_center(level.rooms[0].get_center())
	level.add_child(player)
	await get_tree().physics_frame
	var need := player.xp_needed
	player.add_xp(need)
	_check(player.level == 2 and player.pending_levels == 1, "enough souls raise the level")
	_check(Player.xp_for_level(3) > Player.xp_for_level(2), "each level needs more souls")
	var before := player.stat("dmg_mult")
	player.take_boon("wrath")
	_check(player.stat("dmg_mult") > before and player.boon_level("wrath") == 1, "boon Zorn raises damage")
	var hp0 := player.max_hp
	player.take_boon("hide")
	_check(player.max_hp == hp0 + 20.0, "boon Grabhaut raises max life")
	var choices := LevelUpPanel.roll(player, 3)
	_check(choices.size() == 3, "level-up offers three boons")
	# Souls drift to the player and are absorbed.
	player.peaceful = false
	var xp0 := player.xp
	var soul := Soul.new()
	soul.value = 2
	soul.position = player.position + Vector2(30, 0)
	level.add_child(soul)
	for i in 40:
		await get_tree().physics_frame
	_check(player.xp == xp0 + 2, "a nearby soul is collected")
	level.queue_free()


func _test_new_foes() -> void:
	var level := Level.new()
	add_child(level)
	level.generate(9, Balance.section("run"))
	var foes := Balance.section("enemies")
	var room := level.rooms[0]
	var center := level.cell_center(room.get_center())
	# Cultist smothers a lit brazier nearby.
	var brazier := Brazier.new()
	brazier.position = center
	level.add_child(brazier)
	var c := Enemy.new()
	c.setup(foes["cultist"], level, null, 2, "cultist")
	c.position = center + Vector2(40, 0)
	level.add_child(c)
	await get_tree().physics_frame
	for i in 60 * 5:
		await get_tree().physics_frame
		if not brazier.is_lit():
			break
	_check(not brazier.is_lit(), "a cultist puts out a brazier")
	# Brute: slam hits a player standing beside it.
	var player := Player.new()
	player.sound_parent = level
	player.position = center + Vector2(-60, 0)
	level.add_child(player)
	var b := Enemy.new()
	b.setup(foes["brute"], level, player, 3, "brute")
	b.position = player.position + Vector2(38, 0)
	level.add_child(b)
	await get_tree().physics_frame
	var hp0 := player.hp
	for i in 60 * 3:
		await get_tree().physics_frame
		if player.hp < hp0:
			break
	_check(player.hp < hp0, "a brute's slam hurts the player")
	_check(float(foes["brute"]["max_hp"]) > float(foes["ghoul"]["max_hp"]), "brutes are much tougher than ghouls")
	level.queue_free()


func _test_arena() -> void:
	var level := Level.new()
	add_child(level)
	level.generate_painted(1, Balance.data_file("res://data/maps.json")["basalt"], Balance.section("run"))
	_check(level.is_open(level.start_cell) and level.is_open(level.exit_cell), "arena start/exit are walkable")
	var path := level.find_path(level.cell_center(level.start_cell), level.cell_center(level.exit_cell))
	_check(path.size() > 1, "arena exit is reachable from the start")
	_check(level.spawn_points(10, 9).size() >= 8, "arena has room for enemies")
	_check(level.brazier_points(3).size() == 3, "arena braziers come from the map")
	level.free()
