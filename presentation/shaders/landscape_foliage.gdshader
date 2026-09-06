shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float wind_strength = 0.035;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.73 + origin.z * 0.51;
	float bend = sin(TIME * 1.15 + phase) + sin(TIME * 1.9 + phase * 1.3) * 0.25;
	float height = max(VERTEX.y, 0.0);
	VERTEX.x += bend * wind_strength * height * height;
	VERTEX.z += cos(TIME * 0.9 + phase) * wind_strength * height * 0.4;
}

void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
