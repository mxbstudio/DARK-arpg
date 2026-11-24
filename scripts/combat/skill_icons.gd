class_name SkillIcons
extends RefCounted
## Renders the skill icons (SVG paths from Aschenreich) into textures, cached.

static var _cache: Dictionary = {}


static func get_icon(id: String, size := 32) -> Texture2D:
	var key := "%s@%d" % [id, size]
	if _cache.has(key):
		return _cache[key]
	var s := SkillRotation.skill(id)
	var color := String(s["color"])
	var body := String(s["icon"]).replace("currentColor", color)
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\" viewBox=\"0 0 32 32\" fill=\"none\" stroke=\"%s\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">%s</svg>" % [color, body]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, size / 32.0)
	var tex: Texture2D = null
	if err == OK:
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
