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
var rng := RandomNumberGenerator.new()
var run_cfg: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	run_cfg = Balance.section("run")

	darkness = CanvasModulate.new()
	add_child(darkness)

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
	var enemy_cfg: Dictionary = Balance.section("enemies")["ghoul"]
	for p in level.spawn_points(count, int(run_cfg["spawn_min_dist_cells"])):
		var e := Enemy.new()
		e.setup(enemy_cfg, level, player, rng.randi())
		e.position = p
		world.add_child(e)

	hud.depth = depth


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
			touch.interact_ready = at_gate
			hud.set_hint(act + "  Abstieg beginnen" if at_gate else "")
			if at_gate and Input.is_action_just_pressed("interact"):
				start_run()
		Mode.RUN:
			var near_exit := player.global_position.distance_to(exit_stairs.global_position) < EXIT_REACH
			touch.interact_ready = near_exit
			hud.set_hint(act + "  Hinabsteigen" if near_exit else "")
			if near_exit and Input.is_action_just_pressed("interact"):
				descend()


func _on_player_died() -> void:
	mode = Mode.DEAD
	var gained := Game.record_run(depth)
	hud.show_death(depth, gained)
