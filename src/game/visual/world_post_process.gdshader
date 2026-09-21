shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 grade_tint : source_color = vec4(0.33, 0.86, 0.98, 1.0);
uniform vec4 flash_color : source_color = vec4(0.55, 0.95, 0.81, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.58;
uniform float glow_strength : hint_range(0.0, 0.3) = 0.08;
uniform float grain_strength : hint_range(0.0, 0.04) = 0.008;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float random_noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME * 8.0) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	float edge = smoothstep(0.18, 0.72, length(from_center));
	float aberration = 0.0012 * effect_strength * edge;
	vec2 direction = normalize(from_center + vec2(0.00001));

	vec3 base;
	base.r = texture(screen_texture, uv + direction * aberration).r;
	base.g = texture(screen_texture, uv).g;
	base.b = texture(screen_texture, uv - direction * aberration).b;

	vec2 px = SCREEN_PIXEL_SIZE * 2.25;
	vec3 glow = (
		texture(screen_texture, uv + vec2(px.x, 0.0)).rgb +
		texture(screen_texture, uv - vec2(px.x, 0.0)).rgb +
		texture(screen_texture, uv + vec2(0.0, px.y)).rgb +
		texture(screen_texture, uv - vec2(0.0, px.y)).rgb
	) * 0.25;
	float highlight = smoothstep(0.58, 0.94, luminance(glow));
	base += glow * highlight * glow_strength * effect_strength;

	float luma = luminance(base);
	base = mix(vec3(luma), base, 1.05 + 0.05 * effect_strength);
	base = (base - 0.5) * (1.0 + 0.06 * effect_strength) + 0.5;
	base += grade_tint.rgb * (0.010 + 0.012 * effect_strength);

	float vignette = smoothstep(0.42, 0.82, length(from_center * vec2(1.0, 0.88)));
	base *= 1.0 - vignette * 0.22 * effect_strength;

	float grain = random_noise(floor(uv / SCREEN_PIXEL_SIZE * 0.5)) - 0.5;
	base += grain * grain_strength * effect_strength;
	base = mix(base, flash_color.rgb, clamp(flash_strength, 0.0, 1.0));

	COLOR = vec4(max(base, vec3(0.0)), 1.0);
}
