// Fond animé des menus : nébuleuse lente et étoiles scintillantes.
shader_type canvas_item;

uniform vec4 c1 : source_color = vec4(0.03, 0.02, 0.09, 1.0);
uniform vec4 c2 : source_color = vec4(0.22, 0.08, 0.38, 1.0);
uniform vec4 c3 : source_color = vec4(0.05, 0.25, 0.45, 1.0);
uniform vec2 res = vec2(720.0, 1280.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = UV;
	vec2 p = uv * res / 260.0;
	float t = TIME * 0.025;
	float n = fbm(p + vec2(t, -t * 0.7));
	float n2 = fbm(p * 1.7 - vec2(t * 1.3, t));
	vec3 col = mix(c1.rgb, c2.rgb, smoothstep(0.35, 0.85, n) * 0.85);
	col = mix(col, c3.rgb, smoothstep(0.5, 0.95, n2) * 0.6);
	col *= 0.75 + 0.35 * (1.0 - uv.y);
	vec2 g = floor(uv * res / 6.0);
	float h = hash(g);
	float tw = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 60.0);
	col += vec3(0.9, 0.9, 1.0) * step(0.996, h) * tw;
	COLOR = vec4(col, 1.0);
}
