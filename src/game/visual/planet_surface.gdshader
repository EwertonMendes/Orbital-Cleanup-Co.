shader_type canvas_item;
render_mode unshaded;

uniform vec4 atmosphere_color : source_color = vec4(0.45, 0.87, 1.0, 1.0);
uniform float rotation_speed : hint_range(-0.08, 0.08) = 0.008;
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.42;
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.10;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float angle = TIME * rotation_speed;
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = mat2(vec2(c, -s), vec2(s, c)) * centered + vec2(0.5);
	vec4 base = texture(TEXTURE, rotated);

	float radius = length(centered) * 2.0;
	float edge = smoothstep(0.58, 0.98, radius) * (1.0 - smoothstep(0.98, 1.08, radius));
	float bands = sin((centered.y * 19.0 + centered.x * 7.0) + TIME * 0.18) * 0.5 + 0.5;
	float shimmer = bands * shimmer_strength * (1.0 - smoothstep(0.45, 1.0, radius));

	base.rgb += atmosphere_color.rgb * edge * atmosphere_strength * base.a;
	base.rgb += atmosphere_color.rgb * shimmer * 0.08 * base.a;
	COLOR = base;
}
