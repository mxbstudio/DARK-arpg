class_name SkillRotation
extends RefCounted
## The skill row: slots fire from left to right, then the row starts over.
## A skill's weight is the time until the next slot fires (no cooldowns).
## Preps ("next hit crits") add modifiers to the next attack; triggers (on_crit,
## on_kill) sit on attacks and react to them. While there is no target the row
## holds its place, so combos never fire into nothing.

signal fired(slot: int)

const DATA_PATH := "res://data/skills.json"

var loadout: Array[String] = []
var index := 0
var timer := 0.0
var last_weight := 1.0
## Modifiers collected from preps, consumed by the next attack.
var pending: Dictionary = {}


static func data() -> Dictionary:
	return Balance.data_file(DATA_PATH)


static func skill(id: String) -> Dictionary:
	return data()["skills"][id]


static func config() -> Dictionary:
	return data()["rotation"]


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in (data()["skills"] as Dictionary).keys():
		ids.append(id)
	return ids


## Keeps only known skill ids and pads/trims to the slot count.
static func sanitize(ids: Array) -> Array[String]:
	var skills: Dictionary = data()["skills"]
	var slots := int(config()["slots"])
	var defaults: Array = config()["default_loadout"]
	var result: Array[String] = []
	for i in slots:
		var id := String(ids[i]) if i < ids.size() else ""
		if not skills.has(id):
			id = String(defaults[i % defaults.size()])
		result.append(id)
	return result


func _init(ids: Array = []) -> void:
	set_loadout(ids)


func set_loadout(ids: Array) -> void:
	loadout = sanitize(ids)
	index = 0
	timer = 0.0
	pending = {}


func current_id() -> String:
	return loadout[index]


func progress() -> float:
	return clampf(1.0 - timer / maxf(last_weight, 0.01), 0.0, 1.0)


func tick(delta: float, player: Player) -> void:
	timer -= delta
	if timer > 0.0:
		return
	var s := skill(current_id())
	if s["kind"] == "prep":
		if player.find_target(_next_attack_range(), true) == null:
			return  # nothing nearby: hold the combo
		_merge(s["mods"])
		player.on_prep(s)
	else:
		var target := player.find_target(float(s["range"]), s.get("target", "") == "dark")
		if target == null:
			return
		player.fire_skill(s, pending, target)
		pending = {}
	last_weight = float(s["weight"]) * maxf(player.stat("weight_mult"), 0.4)
	timer = last_weight
	fired.emit(index)
	index = (index + 1) % loadout.size()


func _merge(mods: Dictionary) -> void:
	if mods.get("crit", false):
		pending["crit"] = true
	if mods.has("extra_arrows"):
		pending["extra_arrows"] = int(pending.get("extra_arrows", 0)) + int(mods["extra_arrows"])
	if mods.has("chill"):
		pending["chill"] = maxf(float(pending.get("chill", 0.0)), float(mods["chill"]))


func _next_attack_range() -> float:
	for k in range(1, loadout.size() + 1):
		var s := skill(loadout[(index + k) % loadout.size()])
		if s["kind"] == "attack":
			return float(s["range"])
	return 0.0
