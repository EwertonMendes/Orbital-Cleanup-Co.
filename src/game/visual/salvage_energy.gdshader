shader_type canvas_item;
render_mode unshaded;

uniform vec4 category_tint : source_color = vec4(0.33, 0.86, 1.0, 1.0);
uniform vec4 rarity_tint : source_color = vec4(1.0, 0.82, 0.40, 1.0);
uniform float energy_strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);

	float outline = max(neighbor_alpha - tex.a, 0.0);
	float pulse = 0.72 + sin(TIME * 3.2 + UV.y * 12.0) * 0.28;
	float sweep = smoothstep(0.0, 0.18, 1.0 - abs(fract(UV.y + TIME * 0.13) - 0.5) * 2.0);

	vec3 body = mix(tex.rgb, tex.rgb * category_tint.rgb * 1.30, 0.16);
	body += rarity_tint.rgb * sweep * 0.055 * energy_strength * tex.a;
	vec3 glow = rarity_tint.rgb * pulse;

	COLOR.rgb = mix(glow, body, tex.a);
	COLOR.a = max(tex.a, outline * 0.68 * energy_strength);
}
