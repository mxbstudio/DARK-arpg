class_name Brazier
extends Node2D
## Rare static light source with a crackling fire sound.

var _light: PointLight2D
var _base_energy := 1.0
var _t := 0.0


func _ready() -> void:
	z_index = -4
	var vision := Balance.section("vision")
	var audio := Balance.section("audio")
	_base_energy = float(vision["brazier_energy"])
	_light = LightUtil.make_light(float(vision["brazier_radius_px"]), _base_energy, Color(1.0, 0.55, 0.25))
	add_child(_light)
	var p := AudioStreamPlayer2D.new()
	p.stream = Sfx.stream("fire")
	p.volume_db = float(audio["brazier_fire_db"])
	p.max_distance = float(audio["brazier_fire_audible_px"])
	add_child(p)
	p.play()
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	_light.energy = _base_energy * (1.0 + 0.1 * sin(_t * 11.0) + 0.07 * sin(_t * 23.3))


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0.18, 0.17, 0.17))
	draw_circle(Vector2.ZERO, 5.0, Color(0.6, 0.22, 0.05))
	draw_circle(Vector2(1, -1), 2.5, Color(1.0, 0.6, 0.2))
