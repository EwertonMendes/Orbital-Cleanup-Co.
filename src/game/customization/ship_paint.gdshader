shader_type canvas_item;

uniform vec4 paint_color : source_color = vec4(0.224, 0.714, 0.910, 1.0);
uniform float paint_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float max_rg = max(tex.r, tex.g);
	float blue_bias = max(tex.b - max_rg * 0.94, 0.0);
	float saturation = max(max(tex.r, tex.g), tex.b) - min(min(tex.r, tex.g), tex.b);
	float paint_mask = smoothstep(0.025, 0.22, blue_bias + saturation * 0.10);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 painted = paint_color.rgb * (0.42 + luminance * 0.92);
	vec3 rgb = mix(tex.rgb, painted, paint_mask * paint_strength);
	COLOR = vec4(rgb, tex.a) * COLOR;
}
