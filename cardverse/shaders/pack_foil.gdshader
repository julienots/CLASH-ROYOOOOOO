// Film d'emballage des boosters : impression + foil métallique irisé selon l'angle de vue,
// plastique froissé (normales perturbées), reflets qui accrochent les plis.
shader_type spatial;
render_mode cull_back;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float foil = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// plis du plastique : bruit étiré horizontalement + froissures fines
	vec2 q = UV * vec2(6.0, 18.0) + seed;
	float nx = noise(q + vec2(0.13, 0.0)) - noise(q - vec2(0.13, 0.0));
	float ny = noise(q + vec2(0.0, 0.13)) - noise(q - vec2(0.0, 0.13));
	float fine = noise(UV * 70.0 + seed) - 0.5;
	NORMAL = normalize(NORMAL + vec3(nx * 0.22 + fine * 0.05, ny * 0.16, 0.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// foil : plus brillant sur les zones claires de l'impression
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	METALLIC = foil * (0.25 + 0.4 * lum);
	ROUGHNESS = 0.32 - foil * 0.12 + fine * 0.15;
	SPECULAR = 0.6;
	// irisation arc-en-ciel qui change avec l'angle et les plis
	vec3 iri = hue(fract(dot(NORMAL, VIEW) * 1.6 + UV.y * 0.8 + nx * 0.6));
	EMISSION = iri * foil * (0.06 + fres * 0.35) * (0.4 + lum);
}
