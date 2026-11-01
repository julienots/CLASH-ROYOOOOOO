// Halo radial (auras, éclats de lumière).
shader_type canvas_item;
render_mode blend_add;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 2.0;
uniform float rays = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float g = pow(max(0.0, 1.0 - r), power);
	float ray = rays > 0.0 ? (0.5 + 0.5 * sin(a * rays + TIME * 1.5)) * (1.0 - r) : 0.0;
	COLOR = vec4(color.rgb * (g + ray * 0.6) * color.a, 1.0);
}
