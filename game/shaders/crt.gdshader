shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Диегетический экран CRT. Сэмплирует SubViewport и добавляет развёртку,
// бочку, дрожание строк и зелёное свечение люминофора.
uniform sampler2D screen_tex : filter_linear, repeat_disable;
uniform float glow = 1.25;
uniform float curvature = 0.10;
uniform float scanline = 0.24;
uniform float flicker = 0.025;
uniform vec4 tint : source_color = vec4(0.78, 1.0, 0.86, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + dot(c, c) * curvature * 0.16;
	uv = c * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
		ALPHA = 1.0;
	} else {
		float scan = 1.0 - scanline * (0.5 + 0.5 * sin(uv.y * 820.0 + TIME * 18.0));
		float n = fract(sin(dot(uv * vec2(913.7, 731.3) + TIME, vec2(12.9898, 78.233))) * 43758.5453);
		vec3 col = texture(screen_tex, uv).rgb * tint.rgb;
		col *= scan * (1.0 - flicker * n);
		float v = smoothstep(0.98, 0.30, length(c));
		col *= mix(0.48, 1.0, v);
		col *= glow;
		ALBEDO = col;
		EMISSION = col * 1.15;
		ALPHA = 1.0;
	}
}
