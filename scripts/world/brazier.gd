class_name Brazier
extends Node2D
## Rare static light source with a crackling fire sound.

var _light: PointLight2D
var _base_energy := 1.0
var _t := 0.0
var _reach := 0.0
var _lit := true
var _smother := 0.0
var _fire_snd: AudioStreamPlayer2D


func _ready() -> void:
	z_index = -4
	add_to_group("light_sources")
	add_to_group("braziers")
	var vision := Balance.section("vision")
	var audio := Balance.section("audio")
	_base_energy = float(vision["brazier_energy"])
	_reach = float(vision["brazier_radius_px"]) * float(vision["reveal_fraction"])
	_light = LightUtil.make_light(float(vision["brazier_radius_px"]), _base_energy, Color(1.0, 0.55, 0.25))
	add_child(_light)
	var p := AudioStreamPlayer2D.new()
	_fire_snd = p
	p.stream = Sfx.stream("fire")
	p.volume_db = float(audio["brazier_fire_db"])
	p.max_distance = float(audio["brazier_fire_audible_px"])
	add_child(p)
	p.play()
	_t = randf() * 10.0


## How far this fire reveals enemies (see Lighting).
func light_reach() -> float:
	return _reach if _lit else 0.0


func is_lit() -> bool:
	return _lit


## A cultist smothers the fire; returns true once it is out.
func smother(delta: float, total: float) -> bool:
	if not _lit:
		return true
	_smother += delta
	if _smother < total:
		return false
	_lit = false
	_light.enabled = false
	_fire_snd.stop()
	Sfx.play_at("snuff", global_position, get_parent() as Node2D, -2.0, 600.0)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	_t += delta
	if not _lit:
		return
	# Gutters while being smothered.
	var gutter := 1.0 - 0.6 * clampf(_smother / 2.5, 0.0, 1.0)
	_light.energy = gutter * _base_energy * (1.0 + 0.1 * sin(_t * 11.0) + 0.07 * sin(_t * 23.3))


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0.18, 0.17, 0.17))
	if not _lit:
		draw_circle(Vector2.ZERO, 5.0, Color(0.08, 0.07, 0.07))
		return
	draw_circle(Vector2.ZERO, 5.0, Color(0.6, 0.22, 0.05))
	draw_circle(Vector2(1, -1), 2.5, Color(1.0, 0.6, 0.2))
