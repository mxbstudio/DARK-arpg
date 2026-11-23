class_name Hud
extends CanvasLayer
## Minimal, dim HUD: health, stamina, run info, help and death screen.

const HELP_TEXT := """WASD  bewegen      Maus  zielen      Linksklick  Schlag
Leertaste / Rechtsklick  Ausweichen      F  Fackel an/aus
T  Rüstung wechseln (Prototyp)      E  Treppe hinab      H  Hilfe

Kopfhörer empfohlen. Hör hin: Schritte und Atem verraten Gegner im Dunkeln.
Ein anschwellendes Knurren kündigt einen Angriff an – weich aus, wenn es gipfelt.
Plattenrüstung schützt, ist aber laut. Ohne Fackel sehen dich Gegner schlechter.
Die Treppe nach unten erkennst du am kalten Luftzug."""

var player: Player
var depth := 1

var _bars: Control
var _info: Label
var _center: Label
var _hint: Label
var _help_visible := false
var _death_visible := false
var _help_timer := 0.0


func _ready() -> void:
	layer = 10
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	_info = _make_label(15, Color(0.72, 0.67, 0.6))
	_info.position = Vector2(24, 58)
	_center = _make_label(19, Color(0.8, 0.75, 0.68))
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint = _make_label(18, Color(0.85, 0.8, 0.7))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -70
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_help(auto_hide_after: float) -> void:
	_death_visible = false
	_help_visible = true
	_help_timer = auto_hide_after


func toggle_help() -> void:
	_help_visible = not _help_visible
	_help_timer = 0.0


func show_death(reached_depth: int, ash_gained: int) -> void:
	_help_visible = false
	_death_visible = true
	_center.text = "DU BIST GEFALLEN\n\nErreichte Tiefe: %d\nAsche: +%d  (gesamt %d)\nBeste Tiefe: %d\n\n[R]  Neuer Abstieg" % [
		reached_depth, ash_gained, Game.ash, Game.best_depth]


func set_hint(text: String) -> void:
	_hint.text = text


func _process(delta: float) -> void:
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer <= 0.0:
			_help_visible = false
	if not _death_visible:
		_center.text = HELP_TEXT if _help_visible else ""
	if player != null:
		var armor_name: String = player.armor()["name"]
		_info.text = "Tiefe %d    Rüstung: %s    Fackel: %s\nLauf #%d    Asche: %d    Beste Tiefe: %d" % [
			depth, armor_name, "an" if player.torch_on else "aus",
			Game.total_runs + (0 if _death_visible else 1), Game.ash, Game.best_depth]
	_bars.queue_redraw()


func _draw_bars() -> void:
	if player == null:
		return
	_bar(Vector2(24, 20), Vector2(260, 12), player.hp / player.max_hp, Color(0.55, 0.08, 0.06))
	_bar(Vector2(24, 38), Vector2(260, 7), player.stamina / player.max_stamina, Color(0.55, 0.5, 0.35))


func _bar(pos: Vector2, size: Vector2, fraction: float, color: Color) -> void:
	_bars.draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.6))
	_bars.draw_rect(Rect2(pos, Vector2(size.x * clampf(fraction, 0.0, 1.0), size.y)), color)
	_bars.draw_rect(Rect2(pos, size), Color(0.3, 0.28, 0.25), false, 1.0)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l
