shader_type spatial;
// Public des tribunes : chaque spectateur sautille à son rythme ; « excite » les fait bondir (tour détruite).
uniform float excite = 0.0;
varying vec3 tint;

void vertex() {
	float id = float(INSTANCE_ID);
	float speed = 3.0 + fract(id * 0.37) * 4.0;
	float jump = (0.03 + excite * 0.32) * max(0.0, sin(TIME * speed * (1.0 + excite) + id * 1.7));
	VERTEX.y += jump;
	VERTEX.x += sin(TIME * 1.3 + id) * 0.02;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.8;
}
