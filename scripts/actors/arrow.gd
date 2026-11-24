class_name Arrow
extends Node2D
## A flying arrow fired by a skill. Stops at walls; on hit it applies damage,
## crits, chill, knockback and the skill's triggers (on_crit / on_kill).

const WALL_MASK := 1
const HIT_RADIUS := 6.0

var velocity := Vector2.ZERO
var damage := 10.0
var life := 1.0
var source_pos := Vector2.ZERO
var crit := false
## 0 = stops at the first enemy, n = passes through n more, -1 = through all.
var pierce := 0
var knockback := 0.0
var chill := 0.0
var on_crit: Dictionary = {}
var on_kill: Dictionary = {}
## Non-empty for a flare: {"light_radius", "light_time"}.
var flare: Dictionary = {}
var color := Color(0.75, 0.68, 0.55)
var shooter: Player

var _hit: Array[Node] = []


func _ready() -> void:
	z_index = 2
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_end()
		return
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, WALL_MASK)
	var wall := get_world_2d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		global_position = wall["position"] - velocity.normalized() * 3.0
		_end()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive() or _hit.has(enemy):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, global_position, next)
		if closest.distance_to(enemy.global_position) <= enemy.radius + HIT_RADIUS:
			global_position = closest
			if hit_enemy(enemy):
				return
	global_position = next


## Applies this arrow to `enemy`. Returns true when the arrow is used up.
func hit_enemy(enemy: Enemy) -> bool:
	_hit.append(enemy)
	var killed := enemy.take_damage(damage, source_pos)
	FloatText.spawn(self, enemy.global_position + Vector2(0, -26), ("%d!" if crit else "%d") % int(damage),
			Color(1.0, 0.82, 0.35) if crit else Color(0.92, 0.88, 0.8))
	if not killed:
		if chill > 0.0:
			enemy.apply_chill(chill)
		if knockback > 0.0:
			enemy.push(velocity.normalized() * knockback)
	if crit and on_crit.has("heal") and shooter != null:
		shooter.heal_amount(float(on_crit["heal"]))
	if killed and on_kill.has("burst_damage"):
		_burst(enemy.global_position, float(on_kill["burst_damage"]), float(on_kill["burst_radius"]), enemy)
	if not flare.is_empty():
		_end()
		return true
	if pierce == 0:
		queue_free()
		return true
	if pierce > 0:
		pierce -= 1
	return false


func _burst(center: Vector2, amount: float, radius: float, origin: Enemy) -> void:
	Sfx.play_at("hit", center, get_parent() as Node2D, -2.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == origin or not e.is_alive():
			continue
		if e.global_position.distance_to(center) <= radius + e.radius:
			e.take_damage(amount, center)
			FloatText.spawn(self, e.global_position + Vector2(0, -26), "%d" % int(amount), Color(0.8, 0.85, 0.95))


## End of flight: flares stay stuck in the ground and burn.
func _end() -> void:
	if not flare.is_empty() and get_parent() != null:
		var light := FlareLight.new()
		light.radius = float(flare["light_radius"])
		light.duration = float(flare["light_time"])
		light.position = global_position
		get_parent().add_child(light)
	queue_free()


func _draw() -> void:
	var tip := Color(1.0, 0.85, 0.4) if crit else Color(0.85, 0.85, 0.9)
	draw_line(Vector2(-9, 0), Vector2(3, 0), color, 1.5)
	draw_line(Vector2(3, 0), Vector2(6, 0), tip, 2.0)
	draw_line(Vector2(-9, 0), Vector2(-12, -2), color.darkened(0.2), 1.0)
	draw_line(Vector2(-9, 0), Vector2(-12, 2), color.darkened(0.2), 1.0)
	if not flare.is_empty():
		draw_circle(Vector2(6, 0), 2.0, Color(1.0, 0.75, 0.3))
