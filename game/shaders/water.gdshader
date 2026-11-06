shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

// Вода в трюме: тонкий слой с круговой рябью от капель и насоса.
uniform vec4 water_color : source_color = vec4(0.018, 0.075, 0.082, 1.0);
uniform float wave_height = 0.008;
uniform float opacity : hint_range(0.0, 1.0) = 0.74;
uniform float time_scale = 1.0;

void vertex() {
	float t = TIME * time_scale;
	VERTEX.y += sin(VERTEX.x * 17.0 + t * 1.3) * wave_height;
	VERTEX.y += sin(VERTEX.z * 23.0 - t * 1.05) * wave_height * 0.7;
	VERTEX.y += sin((VERTEX.x + VERTEX.z) * 41.0 + t * 2.2) * wave_height * 0.25;
}

void fragment() {
	float t = TIME * time_scale;
	float r = length(UV - vec2(0.5)) * 18.0;
	float ripple = 0.5 + 0.5 * sin(r * 5.0 - t * 2.0);
	float fine = 0.5 + 0.5 * sin((UV.x + UV.y) * 90.0 + t * 2.7);
	float sheen = ripple * 0.55 + fine * 0.25;
	ALBEDO = water_color.rgb + sheen * vec3(0.018, 0.065, 0.072);
	ALPHA = opacity;
	ROUGHNESS = mix(0.22, 0.06, sheen);
	METALLIC = 0.45;
	EMISSION = vec3(0.0, 0.035, 0.042) * sheen;
}
