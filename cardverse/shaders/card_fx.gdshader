// Effets de surface animés d'une carte (calque additif sur toute la carte).
// mode : 0 aucun, 1 reflet balayant, 2 holographique, 3 holo + scintillements, 4 cosmique, 5 prismatique, 6 or (secret)
// element : -1 aucun, sinon index dans l'ordre feu, eau, terre, foudre, glace, nature, ombre, lumiere, cosmique, neant
// border : 0 aucun, 1 lumière courante, 2 runes primitives, 3 coutures SWAP
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform int mode = 0;
uniform int element = -1;
uniform int border = 0;
uniform float fx_level = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 elem_color : source_color = vec4(1.0);
uniform vec2 tilt = vec2(0.0);
uniform float intensity = 1.0;
uniform vec2 card_size = vec2(450.0, 630.0);
uniform vec4 win = vec4(0.0467, 0.119, 0.953, 0.562);  // fenêtre d'illustration (UV)

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float rounded(vec2 uv) {
	vec2 p = (uv - 0.5) * card_size;
	vec2 q = abs(p) - card_size * 0.5 + 22.0;
	float d = length(max(q, 0.0)) - 22.0;
	return 1.0 - smoothstep(-1.0, 1.0, d);
}

// Champ de particules : p en coordonnées locales (0..1), dir = déplacement par seconde (en cellules)
float field(vec2 p, vec2 dens, vec2 vel, float t, float size, float prob, float ring) {
	vec2 q = p * dens + vel * t;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash(id);
	vec2 o = vec2(hash(id + 1.7), hash(id + 3.1)) - 0.5;
	float d = length((f - o * 0.6) * vec2(1.0, dens.x / dens.y));
	float s = size * (0.6 + 0.8 * hash(id + 5.3));
	float v = ring > 0.0 ? smoothstep(s, s * 0.6, abs(d - s * 0.8)) * 0.8 : smoothstep(s, 0.0, d);
	return v * step(1.0 - prob, h);
}

vec3 element_fx(vec2 p, float t, float lvl) {
	vec3 c = vec3(0.0);
	vec3 ec = elem_color.rgb;
	if (element == 0) { // feu : braises qui montent en vacillant
		vec2 w = p + vec2(sin(p.y * 12.0 + t * 3.0) * 0.01, 0.0);
		float a = field(w, vec2(14.0, 10.0), vec2(0.0, 1.6), t, 0.12, 0.5, 0.0);
		float b = field(w, vec2(24.0, 18.0), vec2(0.0, 2.6), t, 0.1, 0.4, 0.0);
		c += mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.85, 0.3), b) * (a + b) * (0.8 + 0.4 * sin(t * 20.0 + p.x * 40.0));
		c += vec3(1.0, 0.3, 0.05) * smoothstep(0.55, 1.0, p.y) * (0.12 + 0.08 * sin(t * 6.0));
	} else if (element == 1) { // eau : bulles et caustiques
		c += vec3(0.6, 0.9, 1.0) * field(p + vec2(sin(t + p.y * 8.0) * 0.01, 0.0), vec2(10.0, 7.0), vec2(0.0, 0.9), t, 0.18, 0.45, 1.0);
		float caust = pow(abs(sin(p.x * 18.0 + sin(p.y * 13.0 + t) * 2.0 + t * 0.7)), 18.0);
		c += vec3(0.4, 0.8, 1.0) * caust * 0.25 * (1.0 - p.y);
	} else if (element == 2) { // terre : poussière dorée en suspension
		c += vec3(1.0, 0.8, 0.45) * field(p, vec2(16.0, 12.0), vec2(0.35, -0.12), t, 0.1, 0.45, 0.0) * 0.8;
		c += vec3(1.0, 0.7, 0.35) * smoothstep(0.7, 1.0, p.y) * 0.1;
	} else if (element == 3) { // foudre : arcs électriques intermittents
		float flick = step(0.62, hash(vec2(floor(t * 7.0), 3.0)));
		float x0 = 0.2 + 0.6 * hash(vec2(floor(t * 7.0), 9.0));
		float zig = x0 + (noise(vec2(p.y * 14.0, floor(t * 14.0))) - 0.5) * 0.18;
		float arc = smoothstep(0.012, 0.0, abs(p.x - zig)) * flick;
		c += vec3(0.75, 0.9, 1.0) * arc * 1.6 + vec3(1.0, 0.95, 0.4) * smoothstep(0.05, 0.0, abs(p.x - zig)) * flick * 0.35;
		c += vec3(1.0, 0.95, 0.5) * field(p, vec2(18.0, 13.0), vec2(0.6, -0.4), t, 0.08, 0.3, 0.0);
	} else if (element == 4) { // glace : flocons qui tombent
		vec2 w = p + vec2(sin(t * 1.3 + p.y * 9.0) * 0.015, 0.0);
		c += vec3(0.9, 0.97, 1.0) * (field(w, vec2(12.0, 9.0), vec2(0.0, -0.7), t, 0.14, 0.5, 0.0) + field(w, vec2(22.0, 16.0), vec2(0.0, -1.2), t, 0.1, 0.4, 0.0));
		c += vec3(0.6, 0.85, 1.0) * smoothstep(0.75, 1.0, 1.0 - p.y) * 0.08;
	} else if (element == 5) { // nature : lucioles et pollen
		vec2 w = p + vec2(sin(t * 0.8 + p.y * 6.0), cos(t * 0.7 + p.x * 5.0)) * 0.02;
		float f = field(w, vec2(9.0, 7.0), vec2(0.1, 0.2), t, 0.16, 0.45, 0.0);
		c += vec3(0.75, 1.0, 0.35) * f * (0.6 + 0.4 * sin(t * 4.0 + p.x * 30.0));
	} else if (element == 6) { // ombre : fumée violette ondulante
		float n = noise(vec2(p.x * 5.0, p.y * 4.0 + t * 0.6)) * noise(vec2(p.x * 9.0 - t * 0.3, p.y * 7.0 + t));
		c += vec3(0.6, 0.25, 0.9) * smoothstep(0.15, 0.5, n) * smoothstep(0.2, 1.0, p.y) * 0.9;
		c += vec3(0.9, 0.5, 1.0) * field(p, vec2(12.0, 9.0), vec2(0.0, 0.5), t, 0.1, 0.25, 0.0) * 0.6;
	} else if (element == 7) { // lumière : rayons divins et éclats
		float ray = pow(max(0.0, sin((p.x - p.y * 0.4) * 9.0 + t * 0.8)), 10.0);
		c += vec3(1.0, 0.95, 0.7) * ray * 0.3;
		c += vec3(1.0, 0.95, 0.75) * field(p, vec2(12.0, 9.0), vec2(0.0, 0.4), t, 0.13, 0.4, 0.0);
	} else if (element == 8) { // cosmique : étoiles scintillantes et poussière nébulaire
		vec2 g = floor(p * vec2(30.0, 22.0));
		float h = hash(g);
		float tw = pow(max(0.0, sin(t * (1.0 + h * 3.0) + h * 40.0)), 16.0);
		c += vec3(1.0) * tw * step(0.88, h) * 1.4;
		c += hue(fract(p.x * 0.6 + t * 0.05)) * field(p, vec2(10.0, 8.0), vec2(0.15, 0.05), t, 0.12, 0.35, 0.0) * 0.8;
	} else if (element == 10) { // GOD : poussière d'or ascendante et pluie d'étincelles
		vec2 w = p + vec2(sin(t * 0.9 + p.y * 7.0) * 0.012, 0.0);
		float a = field(w, vec2(16.0, 12.0), vec2(0.0, 0.9), t, 0.12, 0.55, 0.0);
		float b = field(w, vec2(28.0, 20.0), vec2(0.1, 1.6), t, 0.09, 0.45, 0.0);
		c += vec3(1.0, 0.82, 0.3) * a * 1.3 + vec3(1.0, 0.97, 0.75) * b * 1.2;
		float ray = pow(max(0.0, sin((p.x + p.y * 0.3) * 7.0 - t * 0.9)), 14.0);
		c += vec3(1.0, 0.85, 0.45) * ray * 0.35;
	} else if (element == 9) { // néant : particules spectrales et glitch
		c += vec3(0.4, 1.0, 0.8) * field(p, vec2(14.0, 10.0), vec2(0.0, 0.8), t, 0.1, 0.4, 0.0);
		float band = step(0.96, hash(vec2(floor(p.y * 40.0), floor(t * 6.0))));
		c += vec3(0.3, 1.0, 0.8) * band * 0.5;
	}
	return c * (0.55 + 0.25 * lvl);
}

void fragment() {
	vec2 uv = UV;
	float m = rounded(uv);
	vec3 c = vec3(0.0);
	float t = TIME;
	// reflet balayant
	float pos = fract(t * 0.18 + tilt.x * 0.3) * 3.0 - 1.0;
	float d = abs((uv.x + uv.y * 0.55) - pos);
	float shine = smoothstep(0.12, 0.0, d) * 0.55;
	if (mode >= 1) c += vec3(shine) * tint.rgb;
	if (mode == 2 || mode == 3 || mode == 5) {
		float k = (uv.x * 0.8 + uv.y * 1.2) + tilt.x * 0.9 + tilt.y * 0.6 + t * 0.05;
		float bandv = 0.5 + 0.5 * sin(k * 18.0);
		float s = mode == 5 ? 0.55 : 0.28;
		c += hue(fract(k * 1.3)) * bandv * s;
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
	if (mode == 7) {
		float k = (uv.x * 0.7 - uv.y) * 5.0 + tilt.x * 2.5 + tilt.y * 1.5 + t * 0.35;
		c += vec3(1.0, 0.82, 0.38) * (0.12 + 0.14 * sin(k * 2.5));
		c += hue(fract(uv.x * 0.8 + uv.y * 0.5 + t * 0.06 + tilt.x)) * 0.07;
		vec2 g = floor(uv * vec2(30.0, 42.0));
		float h = hash(g + 7.0);
		float tw = pow(max(0.0, sin(t * (2.0 + h * 3.0) + h * 50.0)), 22.0);
		vec2 f = fract(uv * vec2(30.0, 42.0)) - 0.5;
		float star = smoothstep(0.2, 0.0, abs(f.x) * abs(f.y) * 14.0 + length(f) * 0.5);
		c += vec3(1.0, 0.95, 0.7) * tw * star * step(0.8, h) * 1.6;
	}
	if (mode == 6) {
		float k = (uv.x - uv.y) * 6.0 + tilt.x * 2.0 + t * 0.4;
		c += vec3(1.0, 0.8, 0.35) * (0.18 + 0.18 * sin(k * 3.0));
	}
	// particules élémentaires dans l'illustration
	if (element >= 0) {
		vec2 wp = (uv - win.xy) / (win.zw - win.xy);
		if (wp.x > 0.0 && wp.x < 1.0 && wp.y > 0.0 && wp.y < 1.0) {
			float edge = smoothstep(0.0, 0.06, min(min(wp.x, 1.0 - wp.x), min(wp.y, 1.0 - wp.y)));
			c += element_fx(wp + tilt * 0.02, t, fx_level) * edge;
		}
	}
	// cadre animé
	vec2 px = uv * card_size;
	float ed = min(min(px.x, card_size.x - px.x), min(px.y, card_size.y - px.y));
	float bandb = smoothstep(16.0, 4.0, ed) * smoothstep(0.0, 3.0, ed);
	float ang = atan(uv.y - 0.5, (uv.x - 0.5) * card_size.x / card_size.y) / 6.2831 + 0.5;
	if (border == 1) {
		float run = smoothstep(0.08, 0.0, abs(fract(ang - t * 0.22) - 0.5) - 0.42);
		float run2 = smoothstep(0.08, 0.0, abs(fract(ang - t * 0.22 + 0.5) - 0.5) - 0.42);
		c += tint.rgb * bandb * (run + run2) * 1.3 + tint.rgb * bandb * 0.15;
	} else if (border == 2) {
		float runes = step(0.5, fract(ang * 48.0)) * (0.55 + 0.45 * sin(t * 2.5 + ang * 30.0));
		c += vec3(1.0, 0.55, 0.15) * bandb * (0.35 + runes * 0.9);
	} else if (border == 5) {
		// Néon : deux tubes qui grésillent, segments qui s'allument, clignotement d'enseigne
		float flick = 0.75 + 0.25 * step(0.08, fract(sin(floor(t * 9.0) * 12.9898) * 43758.5));
		float tube1 = smoothstep(4.0, 0.0, abs(ed - 10.0));
		float tube2 = smoothstep(3.0, 0.0, abs(ed - 18.0));
		float halo1 = exp(-abs(ed - 10.0) * 0.25);
		float seg = step(0.2, fract(ang * 24.0 - t * 0.8));
		vec3 cy = vec3(0.25, 1.0, 1.0);
		vec3 mg = vec3(1.0, 0.25, 0.85);
		c += (cy * (tube1 * 1.6 + halo1 * 0.35) + mg * tube2 * 1.3 * seg) * flick;
		float scan = step(0.97, fract(uv.y * 60.0 - t * 2.0));
		c += cy * scan * 0.08;
	} else if (border == 6) {
		// Infernale : flammes qui lèchent le cadre, braises, chaleur
		vec2 q = vec2(ang * 40.0, ed * 0.08 - t * 1.8);
		float fl = noise(q) * 0.6 + noise(q * 2.3 + 4.0) * 0.4;
		float height = 26.0 + fl * 34.0;
		float flame = smoothstep(height, height * 0.3, ed) * smoothstep(0.0, 2.0, ed);
		vec3 fire = mix(vec3(0.9, 0.12, 0.02), vec3(1.0, 0.85, 0.3), smoothstep(height, 0.0, ed));
		c += fire * flame * (1.1 + 0.3 * sin(t * 10.0 + ang * 30.0));
		vec2 g6 = floor(px / 7.0);
		float h6 = hash(g6 + floor(t * 3.0));
		c += vec3(1.0, 0.6, 0.15) * step(0.985, h6) * smoothstep(60.0, 0.0, ed) * 2.0;
		c += vec3(1.0, 0.3, 0.05) * 0.06 * (0.5 + 0.5 * sin(uv.y * 30.0 + t * 6.0));
	} else if (border == 7) {
		// Mirage : arc-en-ciel ondoyant qui déforme la lumière comme une chaleur
		float wav = sin(uv.y * 22.0 + t * 2.0 + sin(uv.x * 9.0 + t) * 2.0);
		float band7 = smoothstep(28.0, 4.0, ed) * smoothstep(0.0, 2.0, ed);
		c += hue(fract(ang * 1.5 + wav * 0.08 - t * 0.12)) * band7 * 1.2;
		float shimmer = pow(max(0.0, sin((uv.x + uv.y) * 16.0 + wav * 1.5 - t * 1.5)), 8.0);
		c += hue(fract(uv.x * 0.5 + uv.y * 0.3 + t * 0.05)) * shimmer * 0.3;
		c += vec3(1.0) * smoothstep(1.5, 0.0, abs(ed - 30.0)) * (0.4 + 0.4 * sin(t * 4.0 + ang * 40.0));
	} else if (border == 4) {
		// contour d'or liquide, épais et vivant
		float band4 = smoothstep(30.0, 8.0, ed) * smoothstep(0.0, 2.0, ed);
		float flow = 0.5 + 0.5 * sin(ang * 6.2831 * 18.0 - t * 4.0 + sin(ed * 0.4 + t * 2.0) * 1.5);
		float n4 = noise(vec2(ang * 60.0 - t * 1.5, ed * 0.15 + t * 0.5));
		vec3 gold = mix(vec3(0.75, 0.42, 0.05), vec3(1.0, 0.86, 0.35), flow * 0.7 + n4 * 0.3);
		c += gold * band4 * 1.15;
		// deux comètes de lumière qui font le tour
		for (int i = 0; i < 2; i++) {
			float ph = fract(ang - t * 0.18 + float(i) * 0.5);
			float com = smoothstep(0.07, 0.0, min(ph, 1.0 - ph)) + smoothstep(0.18, 0.0, ph) * 0.5 * step(ph, 0.5);
			c += vec3(1.0, 0.98, 0.85) * com * band4 * 2.2;
		}
		// éclats scintillants sur le cadre
		vec2 g4 = floor(px / 9.0);
		float h4 = hash(g4 + 3.3);
		float tw4 = pow(max(0.0, sin(t * (2.5 + h4 * 4.0) + h4 * 70.0)), 26.0);
		c += vec3(1.0, 1.0, 0.85) * tw4 * step(0.86, h4) * band4 * 3.0;
		// liseré intérieur qui pulse
		float inner = smoothstep(2.5, 0.0, abs(ed - 36.0));
		c += vec3(1.0, 0.8, 0.35) * inner * (0.5 + 0.5 * sin(t * 3.0 + ang * 25.0)) * 0.8;
		// rayons divins qui balaient la carte
		float sweep = pow(max(0.0, sin((uv.x * 1.2 - uv.y * 0.8) * 4.0 + t * 0.7)), 18.0);
		c += vec3(1.0, 0.9, 0.55) * sweep * 0.22;
	} else if (border == 3) {
		c += hue(fract(ang * 2.0 - t * 0.3)) * bandb * 1.1;
		float sx = min(abs(uv.x - 0.3333), abs(uv.x - 0.6667));
		float sy = min(abs(uv.y - 0.3333), abs(uv.y - 0.6667));
		float seam = smoothstep(0.004, 0.0, min(sx, sy));
		c += hue(fract((uv.x + uv.y) * 1.5 - t * 0.4)) * seam * (0.4 + 0.3 * sin(t * 3.0));
	}
	COLOR = vec4(c * intensity * m, 1.0);
}
