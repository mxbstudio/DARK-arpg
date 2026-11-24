class_name LoadoutPanel
extends CanvasLayer
## Camp menu at the quiver rack: build the skill row. Tap a slot, then a skill to
## put it there. Works with mouse, keyboard (Esc closes) and touch.

signal closed

const BG := Color(0.05, 0.04, 0.035, 0.94)
const INK := Color(0.9, 0.85, 0.75)
const DIM := Color(0.62, 0.57, 0.5)
const EMBER := Color(0.91, 0.63, 0.29)

var _loadout: Array[String] = []
var _selected := 0
var _slot_buttons: Array[Button] = []
var _info: Label
var _total: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loadout = SkillRotation.sanitize(Game.loadout)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	box.add_child(_label("KÖCHER – SKILL-REIHE", 24, EMBER, true))
	box.add_child(_label("Die Slots feuern von links nach rechts, dann von vorn. Vorbereiter wirken auf den nächsten Angriff.\nTippe einen Slot an, dann einen Skill.", 13, DIM, true))

	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 6)
	box.add_child(slots)
	for i in _loadout.size():
		if i > 0:
			slots.add_child(_label("›", 20, DIM, true))
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_on_slot.bind(i))
		slots.add_child(b)
		_slot_buttons.append(b)

	_total = _label("", 13, DIM, true)
	box.add_child(_total)
	_info = _label("", 14, INK, true)
	_info.custom_minimum_size = Vector2(560, 40)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for id in SkillRotation.all_ids():
		var s := SkillRotation.skill(id)
		var b := Button.new()
		b.text = "%s\n%s" % [s["name"], _kind_label(s)]
		b.icon = SkillIcons.get_icon(id, 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(196, 44)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_skill.bind(id))
		b.mouse_entered.connect(_show_info.bind(id))
		grid.add_child(b)

	var done := Button.new()
	done.text = "Fertig"
	done.custom_minimum_size = Vector2(160, 44)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.add_theme_font_size_override("font_size", 16)
	done.pressed.connect(close)
	box.add_child(done)

	_refresh()
	_show_info(_loadout[_selected])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Game.loadout = _loadout.duplicate()
	Game.save_meta()
	closed.emit()
	queue_free()


func _on_slot(i: int) -> void:
	_selected = i
	_refresh()
	_show_info(_loadout[i])


func _on_skill(id: String) -> void:
	_loadout[_selected] = id
	_show_info(id)
	_selected = (_selected + 1) % _loadout.size()
	_refresh()


func _refresh() -> void:
	var total := 0.0
	for i in _slot_buttons.size():
		var b := _slot_buttons[i]
		b.icon = SkillIcons.get_icon(_loadout[i], 40)
		b.tooltip_text = String(SkillRotation.skill(_loadout[i])["name"])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.08, 0.07)
		sb.set_border_width_all(3 if i == _selected else 1)
		sb.border_color = EMBER if i == _selected else Color(0.3, 0.26, 0.22)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		total += float(SkillRotation.skill(_loadout[i])["weight"])
	_total.text = "Eine Runde dauert %.1f s" % total


func _show_info(id: String) -> void:
	var s := SkillRotation.skill(id)
	_info.text = "%s  (%s, %.2f s)\n%s" % [s["name"], _kind_label(s), float(s["weight"]), s["desc"]]


func _kind_label(s: Dictionary) -> String:
	if s["kind"] == "prep":
		return "Vorbereiter"
	if s.has("on_crit") or s.has("on_kill"):
		return "Angriff mit Auslöser"
	return "Angriff"


func _label(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
