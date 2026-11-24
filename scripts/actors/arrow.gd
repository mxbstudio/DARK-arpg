class_name Arrow
extends Node2D
## A flying arrow. Stops at walls, damages the first enemy it touches.

const WALL_MASK := 1
const HIT_RADIUS := 6.0

var velocity := Vector2.ZERO
var damage := 10.0
var life := 1.0
var source_pos := Vector2.ZERO


func _ready() -> void:
	z_index = 2
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, WALL_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if Geometry2D.get_closest_point_to_segment(enemy.global_position, global_position, next).distance_to(enemy.global_position) <= enemy.radius + HIT_RADIUS:
			enemy.take_damage(damage, source_pos)
			queue_free()
			return
	global_position = next


func _draw() -> void:
	draw_line(Vector2(-9, 0), Vector2(3, 0), Color(0.75, 0.68, 0.55), 1.5)
	draw_line(Vector2(3, 0), Vector2(6, 0), Color(0.85, 0.85, 0.9), 2.0)
	draw_line(Vector2(-9, 0), Vector2(-12, -2), Color(0.6, 0.55, 0.5), 1.0)
	draw_line(Vector2(-9, 0), Vector2(-12, 2), Color(0.6, 0.55, 0.5), 1.0)
