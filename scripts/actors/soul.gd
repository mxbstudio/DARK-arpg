class_name Soul
extends Node2D
## Experience dropped by slain foes (like Vampire Survivors). Drifts to the hero
## once they come close and is absorbed. Faint glow, does not reveal enemies.

var value := 1
var _vel := Vector2.ZERO
var _t := 0.0
var _homing := false


## Drops `xp` worth of souls at `pos` next to `from` (into its parent).
static func drop(from: Node, pos: Vector2, xp: int) -> void:
	if xp <= 0 or from == null or from.get_parent() == null:
		return
	var s := Soul.new()
	s.value = xp
	s.position = pos + Vector2(0, -6)
	s._vel = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)
	from.get_parent().add_child.call_deferred(s)


func _ready() -> void:
	z_index = 1
	var l := LightUtil.make_light(18.0 + 4.0 * minf(value, 6), 0.45, Color(0.6, 0.85, 1.0))
	l.shadow_enabled = false
	add_child(l)


func _physics_process(delta: float) -> void:
	_t += delta
	var prog := Balance.section("progression")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.is_dead() and not player.peaceful:
		var to := player.global_position + Vector2(0, -8) - global_position
		var reach := float(prog["pickup_radius_px"]) * player.stat("pickup_mult")
		if to.length() < reach or _homing:
			_homing = true
			_vel = _vel.lerp(to.normalized() * float(prog["soul_speed"]), minf(1.0, delta * 6.0))
		if to.length() < 10.0:
			player.add_xp(value)
			queue_free()
			return
	if not _homing:
		_vel = _vel.move_toward(Vector2.ZERO, 120.0 * delta)
	position += _vel * delta
	queue_redraw()


func _draw() -> void:
	var r := 2.0 + minf(value, 6) * 0.5
	var bob := sin(_t * 4.0) * 1.5
	draw_circle(Vector2(0, bob), r * 1.8, Color(0.4, 0.7, 1.0, 0.25))
	draw_circle(Vector2(0, bob), r, Color(0.85, 0.95, 1.0))
