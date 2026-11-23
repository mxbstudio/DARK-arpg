extends Node2D
## Run controller: builds floors, tracks depth, handles descending, death and restart.

const EXIT_REACH := 26.0

var depth := 1
var run_over := false
var world: Node2D
var level: Level
var player: Player
var exit_stairs: ExitStairs
var hud: Hud
var rng := RandomNumberGenerator.new()
var run_cfg: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	run_cfg = Balance.section("run")
	var vision := Balance.section("vision")

	# Darkness is the default state: everything not lit is (almost) black.
	var darkness := CanvasModulate.new()
	darkness.color = Balance.to_color(vision["ambient"])
	add_child(darkness)

	var drone := AudioStreamPlayer.new()
	drone.stream = Sfx.stream("drone")
	drone.volume_db = float(Balance.section("audio")["ambient_drone_db"])
	add_child(drone)
	drone.play()

	hud = Hud.new()
	add_child(hud)
	start_run()


func start_run() -> void:
	depth = 1
	run_over = false
	if player != null:
		player.queue_free()
		player = null
	build_floor()
	hud.show_help(12.0)


func build_floor() -> void:
	if player != null and player.get_parent() != null:
		player.get_parent().remove_child(player)
	if world != null:
		remove_child(world)
		world.queue_free()

	world = Node2D.new()
	world.name = "World"
	add_child(world)

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

	if player == null:
		player = Player.new()
		player.died.connect(_on_player_died)
	player.sound_parent = world
	player.position = level.cell_center(level.start_cell)
	world.add_child(player)
	player.snap_camera()

	var count := int(run_cfg["enemies_base"]) + int(run_cfg["enemies_per_depth"]) * (depth - 1)
	var enemy_cfg: Dictionary = Balance.section("enemies")["ghoul"]
	for p in level.spawn_points(count, int(run_cfg["spawn_min_dist_cells"])):
		var e := Enemy.new()
		e.setup(enemy_cfg, level, player, rng.randi())
		e.position = p
		world.add_child(e)

	hud.player = player
	hud.depth = depth


func descend() -> void:
	depth += 1
	Sfx.play_ui("descend", -4.0)
	player.heal(float(run_cfg["heal_on_descend"]))
	build_floor()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("help") and not run_over:
		hud.toggle_help()
	if run_over:
		hud.set_hint("")
		if Input.is_action_just_pressed("restart"):
			start_run()
		return
	var near_exit := player.global_position.distance_to(exit_stairs.global_position) < EXIT_REACH
	hud.set_hint("[E]  Hinabsteigen" if near_exit else "")
	if near_exit and Input.is_action_just_pressed("interact"):
		descend()


func _on_player_died() -> void:
	run_over = true
	var gained := Game.record_run(depth)
	hud.show_death(depth, gained)
