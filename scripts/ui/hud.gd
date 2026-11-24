class_name Hud
extends CanvasLayer
## Minimal, dim HUD: health, stamina, run info, help and death screen.

const HELP_TEXT := """WASD  bewegen      Leertaste / Rechtsklick  Ausweichen
F  Fackel an/aus      T  Rüstung wechseln (Prototyp)      E  Tor / Treppe      H  Hilfe

Dein Bogen schießt von selbst – aber nur auf Gegner, die du im Licht siehst. Seelen getöteter Gegner bringen Stufen und Gaben.
Kopfhörer empfohlen. Hör hin: Schritte und Atem verraten Gegner im Dunkeln.
Ein anschwellendes Knurren kündigt einen Angriff an – weich aus, wenn es gipfelt.
Plattenrüstung schützt, ist aber laut. Ohne Fackel sehen dich Gegner schlechter.
Im Lager: am Köcher (rechts) baust du deine Skill-Reihe, am Tor im Norden beginnt der Abstieg. Unten führt ein kalter Luftzug zur Treppe."""

const TOUCH_HELP_TEXT := """Linke Bildschirmhälfte: Stick zum Laufen (erscheint, wo du tippst)
Rechts: Weg (Ausweichen), Fackel, Aktion (Tor / Treppe), Rüst. (Rüstung wechseln)

Dein Bogen schießt von selbst – aber nur auf Gegner, die du im Licht siehst. Seelen getöteter Gegner bringen Stufen und Gaben.
Kopfhörer empfohlen. Hör hin: Schritte und Atem verraten Gegner im Dunkeln.
Ein anschwellendes Knurren kündigt einen Angriff an – weich aus, wenn es gipfelt.
Plattenrüstung schützt, ist aber laut. Ohne Fackel sehen dich Gegner schlechter.
Im Lager: am Köcher (rechts) baust du deine Skill-Reihe, am Tor im Norden beginnt der Abstieg. Unten führt ein kalter Luftzug zur Treppe."""

var player: Player
var depth := 1
## True while the hero is in the start camp.
var in_camp := false

var _bars: Control
var _info: Label
var _center: Label
var _hint: Label
var _help_visible := false
var _death_visible := false
var _help_timer := 0.0
var _loading := false
var _banner := ""
var _banner_t := 0.0


func _ready() -> void:
	layer = 10
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	_info = _make_label(18 if Game.touch_mode else 15, Color(0.72, 0.67, 0.6))
	_info.position = Vector2(24, 58)
	_center = _make_label(22 if Game.touch_mode else 19, Color(0.8, 0.75, 0.68))
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint = _make_label(18, Color(0.85, 0.8, 0.7))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -70
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func set_loading(fraction: float) -> void:
	if fraction < 0.0:
		_loading = false
		_center.text = ""
		return
	_loading = true
	_center.text = "Lade Klänge … %d %%" % int(fraction * 100.0)


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
	_center.text = "DU BIST GEFALLEN\n\nErreichte Tiefe: %d\nAsche: +%d  (gesamt %d)\nBeste Tiefe: %d\n\n%s" % [
		reached_depth, ash_gained, Game.ash, Game.best_depth,
		"Tippe auf „Lager“, um zurückzukehren" if Game.touch_mode else "[E]  Zurück ins Lager"]


## Large fading title in the upper third (e.g. entering an arena).
func show_banner(text: String) -> void:
	_banner = text
	_banner_t = 3.0


func set_hint(text: String) -> void:
	_hint.text = text


func _process(delta: float) -> void:
	_banner_t = maxf(_banner_t - delta, 0.0)
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer <= 0.0:
			_help_visible = false
	if not _death_visible and not _loading:
		_center.text = (TOUCH_HELP_TEXT if Game.touch_mode else HELP_TEXT) if _help_visible else ""
	if player != null:
		var armor_name: String = player.armor()["name"]
		var where := "Lager" if in_camp else "Tiefe %d" % depth
		_info.text = "%s    Rüstung: %s    Fackel: %s\nLauf #%d    Asche: %d    Beste Tiefe: %d" % [
			where, armor_name, "an" if player.torch_on else "aus",
			Game.total_runs + (0 if _death_visible else 1), Game.ash, Game.best_depth]
	_bars.queue_redraw()


func _draw_bars() -> void:
	if player == null:
		return
	_bar(Vector2(24, 20), Vector2(260, 12), player.hp / player.max_hp, Color(0.55, 0.08, 0.06))
	_bar(Vector2(24, 38), Vector2(260, 7), player.stamina / player.max_stamina, Color(0.55, 0.5, 0.35))
	_draw_rotation()
	_draw_xp()
	if _banner_t > 0.0:
		var font := ThemeDB.fallback_font
		var a := clampf(_banner_t, 0.0, 1.0)
		var fs := 34
		var w := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_bars.draw_string(font, Vector2((_bars.size.x - w) * 0.5, _bars.size.y * 0.28), _banner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.78, 0.66, a))


## Soul bar (experience) at the very bottom, with the level above its left end.
func _draw_xp() -> void:
	if in_camp:
		return
	var w := minf(520.0, _bars.size.x * 0.6)
	var pos := Vector2((_bars.size.x - w) * 0.5, _bars.size.y - 18.0)
	_bars.draw_rect(Rect2(pos, Vector2(w, 6)), Color(0.02, 0.03, 0.04, 0.85))
	_bars.draw_rect(Rect2(pos, Vector2(w * float(player.xp) / maxf(player.xp_needed, 1), 6)), Color(0.5, 0.78, 0.9))
	_bars.draw_rect(Rect2(pos, Vector2(w, 6)), Color(0.18, 0.24, 0.28), false, 1.0)
	var font := ThemeDB.fallback_font
	_bars.draw_string(font, pos + Vector2(0, -4), "Stufe %d" % player.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.8, 0.88))


## The skill row at the bottom: current slot highlighted, its bar fills until it fires.
## A glowing dot means a prep is loaded for the next attack.
func _draw_rotation() -> void:
	var row := player.rotation_row
	if row == null:
		return
	var n := row.loadout.size()
	var box := 40.0
	var gap := 6.0
	var total := n * box + (n - 1) * gap
	var origin := Vector2((_bars.size.x - total) * 0.5, _bars.size.y - box - 42.0)
	for i in n:
		var id := row.loadout[i]
		var r := Rect2(origin + Vector2(i * (box + gap), 0), Vector2(box, box))
		var current := i == row.index and not in_camp
		var col := Color.from_string(String(SkillRotation.skill(id)["color"]), Color.WHITE)
		_bars.draw_rect(r, Color(0.04, 0.035, 0.03, 0.8))
		var icon := SkillIcons.get_icon(id, 32)
		if icon != null:
			_bars.draw_texture_rect(icon, r.grow(-4), false, Color(1, 1, 1, 1.0 if current or in_camp else 0.5))
		_bars.draw_rect(r, col if current else Color(0.3, 0.27, 0.23), false, 2.0 if current else 1.0)
		if current:
			_bars.draw_rect(Rect2(r.position + Vector2(0, box + 3), Vector2(box * row.progress(), 3)), col)
			if not row.pending.is_empty():
				_bars.draw_circle(r.position + Vector2(box * 0.5, -6), 3.5, Color(1.0, 0.8, 0.4))


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
