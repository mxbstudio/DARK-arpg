class_name FloatText
extends Node2D
## Small rising combat text (damage, crits, heals). Lives on an overlay layer
## (group "float_layer") that follows the camera but ignores the darkness.

var text := ""
var color := Color.WHITE
var life := 0.8
var _t := 0.0


static func spawn(ctx: Node, pos: Vector2, label: String, col: Color) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var layer := ctx.get_tree().get_first_node_in_group("float_layer")
	if layer == null:
		return
	var ft := FloatText.new()
	ft.text = label
	ft.color = col
	ft.position = pos + Vector2(randf_range(-4, 4), 0)
	layer.add_child(ft)


func _process(delta: float) -> void:
	_t += delta
	position.y -= 22.0 * delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var a := clampf(1.0 - (_t - life * 0.5) / (life * 0.5), 0.0, 1.0)
	var size := 8
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(-w * 0.5 + 0.5, 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, a))
	draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.r, color.g, color.b, a))
