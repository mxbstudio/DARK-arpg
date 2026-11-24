class_name LevelUpPanel
extends CanvasLayer
## Level-up: choose one of a few boons from the gods (data/boons.json).
## The game is paused while it is open. Keys 1–3 pick a card as well.

signal chosen(id: String)

const BG := Color(0.03, 0.025, 0.02, 0.82)
const INK := Color(0.9, 0.85, 0.75)
const DIM := Color(0.62, 0.57, 0.5)

var player: Player
var _ids: Array[String] = []


## Up to `count` random boons the player has not maxed yet.
static func roll(p: Player, count: int) -> Array[String]:
	var all: Dictionary = Balance.data_file("res://data/boons.json")["boons"]
	var pool: Array[String] = []
	for id: String in all.keys():
		if p.boon_level(id) < int(all[id]["max"]):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data: Dictionary = Balance.data_file("res://data/boons.json")
	_ids = roll(player, int(Balance.section("progression")["choices"]))

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	box.add_child(_label("STUFE %d" % player.level, 26, Color(0.75, 0.88, 0.95)))
	box.add_child(_label("Die Götter bieten dir eine Gabe an.", 14, DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in _ids.size():
		var id := _ids[i]
		var b: Dictionary = data["boons"][id]
		var god: Dictionary = data["gods"][String(b["god"])]
		var col := Color.from_string(String(god["color"]), INK)
		var lvl := player.boon_level(id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 150)
		btn.text = "%s\n\n%s  %s\n\n%s" % [god["name"], b["name"], "◆".repeat(lvl + 1) + "◇".repeat(int(b["max"]) - lvl - 1), b["desc"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 13)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.07, 0.06)
		sb.set_border_width_all(2)
		sb.border_color = col.darkened(0.3)
		sb.set_content_margin_all(10)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.border_color = col
		sbh.bg_color = Color(0.14, 0.1, 0.08)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sbh)
		btn.add_theme_stylebox_override("pressed", sbh)
		btn.add_theme_stylebox_override("focus", sbh)
		btn.pressed.connect(_pick.bind(id))
		row.add_child(btn)
	if _ids.is_empty():
		var ok := Button.new()
		ok.text = "Alle Gaben gemeistert – weiter"
		ok.pressed.connect(_pick.bind(""))
		box.add_child(ok)
	else:
		box.add_child(_label("Wähle mit Klick, Tippen oder 1–%d." % _ids.size(), 12, DIM))
	Sfx.play_ui("levelup", -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode - KEY_1
		if k >= 0 and k < _ids.size():
			get_viewport().set_input_as_handled()
			_pick(_ids[k])


func _pick(id: String) -> void:
	if id != "":
		player.take_boon(id)
	chosen.emit(id)
	queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
