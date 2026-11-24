class_name Enemy
extends CharacterBody2D
## Ghoul: hunts by hearing and sight. Audible (steps, breath, growl) long before
## it is visible. Telegraphs attacks with a rising growl that peaks on impact.

enum State { WANDER, INVESTIGATE, CHASE, WINDUP, ATTACK, RECOVER, DEAD }

const WALL_MASK := 1
const HURT_FLASH := 0.15

var cfg: Dictionary = {}
var level: Level
var player: Player
var hp := 1.0
var radius := 10.0
var state: State = State.WANDER
var state_time := 0.0
var facing := Vector2.DOWN
var target_pos := Vector2.ZERO
var rng := RandomNumberGenerator.new()

var _audio: Dictionary = {}
var _vision: Dictionary = {}
var _path := PackedVector2Array()
var _path_idx := 0
var _path_goal := Vector2.INF
var _repath_t := 0.0
var _last_seen_t := INF
var _idle_t := 0.0
var _wandering := false
var _attack_dir := Vector2.ZERO
var _has_hit := false
var _hurt_flash := 0.0
var _step_t := 0.0
var _breath_t := 0.0
var _slow_t := 0.0
var _sprite: SheetSprite


func setup(p_cfg: Dictionary, p_level: Level, p_player: Player, seed_value: int) -> void:
	cfg = p_cfg
	level = p_level
	player = p_player
	rng.seed = seed_value


func _ready() -> void:
	_audio = Balance.section("audio")
	_vision = Balance.section("vision")
	hp = float(cfg["max_hp"])
	radius = float(cfg["radius"])
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemies")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_sprite = SheetSprite.new()
	add_child(_sprite)
	_sprite.setup("ghoul")
	facing = Vector2.from_angle(rng.randf() * TAU)
	_idle_t = rng.randf_range(0.5, 2.5)
	_breath_t = rng.randf_range(0.5, 3.0)
	Events.noise_emitted.connect(_on_noise)


func is_alive() -> bool:
	return state != State.DEAD


func take_damage(amount: float, from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_hurt_flash = HURT_FLASH
	Sfx.play_on("hit", self, -3.0, 500.0)
	if hp <= 0.0:
		_die()
		return
	# Hits slow the ghoul briefly but never interrupt an attack (poise): the player must dodge.
	_slow_t = float(cfg["hurt_slow_time"])
	if state == State.WANDER or state == State.INVESTIGATE:
		target_pos = from_pos
		_last_seen_t = 0.0
		_spot_player()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	state_time += delta
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	var sees := _can_see_player()
	if sees:
		_last_seen_t = 0.0
		target_pos = player.global_position
	else:
		_last_seen_t += delta

	match state:
		State.WANDER:
			_tick_wander(delta, sees)
		State.INVESTIGATE:
			_tick_investigate(delta, sees)
		State.CHASE:
			_tick_chase(delta, sees)
		State.WINDUP:
			_tick_windup(delta)
		State.ATTACK:
			_tick_attack()
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			if state_time >= float(cfg["recovery"]):
				_enter(State.CHASE)

	if _slow_t > 0.0 and state != State.ATTACK:
		_slow_t -= delta
		velocity *= float(cfg["hurt_slow"])
	move_and_slide()
	_tick_sounds(delta)
	_update_anim()


func _enter(s: State) -> void:
	state = s
	state_time = 0.0
	if s == State.WINDUP:
		Sfx.play_on("growl", self, float(_audio["growl_db"]), float(_audio["growl_audible_px"]))


# --- states --------------------------------------------------------------------

func _tick_wander(delta: float, sees: bool) -> void:
	if sees:
		_spot_player()
		return
	if not _wandering:
		velocity = Vector2.ZERO
		_idle_t -= delta
		if _idle_t <= 0.0:
			target_pos = level.random_open_point_near(global_position, 5, rng)
			_wandering = true
			state_time = 0.0
		return
	if _follow(target_pos, float(cfg["speed_wander"]), delta) or state_time > 8.0:
		_wandering = false
		_idle_t = rng.randf_range(1.5, 4.0)


func _tick_investigate(delta: float, sees: bool) -> void:
	if sees:
		_spot_player()
		return
	if _follow(target_pos, float(cfg["speed_investigate"]), delta) or state_time > 10.0:
		# Reached the noise: stand and listen for a while.
		_enter(State.WANDER)
		_wandering = false
		_idle_t = rng.randf_range(2.0, 3.5)


func _tick_chase(delta: float, sees: bool) -> void:
	if player == null or player.is_dead():
		_enter(State.WANDER)
		return
	if _last_seen_t > float(cfg["lose_sight_after"]):
		_enter(State.INVESTIGATE)  # target_pos = last known position
		return
	var to := player.global_position - global_position
	var speed := float(cfg["speed_chase"])
	if sees and to.length() <= float(cfg["attack_range"]) + radius + Player.RADIUS:
		velocity = Vector2.ZERO
		facing = to.normalized()
		_enter(State.WINDUP)
	elif sees and to.length() < 120.0:
		velocity = to.normalized() * speed
		facing = to.normalized()
	else:
		_follow(target_pos, speed, delta)


func _tick_windup(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	var windup := float(cfg["windup"])
	# Tracks the player until shortly before the lunge, then commits.
	if state_time < windup - 0.15 and player != null:
		facing = (player.global_position - global_position).normalized()
	if state_time >= windup:
		_attack_dir = facing
		_has_hit = false
		_enter(State.ATTACK)


func _tick_attack() -> void:
	velocity = _attack_dir * float(cfg["lunge_speed"])
	if not _has_hit and player != null and not player.is_dead():
		var to := player.global_position - global_position
		if to.length() <= float(cfg["attack_range"]) + radius + Player.RADIUS and absf(_attack_dir.angle_to(to)) < deg_to_rad(70.0):
			_has_hit = true
			player.take_damage(float(cfg["damage"]), global_position)
	if state_time >= float(cfg["active"]):
		_enter(State.RECOVER)


func _spot_player() -> void:
	Sfx.play_on("alert", self, float(_audio["alert_db"]), float(_audio["growl_audible_px"]))
	_enter(State.CHASE)


# --- perception ----------------------------------------------------------------

func _can_see_player() -> bool:
	if player == null or player.is_dead():
		return false
	var sight := float(_vision["enemy_sight_torch_px"]) if player.torch_on else float(_vision["enemy_sight_dark_px"])
	if state == State.CHASE or state == State.WINDUP or state == State.ATTACK or state == State.RECOVER:
		sight *= float(_vision["enemy_alert_sight_mult"])
	if global_position.distance_to(player.global_position) > sight:
		return false
	return _line_of_sight(player.global_position)


func _line_of_sight(to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, to, WALL_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _on_noise(pos: Vector2, noise_radius: float, source: Node) -> void:
	if source == self or not is_inside_tree():
		return
	if state != State.WANDER and state != State.INVESTIGATE:
		return
	var hearing := noise_radius * float(cfg["hearing_mult"])
	if not _line_of_sight(pos):
		hearing *= float(cfg["hearing_occluded_mult"])
	if global_position.distance_to(pos) > hearing:
		return
	if state == State.WANDER:
		# Audible feedback for the player: "it heard you".
		Sfx.play_on("alert", self, float(_audio["heard_db"]), float(_audio["growl_audible_px"]))
	target_pos = pos
	_enter(State.INVESTIGATE)


# --- movement / sound ------------------------------------------------------------

## Moves along an A* path toward `goal`. Returns true once arrived.
func _follow(goal: Vector2, speed: float, delta: float) -> bool:
	_repath_t -= delta
	if _repath_t <= 0.0 or goal.distance_to(_path_goal) > 16.0:
		_path = level.find_path(global_position, goal)
		_path_idx = 1
		_path_goal = goal
		_repath_t = 0.5
	while _path_idx < _path.size() and global_position.distance_to(_path[_path_idx]) < 10.0:
		_path_idx += 1
	var next := goal
	if _path_idx < _path.size():
		next = _path[_path_idx]
	var to := next - global_position
	if next == goal and to.length() < 8.0:
		velocity = Vector2.ZERO
		return true
	velocity = to.normalized() * speed
	facing = facing.slerp(to.normalized(), 0.2)
	return false


func _tick_sounds(delta: float) -> void:
	var speed := velocity.length()
	if speed > 5.0:
		_step_t -= delta * clampf(speed / float(cfg["speed_chase"]), 0.35, 1.5)
		if _step_t <= 0.0:
			_step_t = float(cfg["step_interval"])
			Sfx.play_on("enemy_step", self, float(_audio["enemy_step_db"]), float(_audio["enemy_step_audible_px"]))
	if state == State.WINDUP or state == State.ATTACK:
		return
	_breath_t -= delta
	if _breath_t <= 0.0:
		var interval: Array = cfg["breath_interval"]
		_breath_t = rng.randf_range(float(interval[0]), float(interval[1])) * (0.6 if state == State.CHASE else 1.0)
		Sfx.play_on("breath", self, float(_audio["breath_db"]), float(_audio["breath_audible_px"]))


func _die() -> void:
	_enter(State.DEAD)
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	z_index = -1
	Sfx.play_on("enemy_death", self, 0.0, 600.0)
	_sprite.modulate = Color.WHITE
	_sprite.play("die", false, 9.0)


func _update_anim() -> void:
	_sprite.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 2.0), _hurt_flash / HURT_FLASH)
	_sprite.set_face(facing.x)
	match state:
		State.WINDUP:
			# Rear back during the windup, strike on the lunge.
			var w := float(cfg["windup"])
			_sprite.play("atk", false, 3.0 / w)
		State.ATTACK:
			_sprite.play("atk", false, 3.0 / float(cfg["active"]))
		State.RECOVER:
			_sprite.play("idle", true, 4.0)
		_:
			if _slow_t > 0.0:
				_sprite.play("hurt", false, 14.0)
			elif velocity.length() > 5.0:
				_sprite.play("walk", true, 4.0 + velocity.length() / 10.0)
			else:
				_sprite.play("idle", true, 5.0)
