// Traitement de l'illustration : teinte alternative, chromatique, silhouette, animation, glitch.
// mode : 0 normal, 1 alternate (teinte), 2 chromatique, 3 silhouette, 4 animée, 5 glitch, 6 sépia (verrouillée),
// 7 singularité (trou noir qui courbe l'illustration : lentille gravitationnelle, horizon, disque d'accrétion)
shader_type canvas_item;

uniform int mode = 0;
uniform float hue_shift = 0.33;
uniform vec2 parallax = vec2(0.0);
uniform vec4 sil_color : source_color = vec4(0.12, 0.08, 0.2, 1.0);
uniform vec4 reg = vec4(0.0, 0.0, 1.0, 1.0);   // zone de l'illustration dans la texture (atlas)
uniform float aspect = 1.0;                      // largeur / hauteur de la zone affichée

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}
float hash(float x) { return fract(sin(x * 91.7) * 43758.5453); }

void fragment() {
	vec2 uv = UV + parallax;
	if (mode == 4) {
		uv.x += sin(uv.y * 40.0 + TIME * 2.0) * 0.0018;
		uv.y += sin(uv.x * 30.0 + TIME * 1.6) * 0.0018;
	}
	if (mode == 5) {
		float band = floor(uv.y * 40.0);
		float g = step(0.93, hash(band + floor(TIME * 8.0)));
		uv.x += (hash(band * 3.1 + floor(TIME * 8.0)) - 0.5) * 0.04 * g;
	}
	vec4 col = texture(TEXTURE, uv);
	if (mode == 7) {
		vec2 rs2 = reg.zw - reg.xy;
		vec2 lp = (uv - reg.xy) / rs2;
		vec2 c = vec2(0.5 + 0.16 * sin(TIME * 0.13), 0.46 + 0.08 * cos(TIME * 0.11));
		vec2 d = (lp - c) * vec2(aspect, 1.0);
		float r = length(d);
		float hz = 0.1;
		// lentille : la lumière est déviée autour de la masse
		float bend = hz * hz * 1.8 / max(r, 0.002);
		vec2 lp2 = lp - normalize(d + 1e-5) / vec2(aspect, 1.0) * bend;
		lp2 = clamp(lp2, 0.002, 0.998);
		col = texture(TEXTURE, reg.xy + lp2 * rs2);
		col.rgb *= smoothstep(hz * 0.95, hz * 2.4, r) * 0.6 + 0.4;
		// disque d'accrétion incliné, plus brillant du côté qui vient vers nous
		float ang = atan(d.y * 3.2, d.x);
		float er = length(vec2(d.x, d.y * 3.2));
		float disk = smoothstep(hz * 1.3, hz * 1.7, er) * (1.0 - smoothstep(hz * 2.4, hz * 3.6, er));
		float swirl = 0.55 + 0.45 * sin(ang * 6.0 - TIME * 3.0 + er * 40.0);
		float dop = 1.0 + 0.7 * sign(-d.x) * smoothstep(0.0, hz * 2.0, abs(d.x));
		vec3 hot = mix(vec3(1.0, 0.45, 0.1), vec3(1.0, 0.95, 0.8), swirl);
		col.rgb += hot * disk * swirl * dop * 1.1 * step(hz * 0.9, r);
		// anneau de photons et horizon des événements
		col.rgb += vec3(1.0, 0.85, 0.6) * exp(-pow((r - hz * 1.07) / 0.01, 2.0)) * 1.6;
		col.rgb *= smoothstep(hz * 0.92, hz * 1.0, r);
	}
	if (mode == 1 || mode == 2) {
		vec3 h = rgb2hsv(col.rgb);
		h.x = fract(h.x + hue_shift);
		if (mode == 2) { h.y = min(1.0, h.y * 1.35); h.z = min(1.0, h.z * 1.08); }
		col.rgb = hsv2rgb(h);
	}
	if (mode == 3) {
		float l = dot(col.rgb, vec3(0.3, 0.59, 0.11));
		col.rgb = sil_color.rgb * (0.35 + l * 0.5);
	}
	if (mode == 5) {
		float r = texture(TEXTURE, uv + vec2(0.004, 0.0)).r;
		float b = texture(TEXTURE, uv - vec2(0.004, 0.0)).b;
		col.rgb = vec3(r, col.g, b);
	}
	if (mode == 6) {
		float l = dot(col.rgb, vec3(0.3, 0.59, 0.11));
		col.rgb = mix(vec3(l), col.rgb, 0.3) * 0.88;
	}
	COLOR = col * COLOR;
}
