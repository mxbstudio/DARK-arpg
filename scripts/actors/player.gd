class_name Player
extends CharacterBody2D
## Player (the Archer): moves, dodges and carries a torch; the bow fires on its own
## at the nearest enemy that is lit and in line of sight. Armor makes noise.

signal died

enum State { FREE, DODGE, DEAD }

const RADIUS := 9.0
const BUFFER_TIME := 0.18
const HURT_FLASH := 0.25
const SHOT_ANIM := 0.24
const HURT_ANIM := 0.28

var cfg: Dictionary = {}
var vision: Dictionary = {}
var armor_id := "leather"
var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var state: State = State.FREE
var state_time := 0.0
var facing := Vector2.RIGHT
var torch_on := true
## In the camp there is nothing to shoot and nothing hears you.
var peaceful := false
## Node that receives positional one-shot sounds and arrows (the current floor).
var sound_parent: Node2D

var _dodge_dir := Vector2.ZERO
var _stamina_cooldown := 0.0
var _knockback := Vector2.ZERO
var _hurt_flash := 0.0
var _step_accum := 0.0
var _buffered := ""
var _buffer_t := 0.0
var _flicker_t := 0.0
var _shot_cd := 0.0
var _shot_anim_t := 0.0
var _hurt_anim_t := 0.0
var _light: PointLight2D
var _camera: Camera2D
var _sprite: SheetSprite


func _ready() -> void:
	cfg = Balance.section("player")
	vision = Balance.section("vision")
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	max_stamina = float(cfg["max_stamina"])
	stamina = max_stamina
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 | 4
	add_to_group("player")
	add_to_group("light_sources")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	_sprite = SheetSprite.new()
	add_child(_sprite)
	_sprite.setup("archer")

	_light = LightUtil.make_light(1.0, 1.0, Color.WHITE)
	add_child(_light)
	_camera = Camera2D.new()
	var zoom := float(vision["camera_zoom"])
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_apply_torch()


func armor() -> Dictionary:
	return Balance.section("armor")[armor_id]


func is_dead() -> bool:
	return state == State.DEAD


func heal(fraction: float) -> void:
	hp = minf(hp + max_hp * fraction, max_hp)


func snap_camera() -> void:
	if _camera:
		_camera.reset_smoothing()


## How far the player's own light reveals enemies (see Lighting).
func light_reach() -> float:
	return float(vision["torch_radius_px"] if torch_on else vision["dark_radius_px"]) * float(vision["reveal_fraction"])


func take_damage(amount: float, from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	if state == State.DODGE and state_time < float(cfg["dodge"]["iframes"]):
		return  # dodged through the attack
	hp = maxf(hp - amount * (1.0 - float(armor()["damage_reduction"])), 0.0)
	_hurt_flash = HURT_FLASH
	_hurt_anim_t = HURT_ANIM
	_knockback = (global_position - from_pos).normalized() * 180.0
	Sfx.play_at("player_hurt", global_position, sound_parent, -2.0)
	if hp <= 0.0:
		_enter(State.DEAD)
		velocity = Vector2.ZERO
		_sprite.play("die", false, 8.0)
		died.emit()


func _physics_process(delta: float) -> void:
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.35, 0.3), _hurt_flash / HURT_FLASH)
	if state == State.DEAD:
		return
	state_time += delta
	_read_toggles()
	_update_buffer(delta)
	_regen_stamina(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	match state:
		State.FREE:
			velocity = input_dir * float(cfg["speed"]) * float(armor()["speed_mult"])
			if input_dir.length() > 0.1:
				facing = input_dir.normalized()
			if _consume_buffer("dodge"):
				_try_dodge(input_dir)
		State.DODGE:
			var duration := float(cfg["dodge"]["duration"])
			velocity = _dodge_dir * float(cfg["dodge"]["speed"]) * (0.4 + 0.6 * (1.0 - state_time / duration))
			if state_time >= duration:
				_enter(State.FREE)

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	var before := global_position
	move_and_slide()
	var moved := global_position.distance_to(before)
	if state == State.FREE:
		_footsteps(moved)
	if not peaceful:
		_auto_shoot(delta)
	_update_light(delta)
	_update_anim(delta, moved / maxf(delta, 0.0001))


func _enter(s: State) -> void:
	state = s
	state_time = 0.0


# --- bow ---------------------------------------------------------------------------

func _auto_shoot(delta: float) -> void:
	_shot_cd -= delta
	if _shot_cd > 0.0 or state == State.DODGE:
		return
	var shot: Dictionary = cfg["shot"]
	var target := _pick_target(float(shot["range"]))
	if target == null:
		return
	_shot_cd = float(shot["interval"])
	var dir := (target.global_position - global_position).normalized()
	facing = dir
	var arrow := Arrow.new()
	arrow.velocity = dir * float(shot["speed"])
	arrow.damage = float(shot["damage"])
	arrow.life = float(shot["range"]) / float(shot["speed"]) * 1.3
	arrow.source_pos = global_position
	arrow.position = global_position + dir * 10.0 + Vector2(0, -8)
	sound_parent.add_child(arrow)
	_shot_anim_t = SHOT_ANIM
	Sfx.play_at("swing", global_position, sound_parent, -10.0)
	Events.noise_emitted.emit(global_position, float(shot["noise_radius"]), self)


## Nearest living enemy in range that stands in light and in line of sight.
func _pick_target(max_range: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d > best_d or not _line_of_sight(enemy.global_position):
			continue
		if not Lighting.is_lit(self, enemy.global_position):
			continue
		best_d = d
		best = enemy
	return best


func _line_of_sight(to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, to, Lighting.WALL_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- input / stamina ---------------------------------------------------------------

func _read_toggles() -> void:
	if Input.is_action_just_pressed("torch"):
		torch_on = not torch_on
		_apply_torch()
		Sfx.play_at("dodge", global_position, sound_parent, -14.0)
	if Input.is_action_just_pressed("armor"):
		armor_id = "plate" if armor_id == "leather" else "leather"
		Sfx.play_at("step_plate" if armor_id == "plate" else "step_soft", global_position, sound_parent, -6.0)


func _update_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("dodge"):
		_buffered = "dodge"
		_buffer_t = BUFFER_TIME
	_buffer_t -= delta
	if _buffer_t <= 0.0:
		_buffered = ""


func _consume_buffer(action: String) -> bool:
	if _buffered == action:
		_buffered = ""
		return true
	return false


func _regen_stamina(delta: float) -> void:
	_stamina_cooldown -= delta
	if state == State.FREE and _stamina_cooldown <= 0.0:
		stamina = minf(stamina + float(cfg["stamina_regen"]) * delta, max_stamina)


func _spend_stamina(cost: float) -> bool:
	if stamina < cost:
		return false
	stamina -= cost
	_stamina_cooldown = float(cfg["stamina_regen_delay"])
	return true


func _try_dodge(input_dir: Vector2) -> void:
	if not _spend_stamina(float(cfg["dodge"]["stamina_cost"])):
		return
	_dodge_dir = input_dir.normalized() if input_dir.length() > 0.1 else facing
	_enter(State.DODGE)
	Sfx.play_at("dodge", global_position, sound_parent, -8.0)
	if not peaceful:
		var noise := float(armor()["step_noise_radius"]) * float(cfg["dodge"]["noise_mult"])
		Events.noise_emitted.emit(global_position, noise, self)


func _footsteps(moved: float) -> void:
	_step_accum += moved
	if _step_accum < float(cfg["step_length"]):
		return
	_step_accum = 0.0
	var a := armor()
	var sound := "step_plate" if armor_id == "plate" else "step_soft"
	Sfx.play_at(sound, global_position, sound_parent, float(a["step_volume_db"]), 500.0)
	if not peaceful:
		Events.noise_emitted.emit(global_position, float(a["step_noise_radius"]), self)


# --- light / visuals -------------------------------------------------------------

func _apply_torch() -> void:
	if _light == null:
		return
	if torch_on:
		LightUtil.configure(_light, float(vision["torch_radius_px"]), float(vision["torch_energy"]), Balance.to_color(vision["torch_color"]))
	else:
		LightUtil.configure(_light, float(vision["dark_radius_px"]), float(vision["dark_energy"]), Balance.to_color(vision["dark_color"]))


func _update_light(delta: float) -> void:
	if not torch_on:
		return
	_flicker_t += delta
	var base := float(vision["torch_energy"])
	_light.energy = base * (1.0 + 0.06 * sin(_flicker_t * 13.0) + 0.04 * sin(_flicker_t * 29.7) + randf_range(-0.02, 0.02))


func _update_anim(delta: float, speed: float) -> void:
	_shot_anim_t -= delta
	_hurt_anim_t -= delta
	_sprite.set_face(facing.x)
	if state == State.DODGE:
		_sprite.play("dodge", false, 5.0 / float(cfg["dodge"]["duration"]))
	elif _hurt_anim_t > 0.0:
		_sprite.play("hurt", false, 4.0 / HURT_ANIM)
	elif _shot_anim_t > 0.0:
		if _sprite.anim != "shot":
			_sprite.play_for("shot", SHOT_ANIM)
	elif speed > 10.0:
		_sprite.play("run", true, 10.0)
	else:
		_sprite.play("idle", true, 5.0)
