// Vernis réaliste posé sur toute la carte : grain du carton, reflet doux qui suit l'inclinaison,
// biseau lumineux sur le bord arrondi et léger assombrissement des coins.
shader_type canvas_item;

uniform vec2 tilt = vec2(0.0);
uniform vec2 card_size = vec2(450.0, 630.0);
uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float sd_round(vec2 uv) {
	vec2 p = (uv - 0.5) * card_size;
	vec2 q = abs(p) - card_size * 0.5 + 22.0;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 22.0;
}

void fragment() {
	vec2 uv = UV;
	float d = sd_round(uv);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	// grain du carton (très fin)
	float g = hash(floor(uv * card_size / 1.5)) - 0.5;
	vec4 col = vec4(vec3(0.5 + g), abs(g) * 0.07);
	// reflet doux du vernis : une large tache claire qui glisse avec l'inclinaison
	vec2 lp = vec2(0.28, 0.18) - tilt * 0.35;
	float spec = exp(-dot((uv - lp) * vec2(1.0, 1.4), (uv - lp) * vec2(1.0, 1.4)) * 5.0);
	col = mix(col, vec4(1.0, 1.0, 1.0, 0.13), spec);
	// biseau : liseré clair en haut à gauche, sombre en bas à droite, le long du bord
	float rim = smoothstep(-5.0, -1.0, d) * (1.0 - smoothstep(-1.0, 0.5, d));
	float side = dot(normalize(uv - 0.5 + 1e-4), vec2(-0.6, -0.8));
	col = mix(col, vec4(1.0, 1.0, 1.0, 0.35), rim * max(side, 0.0));
	col = mix(col, vec4(0.0, 0.0, 0.0, 0.3), rim * max(-side, 0.0));
	// vignette des coins (encre plus dense sur les bords)
	float vig = smoothstep(0.35, 0.75, length((uv - 0.5) * vec2(1.0, 0.8)));
	col = mix(col, vec4(0.0, 0.0, 0.0, 0.12), vig * (1.0 - spec));
	col.a *= inside * strength;
	COLOR = col;
}
