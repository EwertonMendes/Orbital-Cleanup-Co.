shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 grade_tint : source_color = vec4(0.33, 0.86, 0.98, 1.0);
uniform vec4 flash_color : source_color = vec4(0.55, 0.95, 0.81, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.58;
uniform float glow_strength : hint_range(0.0, 0.3) = 0.05;
uniform float grain_strength : hint_range(0.0, 0.04) = 0.0;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 environment_color : source_color = vec4(0.12, 0.35, 0.58, 1.0);
uniform float environment_fog_strength : hint_range(0.0, 0.4) = 0.0;
uniform float environment_distortion : hint_range(0.0, 0.3) = 0.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base = texture(screen_texture, uv).rgb;
	vec2 from_center = uv - vec2(0.5);

	float luma = luminance(base);
	float highlight = smoothstep(0.68, 0.96, luma);
	base += base * highlight * glow_strength * effect_strength;
	base = mix(vec3(luma), base, 1.04 + 0.035 * effect_strength);
	base = (base - 0.5) * (1.0 + 0.045 * effect_strength) + 0.5;
	base += grade_tint.rgb * (0.008 + 0.010 * effect_strength);

	float vignette = smoothstep(0.44, 0.84, length(from_center * vec2(1.0, 0.88)));
	base *= 1.0 - vignette * 0.18 * effect_strength;

	float interference = environment_distortion * (0.5 + vignette * 0.5);
	base = mix(base, environment_color.rgb, environment_fog_strength + interference * 0.06);
	base = mix(base, flash_color.rgb, clamp(flash_strength, 0.0, 1.0));

	COLOR = vec4(max(base, vec3(0.0)), 1.0);
}
