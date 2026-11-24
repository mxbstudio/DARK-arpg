shader_type canvas_item;
// Licks a painted flame: noise-driven sideways warping that grows toward the tip,
// a slow wind sway, upward-scrolling turbulence and brightness flicker.

uniform float speed = 1.0;
uniform float strength = 0.05;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float h = 1.0 - uv.y;                 // 0 at the base, 1 at the tip
	float t = TIME * speed + seed;
	float big = fbm(vec2(uv.x * 2.5 + seed, uv.y * 3.0 + t * 1.6)) - 0.5;
	float small = fbm(vec2(uv.x * 7.0 + 11.0, uv.y * 9.0 + t * 4.2)) - 0.5;
	float sway = sin(t * 0.9 + seed) * 0.6 + sin(t * 2.3) * 0.25;
	uv.x += (big * 2.0 + small) * strength * h * h * 2.2 + sway * 0.03 * h * h;
	uv.y += small * strength * 0.8 * h + big * strength * 0.4 * h;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	// Tongues tear off near the tip: fade by moving noise.
	float tear = smoothstep(0.35, 0.75, fbm(vec2(uv.x * 4.0, uv.y * 5.0 + t * 3.0)) + (1.0 - h) * 0.6);
	c.a *= mix(1.0, tear, smoothstep(0.45, 1.0, h));
	float flick = 0.88 + 0.22 * fbm(vec2(t * 2.7, seed * 3.0));
	c.rgb *= flick;
	COLOR = c * COLOR;
}
