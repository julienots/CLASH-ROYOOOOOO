shader_type spatial;
// Rivière cartoon : vagues qui défilent + reflets.
uniform vec4 base_color : source_color = vec4(0.16, 0.72, 0.91, 1.0);

void fragment() {
	vec2 uv = UV * vec2(10.0, 1.0);
	float t = TIME * 0.6;
	float w = sin(uv.x * 6.0 + t * 3.0 + sin(uv.y * 8.0 + t) * 1.5);
	float lines = smoothstep(0.82, 0.95, sin(uv.y * 22.0 + w * 1.2 + t * 2.0));
	float sparkle = smoothstep(0.97, 1.0, sin(uv.x * 23.0 + t * 4.0) * sin(uv.y * 17.0 - t * 3.0));
	vec3 c = base_color.rgb * (0.85 + 0.15 * w) + vec3(1.0) * (lines * 0.35 + sparkle * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.15;
	METALLIC = 0.1;
	EMISSION = base_color.rgb * 0.15;
}
