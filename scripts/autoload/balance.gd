extends Node
## Loads all tunable gameplay values from data/balance.json.
## Gameplay code reads numbers from here instead of hardcoding them.

const PATH := "res://data/balance.json"

var data: Dictionary = {}


func _init() -> void:
	reload()


func reload() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Balance: cannot open %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Balance: invalid JSON in %s" % PATH)


func section(section_name: String) -> Dictionary:
	if not data.has(section_name):
		push_error("Balance: missing section '%s'" % section_name)
		return {}
	return data[section_name]


static func to_color(values: Array) -> Color:
	return Color(float(values[0]), float(values[1]), float(values[2]))
