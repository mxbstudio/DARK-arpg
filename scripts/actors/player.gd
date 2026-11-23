class_name Player
extends CharacterBody2D
## Player: slow, weighty melee with stamina, a torch, and armor that makes noise.

signal died

enum State { FREE, WINDUP, ACTIVE, RECOVERY, DODGE, DEAD }

const RADIUS := 9.0
const BUFFER_TIME := 0.18
const HURT_FLASH := 0.25

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
## Node that receives positional one-shot sounds (the current floor).
var sound_parent: Node2D

var _dodge_dir := Vector2.ZERO
var _hit_this_swing: Array[Node] = []
var _stamina_cooldown := 0.0
var _knockback := Vector2.ZERO
var _hurt_flash := 0.0
var _step_accum := 0.0
var _buffered := ""
var _buffer_t := 0.0
var _flicker_t := 0.0
var _light: PointLight2D
var _camera: Camera2D


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

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

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


func take_damage(amount: float, from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	if state == State.DODGE and state_time < float(cfg["dodge"]["iframes"]):
		return  # dodged through the attack
	hp = maxf(hp - amount * (1.0 - float(armor()["damage_reduction"])), 0.0)
	_hurt_flash = HURT_FLASH
	_knockback = (global_position - from_pos).normalized() * 180.0
	Sfx.play_at("player_hurt", global_position, sound_parent, -2.0)
	if hp <= 0.0:
		_enter(State.DEAD)
		velocity = Vector2.ZERO
		died.emit()
	elif state == State.WINDUP:
		_enter(State.FREE)  # getting hit interrupts the swing


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		queue_redraw()
		return
	state_time += delta
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_read_toggles()
	_update_buffer(delta)
	_regen_stamina(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var atk: Dictionary = cfg["attack"]
	match state:
		State.FREE:
			_aim()
			velocity = input_dir * float(cfg["speed"]) * float(armor()["speed_mult"])
			if _consume_buffer("attack"):
				_try_attack()
			elif _consume_buffer("dodge"):
				_try_dodge(input_dir)
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if state_time >= float(atk["windup"]):
				_enter(State.ACTIVE)
				Sfx.play_at("swing", global_position, sound_parent, -4.0)
				Events.noise_emitted.emit(global_position, float(atk["noise_radius"]), self)
		State.ACTIVE:
			velocity = facing * float(atk["lunge_speed"])
			_check_hits()
			if state_time >= float(atk["active"]):
				_enter(State.RECOVERY)
		State.RECOVERY:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if state_time >= float(atk["recovery"]):
				_enter(State.FREE)
		State.DODGE:
			var duration := float(cfg["dodge"]["duration"])
			velocity = _dodge_dir * float(cfg["dodge"]["speed"]) * (0.4 + 0.6 * (1.0 - state_time / duration))
			if state_time >= duration:
				_enter(State.FREE)

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	var before := global_position
	move_and_slide()
	if state == State.FREE:
		_footsteps(global_position.distance_to(before))
	_update_light(delta)
	queue_redraw()


func _enter(s: State) -> void:
	state = s
	state_time = 0.0


func _aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 2.0:
		facing = to_mouse.normalized()


func _read_toggles() -> void:
	if Input.is_action_just_pressed("torch"):
		torch_on = not torch_on
		_apply_torch()
		Sfx.play_at("dodge", global_position, sound_parent, -14.0)
	if Input.is_action_just_pressed("armor"):
		armor_id = "plate" if armor_id == "leather" else "leather"
		Sfx.play_at("step_plate" if armor_id == "plate" else "step_soft", global_position, sound_parent, -6.0)


func _update_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_buffered = "attack"
		_buffer_t = BUFFER_TIME
	elif Input.is_action_just_pressed("dodge"):
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


func _try_attack() -> void:
	if not _spend_stamina(float(cfg["attack"]["stamina_cost"])):
		return
	_hit_this_swing.clear()
	_enter(State.WINDUP)


func _try_dodge(input_dir: Vector2) -> void:
	if not _spend_stamina(float(cfg["dodge"]["stamina_cost"])):
		return
	_dodge_dir = input_dir.normalized() if input_dir.length() > 0.1 else facing
	_enter(State.DODGE)
	Sfx.play_at("dodge", global_position, sound_parent, -8.0)
	var noise := float(armor()["step_noise_radius"]) * float(cfg["dodge"]["noise_mult"])
	Events.noise_emitted.emit(global_position, noise, self)


func _check_hits() -> void:
	var atk: Dictionary = cfg["attack"]
	var reach := float(atk["reach"])
	var half_arc := deg_to_rad(float(atk["arc_deg"])) * 0.5
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive() or _hit_this_swing.has(enemy):
			continue
		var to := enemy.global_position - global_position
		if to.length() > reach + enemy.radius:
			continue
		if absf(facing.angle_to(to)) > half_arc:
			continue
		_hit_this_swing.append(enemy)
		enemy.take_damage(float(atk["damage"]), global_position)


func _footsteps(moved: float) -> void:
	_step_accum += moved
	if _step_accum < float(cfg["step_length"]):
		return
	_step_accum = 0.0
	var a := armor()
	var sound := "step_plate" if armor_id == "plate" else "step_soft"
	Sfx.play_at(sound, global_position, sound_parent, float(a["step_volume_db"]), 500.0)
	Events.noise_emitted.emit(global_position, float(a["step_noise_radius"]), self)


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


func _draw() -> void:
	var body_col := Color(0.62, 0.62, 0.66) if armor_id == "plate" else Color(0.5, 0.4, 0.3)
	if _hurt_flash > 0.0:
		body_col = body_col.lerp(Color(1.0, 0.2, 0.15), _hurt_flash / HURT_FLASH)
	if state == State.DEAD:
		draw_set_transform(Vector2.ZERO, facing.angle(), Vector2(1.4, 0.7))
		draw_circle(Vector2.ZERO, RADIUS, body_col.darkened(0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var atk: Dictionary = cfg["attack"]
	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	draw_circle(Vector2.ZERO, RADIUS, body_col)
	draw_circle(Vector2(2, 0), 5.0, body_col.lightened(0.15))

	var blade := 0.6
	match state:
		State.WINDUP:
			blade = -lerpf(0.6, 1.6, clampf(state_time / float(atk["windup"]), 0.0, 1.0))
		State.ACTIVE:
			blade = lerpf(-1.6, 1.4, clampf(state_time / float(atk["active"]), 0.0, 1.0))
		State.RECOVERY:
			blade = 1.4
	var dir := Vector2.from_angle(blade)
	var reach := float(atk["reach"])
	draw_line(dir * 6.0, dir * (6.0 + reach * 0.75), Color(0.75, 0.75, 0.78), 2.0)
	if state == State.ACTIVE:
		var half := deg_to_rad(float(atk["arc_deg"])) * 0.5
		draw_arc(Vector2.ZERO, reach, -half, half, 16, Color(0.9, 0.9, 0.9, 0.25), 2.0)
	if torch_on:
		draw_circle(Vector2(0, -8), 2.5, Color(1.0, 0.6, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
