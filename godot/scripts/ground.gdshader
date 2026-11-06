shader_type spatial;
// Sol de l'arène : herbe en damier tondu avec variations, chemins dallés biseautés, ombre des murets.
uniform vec4 grass_a : source_color = vec4(0.35, 0.72, 0.28, 1.0);
uniform vec4 grass_b : source_color = vec4(0.31, 0.66, 0.25, 1.0);
uniform vec4 tile : source_color = vec4(0.85, 0.79, 0.64, 1.0);
uniform float flowers = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float rect(vec2 p, vec4 r) { // r = x0, z0, x1, z1
	return step(r.x, p.x) * step(p.x, r.z) * step(r.y, p.y) * step(p.y, r.w);
}

void fragment() {
	vec2 p = vec2(UV.x * 18.0 - 9.0, UV.y * 32.0 - 16.0);
	float checker = mod(floor(p.x) + floor(p.y), 2.0);
	vec3 g = mix(grass_b.rgb, grass_a.rgb, checker);
	float n = noise(p * 1.7) * 0.5 + noise(p * 5.3) * 0.3 + noise(p * 17.0) * 0.2;
	g *= 0.88 + n * 0.22;
	// petites touffes d'herbe
	vec2 cell = floor(p * 6.0);
	float tuft = step(0.93, hash(cell)) * smoothstep(0.5, 0.1, length(fract(p * 6.0) - 0.5));
	g = mix(g, g * 1.25 + vec3(0.03, 0.06, 0.0), tuft);
	// petites fleurs
	vec2 fc = floor(p * 3.0);
	float fh = hash(fc + 17.0);
	float flower = step(0.965, fh) * smoothstep(0.22, 0.08, length(fract(p * 3.0) - vec2(0.5)));
	vec3 fcol = mix(vec3(1.0, 0.95, 0.55), mix(vec3(1.0, 0.6, 0.8), vec3(1.0), step(0.985, fh)), step(0.975, fh));
	g = mix(g, fcol, flower * flowers);
	float isPath = max(max(rect(p, vec4(-6.25, -12.0, -4.75, 12.0)), rect(p, vec4(4.75, -12.0, 6.25, 12.0))),
		max(rect(p, vec4(-6.25, 11.2, 6.25, 12.4)), rect(p, vec4(-6.25, -12.4, 6.25, -11.2))));
	// dalles : biseau clair en haut à gauche, sombre en bas à droite, joints
	vec2 tp = p / 0.75;
	vec2 f = fract(tp + vec2(mod(floor(tp.y), 2.0) * 0.5, 0.0));
	float id = hash(floor(tp + vec2(mod(floor(tp.y), 2.0) * 0.5, 0.0)));
	vec3 t = tile.rgb * (0.9 + id * 0.18);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	t *= mix(0.55, 1.0, smoothstep(0.02, 0.07, edge));
	t += vec3(0.08) * smoothstep(0.14, 0.04, f.x) * step(0.05, edge);
	t -= vec3(0.07) * smoothstep(0.86, 0.96, f.y);
	t *= 0.92 + noise(p * 9.0) * 0.12;
	vec3 col = mix(g, t, isPath);
	// ombre au pied des murets et vers les bords
	float border = min(9.0 - abs(p.x), 16.0 - abs(p.y));
	col *= mix(0.7, 1.0, smoothstep(0.0, 1.2, border));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.8, isPath);
}
