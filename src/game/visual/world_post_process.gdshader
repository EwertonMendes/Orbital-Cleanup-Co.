shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 grade_tint : source_color = vec4(0.33, 0.86, 0.98, 1.0);
uniform vec4 profile_color : source_color = vec4(0.45, 0.90, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(0.55, 0.95, 0.81, 1.0);
uniform float effect_strength : hint_range(0.0, 1.0) = 0.58;
uniform float glow_strength : hint_range(0.0, 0.3) = 0.05;
uniform float grain_strength : hint_range(0.0, 0.04) = 0.0;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform float profile_strength : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.0;
uniform float quality_factor : hint_range(0.0, 1.0) = 1.0;
uniform int profile_mode = 0;
uniform vec2 profile_focal_point = vec2(0.5, 0.5);
uniform vec4 environment_color : source_color = vec4(0.12, 0.35, 0.58, 1.0);
uniform float environment_fog_strength : hint_range(0.0, 0.4) = 0.0;
uniform float environment_distortion : hint_range(0.0, 0.3) = 0.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float tri_wave(float value) {
	return abs(fract(value) - 0.5) * 2.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	vec2 from_profile = uv - profile_focal_point;
	float profile_radius = length(from_profile);
	float profile = profile_strength * quality_factor;

	if (profile_mode == 2) {
		float wave_x = tri_wave(uv.y * 4.2 + TIME * 0.040) - 0.5;
		float wave_y = tri_wave(uv.x * 3.4 - TIME * 0.032) - 0.5;
		uv += vec2(wave_x, wave_y) * 0.0048 * profile;
	} else if (profile_mode == 3) {
		float heat = tri_wave(uv.y * 9.0 + TIME * 0.15) - 0.5;
		float corona = 1.0 - smoothstep(0.12, 0.92, profile_radius);
		uv.x += heat * 0.0065 * profile * (0.35 + corona * 0.65);
	} else if (profile_mode == 4) {
		float anomaly = (1.0 - smoothstep(0.06, 0.72, profile_radius)) * profile;
		float ring = tri_wave(profile_radius * 9.0 - TIME * 0.10) - 0.5;
		uv += vec2(-from_profile.y, from_profile.x) * ring * 0.024 * anomaly;
	}

	float hazard_wave = tri_wave(uv.y * 16.0 + TIME * 0.18) - 0.5;
	uv.x += hazard_wave * environment_distortion * 0.0035 * quality_factor;
	uv = clamp(uv, vec2(0.001), vec2(0.999));

	vec3 base = texture(screen_texture, uv).rgb;
	float luma = luminance(base);
	float highlight = smoothstep(0.68, 0.96, luma);
	base += base * highlight * glow_strength * effect_strength;
	base = mix(vec3(luma), base, 1.04 + 0.035 * effect_strength);
	base = (base - 0.5) * (1.0 + 0.045 * effect_strength) + 0.5;
	base += grade_tint.rgb * (0.008 + 0.010 * effect_strength);

	float profile_pulse = 0.72 + tri_wave(TIME * 0.055 + uv.x * 0.7) * 0.28;
	float profile_mix = profile * (0.018 + shimmer_strength * 0.070 * profile_pulse);
	if (profile_mode == 1) {
		profile_mix *= 0.55;
	} else if (profile_mode == 3) {
		profile_mix *= 1.25;
	}
	base = mix(base, profile_color.rgb, clamp(profile_mix, 0.0, 0.16));

	float vignette = smoothstep(0.44, 0.84, length(from_center * vec2(1.0, 0.88)));
	float anomaly_vignette = profile_mode == 4 ? profile * 0.14 : 0.0;
	base *= 1.0 - vignette * (0.18 * effect_strength + anomaly_vignette);

	float scan = tri_wave(SCREEN_UV.y * 95.0 + TIME * 0.12);
	float interference = environment_distortion * (0.38 + vignette * 0.32 + scan * 0.30);
	base = mix(base, environment_color.rgb, environment_fog_strength + interference * 0.055);
	base = mix(base, flash_color.rgb, clamp(flash_strength, 0.0, 1.0));

	COLOR = vec4(max(base, vec3(0.0)), 1.0);
}
