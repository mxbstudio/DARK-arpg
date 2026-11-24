class_name Camp
extends Node2D
## The start camp (painted in Aschenreich): a safe hub around the heart fire.
## Runs start at the gate. Geometry comes from data/camp.json in image pixels.

const FLAME_SHADER := preload("res://assets/shaders/flame.gdshader")

var cfg: Dictionary = {}
var world_scale := 1.0
var spawn_point := Vector2.ZERO
var gate_point := Vector2.ZERO
var quiver_point := Vector2.ZERO

var _flames: Array[Sprite2D] = []
var _flame_base: Array[Vector2] = []
var _lights: Array[PointLight2D] = []
var _light_base: Array[float] = []
var _t := 0.0


func _ready() -> void:
	cfg = Balance.data_file("res://data/camp.json")
	world_scale = float(cfg["scale"])
	y_sort_enabled = true
	spawn_point = _pt(cfg["spawn"])
	gate_point = _pt(cfg["gate"])
	quiver_point = _pt(cfg["quiver"])

	var bg := Sprite2D.new()
	bg.texture = load(String(cfg["image"]))
	bg.centered = false
	bg.scale = Vector2(world_scale, world_scale)
	bg.z_index = -10
	add_child(bg)

	_build_collision()
	_build_fires()
	var rack := QuiverRack.new()
	rack.position = quiver_point
	add_child(rack)


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
		# Same z as the actors: y-sorting (bottom of the flame) decides who is in front.
		var mat := ShaderMaterial.new()
		mat.shader = FLAME_SHADER
		mat.set_shader_parameter("seed", float(_flames.size()) * 3.7)
		mat.set_shader_parameter("strength", 0.05 if float(f["k"]) >= 1.0 else 0.08)
		spr.material = mat
		add_child(spr)
		_flames.append(spr)
		_flame_base.append(spr.scale)
		if float(f["k"]) < 1.0:
			_add_light(spr.position, float(small["radius"]), float(small["energy"]))

	_add_sparks(_pt(cfg["heart_fire"]) + Vector2(0, -30))

	var p := AudioStreamPlayer2D.new()
	p.stream = Sfx.stream("fire")
	p.volume_db = -6.0
	p.max_distance = 900.0
	p.position = _pt(cfg["heart_fire"])
	add_child(p)
	p.play()


## Embers rising from the heart fire.
func _add_sparks(pos: Vector2) -> void:
	var sp := CPUParticles2D.new()
	sp.position = pos
	sp.z_index = 1
	sp.amount = 40
	sp.lifetime = 2.2
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 18.0
	sp.direction = Vector2(0, -1)
	sp.spread = 25.0
	sp.gravity = Vector2(6, -40)
	sp.initial_velocity_min = 20.0
	sp.initial_velocity_max = 55.0
	sp.scale_amount_min = 0.8
	sp.scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.45, 0.1, 0.8), Color(0.6, 0.15, 0.05, 0.0)])
	sp.color_ramp = ramp
	add_child(sp)


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
		var lick := 1.0 + 0.04 * sin(_t * 5.0 + i * 1.7) + 0.03 * sin(_t * 11.3 + i)
		_flames[i].scale = Vector2(_flame_base[i].x * (2.0 - lick), _flame_base[i].y * lick)
	for i in _lights.size():
		_lights[i].energy = _light_base[i] * (1.0 + 0.08 * sin(_t * 11.0 + i) + 0.05 * sin(_t * 23.0 + i * 2.0))


func is_at_gate(pos: Vector2) -> bool:
	return pos.distance_to(gate_point) <= float(cfg["gate_reach_px"])


func is_at_quiver(pos: Vector2) -> bool:
	return pos.distance_to(quiver_point) <= float(cfg["quiver_reach_px"])


func ambient_color() -> Color:
	return Balance.to_color(cfg["ambient"])
