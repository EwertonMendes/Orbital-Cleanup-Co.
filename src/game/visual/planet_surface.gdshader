shader_type canvas_item;
render_mode unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.45, 0.87, 1.0, 1.0);
uniform float rotation_speed : hint_range(-0.08, 0.08) = 0.008;
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.42;
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.10;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered) * 2.0;
	float edge = smoothstep(0.60, 0.98, radius) * (1.0 - smoothstep(0.98, 1.08, radius));
	float daylight = clamp(1.0 - (UV.x * 0.70 + UV.y * 0.18), 0.0, 1.0);
	base.rgb += atmosphere_color.rgb * edge * atmosphere_strength * base.a;
	base.rgb += atmosphere_color.rgb * daylight * shimmer_strength * 0.025 * base.a;
	COLOR = base;
}
