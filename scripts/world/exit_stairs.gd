class_name ExitStairs
extends Node2D
## Stairs to the next depth. Not lit; it can be found by ear via a cold draft.

const SIZE := 28.0


func _ready() -> void:
	z_index = -5
	var audio := Balance.section("audio")
	var p := AudioStreamPlayer2D.new()
	p.stream = Sfx.stream("wind")
	p.volume_db = float(audio["exit_wind_db"])
	p.max_distance = float(audio["exit_wind_audible_px"])
	p.attenuation = 1.3
	add_child(p)
	p.play()


func _draw() -> void:
	for i in 5:
		var inset := i * 3.0
		var c := 0.3 - i * 0.055
		draw_rect(Rect2(-SIZE * 0.5 + inset, -SIZE * 0.5 + inset, SIZE - inset * 2.0, SIZE - inset * 2.0), Color(c, c * 0.95, c * 0.9))
	draw_rect(Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE), Color(0.1, 0.1, 0.1), false, 1.0)
