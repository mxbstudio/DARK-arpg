class_name EnemyBolt
extends Node2D
## A cultist's slow dark bolt. Glows faintly (it can be seen coming, but does not
## reveal enemies). Dodging through it avoids the hit.

const WALL_MASK := 1

var velocity := Vector2.ZERO
var damage := 10.0
var hit_radius := 6.0
var life := 4.0
var _t := 0.0


func _ready() -> void:
	z_index = 2
	var l := LightUtil.make_light(34.0, 0.7, Color(0.6, 0.35, 0.95))
	l.shadow_enabled = false
	add_child(l)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, WALL_MASK)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = next
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p != null and not p.is_dead() and p.global_position.distance_to(global_position + Vector2(0, 8)) <= hit_radius + Player.RADIUS:
			p.take_damage(damage, global_position - velocity.normalized() * 10.0)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.2 * sin(_t * 18.0)
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(0.3, 0.12, 0.45, 0.7))
	draw_circle(Vector2.ZERO, 2.5 * pulse, Color(0.85, 0.65, 1.0))
