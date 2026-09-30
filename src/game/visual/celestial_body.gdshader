shader_type canvas_item;
render_mode unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.45, 0.90, 1.0, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.35;
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.08;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.45;
uniform float quality_factor : hint_range(0.0, 1.0) = 1.0;
uniform int profile_mode = 0;

float tri_wave(float value) {
	return abs(fract(value) - 0.5) * 2.0;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float radial = length(centered);
	float phase = tri_wave(TIME * 0.055 + UV.y * 2.3 + UV.x * 1.4);
	float shimmer = (phase - 0.5) * shimmer_strength * quality_factor;

	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float bright = smoothstep(0.34, 0.92, luma);
	float body_energy = atmosphere_strength * (0.035 + bright * 0.075);
	body_energy += shimmer * 0.035 * effect_strength;

	vec3 rgb = source.rgb + atmosphere_color.rgb * body_energy;
	if (profile_mode == 2) {
		rgb = mix(rgb, atmosphere_color.rgb, 0.025 * effect_strength * quality_factor);
	} else if (profile_mode == 3) {
		float solar_pulse = 0.75 + tri_wave(TIME * 0.12) * 0.25;
		rgb += atmosphere_color.rgb * 0.10 * effect_strength * solar_pulse * quality_factor;
	} else if (profile_mode == 4) {
		rgb = mix(rgb, atmosphere_color.rgb, 0.045 * effect_strength * quality_factor);
	}

	float halo_shape = 1.0 - smoothstep(0.34, 0.52, radial);
	float halo = halo_shape * (1.0 - source.a) * atmosphere_strength * 0.16 * quality_factor;
	float alpha = max(source.a, halo);
	vec3 output_rgb = mix(rgb, atmosphere_color.rgb, halo * 0.72);

	COLOR = vec4(output_rgb, alpha) * COLOR;
}
