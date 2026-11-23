class_name LightUtil
extends RefCounted
## Shared helpers for 2D point lights.

const TEXTURE_SIZE := 256

static var _texture: GradientTexture2D


## Soft radial falloff texture shared by all lights.
static func radial_texture() -> GradientTexture2D:
	if _texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_texture = GradientTexture2D.new()
		_texture.gradient = g
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
	return _texture


static func make_light(radius: float, energy: float, color: Color) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial_texture()
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 2.0
	configure(light, radius, energy, color)
	return light


static func configure(light: PointLight2D, radius: float, energy: float, color: Color) -> void:
	light.texture_scale = radius / (TEXTURE_SIZE * 0.5)
	light.energy = energy
	light.color = color
