class_name SheetSprite
extends Sprite2D
## Plays frame animations from a sprite sheet described in data/sprites.json.
## The sheet faces right; `face` flips it. The node's origin is the actor's feet.

signal finished(anim: String)

var anim := ""
var looping := true
var fps := 10.0

var _frames: Array = []
var _t := 0.0
var _def: Dictionary = {}
var _scale := 1.0
var _done := false


func setup(sheet_id: String) -> void:
	_def = Balance.data_file("res://data/sprites.json")[sheet_id]
	texture = load(String(_def["texture"]))
	hframes = int(_def["cols"])
	vframes = int(_def["rows"])
	centered = false
	var a: Array = _def["anchor"]
	offset = -Vector2(float(a[0]), float(a[1]))
	_scale = float(_def["scale"])
	scale = Vector2(_scale, _scale)
	position = Vector2(0, float(_def["feet_offset"]))
	play("idle")


func has_anim(anim_name: String) -> bool:
	return (_def["anims"] as Dictionary).has(anim_name)


## Starts `anim_name` unless it is already playing (pass restart to force).
func play(anim_name: String, loop := true, frames_per_second := 10.0, restart := false) -> void:
	if anim_name == anim and not restart:
		fps = frames_per_second
		return
	anim = anim_name
	looping = loop
	fps = frames_per_second
	_frames = _def["anims"][anim_name]
	_t = 0.0
	_done = false
	frame = int(_frames[0])


## Plays `anim_name` so that it lasts exactly `duration` seconds (one shot).
func play_for(anim_name: String, duration: float) -> void:
	var count: int = (_def["anims"][anim_name] as Array).size()
	play(anim_name, false, count / maxf(duration, 0.01), true)


func set_face(dir_x: float) -> void:
	if absf(dir_x) > 0.05:
		scale.x = _scale * (-1.0 if dir_x < 0.0 else 1.0)


func _process(delta: float) -> void:
	if _frames.is_empty() or _done:
		return
	_t += delta * fps
	var i := int(_t)
	if i >= _frames.size():
		if looping:
			_t = fmod(_t, _frames.size())
			i = int(_t)
		else:
			i = _frames.size() - 1
			_done = true
			finished.emit(anim)
	frame = int(_frames[i])
