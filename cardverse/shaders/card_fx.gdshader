// Effets de surface d'une carte selon sa rareté / variante (calque additif sur toute la carte).
// mode : 0 aucun, 1 reflet balayant, 2 holographique, 3 holo + scintillements, 4 cosmique, 5 prismatique, 6 or (secret)
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 tilt = vec2(0.0);
uniform float intensity = 1.0;
uniform vec2 card_size = vec2(450.0, 630.0);

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float rounded(vec2 uv) {
	vec2 p = (uv - 0.5) * card_size;
	vec2 q = abs(p) - card_size * 0.5 + 22.0;
	float d = length(max(q, 0.0)) - 22.0;
	return 1.0 - smoothstep(-1.0, 1.0, d);
}

void fragment() {
	vec2 uv = UV;
	float m = rounded(uv);
	vec3 c = vec3(0.0);
	float t = TIME;
	// reflet balayant (toutes les raretés >= Rare)
	float pos = fract(t * 0.18 + tilt.x * 0.3) * 3.0 - 1.0;
	float d = abs((uv.x + uv.y * 0.55) - pos);
	float shine = smoothstep(0.12, 0.0, d) * 0.55;
	if (mode >= 1) c += vec3(shine) * tint.rgb;
	if (mode == 2 || mode == 3 || mode == 5) {
		float k = (uv.x * 0.8 + uv.y * 1.2) + tilt.x * 0.9 + tilt.y * 0.6 + t * 0.05;
		float band = 0.5 + 0.5 * sin(k * 18.0);
		float s = mode == 5 ? 0.55 : 0.28;
		c += hue(fract(k * 1.3)) * band * s;
	}
	if (mode == 3 || mode == 5) {
		vec2 g = floor(uv * vec2(28.0, 40.0));
		float h = hash(g);
		float tw = pow(max(0.0, sin(t * (1.5 + h * 3.0) + h * 40.0)), 24.0);
		vec2 f = fract(uv * vec2(28.0, 40.0)) - 0.5;
		float star = smoothstep(0.18, 0.0, abs(f.x) * abs(f.y) * 12.0 + length(f) * 0.6);
		c += vec3(1.0) * tw * star * step(0.82, h) * 1.2;
	}
	if (mode == 4) {
		float n = sin(uv.x * 9.0 + t * 0.4) * sin(uv.y * 7.0 - t * 0.3) + sin((uv.x + uv.y) * 13.0 + t * 0.7) * 0.5;
		c += tint.rgb * (0.12 + 0.12 * n);
		vec2 g = floor(uv * vec2(36.0, 50.0));
		float h = hash(g);
		float tw = pow(max(0.0, sin(t * (1.0 + h * 2.0) + h * 30.0)), 30.0);
		c += vec3(1.0) * tw * step(0.85, h) * 1.4;
		float k = uv.x + uv.y + tilt.x;
		c += hue(fract(k * 0.7 + t * 0.03)) * 0.12;
	}
	if (mode == 6) {
		float k = (uv.x - uv.y) * 6.0 + tilt.x * 2.0 + t * 0.4;
		c += vec3(1.0, 0.8, 0.35) * (0.18 + 0.18 * sin(k * 3.0));
	}
	COLOR = vec4(c * intensity * m, 1.0);
}
