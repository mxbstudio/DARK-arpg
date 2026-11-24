extends Node2D
## Game flow: start camp -> run (floors of increasing depth) -> death -> back to camp.

enum Mode { LOADING, CAMP, RUN, DEAD }

const EXIT_REACH := 26.0

var mode: Mode = Mode.LOADING
var depth := 1
var world: Node2D
var level: Level
var camp: Camp
var player: Player
var exit_stairs: ExitStairs
var hud: Hud
var touch: TouchControls
var darkness: CanvasModulate
var panel: LoadoutPanel
var levelup: LevelUpPanel
var rng := RandomNumberGenerator.new()
var run_cfg: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	run_cfg = Balance.section("run")

	darkness = CanvasModulate.new()
	add_child(darkness)

	# Combat text above the darkness, following the camera.
	var overlay := CanvasLayer.new()
	overlay.layer = 1
	overlay.follow_viewport_enabled = true
	overlay.add_to_group("float_layer")
	add_child(overlay)

	hud = Hud.new()
	add_child(hud)
	touch = TouchControls.new()
	add_child(touch)

	if not Sfx.loaded:
		# Sounds are synthesized at startup; on slow devices this takes a moment.
		hud.set_loading(0.0)
		Sfx.loading_progress.connect(hud.set_loading)
		await Sfx.finished_loading
		hud.set_loading(-1.0)

	var drone := AudioStreamPlayer.new()
	drone.stream = Sfx.stream("drone")
	drone.volume_db = float(Balance.section("audio")["ambient_drone_db"])
	add_child(drone)
	drone.play()
	enter_camp()
	hud.show_help(12.0)


func _new_world() -> void:
	if player != null and player.get_parent() != null:
		player.get_parent().remove_child(player)
	if world != null:
		remove_child(world)
		world.queue_free()
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true  # whoever stands lower on screen is drawn in front
	add_child(world)
	level = null
	camp = null
	exit_stairs = null


func _place_player(pos: Vector2) -> void:
	player.sound_parent = world
	player.position = pos
	world.add_child(player)
	player.snap_camera()
	hud.player = player


## The safe hub. A fresh hero waits here; runs start at the gate.
func enter_camp() -> void:
	mode = Mode.CAMP
	if player != null:
		player.queue_free()
		player = null
	_new_world()
	camp = Camp.new()
	world.add_child(camp)
	darkness.color = camp.ambient_color()
	player = Player.new()
	player.peaceful = true
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_leveled_up)
	_place_player(camp.spawn_point)
	hud.in_camp = true


func start_run() -> void:
	mode = Mode.RUN
	depth = 1
	player.peaceful = false
	Sfx.play_ui("descend", -4.0)
	build_floor()
	hud.in_camp = false


func build_floor() -> void:
	_new_world()
	darkness.color = Balance.to_color(Balance.section("vision")["ambient"])

	level = Level.new()
	world.add_child(level)
	var arena := depth % int(run_cfg["arena_every"]) == 0
	if arena:
		level.generate_painted(rng.randi(), Balance.data_file("res://data/maps.json")["basalt"], run_cfg)
		hud.show_banner(level.map_name)
	else:
		level.generate(rng.randi(), run_cfg)

	var braziers := rng.randi_range(int(run_cfg["braziers_min"]), int(run_cfg["braziers_max"]))
	for p in level.brazier_points(braziers):
		var b := Brazier.new()
		b.position = p
		world.add_child(b)

	exit_stairs = ExitStairs.new()
	exit_stairs.position = level.cell_center(level.exit_cell)
	world.add_child(exit_stairs)

	_place_player(level.cell_center(level.start_cell))

	var count := int(run_cfg["enemies_base"]) + int(run_cfg["enemies_per_depth"]) * (depth - 1)
	if arena:
		count = int(count * float(run_cfg["arena_enemy_mult"]))
	var foes := Balance.section("enemies")
	for p in level.spawn_points(count, int(run_cfg["spawn_min_dist_cells"])):
		var type := _roll_enemy_type()
		var e := Enemy.new()
		e.setup(foes[type], level, player, rng.randi(), type)
		e.position = p
		world.add_child(e)

	hud.depth = depth


## Weighted pick from run.enemy_mix among the types allowed at this depth.
func _roll_enemy_type() -> String:
	var mix: Array = run_cfg["enemy_mix"]
	var total := 0.0
	for m: Dictionary in mix:
		if depth >= int(m["from_depth"]):
			total += float(m["weight"])
	var r := rng.randf() * total
	for m: Dictionary in mix:
		if depth >= int(m["from_depth"]):
			r -= float(m["weight"])
			if r <= 0.0:
				return String(m["type"])
	return "ghoul"


func descend() -> void:
	depth += 1
	Sfx.play_ui("descend", -4.0)
	player.heal(float(run_cfg["heal_on_descend"]))
	build_floor()


func _process(_delta: float) -> void:
	if mode == Mode.LOADING:
		return
	touch.show_restart = mode == Mode.DEAD
	if Input.is_action_just_pressed("help") and mode != Mode.DEAD:
		hud.toggle_help()
	var act := "[Aktion]" if Game.touch_mode else "[E]"
	match mode:
		Mode.DEAD:
			hud.set_hint("")
			if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("interact"):
				enter_camp()
		Mode.CAMP:
			var at_gate := camp.is_at_gate(player.global_position)
			var at_quiver := camp.is_at_quiver(player.global_position)
			touch.interact_ready = at_gate or at_quiver
			if at_gate:
				hud.set_hint(act + "  Abstieg beginnen")
			elif at_quiver:
				hud.set_hint(act + "  Köcher: Skill-Reihe bauen")
			else:
				hud.set_hint("")
			if Input.is_action_just_pressed("interact"):
				if at_gate:
					start_run()
				elif at_quiver:
					open_loadout()
		Mode.RUN:
			var near_exit := player.global_position.distance_to(exit_stairs.global_position) < EXIT_REACH
			touch.interact_ready = near_exit
			hud.set_hint(act + "  Hinabsteigen" if near_exit else "")
			if near_exit and Input.is_action_just_pressed("interact"):
				descend()


## Opens the skill-row menu; the game pauses meanwhile.
func open_loadout() -> void:
	if panel != null:
		return
	touch._release_everything()
	panel = LoadoutPanel.new()
	panel.closed.connect(_on_loadout_closed)
	add_child(panel)
	get_tree().paused = true


func _on_loadout_closed() -> void:
	panel = null
	get_tree().paused = false
	if player != null:
		player.rotation_row.set_loadout(Game.loadout)
	hud.set_hint("")


## A level-up pauses the game and offers boons; several in a row are shown one by one.
func _on_leveled_up() -> void:
	if levelup != null or player.pending_levels <= 0 or mode != Mode.RUN:
		return
	touch._release_everything()
	levelup = LevelUpPanel.new()
	levelup.player = player
	levelup.chosen.connect(_on_boon_chosen)
	add_child.call_deferred(levelup)
	get_tree().paused = true


func _on_boon_chosen(_id: String) -> void:
	levelup = null
	player.pending_levels -= 1
	get_tree().paused = false
	if player.pending_levels > 0:
		_on_leveled_up()


func _on_player_died() -> void:
	mode = Mode.DEAD
	var gained := Game.record_run(depth)
	hud.show_death(depth, gained)
