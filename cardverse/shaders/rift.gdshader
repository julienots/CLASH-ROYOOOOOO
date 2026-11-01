// Faille cosmique pour les révélations de très haute rareté.
shader_type canvas_item;
render_mode blend_add;

uniform float open = 0.0;   // 0 fermée -> 1 ouverte
uniform vec4 color : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform vec2 res = vec2(720.0, 1280.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float x = (uv.x - 0.5) * res.x / res.y;
	float y = uv.y - 0.5;
	float jag = sin(y * 40.0 + TIME * 3.0) * 0.012 + sin(y * 97.0 - TIME * 5.0) * 0.006;
	float w = open * 0.18 * (1.0 - smoothstep(0.0, 0.5, abs(y)) * 0.9);
	float d = abs(x + jag) - w;
	float core = smoothstep(0.02, -0.01, d) * clamp(open * 6.0, 0.0, 1.0);
	float glow = exp(-max(d, 0.0) * 18.0) * open;
	vec3 c = color.rgb * glow * 1.4 + vec3(1.0) * core * 0.9;
	vec2 g = floor(uv * res / 5.0);
	float h = hash(g);
	float star = step(0.985, h) * core * (0.5 + 0.5 * sin(TIME * 4.0 + h * 50.0));
	c += vec3(1.0) * star;
	COLOR = vec4(c, 1.0);
}
