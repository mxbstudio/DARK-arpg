class_name Camp
extends Node2D
## The start camp (painted in Aschenreich): a safe hub around the heart fire.
## Runs start at the gate. Geometry comes from data/camp.json in image pixels.

var cfg: Dictionary = {}
var world_scale := 1.0
var spawn_point := Vector2.ZERO
var gate_point := Vector2.ZERO

var _flames: Array[Sprite2D] = []
var _flame_base: Array[Vector2] = []
var _lights: Array[PointLight2D] = []
var _light_base: Array[float] = []
var _t := 0.0


func _ready() -> void:
	cfg = Balance.data_file("res://data/camp.json")
	world_scale = float(cfg["scale"])
	spawn_point = _pt(cfg["spawn"])
	gate_point = _pt(cfg["gate"])

	var bg := Sprite2D.new()
	bg.texture = load(String(cfg["image"]))
	bg.centered = false
	bg.scale = Vector2(world_scale, world_scale)
	bg.z_index = -10
	add_child(bg)

	_build_collision()
	_build_fires()


## Converts a source-image point to world coordinates.
func _pt(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1])) * world_scale


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	# Outer edge of the walkable platform as a closed chain of segments.
	var poly: Array = cfg["walkable"]
	var segs := PackedVector2Array()
	for i in poly.size():
		segs.append(_pt(poly[i]))
		segs.append(_pt(poly[(i + 1) % poly.size()]))
	var edge := CollisionShape2D.new()
	var concave := ConcavePolygonShape2D.new()
	concave.segments = segs
	edge.shape = concave
	body.add_child(edge)

	# Tents, crates and fires as solid ellipses.
	for o: Array in cfg["obstacles"]:
		var c := _pt([o[0], o[1]])
		var rx := float(o[2]) * world_scale
		var ry := float(o[3]) * world_scale
		var pts := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		var col := CollisionPolygon2D.new()
		col.polygon = pts
		body.add_child(col)


func _build_fires() -> void:
	var heart: Dictionary = cfg["heart_fire_light"]
	_add_light(_pt(cfg["heart_fire"]), float(heart["radius"]), float(heart["energy"]))

	var small: Dictionary = cfg["small_fire_light"]
	for f: Dictionary in cfg["flames"]:
		var tex: Texture2D = load(String(f["texture"]))
		var k := float(f["k"]) * world_scale
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		# Anchor at the bottom centre so the flame licks upwards when stretched.
		spr.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		spr.position = _pt(f["pos"]) + Vector2(tex.get_width() * 0.5, tex.get_height()) * k
		spr.scale = Vector2(k, k)
		spr.z_index = -9
		add_child(spr)
		_flames.append(spr)
		_flame_base.append(spr.scale)
		if float(f["k"]) < 1.0:
			_add_light(spr.position, float(small["radius"]), float(small["energy"]))

	var p := AudioStreamPlayer2D.new()
	p.stream = Sfx.stream("fire")
	p.volume_db = -6.0
	p.max_distance = 900.0
	p.position = _pt(cfg["heart_fire"])
	add_child(p)
	p.play()


func _add_light(pos: Vector2, radius: float, energy: float) -> void:
	var l := LightUtil.make_light(radius, energy, Color(1.0, 0.62, 0.32))
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	_lights.append(l)
	_light_base.append(energy)


func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var lick := 1.0 + 0.06 * sin(_t * 7.0 + i * 1.7) + 0.04 * sin(_t * 13.3 + i)
		_flames[i].scale = Vector2(_flame_base[i].x * (2.0 - lick), _flame_base[i].y * lick)
		_flames[i].modulate.a = 0.75 + 0.15 * sin(_t * 9.0 + i)
	for i in _lights.size():
		_lights[i].energy = _light_base[i] * (1.0 + 0.08 * sin(_t * 11.0 + i) + 0.05 * sin(_t * 23.0 + i * 2.0))


func is_at_gate(pos: Vector2) -> bool:
	return pos.distance_to(gate_point) <= float(cfg["gate_reach_px"])


func ambient_color() -> Color:
	return Balance.to_color(cfg["ambient"])
