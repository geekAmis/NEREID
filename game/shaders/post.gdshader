shader_type canvas_item;
render_mode unshaded;

// Один full-screen pass: зерно, виньетка, хроматическая аберрация, бочка,
// красная кромка тревоги и белая вспышка. Управляется из PostProcess.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain = 0.045;
uniform float vignette = 0.38;
uniform float chroma = 0.0016;
uniform float danger = 0.0;
uniform float flash = 0.0;
uniform float barrel = 0.035;
uniform float exposure = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 + barrel * r2);

	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float ca = chroma * (1.0 + danger * 2.2);
		vec3 col;
		col.r = texture(screen_texture, uv + vec2(ca, 0.0)).r;
		col.g = texture(screen_texture, uv).g;
		col.b = texture(screen_texture, uv - vec2(ca, 0.0)).b;

		float n = hash12(SCREEN_UV * vec2(1920.0, 1080.0) + fract(TIME) * 173.0);
		col += (n - 0.5) * grain;
		col *= exposure;

		float v = smoothstep(0.88, 0.22, length(c));
		col *= mix(1.0 - vignette, 1.0, v);

		// Тревога: красная кромка, пульсирующая на частоте сердца.
		float pulse = 0.65 + 0.35 * sin(TIME * 5.4);
		col = mix(col, vec3(0.58, 0.015, 0.01), danger * (1.0 - v) * 0.48 * pulse);

		col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
		COLOR = vec4(col, 1.0);
	}
}
