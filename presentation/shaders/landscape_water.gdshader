shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform float map_size = 128.0;
uniform vec3 deep_color : source_color = vec3(0.22, 0.49, 0.52);
uniform vec3 shallow_color : source_color = vec3(0.43, 0.66, 0.62);
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float depth = texture(shore_distance, world_xz / map_size).r;
	float swell = sin(world_xz.x * 0.65 + world_xz.y * 0.85 + TIME * 0.38);
	float wave = sin(world_xz.y * 8.0 + world_xz.x * 2.3 + swell * 1.7 - TIME * 1.25);
	float broken = smoothstep(0.35, 0.80, sin(world_xz.x * 2.0 - world_xz.y * 0.7 + TIME * 0.17));
	float ripple = smoothstep(0.93, 1.0, wave) * broken;
	float detail = 1.0 - smoothstep(0.08, 0.28, length(fwidth(world_xz)));
	float near_bank = 1.0 - smoothstep(0.02, 0.20, depth);
	float foam = smoothstep(0.75, 1.0, sin(depth * 125.0 - TIME * 0.85 + swell)) * near_bank;
	ALBEDO = mix(shallow_color, deep_color, smoothstep(0.0, 0.65, depth));
	ALBEDO += swell * 0.012 + ripple * detail * 0.07 + foam * 0.065;
	NORMAL = normalize(NORMAL + vec3(sin(world_xz.x * 2.3 + TIME * 0.5) * 0.045, sin(world_xz.y * 3.1 - TIME * 0.7) * 0.065, 0.0));
	ROUGHNESS = 0.62;
	SPECULAR = 0.25;
}
