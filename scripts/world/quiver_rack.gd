class_name QuiverRack
extends Node2D
## Camp station: a rack of arrows. Standing here opens the skill-row menu.


func _ready() -> void:
	var l := LightUtil.make_light(70.0, 0.45, Color(1.0, 0.7, 0.4))
	l.shadow_enabled = false
	l.position = Vector2(0, -12)
	add_child(l)


func _draw() -> void:
	var wood := Color(0.36, 0.24, 0.15)
	draw_line(Vector2(-10, 0), Vector2(-10, -22), wood, 2.5)
	draw_line(Vector2(10, 0), Vector2(10, -22), wood, 2.5)
	draw_line(Vector2(-12, -18), Vector2(12, -18), wood, 2.0)
	draw_line(Vector2(-12, -6), Vector2(12, -6), wood, 2.0)
	for i in 5:
		var x := -7.0 + i * 3.5
		draw_line(Vector2(x, -2), Vector2(x + 1.5, -26), Color(0.7, 0.62, 0.5), 1.0)
		draw_line(Vector2(x + 1.5, -26), Vector2(x - 0.5, -29), Color(0.85, 0.8, 0.75), 1.5)
