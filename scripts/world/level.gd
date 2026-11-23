class_name Level
extends Node2D
## One procedurally generated dungeon floor.
## Owns the cell grid, wall collision, light occluders and AI pathfinding.

const SOLID := 1
const OPEN := 0
const WALL_LAYER := 1
## Occluders sit on the wall's center line, so the wall half facing the room stays lit.
const OCCLUDER_THICKNESS := 0.25

const FLOOR_COLOR := Color(0.18, 0.165, 0.155)
const WALL_COLOR := Color(0.44, 0.41, 0.39)

var width := 0
var height := 0
var cell := 32
var grid := PackedByteArray()
var rooms: Array[Rect2i] = []
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var astar := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()

var _edge := PackedByteArray()
var _shade := PackedFloat32Array()
var _decals: Array[Dictionary] = []


func generate(seed_value: int, cfg: Dictionary) -> void:
	rng.seed = seed_value
	width = int(cfg["map_w"])
	height = int(cfg["map_h"])
	cell = int(cfg["cell"])
	grid.resize(width * height)
	grid.fill(SOLID)
	rooms.clear()
	_place_rooms(int(cfg["rooms_min"]), int(cfg["rooms_max"]))
	_connect_rooms()
	_pick_start_and_exit()
	_build_walls()
	_build_astar()
	_build_visuals()
	z_index = -10
	queue_redraw()


# --- queries -------------------------------------------------------------------

func is_open(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return false
	return grid[c.y * width + c.x] == OPEN


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * cell, (c.y + 0.5) * cell)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if not is_open(a) or not is_open(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b)


func random_open_point_near(pos: Vector2, radius_cells: int, r: RandomNumberGenerator) -> Vector2:
	var c := world_to_cell(pos)
	for i in 30:
		var t := c + Vector2i(r.randi_range(-radius_cells, radius_cells), r.randi_range(-radius_cells, radius_cells))
		if is_open(t):
			return cell_center(t)
	return pos


## Enemy spawn positions inside rooms, away from the start and spread out.
func spawn_points(count: int, min_dist_cells: int) -> Array[Vector2]:
	var candidates: Array[Vector2i] = []
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if c.distance_to(start_cell) >= min_dist_cells:
					candidates.append(c)
	_shuffle(candidates)
	var picked: Array[Vector2i] = []
	var result: Array[Vector2] = []
	for c in candidates:
		if result.size() >= count:
			break
		var spaced := true
		for p in picked:
			if p.distance_to(c) < 3.0:
				spaced = false
				break
		if spaced:
			picked.append(c)
			result.append(cell_center(c))
	return result


func brazier_points(count: int) -> Array[Vector2]:
	var pool: Array[Rect2i] = []
	for r in rooms:
		if not r.has_point(start_cell):
			pool.append(r)
	_shuffle(pool)
	var result: Array[Vector2] = []
	for i in mini(count, pool.size()):
		var r := pool[i]
		result.append(cell_center(r.position + Vector2i(1, 1)))
	return result


# --- generation ----------------------------------------------------------------

func _open(x: int, y: int) -> void:
	if x >= 1 and y >= 1 and x < width - 1 and y < height - 1:
		grid[y * width + x] = OPEN


func _place_rooms(min_rooms: int, max_rooms: int) -> void:
	var target := rng.randi_range(min_rooms, max_rooms)
	var attempts := 0
	while rooms.size() < target and attempts < 400:
		attempts += 1
		var rw := rng.randi_range(4, 10)
		var rh := rng.randi_range(4, 8)
		var r := Rect2i(rng.randi_range(2, width - rw - 3), rng.randi_range(2, height - rh - 3), rw, rh)
		var overlaps := false
		for other in rooms:
			if other.grow(2).intersects(r):
				overlaps = true
				break
		if overlaps:
			continue
		rooms.append(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_open(x, y)


func _connect_rooms() -> void:
	# Chain rooms left to right (guarantees connectivity), then add a few loops.
	var order: Array[Rect2i] = rooms.duplicate()
	order.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().x < b.get_center().x)
	for i in range(1, order.size()):
		_corridor(order[i - 1].get_center(), order[i].get_center())
	for i in rng.randi_range(1, 3):
		var a := rooms[rng.randi() % rooms.size()]
		var b := rooms[rng.randi() % rooms.size()]
		if a != b:
			_corridor(a.get_center(), b.get_center())


func _corridor(a: Vector2i, b: Vector2i) -> void:
	var wide := rng.randf() < 0.5
	var corner := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_carve_line(a, corner, wide)
	_carve_line(corner, b, wide)


func _carve_line(a: Vector2i, b: Vector2i, wide: bool) -> void:
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var p := a
	while true:
		_open(p.x, p.y)
		if wide:
			_open(p.x + 1, p.y)
			_open(p.x, p.y + 1)
			_open(p.x + 1, p.y + 1)
		if p == b:
			break
		p += step


func _pick_start_and_exit() -> void:
	start_cell = rooms[0].get_center()
	var best := -1.0
	for r in rooms:
		var d := Vector2(r.get_center()).distance_to(Vector2(start_cell))
		if d > best:
			best = d
			exit_cell = r.get_center()


func _edge_at(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	return _edge[y * width + x] == 1


func _build_walls() -> void:
	# Only solid cells touching open floor matter (collision, occlusion, drawing).
	_edge.resize(width * height)
	_edge.fill(0)
	for y in height:
		for x in width:
			if is_open(Vector2i(x, y)):
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if is_open(Vector2i(x + dx, y + dy)):
						_edge[y * width + x] = 1

	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	add_child(body)
	var t := cell * OCCLUDER_THICKNESS

	# Horizontal runs: one collider each, plus a center-line occluder.
	for y in height:
		var x := 0
		while x < width:
			if not _edge_at(x, y):
				x += 1
				continue
			var x0 := x
			while x < width and _edge_at(x, y):
				x += 1
			var n := x - x0
			_add_collider(body, Rect2(x0 * cell, y * cell, n * cell, cell))
			_add_occluder(Rect2((x0 + 0.5) * cell - t * 0.5, (y + 0.5) * cell - t * 0.5, (n - 1) * cell + t, t))

	# Vertical runs: occluders only (colliders already cover every cell).
	for x in width:
		var y := 0
		while y < height:
			if not _edge_at(x, y):
				y += 1
				continue
			var y0 := y
			while y < height and _edge_at(x, y):
				y += 1
			var n := y - y0
			if n >= 2:
				_add_occluder(Rect2((x + 0.5) * cell - t * 0.5, (y0 + 0.5) * cell - t * 0.5, t, (n - 1) * cell + t))


func _add_collider(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)


func _add_occluder(r: Rect2) -> void:
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	add_child(occ)


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(cell, cell)
	astar.offset = Vector2(cell, cell) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			if not is_open(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)


func _build_visuals() -> void:
	_shade.resize(width * height)
	for i in _shade.size():
		_shade[i] = rng.randf_range(0.8, 1.1)
	_decals.clear()
	for y in height:
		for x in width:
			if not is_open(Vector2i(x, y)) or rng.randf() > 0.06:
				continue
			var p := cell_center(Vector2i(x, y)) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
			_decals.append({"kind": rng.randi() % 3, "pos": p, "rot": rng.randf() * TAU, "size": rng.randf_range(3.0, 7.0)})


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Walls read as raised stone blocks: brick top, plus a darker front face where floor lies below.
func _draw_wall(r: Rect2, v: float, front_face: bool) -> void:
	var top := Color(WALL_COLOR.r * v, WALL_COLOR.g * v, WALL_COLOR.b * v)
	var mortar := Color(0.14, 0.13, 0.13)
	draw_rect(r, top)
	var half := r.size.y * 0.5
	draw_line(Vector2(r.position.x, r.position.y + half), Vector2(r.end.x, r.position.y + half), mortar, 1.0)
	draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.position.y + half), mortar, 1.0)
	draw_line(Vector2(r.position.x, r.position.y + half), Vector2(r.position.x, r.end.y), mortar, 1.0)
	if front_face:
		var face := Rect2(r.position.x, r.end.y - r.size.y * 0.35, r.size.x, r.size.y * 0.35)
		draw_rect(face, top.darkened(0.55))
		draw_line(face.position, Vector2(face.end.x, face.position.y), top.lightened(0.25), 1.0)
	draw_rect(r, mortar, false, 1.0)


func _draw() -> void:
	for y in height:
		for x in width:
			var r := Rect2(x * cell, y * cell, cell, cell)
			var v := _shade[y * width + x]
			if is_open(Vector2i(x, y)):
				draw_rect(r, Color(FLOOR_COLOR.r * v, FLOOR_COLOR.g * v, FLOOR_COLOR.b * v))
				draw_rect(r, Color(0.1, 0.09, 0.09), false, 1.0)
			elif _edge_at(x, y):
				_draw_wall(r, v, is_open(Vector2i(x, y + 1)))
	for d in _decals:
		var p: Vector2 = d["pos"]
		var s: float = d["size"]
		match int(d["kind"]):
			0:  # bones
				var dir := Vector2.from_angle(d["rot"]) * s
				draw_line(p - dir, p + dir, Color(0.55, 0.52, 0.45), 1.5)
				draw_circle(p - dir, 1.5, Color(0.55, 0.52, 0.45))
				draw_circle(p + dir, 1.5, Color(0.55, 0.52, 0.45))
			1:  # dark stain
				draw_circle(p, s, Color(0.12, 0.08, 0.08, 0.8))
			2:  # crack
				var dir2 := Vector2.from_angle(d["rot"]) * s * 1.5
				draw_polyline(PackedVector2Array([p - dir2, p + dir2.rotated(0.6) * 0.3, p + dir2]), Color(0.08, 0.07, 0.07), 1.0)
