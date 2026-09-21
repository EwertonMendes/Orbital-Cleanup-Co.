shader_type canvas_item;
render_mode unshaded;

uniform vec4 category_tint : source_color = vec4(0.33, 0.86, 1.0, 1.0);
uniform vec4 rarity_tint : source_color = vec4(1.0, 0.82, 0.40, 1.0);
uniform float energy_strength : hint_range(0.0, 1.0) = 0.7;
uniform float outline_strength : hint_range(0.0, 1.5) = 0.72;
uniform float pulse_speed : hint_range(0.5, 6.0) = 3.2;
uniform float sweep_speed : hint_range(0.02, 0.4) = 0.13;
uniform float effect_mode : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);

	float outline = max(neighbor_alpha - tex.a, 0.0);
	float pulse = 0.72 + sin(TIME * pulse_speed + UV.y * 12.0) * 0.28;
	float sweep = smoothstep(0.0, 0.18, 1.0 - abs(fract(UV.y + TIME * sweep_speed) - 0.5) * 2.0);
	float radial = 1.0 - clamp(distance(UV, vec2(0.5)) * 1.8, 0.0, 1.0);
	float scan_band = smoothstep(0.92, 1.0, sin((UV.y + UV.x * 0.12 + TIME * sweep_speed) * 32.0) * 0.5 + 0.5);

	vec3 body = mix(tex.rgb, tex.rgb * category_tint.rgb * 1.26, 0.14);
	body += rarity_tint.rgb * sweep * 0.05 * energy_strength * tex.a;
	if (effect_mode > 0.5 && effect_mode < 1.5) {
		body += category_tint.rgb * scan_band * 0.08 * energy_strength * tex.a;
	} else if (effect_mode > 1.5 && effect_mode < 2.5) {
		body += category_tint.rgb * radial * pulse * 0.055 * energy_strength * tex.a;
	} else if (effect_mode > 2.5 && effect_mode < 3.5) {
		body += rarity_tint.rgb * radial * 0.045 * energy_strength * tex.a;
	} else if (effect_mode > 3.5) {
		body += category_tint.rgb * scan_band * pulse * 0.065 * energy_strength * tex.a;
	}

	vec3 glow = rarity_tint.rgb * pulse;
	COLOR.rgb = mix(glow, body, tex.a);
	COLOR.a = max(tex.a, outline * outline_strength * energy_strength);
}
