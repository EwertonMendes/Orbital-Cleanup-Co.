shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(0.45, 0.90, 1.0, 1.0);
uniform vec2 texel_size = vec2(0.001, 0.001);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.65;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.7;
uniform float quality_factor : hint_range(0.0, 1.0) = 1.0;
uniform int profile_mode = 0;

float tri_wave(float value) {
	return abs(fract(value) - 0.5) * 2.0;
}

void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	vec2 o1 = texel_size * 3.0;
	vec2 o2 = texel_size * 7.0;
	float blur = center_alpha * 0.20;
	blur += texture(TEXTURE, UV + vec2(o1.x, 0.0)).a * 0.10;
	blur += texture(TEXTURE, UV - vec2(o1.x, 0.0)).a * 0.10;
	blur += texture(TEXTURE, UV + vec2(0.0, o1.y)).a * 0.10;
	blur += texture(TEXTURE, UV - vec2(0.0, o1.y)).a * 0.10;
	blur += texture(TEXTURE, UV + vec2(o2.x, o2.y)).a * 0.10;
	blur += texture(TEXTURE, UV + vec2(-o2.x, o2.y)).a * 0.10;
	blur += texture(TEXTURE, UV + vec2(o2.x, -o2.y)).a * 0.10;
	blur += texture(TEXTURE, UV - o2).a * 0.10;

	float pulse = 0.82 + tri_wave(TIME * (0.07 + float(profile_mode) * 0.012)) * 0.18;
	float profile_boost = 1.0;
	if (profile_mode == 2) {
		profile_boost = 1.20;
	} else if (profile_mode == 3) {
		profile_boost = 1.55;
	} else if (profile_mode == 4) {
		profile_boost = 1.32;
	}
	float halo = max(blur - center_alpha * 0.22, center_alpha * 0.12);
	float alpha = halo * glow_strength * effect_strength * quality_factor * profile_boost * pulse;
	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
