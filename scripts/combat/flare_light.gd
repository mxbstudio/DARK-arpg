class_name FlareLight
extends Node2D
## A burning arrow stuck in the ground: lights up the area for a few seconds,
## which also lets the bow target enemies there.

var radius := 150.0
var duration := 6.0
var _t := 0.0
var _light: PointLight2D


func _ready() -> void:
	add_to_group("light_sources")
	_light = LightUtil.make_light(radius, 1.0, Color(1.0, 0.8, 0.5))
	add_child(_light)


func light_reach() -> float:
	return radius * float(Balance.section("vision")["reveal_fraction"]) * _fade()


func _fade() -> float:
	return clampf((duration - _t) / 1.0, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	_light.energy = (0.9 + 0.15 * sin(_t * 17.0) + randf_range(-0.05, 0.05)) * _fade()
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(-4, 3), Vector2(2, -5), Color(0.6, 0.5, 0.4), 1.5)
	draw_circle(Vector2(2, -6), 2.0 + sin(_t * 20.0) * 0.4, Color(1.0, 0.75, 0.3))
