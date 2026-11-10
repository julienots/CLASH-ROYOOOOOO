// Fond des menus : ciel cosmique vivant.
// Nébuleuse à déformation de domaine, rubans d'aurore, galaxie lointaine qui tourne,
// trois couches d'étoiles en parallaxe (scintillement, couleurs) et étoiles filantes.
shader_type canvas_item;

uniform vec4 c1 : source_color = vec4(0.02, 0.01, 0.06, 1.0);
uniform vec4 c2 : source_color = vec4(0.30, 0.07, 0.45, 1.0);
uniform vec4 c3 : source_color = vec4(0.04, 0.30, 0.55, 1.0);
uniform vec4 aurora : source_color = vec4(0.25, 1.0, 0.75, 1.0);
uniform vec2 res = vec2(720.0, 1280.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
float stars(vec2 uv, float cell, float speed, float thr, float t) {
	vec2 p = uv * res / cell + vec2(0.0, t * speed);
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash(id);
	vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
	float d = length(f - o * 0.6);
	float tw = 0.55 + 0.45 * sin(t * (1.5 + h * 4.0) + h * 80.0);
	return step(thr, h) * smoothstep(0.12, 0.0, d) * tw;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec2 p = uv * res / 300.0;
	// nébuleuse : déformation de domaine (volutes)
	vec2 q = vec2(fbm(p + vec2(0.0, t * 0.02)), fbm(p + vec2(5.2, 1.3) - t * 0.015));
	float n = fbm(p + q * 2.2 + vec2(t * 0.01, 0.0));
	vec3 col = mix(c1.rgb, c2.rgb, smoothstep(0.3, 0.9, n));
	col = mix(col, c3.rgb, smoothstep(0.45, 1.0, q.y) * 0.65);
	col += c2.rgb * pow(n, 4.0) * 0.6;
	// galaxie spirale lointaine
	vec2 g = (uv - vec2(0.72, 0.22)) * vec2(res.x / res.y, 1.0) * 3.2;
	float gr = length(g);
	float ga = atan(g.y, g.x);
	float arms = 0.5 + 0.5 * sin(ga * 2.0 - log(gr + 0.05) * 4.0 + t * 0.15);
	col += vec3(1.0, 0.85, 0.95) * exp(-gr * 3.5) * (0.35 + 0.5 * arms) * 0.6;
	// rubans d'aurore : rideaux verticaux qui ondulent dans la moitié haute
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float y0 = 0.16 + fi * 0.1 + 0.03 * sin(uv.x * 4.0 + t * 0.3 + fi);
		float wave = sin(uv.x * (6.0 + fi * 2.0) + t * (0.4 + fi * 0.15) + fi * 2.0) * 0.04;
		float band = exp(-pow((uv.y - y0 - wave) / 0.045, 2.0));
		float streak = 0.55 + 0.45 * noise(vec2(uv.x * 40.0 + t * 0.5, fi * 10.0));
		float curtain = band + smoothstep(0.0, 0.12, (uv.y - y0 - wave)) * exp(-(uv.y - y0 - wave) * 10.0) * 0.6;
		vec3 ac = mix(aurora.rgb, vec3(0.7, 0.4, 1.0), fi / 2.0);
		col += ac * curtain * streak * 0.32;
	}
	// étoiles : trois profondeurs qui dérivent à des vitesses différentes
	col += vec3(0.85, 0.9, 1.0) * stars(uv, 5.0, 0.6, 0.985, t) * 0.7;
	col += vec3(1.0, 0.95, 0.85) * stars(uv, 11.0, 1.4, 0.975, t) * 0.9;
	col += mix(vec3(0.6, 0.8, 1.0), vec3(1.0, 0.6, 0.9), hash(floor(uv * 20.0))) * stars(uv, 23.0, 3.0, 0.965, t) * 1.2;
	// étoiles filantes occasionnelles
	float k = floor(t / 6.0);
	float lt = fract(t / 6.0);
	vec2 s0 = vec2(hash(vec2(k, 1.0)), hash(vec2(k, 2.0)) * 0.5);
	vec2 dir = normalize(vec2(-1.0, 0.45));
	vec2 head = s0 + vec2(0.4, 0.0) - dir * -lt * 0.9;
	vec2 rel = (uv - head) * vec2(res.x / res.y, 1.0);
	float along = dot(rel, -dir);
	float across = abs(dot(rel, vec2(-dir.y, dir.x)));
	float trail = smoothstep(0.0, 0.002, along) * smoothstep(0.18, 0.0, along) * smoothstep(0.003, 0.0, across);
	col += vec3(1.0) * trail * step(lt, 0.35) * (1.0 - lt / 0.35);
	// vignette douce
	col *= 1.0 - 0.35 * smoothstep(0.4, 0.95, length((uv - 0.5) * vec2(1.0, 0.8)));
	COLOR = vec4(col, 1.0);
}
