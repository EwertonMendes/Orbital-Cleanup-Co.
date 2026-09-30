shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D noise_a : repeat_enable, filter_linear;
uniform sampler2D noise_b : repeat_enable, filter_linear;
uniform vec4 nebula_color : source_color = vec4(0.08, 0.22, 0.45, 1.0);
uniform vec4 accent_color : source_color = vec4(0.45, 0.86, 1.0, 1.0);
uniform vec4 background_color : source_color = vec4(0.01, 0.03, 0.07, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.7;
uniform float quality_factor : hint_range(0.0, 1.0) = 1.0;
uniform float foreground_mix : hint_range(0.0, 1.0) = 0.0;
uniform int profile_mode = 0;
uniform vec2 focal_point = vec2(0.5, 0.5);
uniform vec2 camera_offset = vec2(0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);

float tri_wave(float value) {
	return abs(fract(value) - 0.5) * 2.0;
}

float band(float value, float center, float width) {
	return 1.0 - smoothstep(width, width * 1.75, abs(value - center));
}

void fragment() {
	vec2 uv = UV;
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	vec2 centered = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	vec2 focal_delta = (uv - focal_point) * vec2(aspect, 1.0);
	float radius = length(focal_delta);
	vec2 direction = focal_delta / max(radius, 0.0001);
	vec2 tangent = vec2(-direction.y, direction.x);
	float t = TIME;
	float strength = intensity * quality_factor;

	vec2 drift_a = vec2(t * 0.010, -t * 0.006) + camera_offset * 0.035;
	vec2 drift_b = vec2(-t * 0.006, t * 0.009) + camera_offset * 0.020;
	if (foreground_mix > 0.5) {
		drift_a *= 2.25;
		drift_b *= 1.75;
	}

	float n1 = texture(noise_a, uv * (1.55 + foreground_mix * 0.9) + drift_a).r;
	float n2 = texture(noise_b, uv * (3.10 + foreground_mix * 1.4) + drift_b).r;
	float n3 = texture(noise_a, uv * 6.2 - drift_b * 1.8 + n2 * 0.075).r;
	float broad = n1 * 0.58 + n2 * 0.29 + n3 * 0.13;

	vec3 color = accent_color.rgb;
	float alpha = 0.0;

	if (profile_mode == 0) {
		float aurora_shape = smoothstep(0.48, 0.76, broad);
		float ribbon = band(
			uv.y + (n2 - 0.5) * 0.30 + (n1 - 0.5) * 0.16,
			0.43 + (tri_wave(t * 0.018) - 0.5) * 0.08,
			0.13
		);
		float haze = aurora_shape * ribbon;
		color = mix(nebula_color.rgb, accent_color.rgb, 0.58 + n3 * 0.34);
		alpha = haze * (0.13 + 0.11 * strength);
		if (foreground_mix > 0.5) {
			alpha *= 0.35;
		}
	} else if (profile_mode == 1) {
		float lane = smoothstep(0.38, 0.73, broad);
		float sheet = band(
			uv.y + (n1 - 0.5) * 0.44,
			0.52 + (tri_wave(t * 0.010) - 0.5) * 0.12,
			0.24
		);
		float grit = smoothstep(0.64, 0.91, n3);
		float dust = lane * sheet;
		vec3 pale = mix(nebula_color.rgb, accent_color.rgb, 0.42 + n2 * 0.33);
		vec3 shadow = mix(background_color.rgb, nebula_color.rgb, 0.55);
		color = mix(shadow, pale, clamp(dust * 0.85 + grit * 0.22, 0.0, 1.0));
		alpha = dust * (0.17 + 0.20 * strength) + grit * 0.055 * strength;
		if (foreground_mix > 0.5) {
			alpha *= 0.56;
		}
	} else if (profile_mode == 2) {
		float cloud = smoothstep(0.30, 0.73, broad);
		float filament = smoothstep(0.56, 0.88, n2 * 0.55 + n3 * 0.55);
		float cavity = 1.0 - smoothstep(0.24, 0.78, length(centered + vec2(0.18, -0.08)));
		vec3 deep = mix(background_color.rgb, nebula_color.rgb, 0.72);
		vec3 luminous = mix(nebula_color.rgb, accent_color.rgb, clamp(n2 * 0.82 + filament * 0.46, 0.0, 1.0));
		color = mix(deep, luminous, clamp(cloud * 0.78 + filament * 0.48, 0.0, 1.0));
		alpha = cloud * (0.20 + 0.30 * strength) + filament * 0.16 * strength;
		alpha += cavity * 0.055 * strength;
		if (foreground_mix > 0.5) {
			alpha = filament * (0.10 + 0.18 * strength) + cloud * 0.075 * strength;
		}
	} else if (profile_mode == 3) {
		float radial_flow = texture(
			noise_a,
			uv * 3.3 + direction * (t * 0.055) + camera_offset * 0.010
		).r;
		float plasma = smoothstep(0.44, 0.79, radial_flow * 0.72 + n2 * 0.38);
		float corona = 1.0 - smoothstep(0.14, 0.92, radius);
		float shock = band(radius + (n3 - 0.5) * 0.10, 0.43 + tri_wave(t * 0.025) * 0.05, 0.09);
		float stream = smoothstep(0.62, 0.92, n3) * smoothstep(0.18, 0.95, radius);
		vec3 hot = mix(nebula_color.rgb, accent_color.rgb, 0.65 + n3 * 0.30);
		color = mix(nebula_color.rgb, hot, clamp(plasma + shock * 0.85, 0.0, 1.0));
		alpha = corona * plasma * (0.16 + 0.24 * strength);
		alpha += shock * 0.16 * strength + stream * 0.075 * strength;
		if (foreground_mix > 0.5) {
			alpha = stream * 0.10 * strength + plasma * corona * 0.085 * strength;
		}
	} else {
		float swirl_noise = texture(
			noise_b,
			uv * 4.1 + tangent * (t * 0.042) + direction * n1 * 0.11
		).r;
		float inner_ring = band(radius + (swirl_noise - 0.5) * 0.075, 0.31, 0.075);
		float outer_ring = band(radius + (n3 - 0.5) * 0.11, 0.51, 0.13);
		float accretion = max(inner_ring, outer_ring * 0.62);
		float core = 1.0 - smoothstep(0.10, 0.285, radius);
		float lens = band(radius, 0.36, 0.17);
		vec3 violet = mix(nebula_color.rgb, accent_color.rgb, 0.24 + swirl_noise * 0.72);
		vec3 gold = mix(accent_color.rgb, vec3(1.0, 0.70, 0.34), 0.42);
		color = mix(violet, gold, clamp(inner_ring * 0.82 + n2 * 0.22, 0.0, 1.0));
		alpha = accretion * (0.18 + 0.30 * strength) + lens * 0.055 * strength;
		if (core > 0.0) {
			color = mix(color, vec3(0.0), core * 0.96);
			alpha = max(alpha, core * (0.42 + 0.18 * strength));
		}
		if (foreground_mix > 0.5) {
			alpha = outer_ring * 0.075 * strength + smoothstep(0.70, 0.93, swirl_noise) * lens * 0.08 * strength;
		}
	}

	alpha *= (0.82 + foreground_mix * 0.18);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.72));
}
