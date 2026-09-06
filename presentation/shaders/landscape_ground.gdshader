shader_type spatial;
render_mode diffuse_burley;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float broad = sin(world_xz.x * 0.61 + sin(world_xz.y * 0.33) * 2.0) * sin(world_xz.y * 0.52 + world_xz.x * 0.16);
	float small = sin(world_xz.x * 4.3 + world_xz.y * 1.7) * sin(world_xz.y * 3.8 - world_xz.x * 2.1);
	ALBEDO = COLOR.rgb * (1.0 + broad * 0.045 + small * 0.012);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
