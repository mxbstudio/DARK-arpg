class_name TouchControls
extends CanvasLayer
## On-screen controls for touch devices: floating move stick (left half),
## action buttons (right). Feeds the regular input actions, so gameplay code
## does not care where input comes from. Multi-touch capable.

const LABEL_COLOR := Color(1, 1, 1, 0.85)

## Set by main.gd: show a "new run" button on the death screen.
var show_restart := false
## Set by main.gd: highlight the interact button while standing on the stairs.
var interact_ready := false

var _cfg: Dictionary = {}
var _canvas: Control
var _font: Font

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _buttons: Array[Dictionary] = []
var _held: Dictionary = {}  # touch index -> button id
var _release_at: Dictionary = {}  # action -> time (ms) when it may be released


func _ready() -> void:
	layer = 20
	_cfg = Balance.section("touch")
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	get_viewport().size_changed.connect(_layout)
	Game.touch_mode_changed.connect(_on_mode_changed)
	_on_mode_changed(Game.touch_mode)
	_layout()


func _on_mode_changed(active: bool) -> void:
	visible = active
	_layout.call_deferred()
	if not active:
		_release_everything()


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _layout() -> void:
	var size := _screen_size()
	var r := float(_cfg["button_radius_px"])
	var big := float(_cfg["attack_button_radius_px"])
	var margin := 28.0
	var base := Vector2(size.x - margin - big, size.y - margin - big)
	_buttons = [
		{"id": "attack", "action": "attack", "pos": base, "r": big, "label": "Schlag"},
		{"id": "dodge", "action": "dodge", "pos": base + Vector2(-big - r - 18, big * 0.25), "r": r, "label": "Weg"},
		{"id": "torch", "action": "torch", "pos": base + Vector2(-big * 0.35, -big - r - 14), "r": r * 0.75, "label": "Fackel"},
		{"id": "interact", "action": "interact", "pos": base + Vector2(-big - r - 18 - r * 0.5, -r * 1.7 - big * 0.15), "r": r * 0.8, "label": "Treppe"},
		{"id": "armor", "action": "armor", "pos": Vector2(size.x - 40, 150), "r": 26.0, "label": "Rüst."},
		{"id": "help", "action": "help", "pos": Vector2(size.x - 40, 210), "r": 22.0, "label": "?"},
		{"id": "fullscreen", "action": "", "pos": Vector2(size.x - 40, 262), "r": 22.0, "label": "[ ]"},
		{"id": "restart", "action": "restart", "pos": size * 0.5 + Vector2(0, 120), "r": 56.0, "label": "Neu"},
	]


func _button_visible(b: Dictionary) -> bool:
	return b["id"] != "restart" or show_restart


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			_update_stick(d.position)


## Touch events arrive in root-viewport coordinates, which are also this CanvasLayer's
## coordinates (stretch mode is already applied; the Camera2D does not affect CanvasLayers).
func _to_canvas(p: Vector2) -> Vector2:
	return p


func _on_press(index: int, screen_pos: Vector2) -> void:
	var p := _to_canvas(screen_pos)
	for b in _buttons:
		if not _button_visible(b):
			continue
		var pos: Vector2 = b["pos"]
		if p.distance_to(pos) <= float(b["r"]) * 1.25:
			_held[index] = b["id"]
			_press_button(b)
			return
	if _stick_id == -1 and p.x < _screen_size().x * 0.5:
		_stick_id = index
		_stick_origin = p
		_stick_vec = Vector2.ZERO


func _on_release(index: int) -> void:
	if index == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	if _held.has(index):
		var id: String = _held[index]
		_held.erase(index)
		for b in _buttons:
			if b["id"] == id and b["action"] != "":
				_release_at[b["action"]] = Time.get_ticks_msec() + 90


func _press_button(b: Dictionary) -> void:
	if b["id"] == "fullscreen":
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	Input.action_press(b["action"])
	_release_at.erase(b["action"])


func _update_stick(screen_pos: Vector2) -> void:
	var p := _to_canvas(screen_pos)
	var radius := float(_cfg["stick_radius_px"])
	var delta := p - _stick_origin
	# Floating stick: the base follows the finger when it is dragged past the edge.
	if delta.length() > radius:
		_stick_origin = p - delta.normalized() * radius
		delta = p - _stick_origin
	var v := delta / radius
	_stick_vec = Vector2.ZERO if v.length() < float(_cfg["stick_deadzone"]) else v
	_apply_stick()


func _apply_stick() -> void:
	_set_axis("move_left", "move_right", _stick_vec.x)
	_set_axis("move_up", "move_down", _stick_vec.y)


func _set_axis(neg: String, pos: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > 0.0:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _release_everything() -> void:
	_stick_id = -1
	_stick_vec = Vector2.ZERO
	_apply_stick()
	_held.clear()
	for b in _buttons:
		if b["action"] != "":
			Input.action_release(b["action"])


func _process(_delta: float) -> void:
	if not visible:
		return
	# Keep a pressed action alive for a few ms so quick taps are never lost between frames.
	var now := Time.get_ticks_msec()
	for action: String in _release_at.keys():
		if now >= int(_release_at[action]):
			Input.action_release(action)
			_release_at.erase(action)
	_canvas.queue_redraw()


func _draw_controls() -> void:
	var alpha := float(_cfg["button_alpha"])
	if _stick_id != -1:
		var radius := float(_cfg["stick_radius_px"])
		_canvas.draw_circle(_stick_origin, radius, Color(1, 1, 1, alpha * 0.25))
		_canvas.draw_arc(_stick_origin, radius, 0.0, TAU, 40, Color(1, 1, 1, alpha), 2.0)
		_canvas.draw_circle(_stick_origin + _stick_vec * radius, radius * 0.38, Color(1, 1, 1, alpha * 1.4))
	else:
		# Idle hint: where the stick will appear.
		var hint := Vector2(130, _screen_size().y - 130)
		_canvas.draw_arc(hint, float(_cfg["stick_radius_px"]), 0.0, TAU, 40, Color(1, 1, 1, alpha * 0.5), 2.0)
	for b in _buttons:
		if not _button_visible(b):
			continue
		var pos: Vector2 = b["pos"]
		var r: float = b["r"]
		var held := _held.values().has(b["id"])
		var a := alpha * (1.8 if held else 1.0)
		var col := Color(1, 1, 1, a)
		if b["id"] == "interact" and interact_ready:
			col = Color(1.0, 0.75, 0.35, 0.85)
		_canvas.draw_circle(pos, r, Color(col.r, col.g, col.b, col.a * 0.35))
		_canvas.draw_arc(pos, r, 0.0, TAU, 32, col, 2.0)
		var label: String = b["label"]
		var fs := 15 if r > 30.0 else 12
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_canvas.draw_string(_font, pos + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LABEL_COLOR)
