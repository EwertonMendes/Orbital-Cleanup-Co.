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
		float ribbon = band(uv.y + (n2 - 0.5) * 0.30 + (n1 - 0.5) * 0.16, 0.43 + (tri_wave(t * 0.018) - 0.5) * 0.08, 0.13);
		color = mix(nebula_color.rgb, accent_color.rgb, 0.58 + n3 * 0.34);
		alpha = aurora_shape * ribbon * (0.13 + 0.11 * strength);
		if (foreground_mix > 0.5) alpha *= 0.35;
	} else if (profile_mode == 1) {
		float lane = smoothstep(0.38, 0.73, broad);
		float sheet = band(uv.y + (n1 - 0.5) * 0.44, 0.52 + (tri_wave(t * 0.010) - 0.5) * 0.12, 0.24);
		float grit = smoothstep(0.64, 0.91, n3);
		float dust = lane * sheet;
		color = mix(mix(background_color.rgb, nebula_color.rgb, 0.55), mix(nebula_color.rgb, accent_color.rgb, 0.42 + n2 * 0.33), clamp(dust * 0.85 + grit * 0.22, 0.0, 1.0));
		alpha = dust * (0.17 + 0.20 * strength) + grit * 0.055 * strength;
		if (foreground_mix > 0.5) alpha *= 0.56;
	} else if (profile_mode == 2) {
		float cloud = smoothstep(0.30, 0.73, broad);
		float filament = smoothstep(0.56, 0.88, n2 * 0.55 + n3 * 0.55);
		float cavity = 1.0 - smoothstep(0.24, 0.78, length(centered + vec2(0.18, -0.08)));
		color = mix(mix(background_color.rgb, nebula_color.rgb, 0.72), mix(nebula_color.rgb, accent_color.rgb, clamp(n2 * 0.82 + filament * 0.46, 0.0, 1.0)), clamp(cloud * 0.78 + filament * 0.48, 0.0, 1.0));
		alpha = cloud * (0.20 + 0.30 * strength) + filament * 0.16 * strength + cavity * 0.055 * strength;
		if (foreground_mix > 0.5) alpha = filament * (0.10 + 0.18 * strength) + cloud * 0.075 * strength;
	} else if (profile_mode == 3) {
		float radial_flow = texture(noise_a, uv * 3.3 + direction * (t * 0.055) + camera_offset * 0.010).r;
		float plasma = smoothstep(0.44, 0.79, radial_flow * 0.72 + n2 * 0.38);
		float corona = 1.0 - smoothstep(0.14, 0.92, radius);
		float shock = band(radius + (n3 - 0.5) * 0.10, 0.43 + tri_wave(t * 0.025) * 0.05, 0.09);
		float stream = smoothstep(0.62, 0.92, n3) * smoothstep(0.18, 0.95, radius);
		color = mix(nebula_color.rgb, mix(nebula_color.rgb, accent_color.rgb, 0.65 + n3 * 0.30), clamp(plasma + shock * 0.85, 0.0, 1.0));
		alpha = corona * plasma * (0.16 + 0.24 * strength) + shock * 0.16 * strength + stream * 0.075 * strength;
		if (foreground_mix > 0.5) alpha = stream * 0.10 * strength + plasma * corona * 0.085 * strength;
	} else if (profile_mode == 4) {
		float swirl_noise = texture(noise_b, uv * 4.1 + tangent * (t * 0.042) + direction * n1 * 0.11).r;
		float inner_ring = band(radius + (swirl_noise - 0.5) * 0.075, 0.31, 0.075);
		float outer_ring = band(radius + (n3 - 0.5) * 0.11, 0.51, 0.13);
		float core = 1.0 - smoothstep(0.10, 0.285, radius);
		float lens = band(radius, 0.36, 0.17);
		color = mix(mix(nebula_color.rgb, accent_color.rgb, 0.24 + swirl_noise * 0.72), mix(accent_color.rgb, vec3(1.0, 0.70, 0.34), 0.42), clamp(inner_ring * 0.82 + n2 * 0.22, 0.0, 1.0));
		alpha = max(inner_ring, outer_ring * 0.62) * (0.18 + 0.30 * strength) + lens * 0.055 * strength;
		if (core > 0.0) {
			color = mix(color, vec3(0.0), core * 0.96);
			alpha = max(alpha, core * (0.42 + 0.18 * strength));
		}
		if (foreground_mix > 0.5) alpha = outer_ring * 0.075 * strength + smoothstep(0.70, 0.93, swirl_noise) * lens * 0.08 * strength;
	} else if (profile_mode == 5) {
		float smog = smoothstep(0.37, 0.78, broad);
		float panel_band = band(uv.y + (n1 - 0.5) * 0.12, 0.46, 0.22);
		float sparks = smoothstep(0.88, 0.965, n3) * tri_wave(uv.y * 92.0 + t * 0.8);
		float scan = band(tri_wave(uv.y * 38.0 + t * 0.08), 0.22, 0.035);
		color = mix(mix(background_color.rgb, nebula_color.rgb, 0.55), accent_color.rgb, sparks * 0.85 + scan * 0.16);
		alpha = smog * panel_band * (0.10 + 0.18 * strength) + sparks * 0.20 * strength + scan * 0.025 * strength;
		if (foreground_mix > 0.5) alpha = sparks * 0.24 * strength + smog * 0.035 * strength;
	} else if (profile_mode == 6) {
		float diagonal = band(uv.y + uv.x * 0.34 + (n1 - 0.5) * 0.22, 0.58, 0.20);
		float grit = smoothstep(0.66, 0.93, n3);
		float shards = smoothstep(0.80, 0.965, n2) * smoothstep(0.55, 0.90, n3);
		color = mix(nebula_color.rgb, accent_color.rgb, clamp(grit * 0.55 + shards, 0.0, 1.0));
		alpha = diagonal * smoothstep(0.40, 0.78, broad) * (0.13 + 0.23 * strength) + grit * 0.07 * strength + shards * 0.13 * strength;
		if (foreground_mix > 0.5) alpha = grit * 0.11 * strength + shards * 0.17 * strength;
	} else if (profile_mode == 7) {
		float frost = smoothstep(0.54, 0.84, n2 * 0.48 + n3 * 0.62);
		float vein_x = 1.0 - smoothstep(0.035, 0.11, abs(tri_wave(uv.x * 8.0 + n1 * 0.8) - 0.5));
		float vein_y = 1.0 - smoothstep(0.035, 0.11, abs(tri_wave(uv.y * 7.0 + n2 * 0.7) - 0.5));
		float crystal_veil = frost * max(vein_x, vein_y);
		color = mix(nebula_color.rgb, mix(accent_color.rgb, vec3(1.0), 0.48), 0.45 + frost * 0.55);
		alpha = frost * (0.08 + 0.15 * strength) + crystal_veil * 0.16 * strength;
		if (foreground_mix > 0.5) alpha = crystal_veil * 0.16 * strength + frost * 0.035 * strength;
	} else if (profile_mode == 8) {
		float latitude = uv.y + (n1 - 0.5) * 0.18 + (n2 - 0.5) * 0.07;
		float band_a = band(latitude, 0.35 + tri_wave(t * 0.007) * 0.04, 0.10);
		float band_b = band(latitude, 0.62 - tri_wave(t * 0.006) * 0.035, 0.13);
		float storm = smoothstep(0.50, 0.80, broad) * max(band_a, band_b);
		float eddy = band(radius + (n3 - 0.5) * 0.12, 0.44, 0.15);
		color = mix(nebula_color.rgb, accent_color.rgb, clamp(band_a * 0.45 + band_b * 0.25 + storm * 0.45, 0.0, 1.0));
		alpha = (band_a * 0.12 + band_b * 0.10 + storm * 0.18 + eddy * 0.045) * strength;
		if (foreground_mix > 0.5) alpha *= 0.45;
	} else if (profile_mode == 9) {
		float swell = band(uv.y + (n1 - 0.5) * 0.24, 0.47 + (tri_wave(t * 0.013) - 0.5) * 0.10, 0.19);
		float caustic_x = 1.0 - smoothstep(0.08, 0.22, abs(tri_wave(uv.x * 6.0 + n2 * 0.6 + t * 0.018) - 0.5));
		float caustic_y = 1.0 - smoothstep(0.08, 0.22, abs(tri_wave(uv.y * 5.0 + n1 * 0.5 - t * 0.013) - 0.5));
		float caustic = caustic_x * caustic_y * smoothstep(0.40, 0.78, broad);
		color = mix(nebula_color.rgb, accent_color.rgb, 0.36 + caustic * 0.64);
		alpha = swell * (0.13 + 0.18 * strength) + caustic * 0.16 * strength;
		if (foreground_mix > 0.5) alpha = caustic * 0.13 * strength + swell * 0.035 * strength;
	} else if (profile_mode == 10) {
		float pulse_a = band(radius + (n1 - 0.5) * 0.035, 0.28 + tri_wave(t * 0.15) * 0.10, 0.035);
		float pulse_b = band(radius + (n2 - 0.5) * 0.045, 0.55 + tri_wave(t * 0.11 + 0.4) * 0.12, 0.045);
		float field_line = smoothstep(0.72, 0.94, n3) * (1.0 - smoothstep(0.22, 1.0, radius));
		float beam = band(abs(focal_delta.y), 0.0, 0.025 + 0.025 * n2) * smoothstep(0.15, 0.85, abs(focal_delta.x));
		color = mix(nebula_color.rgb, accent_color.rgb, clamp(pulse_a + pulse_b + field_line + beam, 0.0, 1.0));
		alpha = (pulse_a * 0.19 + pulse_b * 0.14 + field_line * 0.12 + beam * 0.20) * strength;
		if (foreground_mix > 0.5) alpha *= 0.62;
	} else if (profile_mode == 11) {
		float plane = abs(focal_delta.y + focal_delta.x * 0.27 + (n1 - 0.5) * 0.055);
		float ring_main = 1.0 - smoothstep(0.025, 0.15, plane);
		float ring_inner = band(plane, 0.10, 0.035);
		float ring_outer = band(plane, 0.22, 0.055);
		float dust = smoothstep(0.62, 0.91, n3) * ring_main;
		color = mix(nebula_color.rgb, accent_color.rgb, clamp(ring_inner * 0.8 + ring_outer * 0.45 + dust, 0.0, 1.0));
		alpha = (ring_main * 0.10 + ring_inner * 0.14 + ring_outer * 0.09 + dust * 0.09) * strength;
		if (foreground_mix > 0.5) alpha = dust * 0.12 * strength + ring_inner * 0.045 * strength;
	} else if (profile_mode == 12) {
		float ash = smoothstep(0.48, 0.82, broad);
		float ember = smoothstep(0.83, 0.965, n3);
		float plume = band(uv.y + (n1 - 0.5) * 0.36, 0.60 - tri_wave(t * 0.017) * 0.12, 0.22);
		float heat = 1.0 - smoothstep(0.18, 0.90, radius);
		color = mix(mix(background_color.rgb, nebula_color.rgb, 0.58), accent_color.rgb, clamp(ember * 0.95 + heat * 0.38, 0.0, 1.0));
		alpha = ash * plume * (0.13 + 0.19 * strength) + ember * 0.16 * strength + heat * 0.055 * strength;
		if (foreground_mix > 0.5) alpha = ember * 0.21 * strength + ash * plume * 0.045 * strength;
	} else if (profile_mode == 13) {
		float void_haze = smoothstep(0.58, 0.86, broad);
		float cold_glint = smoothstep(0.92, 0.985, n3);
		float isolation = smoothstep(0.16, 0.88, length(centered));
		color = mix(background_color.rgb, accent_color.rgb, cold_glint * 0.72 + void_haze * 0.10);
		alpha = void_haze * isolation * (0.035 + 0.07 * strength) + cold_glint * 0.055 * strength;
		if (foreground_mix > 0.5) alpha = cold_glint * 0.07 * strength;
	} else if (profile_mode == 14) {
		float cell_x = 1.0 - smoothstep(0.05, 0.18, abs(tri_wave(uv.x * 7.0 + n1 * 0.75) - 0.5));
		float cell_y = 1.0 - smoothstep(0.05, 0.18, abs(tri_wave(uv.y * 7.0 + n2 * 0.75) - 0.5));
		float lattice = max(cell_x, cell_y) * smoothstep(0.46, 0.80, broad);
		float sparkle = smoothstep(0.90, 0.985, n3);
		vec3 prism = mix(accent_color.rgb, vec3(0.78, 0.58, 1.0), n2 * 0.65);
		color = mix(nebula_color.rgb, prism, clamp(lattice + sparkle, 0.0, 1.0));
		alpha = lattice * (0.11 + 0.18 * strength) + sparkle * 0.19 * strength;
		if (foreground_mix > 0.5) alpha = sparkle * 0.22 * strength + lattice * 0.05 * strength;
	} else if (profile_mode == 15) {
		float cloud = smoothstep(0.34, 0.75, broad);
		float layer_a = band(uv.y + (n1 - 0.5) * 0.35, 0.40 + tri_wave(t * 0.008) * 0.08, 0.22);
		float layer_b = band(uv.y + (n2 - 0.5) * 0.26, 0.68 - tri_wave(t * 0.009) * 0.06, 0.18);
		float corrosive = smoothstep(0.74, 0.94, n3);
		vec3 sick = mix(nebula_color.rgb, accent_color.rgb, 0.48 + n2 * 0.35);
		color = mix(background_color.rgb, sick, clamp(cloud * 0.78 + corrosive * 0.36, 0.0, 1.0));
		alpha = cloud * (layer_a + layer_b * 0.72) * (0.12 + 0.20 * strength) + corrosive * 0.08 * strength;
		if (foreground_mix > 0.5) alpha = cloud * layer_b * 0.075 * strength + corrosive * 0.10 * strength;
	} else if (profile_mode == 16) {
		float murk = smoothstep(0.44, 0.80, broad);
		float wreck_lane = band(uv.y + uv.x * 0.18 + (n1 - 0.5) * 0.19, 0.53, 0.26);
		float dead_spark = smoothstep(0.91, 0.985, n3) * tri_wave(t * 0.23 + uv.x * 17.0);
		float beacon = band(tri_wave(uv.y * 24.0 + t * 0.035), 0.18, 0.025);
		color = mix(mix(background_color.rgb, nebula_color.rgb, 0.66), accent_color.rgb, dead_spark * 0.78 + beacon * 0.10);
		alpha = murk * wreck_lane * (0.08 + 0.14 * strength) + dead_spark * 0.15 * strength + beacon * 0.015 * strength;
		if (foreground_mix > 0.5) alpha = dead_spark * 0.18 * strength + murk * 0.028 * strength;
	} else if (profile_mode == 17) {
		float filament = smoothstep(0.56, 0.87, n2 * 0.52 + n3 * 0.58);
		float shell_a = band(radius + (n1 - 0.5) * 0.06, 0.34 + tri_wave(t * 0.012) * 0.05, 0.055);
		float shell_b = band(radius + (n2 - 0.5) * 0.08, 0.66 + tri_wave(t * 0.009 + 0.3) * 0.07, 0.085);
		float cloud = smoothstep(0.34, 0.72, broad);
		color = mix(nebula_color.rgb, accent_color.rgb, clamp(filament * 0.65 + shell_a + shell_b * 0.55, 0.0, 1.0));
		alpha = cloud * (0.09 + 0.13 * strength) + filament * 0.16 * strength + shell_a * 0.17 * strength + shell_b * 0.11 * strength;
		if (foreground_mix > 0.5) alpha = filament * 0.12 * strength + shell_a * 0.055 * strength;
	} else {
		color = mix(nebula_color.rgb, accent_color.rgb, broad);
		alpha = smoothstep(0.55, 0.82, broad) * 0.10 * strength;
	}

	alpha *= (0.82 + foreground_mix * 0.18);
	COLOR = vec4(color, clamp(alpha, 0.0, 0.72));
}
