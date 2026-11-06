shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx, fog_disabled;

// Иллюминатор: три слоя стекла, конденсат, потёки и маска протирания.
uniform float condensation : hint_range(0.0, 1.0) = 0.58;
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.30, 0.47, 0.50, 1.0);
uniform float time_scale = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	float slow = vnoise(uv * 7.0 + vec2(0.0, t * 0.015));
	float fine = vnoise(uv * 31.0 + vec2(t * 0.01, -t * 0.02));
	float drops = smoothstep(0.58, 0.94, fine) * smoothstep(0.30, 0.72, slow);
	float streaks = smoothstep(0.62, 1.0, vnoise(vec2(uv.x * 46.0, uv.y * 3.0 + t * 0.03)));
	float cond = condensation * (1.0 - wipe) * (0.22 + drops * 0.92 + streaks * 0.35);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = tint.rgb + fres * vec3(0.18, 0.28, 0.32);
	ALBEDO = col;
	ALPHA = clamp(0.07 + cond * 0.58 + fres * 0.28, 0.0, 0.94);
	ROUGHNESS = mix(0.035, 0.72, cond);
	METALLIC = 0.08;
	EMISSION = vec3(0.018, 0.055, 0.070) * (0.35 + cond);
}
